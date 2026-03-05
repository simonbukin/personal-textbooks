# The Scaling Playbook

## Why This Matters

Your app is getting popular. Response times are creeping up. The database is working harder. You need to scale, but where do you start?

This chapter gives you concrete techniques for handling more load. Not distributed systems theory — practical moves you can make when your startup hits real growth.

## The First Rule of Scaling

> Don't scale until you have to. When you do, scale the bottleneck, not everything.

Most performance problems have a single cause. Find it before adding complexity. More servers won't fix a slow database query. A cache won't help if you're CPU-bound.

### Finding the Bottleneck

**Database-bound:** Query times are high. `pg_stat_statements` shows slow queries. Adding more API servers doesn't help.

**CPU-bound:** CPU usage is high across all instances. Response times increase under load even when database is fast.

**Memory-bound:** Memory usage is high. OOM kills happen. GC pauses are long.

**I/O-bound:** Network or disk waits dominate. External API calls are slow.

```sql
-- Find slow queries in Postgres
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

```typescript
// Log which phase of request is slow
app.use(async (c, next) => {
  const timings: Record<string, number> = {}

  const trace = (name: string) => {
    timings[name] = Date.now()
  }

  c.set('trace', trace)
  trace('start')

  await next()

  trace('end')
  console.log({
    path: c.req.path,
    timings: Object.entries(timings).reduce((acc, [k, v], i, arr) => {
      if (i > 0) acc[k] = v - arr[i-1][1]
      return acc
    }, {} as Record<string, number>)
  })
})

// In handlers
c.get('trace')('db_query')
await db.query(...)
c.get('trace')('serialization')
```

## Database Scaling

The database is the bottleneck 80% of the time. Fix it first.

### Level 1: Query Optimization

Before scaling hardware, make queries efficient.

```sql
-- Find missing indexes (queries with seq scans on large tables)
SELECT relname, seq_scan, idx_scan,
       seq_scan / GREATEST(seq_scan + idx_scan, 1)::float AS seq_scan_ratio
FROM pg_stat_user_tables
WHERE seq_scan > 1000
ORDER BY seq_scan DESC;
```

```sql
-- Add covering index to avoid table lookup
CREATE INDEX idx_tasks_user_status ON tasks(user_id, status)
INCLUDE (title, due_date);

-- Now this query is index-only:
SELECT title, due_date FROM tasks
WHERE user_id = 'x' AND status = 'pending';
```

**N+1 queries** are the silent killer:

```typescript
// ❌ N+1: one query per task
const projects = await db.query.projects.findMany()
for (const project of projects) {
  project.tasks = await db.query.tasks.findMany({
    where: eq(tasks.projectId, project.id)
  })
}

// ✅ Single query with join
const projects = await db.query.projects.findMany({
  with: { tasks: true }
})
```

### Level 2: Connection Pooling

Each database connection consumes memory (~10MB in Postgres). Too many connections exhaust server resources.

```typescript
// Configure pool size based on available connections
const pool = new Pool({
  max: 20,  // Match to available connections / number of instances
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
})

// Monitor pool health
setInterval(() => {
  console.log({
    total: pool.totalCount,
    idle: pool.idleCount,
    waiting: pool.waitingCount,
  })
}, 10000)
```

For serverless or high-instance-count environments, use a pooler like PgBouncer:

```
App Instance 1 ──┐
App Instance 2 ──┼──► PgBouncer (100 connections) ──► Postgres (100 max)
App Instance 3 ──┘
```

### Level 3: Read Replicas

When read traffic exceeds what one server can handle, add read replicas.

```typescript
import { Pool } from 'pg'

const writePool = new Pool({ connectionString: process.env.DATABASE_URL })
const readPool = new Pool({ connectionString: process.env.DATABASE_REPLICA_URL })

// Route queries based on operation
export function getDb(operation: 'read' | 'write') {
  return operation === 'read' ? readPool : writePool
}

// Usage
const tasks = await getDb('read').query('SELECT * FROM tasks WHERE user_id = $1', [userId])
await getDb('write').query('INSERT INTO tasks ...')
```

**Replication lag caveat:** Replicas can be milliseconds to seconds behind. Reading your own writes requires either:
- Reading from primary after writes
- Session affinity to primary for write-heavy sessions
- Accepting eventual consistency in UI

### Level 4: Vertical Scaling

Before adding complexity, try a bigger database server.

```
db.t4g.micro  (2 vCPU, 1GB)   → handles ~1K queries/sec
db.t4g.medium (2 vCPU, 4GB)   → handles ~5K queries/sec
db.r6g.large  (2 vCPU, 16GB)  → handles ~15K queries/sec
```

Vertical scaling is simple. It buys you time to implement proper solutions.

### Level 5: Partitioning

When a single table gets too large (100M+ rows), partition it:

```sql
-- Partition by time for time-series data
CREATE TABLE events (
    id uuid,
    user_id uuid,
    event_type text,
    created_at timestamptz,
    payload jsonb
) PARTITION BY RANGE (created_at);

