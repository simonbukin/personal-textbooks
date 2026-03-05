# Testing Strategy

## Why This Matters

Every developer has shipped code that worked on their machine and broke in production. Tests exist to catch this before users do.

But testing isn't free. Tests take time to write, time to run, and time to maintain. Write too few and bugs slip through. Write too many of the wrong kind and you spend more time fixing tests than fixing code.

The question isn't "should I test?" — it's "what should I test?" This chapter gives you a pragmatic framework for making those decisions.

By the end, you'll know which tests provide the most value, how to structure your test suite, and how to avoid the common traps that make testing painful instead of productive.

## The Testing Pyramid (and Why It's Still Relevant)

The testing pyramid is old wisdom that still applies:

```
          /\
         /  \       End-to-End Tests
        /    \      (few, slow, expensive)
       /------\
      /        \    Integration Tests
     /          \   (some, medium speed)
    /------------\
   /              \ Unit Tests
  /                \ (many, fast, cheap)
 /------------------\
```

**Unit tests** verify individual functions or classes in isolation. They're fast (milliseconds), cheap to write, and catch logic errors early.

**Integration tests** verify that components work together. They test database queries, API endpoints, service interactions. Slower than unit tests but catch problems unit tests miss.

**End-to-end tests** verify complete user flows through the entire system. They're slow, brittle, and expensive to maintain, but they catch issues nothing else can.

The pyramid suggests you should have many unit tests, some integration tests, and few E2E tests. The rationale: fast tests give quick feedback, and you can cover more cases cheaply at the unit level.

But the pyramid isn't gospel. Backend applications often benefit from more integration tests than the classic pyramid suggests. A unit test for your repository layer doesn't catch SQL errors. An integration test with a real database does.

🤔 **Taste Moment:** For backend services, I advocate a "testing trophy" instead of a pyramid — heavier on integration tests than unit tests. Modern tooling (like running Postgres in Docker) makes integration tests fast enough to run frequently. Unit test pure logic; integration test anything touching infrastructure.

## What to Test

Focus testing effort where bugs cause the most damage:

**Test heavily:**
- Business logic with many edge cases
- Authorization rules
- Data transformations and calculations
- External API integrations
- Critical user flows (authentication, payments)

