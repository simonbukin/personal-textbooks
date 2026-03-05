# Queries, Performance, and the N+1 Problem

## Why This Matters

You've been on the frontend watching slow APIs. You've seen loading spinners that spin too long, response times that make users bounce, and network waterfalls that multiply latency. You know what bad API performance feels like.

Now you get to fix it from the other side.

Most backend performance problems are query problems. Not server CPU, not memory, not network — queries. The database is doing too much work, either because the queries are inefficient or because there are too many of them. An API that takes 500ms to respond might be executing 47 queries that each take 10ms. Another might be executing one query that scans millions of rows. Both are fixable once you know how to diagnose them.

Learning to diagnose and fix these issues is one of the most immediately valuable backend skills you can develop. It's also one of the most satisfying — there's something deeply gratifying about taking a 2-second API call down to 20 milliseconds.

By the end of this chapter, you'll be able to identify why a query is slow, fix the common patterns that cause performance issues, and know when "add a cache" is the right answer versus when you're just hiding the real problem.

## SQL Fluency for the Working Engineer

You don't need to be an SQL expert. You need to be fluent in the patterns you'll actually use. Let's cover them.

A note on learning SQL: you learn it by writing it. Each pattern here has a code example. Type them out. Run them against your database with real data. See what they return. Modify them. Break them. The muscle memory of writing SQL is more valuable than reading about it.

### JOINs: The Basics You Actually Need

JOINs combine data from multiple tables. There are four types, but you'll use three:

**INNER JOIN** — Returns rows only when both tables have matching data.

```sql
-- Get tasks with their project names
-- Only tasks that have a project (project_id is not null)
select t.id, t.title, p.name as project_name
from tasks t
inner join projects p on t.project_id = p.id
where t.workspace_id = 'abc123';
```

**LEFT JOIN** — Returns all rows from the left table, with matching data from the right table (or null if no match).

```sql
-- Get ALL tasks, with project names where they exist
-- Tasks without a project will have null for project_name
select t.id, t.title, p.name as project_name
from tasks t
left join projects p on t.project_id = p.id
where t.workspace_id = 'abc123';
```

**RIGHT JOIN** — Same as LEFT JOIN but from the right table's perspective. Rarely used in practice — you can always rewrite it as a LEFT JOIN by swapping the table order.

The mental model: LEFT JOIN means "give me everything from the left table, with related data if it exists." INNER JOIN means "give me only the rows where both sides have data."

🤔 **Taste Moment:** When you see a query returning fewer results than expected, check if an INNER JOIN should be a LEFT JOIN. It's a common bug.

### CTEs for Readable Complex Queries

Common Table Expressions (CTEs) let you break complex queries into readable steps:

```sql
-- Find workspace members who have overdue tasks
-- Without CTE: a mess of nested subqueries
-- With CTE: clear and readable

with overdue_tasks as (
  select assignee_id, count(*) as overdue_count
  from tasks
  where due_date < now()
    and status != 'done'
    and deleted_at is null
  group by assignee_id
),
member_details as (
  select
    u.id,
    u.name,
    u.email,
    wm.workspace_id
  from users u
  join workspace_members wm on u.id = wm.user_id
  where wm.workspace_id = 'abc123'
)
select
  m.name,
  m.email,
  coalesce(o.overdue_count, 0) as overdue_tasks
from member_details m
left join overdue_tasks o on m.id = o.assignee_id
order by overdue_tasks desc;
```

CTEs don't make queries faster (they're essentially inline views), but they make queries understandable. A query you can read is a query you can debug. A query you can debug is a query you can optimize. Start with CTEs when writing complex queries, then simplify if profiling reveals the structure adds measurable overhead.

### Window Functions: When Aggregates Aren't Enough

Window functions let you compute values across rows related to the current row — without collapsing those rows into groups.

**ROW_NUMBER() for pagination and deduplication:**

```sql
-- Get the most recent comment for each task
with ranked_comments as (
  select
    c.*,
    row_number() over (partition by task_id order by created_at desc) as rn
  from comments c
)
select * from ranked_comments where rn = 1;
```

**LAG/LEAD for comparing adjacent rows:**