CREATE TABLE events_2025_01 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE events_2025_02 PARTITION OF events
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Partition by tenant for multi-tenant
CREATE TABLE tasks (
    id uuid,
    workspace_id uuid,
    title text,
    ...
) PARTITION BY HASH (workspace_id);

CREATE TABLE tasks_0 PARTITION OF tasks FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE tasks_1 PARTITION OF tasks FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE tasks_2 PARTITION OF tasks FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE tasks_3 PARTITION OF tasks FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

## Caching Strategies

Caching reduces database load by serving repeated reads from memory.

### Cache-Aside (Lazy Loading)

The most common pattern: check cache, if miss, load from database and populate cache.

```typescript
async function getUser(userId: string): Promise<User> {
  const cacheKey = `user:${userId}`

  // Check cache
  const cached = await redis.get(cacheKey)
  if (cached) {
    return JSON.parse(cached)
  }

  // Load from database
  const user = await db.query.users.findFirst({
    where: eq(users.id, userId)
  })

  // Populate cache
  if (user) {
    await redis.setex(cacheKey, 3600, JSON.stringify(user))  // 1 hour TTL
  }

  return user
}
```

**Invalidation:** When data changes, delete the cache key.

```typescript
async function updateUser(userId: string, data: Partial<User>) {
  await db.update(users).set(data).where(eq(users.id, userId))
  await redis.del(`user:${userId}`)  // Invalidate cache
}
```

### Write-Through Cache

Write to cache and database together. Ensures cache is always fresh.

```typescript
async function updateUser(userId: string, data: Partial<User>) {
  const user = await db.update(users)
    .set(data)
    .where(eq(users.id, userId))
    .returning()

  // Update cache with fresh data
  await redis.setex(`user:${userId}`, 3600, JSON.stringify(user[0]))

  return user[0]
}
```

### Cache Stampede Prevention

When cache expires, many concurrent requests hit the database simultaneously.

```typescript
async function getWithLock<T>(
  key: string,
  ttl: number,
  loader: () => Promise<T>
): Promise<T> {
  const cached = await redis.get(key)
  if (cached) return JSON.parse(cached)

  // Try to acquire lock
  const lockKey = `lock:${key}`
  const acquired = await redis.set(lockKey, '1', 'EX', 10, 'NX')

  if (!acquired) {
    // Another process is loading, wait and retry
    await new Promise(r => setTimeout(r, 100))
    return getWithLock(key, ttl, loader)
  }

  try {
    const value = await loader()
    await redis.setex(key, ttl, JSON.stringify(value))
    return value
  } finally {
    await redis.del(lockKey)
  }
}
```

### What to Cache

**Good cache candidates:**
- User profiles (read often, change rarely)
- Configuration/settings
- Computed aggregations (daily counts, leaderboards)
- External API responses

**Poor cache candidates:**
- Data that changes constantly
- Data with strict consistency requirements
- Data unique to each request

💸 **Startup Cost Callout:** Redis caching can cut your database costs significantly. A 500MB Redis instance (~$15/month) can handle millions of cached reads that would otherwise hit Postgres.

## Application-Level Scaling

### Horizontal Scaling

Add more instances behind a load balancer.

```
Load Balancer
     │
     ├──► API Instance 1
     ├──► API Instance 2
     └──► API Instance 3
```

**Requirements for horizontal scaling:**
- **Stateless instances:** No local state that matters (use Redis for sessions)
- **Shared database:** All instances connect to the same database
- **Distributed caching:** All instances share the same Redis

```yaml
# Fly.io: scale with a command
fly scale count 3

# Or auto-scale based on metrics
fly autoscale set min=2 max=10
```

### Background Job Scaling

Job processing can scale independently from web servers.

```typescript
// Separate workers from web servers
if (process.env.WORKER_MODE === 'true') {
  // Only run worker
  const worker = new Worker('main-queue', processJob, {
    concurrency: 10,
  })
  console.log('Worker started')
} else {
  // Only run web server
  app.listen(3000)
  console.log('Web server started')
}
```

```yaml
# Deploy separately
# fly.toml
[processes]
  web = "node dist/index.js"
  worker = "WORKER_MODE=true node dist/index.js"
```

### Rate Limiting Under Load

When traffic exceeds capacity, prioritize important requests.

```typescript
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(100, '1m'),  // 100 requests per minute
})

app.use(async (c, next) => {
  const ip = c.req.header('x-forwarded-for') || 'anonymous'
  const { success, remaining, reset } = await ratelimit.limit(ip)

  c.header('X-RateLimit-Remaining', remaining.toString())
  c.header('X-RateLimit-Reset', reset.toString())

  if (!success) {
    return c.json({ error: 'Rate limit exceeded' }, 429)
  }

  return next()
})
```

## Async Everything

Moving work off the request path is often the best scaling lever.

### Fire-and-Forget

Operations that don't need immediate confirmation:

```typescript
// ❌ Slow: wait for email to send
app.post('/api/signup', async (c) => {
  const user = await createUser(c.req.json())
  await sendWelcomeEmail(user.email)  // 500ms
  return c.json(user)
})

// ✅ Fast: queue the email
app.post('/api/signup', async (c) => {
  const user = await createUser(c.req.json())
  await emailQueue.add('welcome', { email: user.email })  // 5ms
  return c.json(user)
})
```

### Batch Processing

Aggregate small operations into larger batches:

```typescript
// ❌ One database write per page view
app.get('/page/:id', async (c) => {
  await db.execute(sql`
    UPDATE pages SET views = views + 1 WHERE id = ${c.req.param('id')}
  `)
  // ...
})

// ✅ Buffer in Redis, flush periodically
const viewBuffer = new Map<string, number>()

app.get('/page/:id', async (c) => {
  const pageId = c.req.param('id')
  viewBuffer.set(pageId, (viewBuffer.get(pageId) || 0) + 1)
  // ...
})

// Flush every 10 seconds
setInterval(async () => {
  const entries = Array.from(viewBuffer.entries())
  viewBuffer.clear()

  if (entries.length > 0) {
    await db.execute(sql`
      UPDATE pages SET views = views + CASE id
        ${sql.join(entries.map(([id, count]) =>
          sql`WHEN ${id} THEN ${count}`
        ), sql` `)}
      END
      WHERE id IN (${sql.join(entries.map(([id]) => sql`${id}`), sql`, `)})
    `)
  }
}, 10000)
```

### Eventual Consistency

Accept that not everything needs to be immediately consistent:

```typescript
// User sees their own writes immediately (session cache)
// Other users see updates within seconds (database + cache TTL)

async function getTaskCount(projectId: string, userId: string) {
  // Check if this user just modified, use fresh count
  const freshKey = `fresh:tasks:${projectId}:${userId}`
  if (await redis.exists(freshKey)) {
    return db.query.tasks.count({ where: eq(tasks.projectId, projectId) })
  }

  // Otherwise, use cached count
  const cacheKey = `count:tasks:${projectId}`
  return getWithLock(cacheKey, 60, () =>
    db.query.tasks.count({ where: eq(tasks.projectId, projectId) })
  )
}

async function createTask(projectId: string, userId: string, data: TaskInput) {
  await db.insert(tasks).values({ projectId, ...data })

  // Mark this user as needing fresh reads
  await redis.setex(`fresh:tasks:${projectId}:${userId}`, 30, '1')

  // Invalidate cached count for others
  await redis.del(`count:tasks:${projectId}`)
}
```

## The Scaling Sequence

When you need to scale, try these in order:

1. **Optimize queries** — Fix N+1s, add indexes, rewrite slow queries
2. **Add caching** — Cache expensive computations and frequent reads
3. **Move work async** — Queue emails, notifications, analytics
4. **Vertical scale** — Bigger database, bigger servers
5. **Add read replicas** — Separate read traffic
6. **Horizontal scale** — More API instances

Most startups never get past step 3 or 4. Don't over-engineer for scale you don't have.

## The Taste Test

**Scenario 1:** Database CPU is at 90%. The team proposes adding three read replicas.

*Check queries first.* One slow query running constantly could be the entire cause. Fix the query, then reassess.

**Scenario 2:** A team caches everything with 24-hour TTLs to reduce database load.

*Too aggressive.* Long TTLs cause stale data issues. Cache what's read-heavy and stable. Use shorter TTLs (minutes) for user-facing data.

**Scenario 3:** Response times are slow, but only during business hours.

*Traffic pattern issue.* Could be database connection exhaustion, job queue backup, or external API rate limits. Add monitoring to identify the specific bottleneck during peak.

**Scenario 4:** A startup with 100 users wants to shard their database.

*Way premature.* A single Postgres instance handles millions of rows. Sharding adds massive complexity. Vertical scale and read replicas come first.

## Practical Exercise

Profile and optimize your TaskFlow API for 10x traffic:

**Requirements:**
1. Run a load test to establish baseline (max RPS, p95 latency)
2. Identify the primary bottleneck
3. Apply appropriate optimization (query, cache, async, or scale)
4. Re-run load test to measure improvement
5. Document what you changed and why

**Deliverable:** A short report showing before/after metrics and your optimization strategy.

**⚡ AI Shortcut:**

Have Claude analyze your slow queries:

```
Here's my pg_stat_statements output showing slow queries:
[paste output]

For each slow query:
1. Explain why it might be slow
2. Suggest index additions
3. Suggest query rewrites if applicable
4. Estimate improvement potential
```

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can identify whether my system is database, CPU, memory, or I/O bound
- [ ] I know the sequence of scaling techniques to try
- [ ] I can implement cache-aside and write-through caching
- [ ] I understand when to use read replicas vs vertical scaling
- [ ] I can move work off the request path using queues

Scaling is about removing bottlenecks one at a time. Find the constraint, fix it, repeat.