**Test lightly:**
- Simple CRUD operations (let integration tests cover these)
- Type-enforced code (TypeScript catches many errors at compile time)
- Third-party library wrappers (trust the library's tests)

**Don't test:**
- Framework behavior (Hono routing works, you don't need to verify it)
- Language features
- Code you're about to delete

```typescript
// Worth testing - complex business logic
function calculateSubscriptionPrice(
  plan: Plan,
  quantity: number,
  coupon: Coupon | null,
  billingPeriod: 'monthly' | 'annual'
): number {
  // Many edge cases: discounts, annual pricing, quantity breaks, etc.
}

// Not worth unit testing - simple getter
function getTaskTitle(task: Task): string {
  return task.title
}
```

## Unit Testing Pure Functions

Start with the easiest wins: pure functions. These take inputs and return outputs with no side effects. They're trivial to test.

```typescript
// src/utils/pricing.ts
export function calculateLineItemTotal(
  unitPrice: number,
  quantity: number,
  discountPercent: number = 0
): number {
  if (quantity <= 0) return 0
  if (discountPercent < 0 || discountPercent > 100) {
    throw new Error('Invalid discount percentage')
  }

  const subtotal = unitPrice * quantity
  const discount = subtotal * (discountPercent / 100)
  return Math.round((subtotal - discount) * 100) / 100  // Round to cents
}
```

```typescript
// src/utils/pricing.test.ts
import { describe, it, expect } from 'vitest'
import { calculateLineItemTotal } from './pricing'

describe('calculateLineItemTotal', () => {
  it('calculates basic total without discount', () => {
    expect(calculateLineItemTotal(10, 5)).toBe(50)
  })

  it('applies percentage discount', () => {
    expect(calculateLineItemTotal(100, 1, 20)).toBe(80)
  })

  it('rounds to cents', () => {
    expect(calculateLineItemTotal(10.333, 3)).toBe(31)  // 30.999 rounds to 31
  })

  it('returns 0 for zero quantity', () => {
    expect(calculateLineItemTotal(100, 0)).toBe(0)
  })

  it('returns 0 for negative quantity', () => {
    expect(calculateLineItemTotal(100, -5)).toBe(0)
  })

  it('throws for invalid discount', () => {
    expect(() => calculateLineItemTotal(100, 1, 150)).toThrow('Invalid discount')
    expect(() => calculateLineItemTotal(100, 1, -10)).toThrow('Invalid discount')
  })
})
```

Notice the test structure:
- Each test has a single assertion (mostly)
- Test names describe the behavior, not the implementation
- Edge cases are tested explicitly
- Invalid inputs are tested for proper error handling

### Testing Authorization Policies

Remember the policy pattern from Chapter 9? Policies are perfect for unit testing:

```typescript
// src/modules/workspace/policy.test.ts
import { describe, it, expect } from 'vitest'
import { workspacePolicy } from './policy'

describe('workspacePolicy', () => {
  const owner = { id: '1', role: 'owner' } as WorkspaceMembership
  const admin = { id: '2', role: 'admin' } as WorkspaceMembership
  const member = { id: '3', role: 'member' } as WorkspaceMembership

  describe('canDelete', () => {
    it('allows owners to delete', () => {
      expect(workspacePolicy.canDelete(owner)).toBe(true)
    })

    it('prevents admins from deleting', () => {
      expect(workspacePolicy.canDelete(admin)).toBe(false)
    })

    it('prevents members from deleting', () => {
      expect(workspacePolicy.canDelete(member)).toBe(false)
    })

    it('returns false for null membership', () => {
      expect(workspacePolicy.canDelete(null)).toBe(false)
    })
  })

  describe('canInvite', () => {
    it('allows owners to invite', () => {
      expect(workspacePolicy.canInvite(owner)).toBe(true)
    })

    it('allows admins to invite', () => {
      expect(workspacePolicy.canInvite(admin)).toBe(true)
    })

    it('prevents members from inviting', () => {
      expect(workspacePolicy.canInvite(member)).toBe(false)
    })
  })
})
```

These tests run in milliseconds and catch authorization regressions immediately.

## Integration Testing with Databases

Unit tests can't catch SQL errors, transaction bugs, or constraint violations. For that, you need integration tests with a real database.

### Setting Up a Test Database

Use Docker to run a test database:

```yaml
# docker-compose.test.yml
services:
  postgres-test:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: test
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
    ports:
      - "5433:5432"
    tmpfs:
      - /var/lib/postgresql/data  # RAM disk for speed
```

```typescript
// src/test/setup.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import { migrate } from 'drizzle-orm/postgres-js/migrator'

const connectionString = process.env.TEST_DATABASE_URL
  || 'postgres://test:test@localhost:5433/test'

export const testDb = drizzle(postgres(connectionString))

export async function setupTestDatabase() {
  // Run migrations
  await migrate(testDb, { migrationsFolder: './drizzle' })
}

export async function teardownTestDatabase() {
  // Truncate all tables between tests
  await testDb.execute(sql`
    DO $$ DECLARE
      r RECORD;
    BEGIN
      FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.tablename) || ' CASCADE';
      END LOOP;
    END $$;
  `)
}
```

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globalSetup: './src/test/globalSetup.ts',
    setupFiles: ['./src/test/setup.ts']
  }
})
```

### Testing Repository Functions

```typescript
// src/modules/task/repository.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { testDb, teardownTestDatabase } from '../../test/setup'
import { createTaskRepository } from './repository'
import { tasks, projects, workspaces } from '../../db/schema'

