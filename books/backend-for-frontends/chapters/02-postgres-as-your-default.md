# Postgres as Your Default Answer

## Why This Matters

Every startup needs to pick a database. It's one of the earliest technical decisions, and it's one that's almost impossible to reverse without significant pain. Pick wrong and you'll spend years working around limitations or migrating to something better.

Here's the good news: for almost every startup, the answer is PostgreSQL. Not "it depends on your use case." Not "relational databases are generally a good choice." Postgres, specifically, is the right default.

This isn't a marginal preference — it's a strong recommendation backed by decades of production use across companies of every size. Postgres handles everything from local development to millions of transactions per second. It's what you'll find at mature startups, at banks, at governments. Learning Postgres deeply is one of the highest-leverage investments you can make as a backend engineer.

By the end of this chapter, you'll understand why Postgres is the right choice, and you'll be able to design schemas that evolve gracefully as your product changes. You'll know how to write migrations that don't cause downtime, how to add indexes that actually help, and how to use transactions to prevent data corruption.

## Why Postgres, Specifically

The question isn't "should I use a relational database?" The question is "which database will let me move fast now without creating problems later?" The answer is Postgres.

Why does this matter so much? Because your database is the one piece of infrastructure that's hardest to change. You can swap out your web framework in a few weeks. You can move from one cloud provider to another. But migrating from one database to another is a months-long project that requires touching every query in your application. Make a good choice upfront and you'll never have to think about it again.

**JSONB for semi-structured data.** When you need document-store flexibility — user preferences, dynamic form responses, configuration blobs — Postgres handles it with the `jsonb` type. You get the flexibility of storing nested, variable-schema data alongside the power of SQL queries. You can index into JSONB columns with GIN indexes for fast lookups. You don't need to run a separate MongoDB instance to handle semi-structured data.

```sql
-- Store flexible metadata alongside structured data
create table tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  metadata jsonb default '{}',
  created_at timestamptz default now()
);

-- Index into the JSONB for fast queries
create index idx_tasks_metadata on tasks using gin (metadata);

-- Query by nested JSONB values
select * from tasks where metadata->>'priority' = 'high';
select * from tasks where metadata @> '{"labels": ["urgent"]}';
```

**Full-text search.** Need search? Postgres has it built in. It's not as sophisticated as Elasticsearch, but it's good enough for most applications — and it doesn't require running another service. You can add full-text search to existing tables without a separate indexing pipeline.

```sql
-- Add full-text search to tasks
alter table tasks add column search_vector tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B')
  ) stored;

create index idx_tasks_search on tasks using gin (search_vector);

-- Search with ranking
select title, ts_rank(search_vector, query) as rank
from tasks, to_tsquery('english', 'backend & architecture') query
where search_vector @@ query
order by rank desc;
```

**Extensions ecosystem.** Need vector similarity search for AI features? pgvector. Need geospatial queries? PostGIS. Need scheduled jobs? pg_cron. The Postgres extension ecosystem means you can add capabilities without adding services.

**Operational maturity.** Postgres has been production-ready for decades. It's available as a managed service on every cloud: RDS on AWS, Cloud SQL on GCP, Azure Database for PostgreSQL. Backup, replication, failover — all solved problems. When you need help, there's abundant documentation and community knowledge.

💸 **Startup Cost Callout:** Managed Postgres starts at ~$15/month for a small instance on most clouds. That's cheaper than most meals and handles 90% of startup workloads. Don't overspend on database infrastructure until you have actual performance data suggesting you need more.

### What About Other Databases?

Let's address the alternatives briefly, since someone will ask:

**MySQL/MariaDB** — Fine databases, widely used. But Postgres has better JSON support, better extension ecosystem, and better standards compliance. If your company uses MySQL, that's fine. For new projects, Postgres is the better default.

