# Capstone: The Full Data Layer

## Why This Matters

You've learned the individual pieces: Postgres schema design, query optimization, Redis caching, and the decision framework for additional data stores. Now you bring them together.

This capstone isn't a tutorial to follow — it's a specification to implement. The goal is to build something that demonstrates sound judgment, not just working code. A senior engineer reviewing your solution should see that you understand *why* things are built a certain way, not just *how*.

This is also a preview of how technical work gets evaluated. The code matters, but the decisions matter more. Documentation of your reasoning is as important as the implementation.

## Project Brief

Build the complete data layer for a SaaS project management tool.

The product requirements are:
- Multi-tenant: multiple workspaces, each isolated
- Users can belong to multiple workspaces
- Workspaces contain projects, projects contain tasks
- Tasks can have comments and file attachments
- Activity logs track who did what
- A "find similar tasks" AI feature suggests related tasks

You're building the data layer only — no API routes, no frontend. A backend engineer should be able to write API endpoints against your data layer tomorrow.

## Requirements and Deliverables

### 1. Postgres Schema

Create a complete schema with Drizzle ORM that includes:

**Core tables:**
- `workspaces` — Multi-tenant containers
- `users` — User accounts
- `workspace_members` — Many-to-many with roles
- `projects` — Containers for tasks within a workspace
- `tasks` — The main work items
- `comments` — Discussion on tasks
- `attachments` — File metadata (actual files in S3)
- `activity_logs` — Audit trail

**Requirements:**
- All foreign keys properly defined
- `workspace_id` on every tenant-scoped table
- `created_at`, `updated_at` on all tables
- Soft deletes where appropriate (tasks, projects — not comments)
- JSONB `metadata` column on tasks for extensibility
- Embedding column (vector) on tasks for similarity search

### 2. Migration History

Create a migration sequence that:
- Builds the complete schema from scratch
- Includes at least one "add feature" migration that demonstrates the expand/contract pattern
- All migrations are reversible

### 3. Seed Script

Generate 100,000+ realistic records:
- 5-10 workspaces
- 50-100 users distributed across workspaces
- 200-500 projects
- 100,000 tasks with realistic distribution:
  - Status: 60% todo, 25% in_progress, 15% done
  - 70% assigned, 30% unassigned
  - 40% have due dates
- 300,000 comments
- Activity logs for task creation and status changes

The data should look real:
- Task titles should be realistic ("Fix login button alignment", not "Task 1")
- Descriptions should be varied
- Timestamps should span the last 6 months
- Assignment and completion patterns should be realistic

⚡ **AI Shortcut:** Use Claude to generate the seed script. Provide specific distributions and constraints. Have it use faker.js for realistic content generation.

### 4. Indexes

Add indexes that support these query patterns efficiently:

| Query Pattern | Target |
|--------------|--------|
| List tasks by workspace and status | <10ms at 100k tasks |
| List tasks assigned to a user, by due date | <10ms |
| Search tasks by title/description | <50ms |
| Get comments for a task, chronological | <5ms |
| Activity feed for a workspace, recent first | <20ms |
| Find similar tasks (vector) | <100ms |

Verify each with `EXPLAIN ANALYZE` against your seeded data.

### 5. Redis Caching Layer

Implement cache-aside caching for:
- Project details with task counts
- Workspace member list with roles
- User's assigned task count per workspace

Include:
- TTL-based expiration
- Event-based invalidation when underlying data changes
- Graceful fallback when Redis is unavailable

### 6. S3 Integration

Implement presigned URLs for:
- File upload (frontend uploads directly to S3)
- File download (temporary access to private files)

Store file metadata in Postgres, actual files in S3.

### 7. Vector Similarity Search

Implement the "find similar tasks" feature:
- Store embeddings in pgvector
- Implement similarity search endpoint
- For the capstone, you can use random embeddings in seed data

The implementation should be ready for real embeddings from OpenAI.

### 8. Architecture Decision Record (ADR)

Write a markdown document explaining:
- Every data store choice (Postgres, Redis, S3, pgvector) with justification
- The alternatives considered and why they were rejected
- Known limitations and when you'd revisit decisions
- Operational considerations (backup strategy, monitoring needs)

## Evaluation Criteria

How do you know you did it well?

### Performance

- [ ] Queries complete within target times at 100k+ rows
- [ ] No N+1 patterns in common operations
- [ ] Indexes are used (verified with `EXPLAIN ANALYZE`)
- [ ] Cache hit rate > 80% for cached endpoints

### Data Integrity

- [ ] Foreign keys prevent orphaned records
- [ ] Constraints enforce valid states (e.g., completed tasks have `completed_at`)
- [ ] Workspace isolation is enforced — queries can't leak across tenants

### Evolvability

- [ ] Schema can accommodate foreseeable features without painful migrations
- [ ] Adding a new field to tasks doesn't require downtime
- [ ] JSONB `metadata` is used for genuinely flexible parts, not as a schema avoidance mechanism

### Operational Readiness

- [ ] Migrations run idempotently (can be re-run safely)
- [ ] Application handles Redis unavailability gracefully
- [ ] File uploads work via presigned URLs
- [ ] ADR documents decisions for future engineers

### Code Quality

- [ ] Drizzle schema is type-safe and readable
- [ ] Cache keys are consistently named and documented
- [ ] Error handling is explicit, not swallowed
- [ ] Seed script is idempotent and configurable

## Stretch Goals

If you finish early and want more challenge:

1. **Row-Level Security:** Implement Postgres RLS policies that enforce workspace isolation at the database level, not just application level.

2. **Change Data Capture:** Set up triggers that automatically log changes to an audit table.

3. **Batch Import:** Implement a system for importing tasks from CSV, handling 10,000+ tasks in a single operation efficiently.

4. **Cache Warming:** Implement a background job that pre-warms the cache for frequently accessed data.

## Submission Structure

Organize your submission like a real project:

```
phase1-capstone/
├── src/
│   ├── db/
│   │   ├── schema.ts          # Drizzle schema
│   │   ├── index.ts           # DB connection
│   │   └── migrations/        # Migration files
│   ├── cache/
│   │   ├── index.ts           # Redis client
│   │   ├── project.cache.ts   # Project caching logic
│   │   └── invalidation.ts    # Invalidation helpers
│   ├── storage/
│   │   └── s3.ts              # Presigned URL generation
│   └── search/
│       └── similarity.ts      # Vector search
├── scripts/
│   └── seed.ts                # Seed data generation
├── docs/
│   ├── ADR.md                 # Architecture Decision Record
│   └── QUERY_ANALYSIS.md      # EXPLAIN ANALYZE outputs
├── docker-compose.yml         # Local dev setup
├── drizzle.config.ts
├── package.json
└── README.md                  # Setup and run instructions
```

## Timeline

This capstone is designed to take 8-15 hours of focused work:
- Schema design and migrations: 2-3 hours
- Indexes and query optimization: 2-3 hours
- Caching layer: 2-3 hours
- S3 integration: 1-2 hours
- Vector search: 1-2 hours
- Seed script: 1-2 hours
- Documentation: 1-2 hours

Don't rush. The goal is to build something you'd be proud to show in a technical interview or use as the foundation for a real product.

## Ready?

You have all the knowledge you need from Chapters 2-5. Now apply it.

When you're done, you'll have:
- A production-ready data layer
- Documentation that demonstrates your judgment
- A portfolio piece that shows backend competence
- Confidence that you understand the data layer deeply

This is what Phase 1 was building toward. Make it count.