describe('TaskRepository', () => {
  const repository = createTaskRepository(testDb)

  beforeEach(async () => {
    await teardownTestDatabase()

    // Seed test data
    await testDb.insert(workspaces).values({
      id: 'workspace-1',
      name: 'Test Workspace'
    })

    await testDb.insert(projects).values({
      id: 'project-1',
      name: 'Test Project',
      workspaceId: 'workspace-1'
    })
  })

  describe('create', () => {
    it('creates a task with all fields', async () => {
      const task = await repository.create({
        title: 'Test Task',
        projectId: 'project-1',
        assigneeId: 'user-1'
      })

      expect(task.id).toBeDefined()
      expect(task.title).toBe('Test Task')
      expect(task.status).toBe('pending')  // Default value
    })

    it('fails with invalid project ID', async () => {
      await expect(
        repository.create({
          title: 'Test Task',
          projectId: 'nonexistent'
        })
      ).rejects.toThrow()  // Foreign key violation
    })
  })

  describe('findByProject', () => {
    it('returns tasks for the project', async () => {
      await repository.create({ title: 'Task 1', projectId: 'project-1' })
      await repository.create({ title: 'Task 2', projectId: 'project-1' })

      const found = await repository.findByProject('project-1')

      expect(found).toHaveLength(2)
      expect(found.map(t => t.title)).toContain('Task 1')
      expect(found.map(t => t.title)).toContain('Task 2')
    })

    it('returns empty array for project with no tasks', async () => {
      const found = await repository.findByProject('project-1')
      expect(found).toEqual([])
    })
  })
})
```

💸 **Startup Cost Callout:** Running Postgres in Docker with tmpfs (RAM disk) makes integration tests fast — hundreds of tests per minute. The setup cost is minimal compared to the bugs caught.

### Testing Service Layer

Service tests verify business logic while using real dependencies:

```typescript
// src/modules/task/service.test.ts
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { createTaskService } from './service'
import { testDb, teardownTestDatabase } from '../../test/setup'

describe('TaskService', () => {
  const mockNotificationService = {
    notify: vi.fn()
  }

  const service = createTaskService({
    db: testDb,
    notificationService: mockNotificationService
  })

  beforeEach(async () => {
    await teardownTestDatabase()
    vi.clearAllMocks()
    // Seed test data...
  })

  describe('completeTask', () => {
    it('updates status and notifies assignee', async () => {
      const task = await createTask({ assigneeId: 'user-1' })

      await service.completeTask(task.id, 'user-2')

      const updated = await service.getTask(task.id)
      expect(updated.status).toBe('complete')
      expect(updated.completedAt).toBeDefined()

      expect(mockNotificationService.notify).toHaveBeenCalledWith(
        'user-1',
        expect.objectContaining({
          type: 'task_completed',
          taskId: task.id
        })
      )
    })

    it('throws if task already complete', async () => {
      const task = await createTask({ status: 'complete' })

      await expect(
        service.completeTask(task.id, 'user-1')
      ).rejects.toThrow('Task is already complete')
    })
  })
})
```

Notice how we mock the notification service but use the real database. This is the sweet spot — test the critical path (database operations) while isolating external effects (notifications).

## API Integration Tests

Test your HTTP endpoints with real requests:

```typescript
// src/modules/task/routes.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { app } from '../../index'
import { testDb, teardownTestDatabase } from '../../test/setup'

describe('Task API', () => {
  beforeEach(async () => {
    await teardownTestDatabase()
    // Seed workspace, project, and test user
  })

  describe('POST /api/tasks', () => {
    it('creates a task', async () => {
      const response = await app.request('/api/tasks', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer test-token'
        },
        body: JSON.stringify({
          title: 'New Task',
          projectId: 'project-1'
        })
      })

      expect(response.status).toBe(201)

      const body = await response.json()
      expect(body.id).toBeDefined()
      expect(body.title).toBe('New Task')
    })

    it('returns 400 for missing title', async () => {
      const response = await app.request('/api/tasks', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer test-token'
        },
        body: JSON.stringify({
          projectId: 'project-1'
        })
      })

      expect(response.status).toBe(400)

      const body = await response.json()
      expect(body.details.title).toBeDefined()
    })

    it('returns 401 without authentication', async () => {
      const response = await app.request('/api/tasks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: 'New Task',
          projectId: 'project-1'
        })
      })

      expect(response.status).toBe(401)
    })
  })
})
```

Hono's `app.request()` method lets you test without running a server. Tests are fast and isolated.

## Testing Background Jobs

Jobs are tricky to test because they run asynchronously. Test the job handler, not the queueing:

```typescript
// src/workers/export.worker.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { Job } from 'bullmq'
import { processExport } from './export.processor'