**MongoDB** — Document databases have their place (we'll cover this in Chapter 5), but "I don't want to think about schemas" is not that place. Postgres with JSONB gives you document flexibility where you need it and relational structure where you need that.

**SQLite** — Excellent for embedded applications and local development. But it doesn't handle concurrent writes well and has no network protocol. Not for production web applications with multiple server instances.

**Managed NoSQL (DynamoDB, Firestore)** — Lock-in, weird pricing models, and optimized for specific access patterns. You're trading flexibility for...what exactly? Most startups don't need planet-scale distribution. They need reliable data storage with flexible queries.

The pattern you'll see in Chapter 5: start with Postgres, add Redis for caching/queues, add specialized stores only when you have specific needs Postgres can't handle. That covers 95% of startups.

## Schema Design for the Real World

Schema design isn't about following normalization rules from a textbook. It's about anticipating how your product will evolve and making that evolution cheap.

Let's design a schema for a project management tool — workspaces, users, projects, tasks, comments. Real SaaS, not a toy example.

### Starting Point: The Core Entities

```typescript
// src/db/schema.ts
import { pgTable, uuid, text, timestamp, boolean, jsonb } from 'drizzle-orm/pg-core';

export const workspaces = pgTable('workspaces', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: text('name').notNull(),
  slug: text('slug').notNull().unique(),
  settings: jsonb('settings').default({}),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});

export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').notNull().unique(),
  name: text('name'),
  avatarUrl: text('avatar_url'),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});

export const workspaceMembers = pgTable('workspace_members', {
  id: uuid('id').primaryKey().defaultRandom(),
  workspaceId: uuid('workspace_id').notNull().references(() => workspaces.id),
  userId: uuid('user_id').notNull().references(() => users.id),
  role: text('role').notNull().default('member'), // 'owner', 'admin', 'member'
  joinedAt: timestamp('joined_at', { withTimezone: true }).defaultNow(),
});

export const projects = pgTable('projects', {
  id: uuid('id').primaryKey().defaultRandom(),
  workspaceId: uuid('workspace_id').notNull().references(() => workspaces.id),
  name: text('name').notNull(),
  description: text('description'),
  color: text('color').default('#6366f1'),
  archived: boolean('archived').default(false),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});

export const tasks = pgTable('tasks', {
  id: uuid('id').primaryKey().defaultRandom(),
  workspaceId: uuid('workspace_id').notNull().references(() => workspaces.id),
  projectId: uuid('project_id').references(() => projects.id),
  creatorId: uuid('creator_id').notNull().references(() => users.id),
  assigneeId: uuid('assignee_id').references(() => users.id),
  title: text('title').notNull(),
  description: text('description'),
  status: text('status').notNull().default('todo'), // 'todo', 'in_progress', 'done'
  priority: text('priority').default('medium'), // 'low', 'medium', 'high', 'urgent'
  dueDate: timestamp('due_date', { withTimezone: true }),
  completedAt: timestamp('completed_at', { withTimezone: true }),
  position: text('position').notNull(), // For ordering within a project/status
  metadata: jsonb('metadata').default({}),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});

export const comments = pgTable('comments', {
  id: uuid('id').primaryKey().defaultRandom(),
  taskId: uuid('task_id').notNull().references(() => tasks.id),
  authorId: uuid('author_id').notNull().references(() => users.id),
  content: text('content').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});
```

A few things to notice:

**Foreign keys everywhere.** Every reference between tables has an explicit foreign key constraint. This isn't optional — it's how Postgres enforces data integrity. Without foreign keys, you end up with orphaned records, broken references, and bugs that only show up in production.

**`workspaceId` on nearly every table.** This is multi-tenancy. Every query will be scoped to a workspace, so having the workspace ID directly on each row (rather than joined through another table) makes queries simpler and faster.

**`createdAt`/`updatedAt` on everything.** You'll want to know when records were created and modified. Always. Add these columns from the start and update `updatedAt` automatically with a trigger or in your application code.

**JSONB `metadata` for extensibility.** Rather than anticipating every field you might need, include a `metadata` column for ad-hoc properties. Custom fields, integration data, temporary experiments — all can live here without schema changes.

### UUIDs vs Serial IDs

🤔 **Taste Moment:** The ID type decision.

Serial integers (`id serial primary key`) are simpler: smaller storage, faster indexes, easier to read in logs. UUIDs are larger and uglier.

But UUIDs win for most applications:

- **Client-side generation.** The frontend can generate IDs before the record exists in the database. Useful for optimistic updates and offline-first patterns.
- **Multi-system environments.** If you ever need to merge data from multiple sources, or replicate across regions, UUIDs don't collide. Serials do.
- **No information leakage.** Serial IDs reveal how many records exist and roughly when they were created. `/users/47` tells an attacker there are at least 47 users. `/users/a1b2c3d4...` reveals nothing.

The recommendation: use UUIDs by default. Use serial IDs only if you have a specific reason (e.g., very high-volume analytics tables where storage matters).

### Soft Deletes: Think Before You Add Them

🤔 **Taste Moment:** `deleted_at` is a pattern, not a requirement.

Soft deletes — marking records as deleted with a timestamp instead of actually removing them — are common advice. "Never delete data! What if you need it later?"

But soft deletes add complexity to every query. Every `SELECT` needs `WHERE deleted_at IS NULL`. Every index potentially includes deleted records. Every unique constraint needs to be partial (`WHERE deleted_at IS NULL`). Miss one filter and you're showing "deleted" data to users.

Use soft deletes when you genuinely need:
- User-facing "undo delete" functionality
- Audit trails for compliance
- Data recovery capabilities

Don't use them just because someone once told you "never delete data." Hard deletes are simpler. If you need audit trails, use a separate audit log table. If you need recovery, use database backups.

For our schema, tasks and projects get soft deletes (users expect to undo), but comments don't (users expect delete to mean delete).

```typescript
// Add soft delete only where genuinely needed
export const tasks = pgTable('tasks', {
  // ... other fields
  deletedAt: timestamp('deleted_at', { withTimezone: true }),
});
```

### Enum Types vs Lookup Tables

For values like `status` and `priority`, you have three options:

1. **PostgreSQL ENUM types.** Type-safe at the database level, but painful to modify — adding a value requires an `ALTER TYPE` migration.

2. **Lookup tables.** Fully normalized, easy to extend, but adds joins to every query.

3. **Text columns with application validation.** Flexible, no schema changes to add values, but no database-level enforcement.

For startups, option 3 is usually right. You'll change these values frequently as the product evolves. Adding a new status shouldn't require a migration. Validate in your application code with TypeScript enums or Zod schemas.

```typescript
// Application-level validation with Zod
import { z } from 'zod';

export const TaskStatus = z.enum(['todo', 'in_progress', 'review', 'done']);
export const TaskPriority = z.enum(['low', 'medium', 'high', 'urgent']);

// TypeScript gets the types
type TaskStatus = z.infer<typeof TaskStatus>;
```

### Constraints Beyond Foreign Keys

Foreign keys aren't the only constraints you should use. Postgres gives you several tools to enforce data integrity at the database level:

**CHECK constraints** enforce business rules:

```sql
-- Ensure due_date is in the future when set
alter table tasks add constraint check_due_date_future
  check (due_date is null or due_date > created_at);

-- Ensure completed_at is only set when status is 'done'
alter table tasks add constraint check_completed_status
  check ((status = 'done' and completed_at is not null)
      or (status != 'done' and completed_at is null));
```

**UNIQUE constraints** with partial indexes handle soft deletes:

```sql
-- Only enforce uniqueness among non-deleted projects
create unique index idx_projects_workspace_name_unique
  on projects (workspace_id, name)
  where deleted_at is null;
```

**NOT NULL constraints** are underused. Every column should be NOT NULL unless you have a specific reason for allowing nulls. Nulls complicate queries (three-valued logic, NULL != NULL) and indicate incomplete data. If a column is optional, consider whether it really should be — or whether you need a better data model.

🤔 **Taste Moment:** Constraints are documentation that Postgres enforces. When you write `assignee_id references users(id)`, you're telling future developers (and your future self) that this is a user reference that must exist. Let the database enforce your invariants.

### Activity Logging

You'll want an audit trail: who did what, when. There are two approaches:

**Option 1: Separate activity log table**

```typescript
export const activityLogs = pgTable('activity_logs', {
  id: uuid('id').primaryKey().defaultRandom(),
  workspaceId: uuid('workspace_id').notNull().references(() => workspaces.id),
  actorId: uuid('actor_id').notNull().references(() => users.id),
  action: text('action').notNull(), // 'task.created', 'task.status_changed', etc.
  targetType: text('target_type').notNull(), // 'task', 'project', 'comment'
  targetId: uuid('target_id').notNull(),
  metadata: jsonb('metadata').default({}), // { old_status: 'todo', new_status: 'done' }
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
});
```

This is explicit, queryable, and keeps your main tables clean. Use it for user-facing activity feeds and compliance audit trails.

**Option 2: CDC (Change Data Capture) with triggers**

```sql
-- Capture all changes to tasks table
create table task_history (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null,
  operation text not null, -- 'INSERT', 'UPDATE', 'DELETE'
  old_data jsonb,
  new_data jsonb,
  changed_at timestamptz default now()
);

create or replace function log_task_changes()
returns trigger as $$
begin
  insert into task_history (task_id, operation, old_data, new_data)
  values (
    coalesce(new.id, old.id),
    TG_OP,
    case when TG_OP = 'DELETE' then to_jsonb(old) else null end,
    case when TG_OP != 'DELETE' then to_jsonb(new) else null end
  );
  return coalesce(new, old);
end;
$$ language plpgsql;

create trigger task_audit_trigger
after insert or update or delete on tasks
for each row execute function log_task_changes();
```

This captures every change automatically, but the data is raw and harder to query for user-facing features. Use it for debugging and forensic analysis, not activity feeds.

For most applications, use option 1 (explicit activity logs) for user-facing features and save CDC for when you need it.

## Migrations as a First-Class Concern

Migrations aren't an afterthought — they're how your schema evolves safely in production. Every schema change is a migration. No exceptions.

### Migration Tooling

Drizzle Kit handles migrations:

```bash
# Generate a migration from schema changes
npx drizzle-kit generate:pg

# Apply migrations
npx drizzle-kit push:pg

# Or in production, with explicit migration files
npx drizzle-kit migrate
```

### Writing Reversible Migrations

Every migration should be reversible. Not because you'll always need to roll back, but because the discipline forces you to understand what you're changing.

```typescript
// drizzle/migrations/0001_add_task_position.ts
import { sql } from 'drizzle-orm';

export async function up(db) {
  await db.execute(sql`
    ALTER TABLE tasks ADD COLUMN position text;
  `);

  // Backfill existing rows
  await db.execute(sql`
    UPDATE tasks SET position = id::text WHERE position IS NULL;
  `);

  await db.execute(sql`
    ALTER TABLE tasks ALTER COLUMN position SET NOT NULL;
  `);
}

export async function down(db) {
  await db.execute(sql`
    ALTER TABLE tasks DROP COLUMN position;
  `);
}
```

### The Expand and Contract Pattern

When making breaking schema changes, use expand and contract:

1. **Expand:** Add the new structure alongside the old
2. **Migrate data:** Copy/transform data to the new structure
3. **Deploy new code:** Application uses the new structure
4. **Contract:** Remove the old structure

Example: Renaming a column from `due_date` to `deadline`.

```typescript
// Step 1: Expand - add new column
export async function up(db) {
  await db.execute(sql`
    ALTER TABLE tasks ADD COLUMN deadline timestamptz;
  `);

  // Copy existing data
  await db.execute(sql`
    UPDATE tasks SET deadline = due_date;
  `);

  // Add trigger to keep in sync during transition
  await db.execute(sql`
    CREATE OR REPLACE FUNCTION sync_task_deadline()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.deadline = COALESCE(NEW.deadline, NEW.due_date);
      NEW.due_date = COALESCE(NEW.due_date, NEW.deadline);
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER task_deadline_sync
    BEFORE INSERT OR UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION sync_task_deadline();
  `);
}

// Step 2: Deploy code that writes to both columns but reads from 'deadline'
// Step 3: Contract - in a later migration, remove the old column
export async function up(db) {
  await db.execute(sql`
    DROP TRIGGER IF EXISTS task_deadline_sync ON tasks;
    DROP FUNCTION IF EXISTS sync_task_deadline();
    ALTER TABLE tasks DROP COLUMN due_date;
  `);
}
```

🔒 **Security Callout:** Never run migrations that could lock tables during high traffic. Adding a column with a default used to lock the entire table in older Postgres versions. In Postgres 11+, `ADD COLUMN ... DEFAULT` is safe. But always test migrations against a copy of production data first.

### Migration Ordering in Production

The order of operations matters:

1. **Deploy new code that's compatible with both old and new schema** — your code should work whether or not the migration has run yet
2. **Run the migration** — this changes the database schema
3. **Deploy code that uses the new schema** — now you can use the new columns/tables
4. **Later: clean up backward-compatible code** — remove the old code paths

This sequence ensures zero-downtime deployments. If you deploy code that requires a new column before the column exists, your application crashes. If you run a migration that removes a column before deploying code that doesn't use it, your application crashes.

For simple additions (new nullable columns, new tables), you can sometimes combine steps. For anything that changes existing structure, follow the sequence.

## Indexes: The 20% You Need to Know

Indexes make queries fast. Too few indexes and your queries scan entire tables. Too many and your writes slow down and your storage bloats.

### B-tree Indexes (Your Default)

The standard index type. Good for equality (`=`) and range queries (`<`, `>`, `BETWEEN`), ordering (`ORDER BY`).

```sql
-- Index columns you filter and sort by
create index idx_tasks_workspace_status
  on tasks (workspace_id, status);

create index idx_tasks_project_position
  on tasks (project_id, position);

create index idx_tasks_assignee_due
  on tasks (assignee_id, due_date);
```

### Composite Index Column Order

For composite indexes, column order matters. Put the columns you filter by equality first, then range/sort columns.

```sql
-- Good: equality column first, then range column
create index idx_tasks_workspace_created
  on tasks (workspace_id, created_at);

-- This index is efficient for:
-- WHERE workspace_id = 'x' ORDER BY created_at
-- WHERE workspace_id = 'x' AND created_at > '2026-01-01'

-- But NOT efficient for:
-- WHERE created_at > '2026-01-01' (can't use the index well)
```

### Partial Indexes

Index only the rows that matter. Smaller indexes are faster.

```sql
-- Only index non-deleted tasks
create index idx_tasks_workspace_active
  on tasks (workspace_id, status)
  where deleted_at is null;

-- Only index incomplete tasks
create index idx_tasks_incomplete
  on tasks (assignee_id, due_date)
  where status != 'done' and deleted_at is null;
```

### GIN Indexes for JSONB

When you query into JSONB columns, use GIN indexes:

```sql
-- Index the entire JSONB column
create index idx_tasks_metadata on tasks using gin (metadata);

-- Supports queries like:
-- WHERE metadata @> '{"priority": "high"}'
-- WHERE metadata ? 'custom_field'
```

### The Cost of Indexes

Every index:
- Increases storage (indexes can be larger than the table itself)
- Slows down writes (every INSERT/UPDATE/DELETE touches the index)
- Needs maintenance (bloat accumulates, especially with heavy updates)

🤔 **Taste Moment:** Don't add indexes speculatively. Add them when you have slow queries. Use `EXPLAIN ANALYZE` to verify they're being used.

### Reading EXPLAIN ANALYZE

When a query is slow, `EXPLAIN ANALYZE` tells you why:

```sql
explain analyze
select * from tasks
where workspace_id = 'abc123'
  and status = 'todo'
order by created_at desc
limit 20;
```

Output (without index):
```
Limit  (cost=1234.56..1234.78 rows=20 width=200) (actual time=45.123..45.145 rows=20 loops=1)
  ->  Sort  (cost=1234.56..1267.89 rows=13000 width=200) (actual time=45.120..45.130 rows=20 loops=1)
        Sort Key: created_at DESC
        Sort Method: top-N heapsort  Memory: 30kB
        ->  Seq Scan on tasks  (cost=0.00..1100.00 rows=13000 width=200) (actual time=0.020..35.000 rows=13000 loops=1)
              Filter: ((workspace_id = 'abc123'::uuid) AND (status = 'todo'::text))
              Rows Removed by Filter: 87000
```

**Red flags:**
- `Seq Scan` on a large table (scanning all 100,000 rows)
- `Rows Removed by Filter: 87000` (read 100k, kept 13k)
- `actual time=45.123` (45ms is slow for a simple lookup)

After adding an index:
```sql
create index idx_tasks_workspace_status_created
  on tasks (workspace_id, status, created_at desc);
```

Output:
```
Limit  (cost=0.42..1.50 rows=20 width=200) (actual time=0.050..0.080 rows=20 loops=1)
  ->  Index Scan using idx_tasks_workspace_status_created on tasks  (cost=0.42..500.00 rows=13000 width=200) (actual time=0.048..0.075 rows=20 loops=1)
        Index Cond: ((workspace_id = 'abc123'::uuid) AND (status = 'todo'::text))
```

**Green flags:**
- `Index Scan` instead of `Seq Scan`
- `actual time=0.050` (sub-millisecond)
- No "Rows Removed by Filter" — the index found exactly what we needed

### Common EXPLAIN ANALYZE Patterns

Here are patterns you'll encounter and what they mean:

**Index Only Scan** — The query was satisfied entirely from the index, without touching the table. This is ideal but requires a covering index (all needed columns are in the index) and recent vacuuming.

**Bitmap Heap Scan** — Postgres built a bitmap of matching rows from multiple indexes, then fetched them. Common when combining multiple conditions. Usually efficient.

**Nested Loop** — For each row from one source, scan the other. Efficient for small outer tables with indexed inner lookups. Slow if the outer set is large.

**Hash Join** — Build a hash table from one set, probe it with the other. Efficient for larger joins, especially equality joins. Watch for high "Rows Removed" in the build phase.

**Sort** — Postgres had to sort results. Check if you can add an index that provides the sort order directly.

⚡ **AI Shortcut:** When analyzing a complex query plan, paste the entire `EXPLAIN ANALYZE` output to Claude with "What's the bottleneck in this query plan and how would you address it?" AI is good at spotting patterns in plan output.

## Transactions and Isolation Levels

Transactions prevent data corruption when multiple operations need to succeed or fail together.

### The Race Condition Without Transactions

Consider assigning a task to the first available team member:

```typescript
// ❌ Without a transaction: race condition
async function assignTask(taskId: string, teamMemberIds: string[]) {
  // Find a team member who has fewer than 10 active tasks
  const available = await db.query.workspaceMembers.findFirst({
    where: and(
      inArray(workspaceMembers.userId, teamMemberIds),
      sql`(
        select count(*) from tasks
        where assignee_id = workspace_members.user_id
        and status != 'done'
      ) < 10`
    ),
  });

  if (!available) {
    throw new Error('No available team members');
  }

  // Between the check above and the update below, another request
  // might have assigned a task to this same user
  await db.update(tasks)
    .set({ assigneeId: available.userId })
    .where(eq(tasks.id, taskId));
}
```

Two concurrent requests could both find the same "available" team member who has 9 tasks, and both assign to them, leaving them with 11 tasks.

### The Fix: Transactions with Row Locking

```typescript
// ✅ With transaction and locking
async function assignTask(taskId: string, teamMemberIds: string[]) {
  return await db.transaction(async (tx) => {
    // Lock the task row to prevent concurrent assignment
    const [task] = await tx.execute(sql`
      SELECT * FROM tasks WHERE id = ${taskId} FOR UPDATE
    `);

    if (task.assignee_id) {
      throw new Error('Task already assigned');
    }

    // Find and lock an available team member
    const [available] = await tx.execute(sql`
      SELECT wm.user_id FROM workspace_members wm
      WHERE wm.user_id = ANY(${teamMemberIds})
      AND (
        SELECT count(*) FROM tasks
        WHERE assignee_id = wm.user_id
        AND status != 'done'
      ) < 10
      LIMIT 1
      FOR UPDATE
    `);

    if (!available) {
      throw new Error('No available team members');
    }

    await tx.update(tasks)
      .set({ assigneeId: available.user_id, updatedAt: new Date() })
      .where(eq(tasks.id, taskId));

    return available.user_id;
  });
}
```

`FOR UPDATE` locks the selected rows until the transaction commits. Another transaction trying to select the same rows will wait.

### Isolation Levels

Postgres has four isolation levels. You need to know two:

**READ COMMITTED (the default).** Each statement sees only data committed before it started. Good enough for almost everything.

**SERIALIZABLE.** Transactions execute as if they ran one at a time. Catches all anomalies but can cause more retries. Use it when correctness matters more than throughput — financial transactions, inventory counts.

```typescript
// Use SERIALIZABLE for critical operations
await db.transaction(async (tx) => {
  // ... critical operation
}, { isolationLevel: 'serializable' });
```

🤔 **Taste Moment:** Start with READ COMMITTED. Only reach for SERIALIZABLE when you've identified a specific concurrency bug that it would prevent. Overusing SERIALIZABLE hurts performance and increases retry complexity.

### Advisory Locks for Application-Level Coordination

Sometimes you need to coordinate across transactions without locking specific rows. Advisory locks are application-level locks that Postgres tracks for you:

```typescript
// Prevent concurrent processing of the same task
async function processTaskExclusively(taskId: string) {
  // Convert UUID to a numeric lock key (hash it)
  const lockKey = hashToInt(taskId);

  return await db.transaction(async (tx) => {
    // Try to acquire the lock (returns false immediately if unavailable)
    const [{ acquired }] = await tx.execute(sql`
      SELECT pg_try_advisory_xact_lock(${lockKey}) as acquired
    `);

    if (!acquired) {
      throw new Error('Task is being processed by another worker');
    }

    // Do the work...
    // Lock is automatically released when transaction commits
  });
}
```

Advisory locks are useful for:
- Job deduplication (prevent the same job from running twice)
- Rate limiting per resource
- Coordinating distributed workers

The key: they're application-managed. Postgres doesn't know what you're protecting — you're just getting a named lock.

## The Taste Test

You've learned the foundations. Now let's test your judgment.

**Scenario 1:** A colleague proposes adding a `tags` table with a many-to-many relationship to tasks, even though there's currently no tags feature planned. "It'll be easier to add later if the schema is already there."

*Your instinct should be:* Don't add it. Speculative schema additions create maintenance burden (more tables to consider, more migration edge cases) without benefit. Add the tags schema when you actually build the feature. A schema migration takes an hour; an unused table costs attention forever.

**Scenario 2:** You're reviewing a PR that adds a new string column without a default value to a table with 10 million rows.

*Your instinct should be:* This could be dangerous. In older Postgres, adding a column without a default required rewriting the entire table. In Postgres 11+, `ADD COLUMN ... DEFAULT` is safe, but adding a non-nullable column without a default will fail if there's existing data. Verify the migration handles existing rows and won't lock the table.

**Scenario 3:** A teammate wants to use MongoDB instead of Postgres because "we're not sure what the schema will look like yet."

*Your instinct should be:* This is a red flag. Schema uncertainty is not a reason to use MongoDB — it's a reason to use Postgres with JSONB. You get flexibility where you need it (JSONB columns) and structure where you need it (typed columns with constraints). MongoDB's schemaless nature feels liberating initially but becomes painful when you need to query across documents with inconsistent shapes.

**Scenario 4:** You see `select *` in application code instead of explicit column selection.

*Your instinct should be:* Mildly concerning but not critical. `SELECT *` fetches all columns, which can hurt performance if the table has large columns you don't need (like `text` descriptions or `jsonb` blobs). More importantly, it breaks when columns are added or renamed. Prefer explicit column selection. But don't refactor working code just for this — fix it when you're already touching that query.

**Scenario 5:** A migration adds an index with `CREATE INDEX idx_foo ON large_table (column)` without `CONCURRENTLY`.

*Your instinct should be:* Dangerous in production. Regular `CREATE INDEX` locks the table for writes. On a large table, this can cause downtime. Use `CREATE INDEX CONCURRENTLY`, which builds the index without blocking writes (though it takes longer and can't run inside a transaction).

## Practical Exercise

Design and implement the data layer for the project management tool described in this chapter.

**Requirements:**
1. Create the full schema in Drizzle ORM: workspaces, users, workspace_members, projects, tasks, comments
2. Write migrations for the schema (Drizzle Kit)
3. Add appropriate indexes for these query patterns:
   - List tasks in a workspace by status
   - List tasks assigned to a user, ordered by due date
   - Search tasks by title/description text
   - Get all comments for a task, ordered by creation time
4. Implement a transaction that safely assigns a task to a team member (as shown above)
5. Generate 10,000+ realistic seed records

**AI Integration Point:**

After creating your schema, give it to Claude with this prompt:

```
Here is a PostgreSQL schema for a multi-tenant project management app:

[paste your schema]

Analyze this schema for:
1. Normalization issues that will cause data inconsistency
2. Missing indexes for these query patterns: [list your actual query patterns]
3. Multi-tenancy isolation gaps — can a query accidentally leak data across workspaces?
4. Schema evolution risks — what product changes would require painful migrations?
```

Iterate on your schema based on the feedback. Then verify by actually running the queries against your seeded database with `EXPLAIN ANALYZE`.

**Acceptance Criteria:**
- All tables have appropriate foreign keys and constraints
- Migrations run successfully from a fresh database
- Each query pattern has an index that shows up in `EXPLAIN ANALYZE`
- The assignment transaction handles concurrent requests correctly (test with two terminals)
- Seed data is realistic (varied names, dates, distributions — not just "Test Task 1, Test Task 2")

**Setup instructions:**

Start Postgres locally with Docker Compose:

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: project_management
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

Run with `docker compose up -d`, then connect with your Drizzle config pointing to `postgres://dev:dev@localhost:5432/project_management`.

**Testing concurrency:**

To verify your transaction handles concurrent requests:

```bash
# Terminal 1
psql -U dev -d project_management
BEGIN;
SELECT * FROM tasks WHERE id = 'your-task-id' FOR UPDATE;
-- Don't commit yet, leave the terminal open

# Terminal 2 (in another window)
psql -U dev -d project_management
SELECT * FROM tasks WHERE id = 'your-task-id' FOR UPDATE;
-- This should hang, waiting for Terminal 1's lock

# Back to Terminal 1
COMMIT;
-- Now Terminal 2's query completes
```

## Checkpoint

After completing this chapter and the exercise, you should be able to agree with these statements:

- [ ] I can design a schema that separates normalized structured data from flexible JSONB columns appropriately
- [ ] I understand when to use UUIDs vs serial IDs and can defend my choice
- [ ] I can write migrations that are reversible and safe for production
- [ ] I know which columns to index for a given query pattern and can verify with EXPLAIN ANALYZE
- [ ] I understand what transactions prevent and when to use row-level locking
- [ ] I can evaluate a schema proposal and identify potential issues before they become problems
- [ ] I know when soft deletes are appropriate and when they add unnecessary complexity
- [ ] I can set up Postgres locally with Docker and connect to it from a Node.js application
- [ ] I understand the trade-offs between database-level constraints and application-level validation
