# CI/CD Pipelines

## Why This Matters

Every line of code you write will eventually run in production. The path from your keyboard to production is your deployment pipeline. A good pipeline gives you confidence. A bad one — or none at all — gives you anxiety.

**Continuous Integration (CI)** means every code change is automatically tested. Push a commit, tests run. Open a PR, tests run. Merge to main, tests run. No human has to remember to run tests — the system does it.

**Continuous Deployment (CD)** means tested code automatically deploys. Merge to main, tests pass, production updates. No human has to remember to deploy — the system does it.

Together, CI/CD removes manual steps from your workflow. Manual steps are error-prone. Manual steps are slow. Manual steps get skipped when you're in a rush. Automation is reliable.

By the end of this chapter, you'll have a GitHub Actions pipeline that tests every PR and deploys every merge to main. Shipping code will feel routine, not risky.

## A Complete CI Pipeline

Here's a production-quality CI pipeline:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '20'

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck

  test:
    runs-on: ubuntu-latest
    needs: lint

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      - run: npm ci
      - name: Run migrations
        run: npm run db:migrate
        env:
          DATABASE_URL: postgres://test:test@localhost:5432/test
      - name: Run tests
        run: npm test -- --coverage
        env:
          DATABASE_URL: postgres://test:test@localhost:5432/test
          REDIS_URL: redis://localhost:6379

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      - run: npm ci
      - run: npm audit --audit-level=high

  build:
    runs-on: ubuntu-latest
    needs: [lint, test, security]
    steps:
      - uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Build Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          tags: my-api:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

This runs lint, tests with real Postgres/Redis, security scanning, and Docker build. Jobs run in parallel where possible; `needs:` creates dependencies.

The key patterns:
- **Service containers** give you real databases in CI — no mocking
- **Caching** (`cache: 'npm'`, `cache-from: type=gha`) makes subsequent runs fast
- **Health checks** ensure services are ready before tests run

💸 **Startup Cost Callout:** GitHub Actions is free for public repos. Private repos get 2,000 minutes/month free. Most startups never exceed this.

## Continuous Deployment

CD deploys verified code automatically. Here's a complete workflow for Fly.io (the simplest production path):

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: superfly/flyctl-actions/setup-flyctl@master
      - run: flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

That's it. Push to main, tests pass, production updates.

For AWS ECS, the pattern is similar but more verbose — authenticate via OIDC, push to ECR, trigger ECS deployment. The core flow is the same: push → build → deploy.

### Environment Protection

For production deployments, add approval gates:

```yaml
jobs:
  deploy-staging:
    environment: staging
    # Deploys immediately

  deploy-production:
    environment: production
    needs: deploy-staging
    # Requires manual approval (configured in GitHub settings)
```

Configure environments in Settings → Environments. Add required reviewers for production.

## Database Migrations: The Expand/Contract Pattern

Migrations are where deployments get tricky. You can't just run a migration and deploy — during the transition, old code instances are still running.

The **expand/contract** pattern makes migrations safe:

**Phase 1: Expand (backward-compatible)**
Add new schema that works with both old and new code.

```sql
-- Migration: Add status column (nullable, with default)
ALTER TABLE tasks ADD COLUMN status_v2 varchar(20) DEFAULT 'pending';
```

```typescript
// Code: Write to both columns during transition
await db.update(tasks).set({
  status: newStatus,      // Old column (still used by old code)
  status_v2: newStatus    // New column
})
```

**Phase 2: Migrate data**
Backfill the new column:

```sql
UPDATE tasks SET status_v2 = status WHERE status_v2 IS NULL;
```

**Phase 3: Contract**
Once all code uses the new column, remove the old one:

```sql
ALTER TABLE tasks DROP COLUMN status;
ALTER TABLE tasks RENAME COLUMN status_v2 TO status;
```

The key insight: **never deploy a migration that breaks currently-running code**. If old instances can't write to the database, you'll have errors during deployment.

```yaml
# In your workflow: run migrations BEFORE deploying new code
- name: Run migrations
  run: npm run db:migrate:production
  env:
    DATABASE_URL: ${{ secrets.PRODUCTION_DATABASE_URL }}

- name: Deploy new code
  run: flyctl deploy --remote-only
```

🤔 **Taste Moment:** If a migration requires the expand/contract pattern, that's three deployments, not one. Plan for this. Most teams get bitten by "just add a required column" — it breaks old code that doesn't know about the column.

## Feature Flags: Deploy Without Releasing

Feature flags are the most underused tool in startup engineering. They decouple deployment from release — you can ship code to production without users seeing it.

Here's a simple database-backed implementation:

```typescript
// src/modules/featureFlags/schema.ts
export const featureFlags = pgTable('feature_flags', {
  id: text('id').primaryKey(),
  name: text('name').notNull().unique(),
  enabled: boolean('enabled').notNull().default(false),
  rolloutPercent: integer('rollout_percent').default(0),  // 0-100
  allowedUserIds: text('allowed_user_ids').array(),       // For beta users
  createdAt: timestamp('created_at').defaultNow()
})
```