```sql
-- Show tasks with how long since the previous task was created
select
  title,
  created_at,
  created_at - lag(created_at) over (order by created_at) as time_since_previous
from tasks
where workspace_id = 'abc123'
order by created_at;
```

**Running totals and averages:**

```sql
-- Cumulative task count over time
select
  date_trunc('day', created_at) as day,
  count(*) as tasks_created,
  sum(count(*)) over (order by date_trunc('day', created_at)) as cumulative_total
from tasks
where workspace_id = 'abc123'
group by date_trunc('day', created_at)
order by day;
```

Window functions are powerful but can be slow on large datasets. Use them in analytics queries and reports, not in hot paths.

**SUM, AVG, MIN, MAX over a window:**

```sql
-- Task completion rate per user, with running average
select
  assignee_id,
  date_trunc('week', completed_at) as week,
  count(*) as tasks_completed,
  avg(count(*)) over (
    partition by assignee_id
    order by date_trunc('week', completed_at)
    rows between 3 preceding and current row
  ) as four_week_average
from tasks
where status = 'done'
group by assignee_id, date_trunc('week', completed_at)
order by assignee_id, week;
```

### Aggregations: GROUP BY and HAVING

```sql
-- Task count by status for each project
select
  p.name as project_name,
  t.status,
  count(*) as task_count
from tasks t
join projects p on t.project_id = p.id
where t.workspace_id = 'abc123'
  and t.deleted_at is null
group by p.name, t.status
order by p.name, t.status;

-- Only projects with more than 10 incomplete tasks
select
  project_id,
  count(*) as incomplete_count
from tasks
where status != 'done'
  and deleted_at is null
group by project_id
having count(*) > 10;
```

The difference: WHERE filters rows before aggregation, HAVING filters groups after aggregation.

### Subqueries: Scalar, Correlated, and EXISTS

**Scalar subqueries** return a single value and can be used in SELECT:

```sql
-- Add task count to each project row
select
  p.id,
  p.name,
  (select count(*) from tasks t where t.project_id = p.id) as task_count
from projects p
where p.workspace_id = 'abc123';
```

**EXISTS for efficiency** when you only need to know if matching rows exist:

```sql
-- Get projects that have at least one overdue task
select p.*
from projects p
where exists (
  select 1 from tasks t
  where t.project_id = p.id
    and t.due_date < now()
    and t.status != 'done'
);
```

`EXISTS` stops scanning as soon as it finds one match. This is more efficient than `COUNT(*) > 0`.

**IN vs EXISTS:** For small lists, `IN` is fine. For subqueries that might return many rows, `EXISTS` is often more efficient because it can short-circuit.

```sql
-- Prefer EXISTS for large sets
select * from users u
where exists (select 1 from tasks t where t.assignee_id = u.id and t.status = 'todo');

-- IN is fine for small, explicit lists
select * from tasks where status in ('todo', 'in_progress');
```

## The N+1 Problem From the Backend Side

You've seen N+1 from the frontend: an API that makes one request to get a list, then N additional requests to get related data for each item. It looks like this in the network tab:

```
GET /api/projects              200 OK  150ms
GET /api/projects/1/tasks      200 OK   50ms
GET /api/projects/2/tasks      200 OK   48ms
GET /api/projects/3/tasks      200 OK   52ms
... (N more requests)
```

The backend equivalent is worse because it happens inside a single API request — invisible to the frontend but killing your response time.

### How ORMs Create N+1 Problems

```typescript
// ❌ Classic N+1 with Drizzle (or any ORM)
async function getProjectsWithTasks(workspaceId: string) {
  // Query 1: Get all projects
  const projects = await db.query.projects.findMany({
    where: eq(projects.workspaceId, workspaceId),
  });

  // Queries 2 through N+1: Get tasks for each project
  const result = await Promise.all(
    projects.map(async (project) => {
      const tasks = await db.query.tasks.findMany({
        where: eq(tasks.projectId, project.id),
      });
      return { ...project, tasks };
    })
  );

  return result;
}
```

This generates:
```sql
SELECT * FROM projects WHERE workspace_id = 'abc123';
SELECT * FROM tasks WHERE project_id = 'project-1';
SELECT * FROM tasks WHERE project_id = 'project-2';
SELECT * FROM tasks WHERE project_id = 'project-3';
-- ... N more queries
```