describe('Export Worker', () => {
  const mockStorage = {
    upload: vi.fn().mockResolvedValue('https://s3.example.com/export.pdf')
  }

  const mockNotify = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('generates PDF and uploads to storage', async () => {
    const job = {
      data: {
        workspaceId: 'workspace-1',
        userId: 'user-1',
        format: 'pdf'
      },
      updateProgress: vi.fn()
    } as unknown as Job

    const result = await processExport(job, {
      storage: mockStorage,
      notify: mockNotify
    })

    expect(result.url).toBe('https://s3.example.com/export.pdf')
    expect(mockStorage.upload).toHaveBeenCalled()
    expect(mockNotify).toHaveBeenCalledWith('user-1', expect.any(Object))
  })

  it('handles empty workspace gracefully', async () => {
    const job = {
      data: {
        workspaceId: 'empty-workspace',
        userId: 'user-1',
        format: 'csv'
      },
      updateProgress: vi.fn()
    } as unknown as Job

    const result = await processExport(job, {
      storage: mockStorage,
      notify: mockNotify
    })

    // Should still produce a file, just empty
    expect(result.url).toBeDefined()
  })
})
```

For testing job queue behavior (retries, delays), use BullMQ's test utilities:

```typescript
// Full integration test with real queue
import { Queue, Worker, Job } from 'bullmq'

describe('Export Queue Integration', () => {
  let queue: Queue
  let worker: Worker
  const processedJobs: Job[] = []

  beforeAll(async () => {
    queue = new Queue('test-exports', { connection: testRedis })
    worker = new Worker('test-exports', async (job) => {
      processedJobs.push(job)
      return { processed: true }
    }, { connection: testRedis })
  })

  afterAll(async () => {
    await worker.close()
    await queue.obliterate({ force: true })
  })

  it('processes jobs in order', async () => {
    await queue.add('job-1', { order: 1 })
    await queue.add('job-2', { order: 2 })

    // Wait for processing
    await new Promise(r => setTimeout(r, 1000))

    expect(processedJobs[0].data.order).toBe(1)
    expect(processedJobs[1].data.order).toBe(2)
  })
})
```

## Test Organization

Structure tests to mirror your source code:

```
src/
├── modules/
│   ├── task/
│   │   ├── service.ts
│   │   ├── service.test.ts     # Unit tests
│   │   ├── repository.ts
│   │   ├── repository.test.ts  # Integration tests
│   │   ├── routes.ts
│   │   └── routes.test.ts      # API tests
│   └── ...
├── utils/
│   ├── pricing.ts
│   └── pricing.test.ts
└── test/
    ├── setup.ts          # Test utilities
    ├── globalSetup.ts    # Database setup
    └── fixtures/         # Test data factories
```

### Test Data Factories

Don't repeat test data setup. Use factories:

```typescript
// src/test/fixtures/task.factory.ts
import { faker } from '@faker-js/faker'

interface TaskOverrides {
  id?: string
  title?: string
  projectId?: string
  status?: TaskStatus
}

export function createTaskFixture(overrides: TaskOverrides = {}): Task {
  return {
    id: faker.string.uuid(),
    title: faker.lorem.sentence(),
    description: faker.lorem.paragraph(),
    status: 'pending',
    priority: 'medium',
    projectId: faker.string.uuid(),
    assigneeId: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides
  }
}