```typescript
// src/modules/featureFlags/service.ts
import { createHash } from 'crypto'

export function createFeatureFlagService(db: Database, redis: Redis) {
  // Cache flags in Redis for fast reads
  async function getFlag(name: string): Promise<FeatureFlag | null> {
    const cached = await redis.get(`ff:${name}`)
    if (cached) return JSON.parse(cached)

    const flag = await db.query.featureFlags.findFirst({
      where: eq(featureFlags.name, name)
    })

    if (flag) {
      await redis.setex(`ff:${name}`, 60, JSON.stringify(flag))  // 1 min cache
    }
    return flag
  }

  async function isEnabled(name: string, userId?: string): Promise<boolean> {
    const flag = await getFlag(name)
    if (!flag) return false
    if (!flag.enabled) return false

    // Check if user is in allowed list (beta users)
    if (userId && flag.allowedUserIds?.includes(userId)) {
      return true
    }

    // Percentage rollout: hash user ID for consistent bucketing
    if (flag.rolloutPercent > 0 && userId) {
      const hash = createHash('md5').update(`${name}:${userId}`).digest('hex')
      const bucket = parseInt(hash.slice(0, 8), 16) % 100
      return bucket < flag.rolloutPercent
    }

    // If no user ID and no rollout, just check enabled
    return flag.rolloutPercent === 100 || flag.rolloutPercent === 0
  }

  return { isEnabled, getFlag }
}
```

```typescript
// Usage in your code
const featureFlags = createFeatureFlagService(db, redis)

app.get('/api/export', async (c) => {
  const user = c.get('user')

  if (await featureFlags.isEnabled('new-export-system', user.id)) {
    return newExportHandler(c)
  }
  return legacyExportHandler(c)
})
```

**The workflow:**
1. Deploy code with flag defaulting to `false`
2. Enable for internal users (add to `allowedUserIds`)
3. Roll out to 10%, monitor
4. Roll out to 50%, monitor
5. Roll out to 100%
6. Remove the flag and old code path

Feature flags let you:
- Ship incomplete features (hidden behind flags)
- A/B test changes
- Instant rollback (disable the flag, no deployment needed)
- Gradual rollouts to catch issues early

For production, consider LaunchDarkly or Unleash. But this simple implementation covers most startup needs.

🤔 **Taste Moment:** Feature flags add code complexity (if/else branches everywhere). Clean up flags aggressively — once a feature is at 100% for a week with no issues, remove the flag. Dead flags are technical debt.

## Rollbacks

When a deployment goes wrong, you need to revert fast.

**Immediate rollback (< 5 minutes):**

```bash
# Fly.io: deploy previous release
flyctl releases list
flyctl deploy --image registry.fly.io/my-api:v42  # Previous version

# Or revert the commit and push
git revert HEAD --no-edit
git push
```

**With feature flags (instant):**
If the broken code is behind a flag, just disable it. No deployment needed.

**Automated rollback:**

```yaml
- name: Deploy and verify
  run: |
    flyctl deploy --remote-only

    # Wait for deployment to stabilize
    sleep 30

    # Health check
    if ! curl -f https://my-api.fly.dev/health; then
      echo "Health check failed, rolling back"
      flyctl releases list
      flyctl deploy --image $(flyctl releases list --json | jq -r '.[1].image')
      exit 1
    fi
```

**Database rollback:**
This is harder. If a migration corrupted data, you need to restore from backup. This is why:
1. Test migrations thoroughly in staging
2. Use the expand/contract pattern
3. Have point-in-time recovery enabled on your database

🔒 **Security Callout:** Practice rollbacks before you need them. Run a drill: deploy a broken change to staging, time how long it takes to recover. If it's more than 10 minutes, improve your process.

## Branch Protection

Protect your main branch:

1. Settings → Branches → Add rule
2. Enable:
   - Require status checks (your CI jobs)
   - Require pull request reviews
   - Dismiss stale approvals when new commits are pushed

Now code can only reach main through reviewed, tested PRs.

## The Taste Test

**Scenario 1:** CI takes 15 minutes. Developers context-switch while waiting, then forget what they were working on.

*The fix:* CI should be under 5 minutes. Run jobs in parallel, cache aggressively, use path filtering to skip irrelevant tests. Speed is a feature of your pipeline.

**Scenario 2:** A migration adds a `NOT NULL` column. During deployment, old code instances crash because they don't provide the new column.

*What went wrong:* The migration wasn't backward-compatible. Add the column as nullable first, deploy code that writes to it, then make it required.

**Scenario 3:** A bug ships to production. The team debates whether to roll back or push a fix forward.

*The rule:* If you can fix it in 15 minutes, fix forward. If not, roll back immediately, then fix. Every minute of broken production is user pain.

**Scenario 4:** A feature is 90% done but the sprint ends. The team merges it anyway with `// TODO: finish this`.

*Better approach:* Use a feature flag. Merge the incomplete code, but keep it disabled. No pressure to ship half-baked features.

## Practical Exercise

Build a complete CI/CD pipeline for your TaskFlow project:

**Requirements:**
1. CI that runs lint, typecheck, tests with real database, and security scan
2. CD that deploys to staging on every push to main
3. Production deployment requiring manual approval
4. One feature behind a feature flag with percentage rollout
5. Documented rollback procedure (test it!)

**Acceptance criteria:**
- PRs cannot merge without passing CI
- You can roll back a bad deployment in under 5 minutes
- Feature flag can be toggled without deployment

**AI Integration:**

Have Claude review your workflow:

```
Review this GitHub Actions workflow for security and reliability:

[paste YAML]

Check for:
1. Exposed secrets or excessive permissions
2. Missing caching opportunities
3. Race conditions in deployments
4. Proper error handling
```

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can write GitHub Actions workflows that run tests with real databases
- [ ] I understand the expand/contract pattern for safe migrations
- [ ] I can implement feature flags for gradual rollouts
- [ ] I know how to roll back a failed deployment quickly
- [ ] I understand branch protection and why it matters

CI/CD transforms deployment from a scary event into a routine operation. Feature flags transform releases from all-or-nothing gambles into gradual rollouts. Together, they let you ship faster with less risk.