If you have 50 projects, that's 51 database round-trips. At 2ms per query, you're at 100ms of just query latency — before any processing.

### Fix 1: Eager Loading (Drizzle's `with` clause)

```typescript
// ✅ Eager loading: 1 query instead of N+1
async function getProjectsWithTasks(workspaceId: string) {
  return await db.query.projects.findMany({
    where: eq(projects.workspaceId, workspaceId),
    with: {
      tasks: true, // Eager load tasks
    },
  });
}
```

Drizzle generates a JOIN or a second query to fetch all tasks at once:
```sql
SELECT * FROM projects WHERE workspace_id = 'abc123';
SELECT * FROM tasks WHERE project_id IN ('project-1', 'project-2', ...);
```

Two queries regardless of project count. Much better.

### Fix 2: The DataLoader Pattern

When you can't use eager loading (e.g., in GraphQL resolvers or when the relationship is complex), use batching:

```typescript
// DataLoader batches multiple requests into one
import DataLoader from 'dataloader';

const tasksByProjectLoader = new DataLoader(async (projectIds: string[]) => {
  // Single query for ALL project IDs
  const tasks = await db.query.tasks.findMany({
    where: inArray(tasks.projectId, projectIds),
  });

  // Group tasks by project ID
  const tasksByProject = new Map<string, Task[]>();
  for (const task of tasks) {
    const existing = tasksByProject.get(task.projectId) || [];
    tasksByProject.set(task.projectId, [...existing, task]);
  }

  // Return in the same order as the input IDs
  return projectIds.map((id) => tasksByProject.get(id) || []);
});

// Usage: looks like N+1, but DataLoader batches it
async function getProjectsWithTasks(workspaceId: string) {
  const projects = await db.query.projects.findMany({
    where: eq(projects.workspaceId, workspaceId),
  });

  return Promise.all(
    projects.map(async (project) => ({
      ...project,
      tasks: await tasksByProjectLoader.load(project.id),
    }))
  );
}
```

DataLoader collects all the `.load()` calls within a tick, deduplicates them, and issues a single batch query. The code looks like it's making N calls, but it actually makes one.

### Fix 3: Single Query with JOIN

Sometimes the simplest solution is to write the SQL directly:

```typescript
// ✅ Single JOIN query
async function getProjectsWithTasks(workspaceId: string) {
  const rows = await db.execute(sql`
    SELECT
      p.id as project_id,
      p.name as project_name,
      t.id as task_id,
      t.title as task_title,
      t.status as task_status
    FROM projects p
    LEFT JOIN tasks t ON t.project_id = p.id AND t.deleted_at IS NULL
    WHERE p.workspace_id = ${workspaceId}
    ORDER BY p.name, t.created_at
  `);

  // Transform flat rows into nested structure
  const projectsMap = new Map<string, Project>();
  for (const row of rows) {
    if (!projectsMap.has(row.project_id)) {
      projectsMap.set(row.project_id, {
        id: row.project_id,
        name: row.project_name,
        tasks: [],
      });
    }
    if (row.task_id) {
      projectsMap.get(row.project_id)!.tasks.push({
        id: row.task_id,
        title: row.task_title,
        status: row.task_status,
      });
    }
  }

  return Array.from(projectsMap.values());
}
```

One query, explicit control over what data is fetched, no ORM magic. The trade-off: more code, less abstraction.

🤔 **Taste Moment:** Start with eager loading. Reach for DataLoader when you need more complex batching (GraphQL, nested relationships). Drop to raw SQL when you need maximum control or when the ORM generates inefficient queries.

### Detecting N+1 Problems

How do you know if you have an N+1 problem?

**Log your queries.** Enable query logging in development and count the queries per request.

```typescript
// Drizzle query logging
const db = drizzle(pool, {
  logger: {
    logQuery: (query, params) => {
      console.log('SQL:', query);
      console.log('Params:', params);
    },
  },
});
```

**Watch for patterns.** If you see the same query structure repeated with different IDs, that's N+1.

**Use APM tools.** In production, tools like Datadog APM or Sentry performance monitoring show you query counts and timing per request.

**Rule of thumb:** A typical API endpoint should execute fewer than 10 queries. If you're seeing 50+ queries, investigate.