// Usage in tests
const task = createTaskFixture({ status: 'complete' })
```

## When to Write Tests

**Write tests first (TDD) when:**
- You're implementing complex business logic
- Requirements are clear and unlikely to change
- You want to drive cleaner design

**Write tests after when:**
- You're exploring or prototyping
- Requirements are fuzzy
- You're integrating with unfamiliar systems

**Write tests during when:**
- You're fixing bugs (write the test that proves the bug, then fix)
- You're refactoring (tests protect against regressions)

The point isn't dogma. The point is confidence. However you achieve it, your code should be tested before it goes to production.

## The Taste Test

**Scenario 1:** A developer writes a test that mocks the database, mocks the external API, and mocks the cache. The test passes, but the code fails in production.

*What went wrong?* Over-mocking. When everything is mocked, you're testing your mocks, not your code. Integration tests with real dependencies catch bugs mocks hide.

**Scenario 2:** The test suite takes 15 minutes to run. Developers skip running tests locally and wait for CI.

*What would you change?* Slow tests don't get run. Optimize: run Postgres with tmpfs, parallelize test files, split unit and integration tests into separate commands. Aim for under 2 minutes for the full suite.

**Scenario 3:** A test file has 500 lines with 50 test cases, many with complex setup. Adding a new test is painful.

*What's the fix?* Break it up. Extract setup into factories. Group related tests in describe blocks. If tests are hard to write, the code under test might need refactoring too.

**Scenario 4:** Every PR adds new tests, but old tests keep breaking because they depend on implementation details.

*What's happening?* Tests are too tightly coupled to implementation. Test behavior, not implementation. If you refactor code and functionality stays the same, tests shouldn't break.

**Scenario 5:** The team debates whether to write a unit test or integration test for a new service method.

*How do you decide?* Does the method contain complex logic independent of dependencies? Unit test it. Does it primarily orchestrate database calls? Integration test it. When in doubt, write the integration test — it provides more confidence.

## Practical Exercise

Build a comprehensive test suite for the task management API:

**Requirements:**

1. **Unit tests:**
   - Pricing calculations (if applicable)
   - Authorization policies
   - Date/time utilities
   - Data transformation functions

2. **Integration tests:**
   - All repository methods with real database
   - Service layer methods with real database, mocked external services
   - Background job processors

3. **API tests:**
   - CRUD operations for tasks, projects, workspaces
   - Authentication flows
   - Error responses (400, 401, 403, 404)
   - Pagination

4. **Test infrastructure:**
   - Docker Compose for test database
   - Test data factories
   - Proper setup/teardown between tests

**Acceptance criteria:**
- Test suite runs in under 3 minutes
- Code coverage is above 70% for critical paths
- Tests are independent (can run in any order)
- No mocking of database or Redis in integration tests

**AI Integration:**

Use Claude to generate test cases:

```
Here is a service method for completing a task:

[paste your code]

Generate test cases that cover:
1. Happy path
2. Edge cases (null values, empty arrays)
3. Error conditions
4. Authorization boundaries
5. Concurrent access scenarios

For each test case, explain what bug it would catch.
```

Implement the generated test cases and document which ones caught real issues.

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I understand the testing pyramid and when to deviate from it
- [ ] I can write focused unit tests for pure functions and policies
- [ ] I can set up integration tests with a real database
- [ ] I know how to test API endpoints end-to-end
- [ ] I can test background job handlers
- [ ] I understand when to mock and when to use real dependencies
- [ ] I can organize tests for maintainability
- [ ] I know how to use factories for test data

Testing is an investment. The time you spend writing tests saves multiples of that time in debugging production issues, reviewing code with confidence, and onboarding new developers. A well-tested codebase is a pleasure to work in. An untested one is a minefield.

## Code Coverage: A Useful Metric, Not a Goal

Code coverage measures what percentage of your code is executed by tests. It's useful but misleading if misused.

```bash
# Run tests with coverage
npm test -- --coverage
```

```
---------------|---------|----------|---------|---------|
File           | % Stmts | % Branch | % Funcs | % Lines |
---------------|---------|----------|---------|---------|
All files      |   78.5  |   72.1   |   82.3  |   79.1  |
 modules/task  |   92.3  |   88.4   |   95.0  |   91.7  |
 modules/user  |   65.2  |   58.3   |   70.0  |   66.8  |
 utils         |   95.0  |   92.1   |  100.0  |   94.5  |