## Reading EXPLAIN ANALYZE Like a Doctor Reads an X-ray

When a query is slow, `EXPLAIN ANALYZE` tells you why. Learning to read it is like learning to read a diagnostic report — the information is there, you just need to know what to look for.

### Running EXPLAIN ANALYZE

```sql
EXPLAIN ANALYZE
SELECT t.*, u.name as assignee_name
FROM tasks t
LEFT JOIN users u ON t.assignee_id = u.id
WHERE t.workspace_id = '550e8400-e29b-41d4-a716-446655440000'
  AND t.status = 'todo'
ORDER BY t.created_at DESC
LIMIT 20;
```

### Reading the Output

```
Limit  (cost=0.56..89.42 rows=20 width=250) (actual time=0.089..0.156 rows=20 loops=1)
  ->  Nested Loop Left Join  (cost=0.56..3456.78 rows=780 width=250) (actual time=0.087..0.152 rows=20 loops=1)
        ->  Index Scan using idx_tasks_workspace_status on tasks t  (cost=0.42..1234.56 rows=780 width=200) (actual time=0.062..0.095 rows=20 loops=1)
              Index Cond: ((workspace_id = '550e8400...'::uuid) AND (status = 'todo'::text))
        ->  Index Scan using users_pkey on users u  (cost=0.14..0.20 rows=1 width=50) (actual time=0.002..0.002 rows=1 loops=20)
              Index Cond: (id = t.assignee_id)
Planning Time: 0.234 ms
Execution Time: 0.189 ms
```

**What to look for:**

1. **`cost=X..Y`** — Estimated cost (arbitrary units). Lower is better. The first number is startup cost, the second is total cost.

2. **`actual time=X..Y`** — Real execution time in milliseconds. This is what matters.

3. **`rows=N`** — Number of rows. Compare estimated vs actual. Large differences indicate stale statistics (`ANALYZE your_table` fixes this).

4. **Scan types:**
   - `Index Scan` — Good. Using an index.
   - `Index Only Scan` — Better. All data comes from the index.
   - `Seq Scan` — Often bad on large tables. Scanning every row.
   - `Bitmap Index Scan` + `Bitmap Heap Scan` — Okay. Using multiple indexes.

5. **`loops=N`** — How many times this operation ran. In nested loops, watch for high loop counts.

6. **Planning Time vs Execution Time** — At the bottom of the output. Planning time is how long Postgres spent choosing a query plan. If planning time is high (>10ms), the query might have too many possible plans (complex joins, many indexes to consider). Execution time is the actual query work. Focus on execution time for optimization.

The skill is pattern matching. After looking at a few dozen query plans, you'll spot problems instantly. The first few will require careful reading. That's normal.

### Common Problems and Fixes

**Problem: Seq Scan on a large table**
```
Seq Scan on tasks  (actual time=0.012..145.678 rows=100000 loops=1)
  Filter: (workspace_id = '...')
  Rows Removed by Filter: 900000
```

Fix: Add an index on the filter column.

```sql
CREATE INDEX idx_tasks_workspace ON tasks (workspace_id);
```

**Problem: Index not being used**

Even with an index, Postgres might choose a Seq Scan if:
- The table is small (Seq Scan is faster for small tables)
- The query returns a large percentage of rows
- Statistics are stale

Check with:
```sql
ANALYZE tasks; -- Update statistics
EXPLAIN ANALYZE ... -- Re-run the query
```

**Problem: Nested Loop with high loop count**
```
Nested Loop  (actual time=0.050..456.789 rows=10000 loops=1)
  ->  Seq Scan on projects  (actual time=0.020..1.234 rows=100 loops=1)
  ->  Index Scan on tasks  (actual time=0.010..4.500 rows=100 loops=100)
```

The inner scan runs 100 times. If that inner scan is slow, it multiplies.

Fix: Ensure the inner table has a good index, or restructure the query to use a hash join.

**Problem: Sort operation on large result set**
```
Sort  (cost=10000.00..10250.00 rows=100000 width=200) (actual time=89.123..95.456 rows=100000 loops=1)
  Sort Key: created_at DESC
  Sort Method: external merge  Disk: 25000kB
```

"External merge" and "Disk" mean the sort didn't fit in memory.