---------------|---------|----------|---------|---------|
```

**Coverage tells you what's tested, not how well it's tested.** You can have 100% coverage with useless tests:

```typescript
// ❌ High coverage, useless test
it('creates a task', async () => {
  await service.createTask({ title: 'Test' })
  // No assertions - we ran the code but verified nothing
})

// ✅ Meaningful test
it('creates a task with correct defaults', async () => {
  const task = await service.createTask({ title: 'Test' })

  expect(task.status).toBe('pending')
  expect(task.priority).toBe('medium')
  expect(task.createdAt).toBeInstanceOf(Date)
})
```

**Reasonable coverage targets:**
- Critical paths (auth, payments, data mutations): 80%+
- Business logic utilities: 90%+
- CRUD operations: 60%+ (integration tests cover a lot)
- Glue code and configuration: don't stress about it

🤔 **Taste Moment:** Never set coverage as a strict gate (e.g., "PRs must have 80% coverage"). Teams game it by writing low-value tests to hit the number. Instead, review test quality in code reviews.

## Continuous Integration Testing

Tests should run automatically on every PR:

```yaml
# .github/workflows/test.yml
name: Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: test
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
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
          node-version: '20'
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

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          fail_ci_if_error: false
```

### Parallelizing Tests

Vitest runs test files in parallel by default. For maximum speed:

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    pool: 'threads',     // Run in worker threads
    poolOptions: {
      threads: {
        singleThread: false,
        maxThreads: 4
      }
    },
    testTimeout: 30000,  // 30s timeout for integration tests
    hookTimeout: 10000   // 10s for setup/teardown
  }
})
```

For database tests, ensure tests don't interfere with each other:

```typescript
// Each test file uses a unique schema
beforeAll(async () => {
  const schemaName = `test_${process.env.VITEST_WORKER_ID}`
  await db.execute(sql`CREATE SCHEMA IF NOT EXISTS ${sql.identifier(schemaName)}`)
  await db.execute(sql`SET search_path TO ${sql.identifier(schemaName)}`)
})
```

## Snapshot Testing

Snapshot tests capture output and compare against a saved "snapshot." Useful for testing complex objects or API responses:

```typescript
// src/modules/task/serializer.test.ts
import { describe, it, expect } from 'vitest'
import { serializeTask } from './serializer'

describe('serializeTask', () => {
  it('serializes a task correctly', () => {
    const task = {
      id: 'task-123',
      title: 'Test Task',
      description: 'A test task',
      status: 'pending',
      priority: 'high',
      createdAt: new Date('2026-01-15T10:00:00Z'),
      updatedAt: new Date('2026-01-15T10:00:00Z')
    }

    expect(serializeTask(task)).toMatchSnapshot()
  })
})
```

The first run creates a snapshot file. Subsequent runs compare against it.

**When to use snapshots:**
- Large objects where listing every field is tedious
- HTML/JSON output that shouldn't change unexpectedly
- API responses (catch accidental changes)

**When not to use snapshots:**
- Dynamic data (timestamps, IDs)
- When you need to understand why a test failed quickly

🔒 **Security Callout:** Review snapshot changes carefully in PRs. An attacker could sneak in a malicious change that "just updates snapshots."

## Testing Error Handling

Errors are part of your API contract. Test them:

```typescript
describe('TaskService error handling', () => {
  describe('getTask', () => {
    it('throws NotFoundError for nonexistent task', async () => {
      await expect(
        service.getTask('nonexistent-id')
      ).rejects.toThrow(NotFoundError)
    })

    it('throws NotFoundError (not ForbiddenError) for unauthorized access', async () => {
      // This tests the security behavior of returning 404 vs 403
      const task = await createTaskInOtherWorkspace()

      await expect(
        service.getTask(task.id)
      ).rejects.toThrow(NotFoundError)
    })
  })

  describe('completeTask', () => {
    it('throws ValidationError when task already complete', async () => {
      const task = await createTask({ status: 'complete' })

      await expect(
        service.completeTask(task.id, 'user-1')
      ).rejects.toThrow(ValidationError)
    })
  })
})
```

## Contract Testing with External APIs

When your service calls external APIs, test the contract:

```typescript
// src/services/stripe.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import Stripe from 'stripe'
import { createPaymentService } from './payment'

describe('PaymentService', () => {
  const mockStripe = {
    paymentIntents: {
      create: vi.fn(),
      retrieve: vi.fn()
    }
  }

  const service = createPaymentService(mockStripe as unknown as Stripe)

  describe('createPayment', () => {
    it('calls Stripe with correct parameters', async () => {
      mockStripe.paymentIntents.create.mockResolvedValue({
        id: 'pi_123',
        client_secret: 'secret_123',
        status: 'requires_payment_method'
      })

      const result = await service.createPayment({
        amount: 1000,
        currency: 'usd',
        customerId: 'cus_123'
      })

      expect(mockStripe.paymentIntents.create).toHaveBeenCalledWith({
        amount: 1000,
        currency: 'usd',
        customer: 'cus_123',
        automatic_payment_methods: { enabled: true }
      })

      expect(result.clientSecret).toBe('secret_123')
    })

    it('handles Stripe errors gracefully', async () => {
      mockStripe.paymentIntents.create.mockRejectedValue(
        new Stripe.errors.StripeCardError({
          type: 'card_error',
          message: 'Card declined'
        })
      )

      await expect(
        service.createPayment({ amount: 1000, currency: 'usd' })
      ).rejects.toThrow('Payment failed: Card declined')
    })
  })
})
```

For critical integrations, add contract tests that verify the external API's behavior:

```typescript
// src/services/stripe.contract.test.ts
// These tests call the real Stripe test API
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_TEST_KEY!)

describe('Stripe API Contract', () => {
  it('creates payment intent with expected response shape', async () => {
    const intent = await stripe.paymentIntents.create({
      amount: 1000,
      currency: 'usd',
      automatic_payment_methods: { enabled: true }
    })

    // Verify the response shape matches what we expect
    expect(intent).toHaveProperty('id')
    expect(intent).toHaveProperty('client_secret')
    expect(intent).toHaveProperty('status')
    expect(typeof intent.id).toBe('string')
    expect(intent.id).toMatch(/^pi_/)
  })
})
```

Run contract tests less frequently (nightly, not on every PR) since they hit external services.

⚡ **AI Shortcut:** When integrating a new external API, paste the API documentation into Claude and ask it to generate contract tests for the endpoints you'll use. This catches documentation mismatches early.

## Performance Testing Basics

Performance issues are bugs. While detailed load testing comes in Phase 3, basic performance assertions belong in your test suite:

```typescript
describe('TaskService performance', () => {
  it('lists tasks in under 100ms with 1000 tasks', async () => {
    // Seed 1000 tasks
    await Promise.all(
      Array.from({ length: 1000 }, (_, i) =>
        repository.create({ title: `Task ${i}`, projectId: 'project-1' })
      )
    )

    const start = performance.now()
    const tasks = await service.listTasks('project-1', { limit: 50 })
    const duration = performance.now() - start

    expect(tasks).toHaveLength(50)
    expect(duration).toBeLessThan(100)
  })
})
```

These tests catch N+1 queries and missing indexes before they reach production.

## Debugging Failing Tests

When tests fail, make them easy to debug:

```typescript
// Bad: No context when it fails
expect(result).toBe(true)

// Good: Clear failure message
expect(result).toBe(true, `Expected task ${taskId} to be deletable by owner`)

// Better: Use descriptive assertions
expect(taskService.canDelete(owner, task)).toBe(true)
```

For intermittent failures (flaky tests):

1. **Add timeouts for async operations:** Tests fail differently under load
2. **Check for test pollution:** Tests shouldn't depend on order
3. **Add retry logic sparingly:** Only for truly non-deterministic operations
4. **Log test state:** Add console output that only appears on failure

```typescript
// Vitest retry for flaky tests (use sparingly)
it('handles concurrent writes', { retry: 2 }, async () => {
  // This test involves race conditions that occasionally fail
})
```

💸 **Startup Cost Callout:** Fix flaky tests immediately. Each flaky test erodes trust in the test suite. Soon developers ignore all failures because "tests are flaky." That's a path to no tests at all.