Fix: Add an index that provides the sort order, or increase `work_mem`.

```sql
CREATE INDEX idx_tasks_created ON tasks (created_at DESC);
```

**Problem: High row estimates vs actual**
```
Index Scan on tasks  (cost=0.42..1234.56 rows=50000 width=200) (actual time=0.050..2.500 rows=47 loops=1)
```

The planner estimated 50,000 rows but only got 47. This suggests stale statistics.

Fix: Run `ANALYZE tasks;` to update statistics. Postgres uses these statistics to choose query plans. Stale statistics lead to poor choices.

**Problem: Filter applied after index scan**
```
Index Scan on idx_tasks_workspace  (actual time=0.050..45.000 rows=100 loops=1)
  Index Cond: (workspace_id = '...')
  Filter: (status = 'todo')
  Rows Removed by Filter: 9900
```

The index only covered `workspace_id`. After finding 10,000 rows by workspace, Postgres filtered to 100 rows with status='todo'.

Fix: Create a composite index on both columns:
```sql
CREATE INDEX idx_tasks_workspace_status ON tasks (workspace_id, status);
```

## Connection Pooling

Every database connection uses resources — about 10MB of memory on Postgres, plus file descriptors and context-switching overhead. Postgres has a maximum connection limit (usually 100-500 depending on configuration).

Without pooling, each request opens a new connection, uses it, closes it. At high concurrency, you hit the connection limit and requests fail.

### The Solution: Connection Pooling

A pool maintains a set of open connections. Your application borrows a connection, uses it, returns it. The connection stays open for the next request.

**Drizzle with built-in pooling:**

```typescript
// src/db/index.ts
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20, // Maximum connections in the pool
  idleTimeoutMillis: 30000, // Close idle connections after 30s
  connectionTimeoutMillis: 2000, // Fail if can't connect in 2s
});

export const db = drizzle(pool);
```

**PgBouncer for production:**

For high-traffic applications, PgBouncer sits between your app and Postgres, managing connections more efficiently:

```yaml
# docker-compose.yml
services:
  pgbouncer:
    image: edoburu/pgbouncer:1.18.0
    environment:
      DATABASE_URL: postgres://user:pass@postgres:5432/mydb
      POOL_MODE: transaction
      MAX_CLIENT_CONN: 1000
      DEFAULT_POOL_SIZE: 20
    ports:
      - "6432:6432"
```

Your app connects to PgBouncer (port 6432), which manages the actual Postgres connections.

🤔 **Taste Moment:** Start with your ORM's built-in pooling. Add PgBouncer when you have multiple app instances sharing the same database, or when you need more than ~100 concurrent connections.

### Diagnosing Pool Exhaustion

Symptoms:
- Requests timing out
- "too many connections" errors
- Latency spikes under load

Check current connections:
```sql
SELECT count(*) FROM pg_stat_activity WHERE datname = 'your_database';
```

Check what's holding connections:
```sql
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity
WHERE datname = 'your_database'
  AND state != 'idle'
ORDER BY duration DESC;
```

Long-running queries hold connections. Fix the queries or add timeouts.

### Query Timeouts

Set timeouts to prevent runaway queries from holding connections forever:

```typescript
// Per-query timeout
const result = await db.execute(sql`
  SET LOCAL statement_timeout = '5000'; -- 5 seconds
  SELECT * FROM large_table WHERE ...;
`);

// Or at the connection level in your pool config
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  statement_timeout: 10000, // 10 seconds
});
```

A query that should take 50ms but takes 10 seconds is a sign of a bigger problem. Time it out and investigate rather than letting it consume resources.

## ORMs: The Trade-off You're Making

Drizzle, Prisma, TypeORM, Sequelize — ORMs provide type safety, protect against SQL injection, and make common operations easier. But they hide what's actually happening.

### What You Gain

**Type safety:** The ORM knows your schema and gives you TypeScript types.

```typescript
// Drizzle knows task.status is a string
const tasks = await db.query.tasks.findMany({
  where: eq(tasks.workspaceId, workspaceId),
});
tasks[0].status; // TypeScript knows this is string
```

**SQL injection protection:** Parameterized queries by default.

```typescript
// Safe: the ORM parameterizes the value
await db.query.tasks.findMany({
  where: eq(tasks.title, userInput), // userInput is safely escaped
});
```

**Productivity:** Common operations are one-liners.

### What You Lose

**Visibility:** You don't see the SQL being generated. Bad query patterns hide.

**Control:** The ORM decides how to fetch data. Sometimes it decides poorly.

**Understanding:** If you don't know SQL, you can't optimize what you can't see.

### The Mitigation: Always Know the SQL

Configure your ORM to log queries in development:

```typescript
// Drizzle query logging
import { drizzle } from 'drizzle-orm/node-postgres';

export const db = drizzle(pool, {
  logger: process.env.NODE_ENV === 'development',
});
```

When a query is slow, look at the generated SQL. Run `EXPLAIN ANALYZE` on it. Understand what the ORM is doing.

Sometimes the right answer is to bypass the ORM entirely:

```typescript
// When the ORM can't express what you need
const result = await db.execute(sql`
  WITH task_counts AS (
    SELECT project_id, count(*) as count
    FROM tasks
    WHERE workspace_id = ${workspaceId}
    GROUP BY project_id
  )
  SELECT p.*, tc.count
  FROM projects p
  LEFT JOIN task_counts tc ON p.id = tc.project_id
  WHERE p.workspace_id = ${workspaceId}
`);
```

### The Best of Both Worlds

A pragmatic approach: use the ORM for simple CRUD and common queries, drop to raw SQL for complex or performance-critical queries.

```typescript
// Simple queries: use Drizzle
const user = await db.query.users.findFirst({
  where: eq(users.id, userId),
});

// Insert/update: use Drizzle (protects against SQL injection)
await db.insert(tasks).values({
  title: userInput.title, // safely parameterized
  workspaceId,
});

// Complex analytics: use raw SQL
const stats = await db.execute(sql`
  SELECT
    date_trunc('day', created_at) as day,
    status,
    count(*) as count
  FROM tasks
  WHERE workspace_id = ${workspaceId}
    AND created_at > now() - interval '30 days'
  GROUP BY GROUPING SETS ((date_trunc('day', created_at), status), (status))
`);
```

The ORM handles 90% of your queries safely and productively. Raw SQL handles the 10% that need special treatment.

This isn't a failure of ORMs — it's using the right tool for each job. The ORM gives you safety and speed for routine operations. Raw SQL gives you power and control for the complex stuff.

## The Taste Test

**Scenario 1:** A colleague's API endpoint returns all tasks for a workspace. The query takes 200ms with 1,000 tasks. They propose adding pagination to improve performance.

*Your instinct should be:* Pagination is good UX, but 200ms for 1,000 rows suggests the query itself is slow. Run `EXPLAIN ANALYZE`. Is it using indexes? Is there an N+1 hiding in the code? Fix the query first, then add pagination for UX reasons.

**Scenario 2:** You see this pattern in a codebase:

```typescript
const users = await db.query.users.findMany();
const activeUsers = users.filter(u => u.status === 'active');
```

*Your instinct should be:* This fetches all users, then filters in JavaScript. If there are 100,000 users, you're loading all 100,000 to get 10,000 active ones. Filter in the database:

```typescript
const activeUsers = await db.query.users.findMany({
  where: eq(users.status, 'active'),
});
```

**Scenario 3:** An API endpoint that loads "projects with their tasks and task comments" has a response time that scales linearly with the number of projects.

*Your instinct should be:* Classic N+1, possibly N+1+1 (one for projects, N for tasks, N*M for comments). Check the query count. Use eager loading or restructure to batch fetches.

**Scenario 4:** A query runs in 10ms locally but takes 500ms in production.

*Your instinct should be:* Different data volumes. Your local database has hundreds of rows; production has millions. Run `EXPLAIN ANALYZE` in both environments. The query plan might be different (Postgres chooses plans based on table statistics). Add indexes that make sense at production scale.

**Scenario 5:** Someone proposes adding `SELECT COUNT(*)` to every list endpoint to show total record count.

*Your instinct should be:* `COUNT(*)` can be expensive on large tables in Postgres (it has to count actual rows due to MVCC). For pagination, consider showing "Page 1 of many" instead of exact counts, or cache the count and update it periodically. Only pay for exact counts when users actually need them.

## Practical Exercise

Take the project management schema from Chapter 2 and implement a performant data access layer.

**Requirements:**

1. Implement these endpoints:
   - `GET /workspaces/:id/projects` — List projects with task counts
   - `GET /projects/:id/tasks` — List tasks with assignee names, cursor-paginated
   - `GET /workspaces/:id/activity` — Activity feed with actor names and targets
   - `GET /tasks/search?q=...` — Full-text search across task titles and descriptions

2. Each endpoint must:
   - Complete in under 50ms with 100,000 rows in the database
   - Not have N+1 queries (verify with query logging)
   - Use appropriate indexes (verify with `EXPLAIN ANALYZE`)

3. Generate 100,000+ realistic seed records using AI

**AI Integration Point:**

Use Claude to generate realistic seed data:

```
Generate a Node.js script that seeds a PostgreSQL database for a project management app with:
- 10 workspaces
- 50 users (distributed across workspaces)
- 100 projects (distributed across workspaces)
- 100,000 tasks with realistic titles, descriptions, and status distributions:
  - 60% todo, 25% in_progress, 15% done
  - 70% have assignees, 30% unassigned
  - 40% have due dates (spread over the past month to 2 months in future)
- 200,000 comments on tasks

Use faker.js for realistic content. Make the script idempotent (can run multiple times safely).
```

Then run the queries against this dataset and analyze performance.

**Acceptance Criteria:**
- All endpoints complete in <50ms with seeded data
- Query logging shows no N+1 patterns
- `EXPLAIN ANALYZE` shows index usage on all hot-path queries
- Pagination is cursor-based, not offset-based

**Why cursor-based pagination?**

Offset pagination (`LIMIT 20 OFFSET 40`) has problems:
1. **Performance degrades.** Postgres still scans past the offset, so page 1000 is slower than page 1.
2. **Inconsistent results.** If items are added/removed between page loads, you might skip or duplicate items.

Cursor pagination uses a stable reference point:

```typescript
// Cursor-based: return tasks after this ID
const tasks = await db.execute(sql`
  SELECT * FROM tasks
  WHERE workspace_id = ${workspaceId}
    AND (created_at, id) < (${cursorTimestamp}, ${cursorId})
  ORDER BY created_at DESC, id DESC
  LIMIT 21  -- Fetch one extra to detect if there's a next page
`);

const hasNextPage = tasks.length > 20;
const results = tasks.slice(0, 20);
const nextCursor = results.length
  ? encode({ ts: results[results.length - 1].created_at, id: results[results.length - 1].id })
  : null;
```

The cursor is typically a base64-encoded JSON object with the values needed to continue the query.

## Key Takeaways

Before moving to the next chapter, internalize these principles:

1. **Measure before optimizing.** Run `EXPLAIN ANALYZE`. Know whether a query is slow because of missing indexes, poor join strategies, or too much data. Don't guess.

2. **N+1 is the most common performance bug.** Learn to spot it (same query repeated with different IDs), learn to fix it (eager loading, batching, JOINs).

3. **Indexes have costs.** They speed up reads but slow down writes. Add them intentionally based on actual query patterns, not speculatively.

4. **Connection pooling is non-negotiable.** Your app will crash without it under any real load.

5. **Know your ORM's SQL.** Enable query logging. When something is slow, look at the generated SQL. Sometimes the fix is raw SQL.

6. **50ms is slow for a database query.** With proper indexes, most queries should complete in under 10ms. If you're seeing 100ms+ consistently, investigate.

## Checkpoint

After completing this chapter and the exercise, you should be able to agree with these statements:

- [ ] I can write JOIN queries and know when to use INNER vs LEFT JOIN
- [ ] I can identify N+1 problems in code and fix them with eager loading, DataLoader, or query restructuring
- [ ] I can read `EXPLAIN ANALYZE` output and identify sequential scans, missing indexes, and slow operations
- [ ] I understand connection pooling and can configure it for a Node.js application
- [ ] I know the trade-offs of using an ORM vs raw SQL and when each is appropriate
- [ ] I can write a query that performs well at 100k+ rows by using appropriate indexes
- [ ] I can use window functions for pagination and analytics queries
- [ ] I have a systematic approach to diagnosing slow queries (measure, analyze, fix, verify)
