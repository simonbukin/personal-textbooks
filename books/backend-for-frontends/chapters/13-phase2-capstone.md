# Capstone: The Complete Backend

## The Complete Backend

You've built the pieces. Now assemble them into a complete, production-ready backend.

The Phase 1 capstone gave you a data layer: Postgres schema, Redis caching, efficient queries. Phase 2 added everything else: project structure, authentication, authorization, background jobs, API design, and testing. This capstone integrates all of it into a cohesive system.

By the end, you'll have a backend that could power a real startup.

## Project: TaskFlow API

Build the complete backend for **TaskFlow**, a project management application. This isn't a toy — it's a backend you could actually ship.

### Core Features

**Workspaces:**
- Multi-tenant isolation
- Workspace settings (name, billing plan)
- Member management with roles (owner, admin, member)

**Projects:**
- Projects belong to workspaces
- Project visibility settings
- Project archiving

**Tasks:**
- Full CRUD with validation
- Status workflow (pending → in_progress → complete)
- Assignments, priorities, due dates
- Comments and activity feed

**User Management:**
- Clerk (or equivalent) for authentication
- Local user records linked to auth provider
- Profile management

**Exports:**
- Export tasks to CSV/PDF
- Background job processing
- Progress tracking and notifications

**Webhooks:**
- Configurable webhook endpoints per workspace
- Event delivery for task lifecycle events
- Signature verification and retry logic

### Technical Requirements

**Architecture:**
- Modular monolith structure from Chapter 8
- Clean separation between routes, services, and repositories
- Dependency injection without frameworks
- Centralized error handling

**Database:**
- PostgreSQL with Drizzle ORM
- Proper indexing for common queries
- Redis caching for hot paths
- Migrations tracked in version control

**Authentication & Authorization:**
- Auth provider integration (Clerk)
- Resource-level authorization checks
- Policy pattern for permission logic
- API key authentication for webhooks

**Background Jobs:**
- BullMQ for job processing
- Export queue with progress tracking
- Webhook delivery queue with retries
- Dead letter queue for failed jobs

**API Design:**
- RESTful endpoints with consistent naming
- Cursor-based pagination
- Proper HTTP status codes
- Rate limiting
- Request validation with Zod

**Testing:**
- Unit tests for policies and utilities
- Integration tests for services and repositories
- API tests for endpoints
- Minimum 70% coverage on critical paths

### Acceptance Criteria

Your capstone must pass these checks:

**Functionality:**
- [ ] Users can create workspaces and invite members
- [ ] Members can create projects and tasks
- [ ] Authorization prevents cross-workspace access
- [ ] Exports generate correctly and deliver notifications
- [ ] Webhooks deliver with signatures and retry on failure

**Code Quality:**
- [ ] Modules have clear boundaries (no circular dependencies)
- [ ] All public APIs are validated with Zod schemas
- [ ] Errors return consistent format with request IDs
- [ ] No hardcoded secrets in code

**Performance:**
- [ ] Task list endpoint returns in under 100ms with 1000 tasks
- [ ] No N+1 queries in list endpoints
- [ ] Pagination works correctly

**Testing:**
- [ ] Tests pass with `npm test`
- [ ] Integration tests use real database
- [ ] Coverage report shows critical paths tested

**Infrastructure:**
- [ ] Docker Compose runs all dependencies
- [ ] Migrations apply cleanly on fresh database
- [ ] Environment variables documented in `.env.example`

## Implementation Guide

### Week 1: Foundation

1. **Project setup:**
   - Initialize Node.js project with TypeScript
   - Configure Drizzle ORM and migrations
   - Set up Docker Compose for Postgres and Redis
   - Create modular folder structure

2. **Data layer:**
   - Define schemas for workspaces, users, projects, tasks, comments
   - Write migrations
   - Implement repositories with Drizzle

3. **Basic API:**
   - Set up Hono with middleware (CORS, auth, error handling)
   - Implement workspace and project CRUD
   - Add request validation

### Week 2: Features and Polish

4. **Authentication:**
   - Integrate Clerk
   - Create user sync webhook
   - Implement session handling

5. **Authorization:**
   - Write workspace membership policies
   - Add resource-level checks to all endpoints
   - Test authorization boundaries

6. **Background jobs:**
   - Set up BullMQ queues
   - Implement export worker
   - Add progress tracking endpoint

7. **Testing:**
   - Write test infrastructure (factories, database setup)
   - Add tests for policies, services, and endpoints
   - Verify coverage targets

## AI Integration Points

Use AI tools throughout the capstone:

**Schema Review:**
```
Review this database schema for a multi-tenant project management app:

[paste your schema]

Check for:
1. Missing indexes for common query patterns
2. Multi-tenancy isolation gaps
3. Normalization issues
4. Schema evolution risks

Suggest improvements with explanations.
```

**Security Audit:**
```
Review this authorization implementation:

[paste policy and service files]

Look for:
1. Authorization bypass vulnerabilities
2. Missing checks on any endpoint
3. Information leakage through errors
4. Race conditions in permission changes
```

**Test Generation:**
```
Generate integration tests for this service:

[paste service code]

Cover:
1. Happy paths
2. Authorization failures
3. Validation errors
4. Edge cases (empty lists, null values)
```

**Code Review:**
```
Review this API endpoint implementation:

[paste route handler]

Check for:
1. REST convention violations
2. Missing error handling
3. Input validation gaps
4. Pagination issues
```

Document insights from each AI review session in your project notes.

## Evaluation Criteria

Your capstone will be evaluated on:

**Architecture (25%):**
- Clean module boundaries
- Appropriate abstraction levels
- No circular dependencies
- Configuration externalized

**API Design (25%):**
- RESTful conventions followed
- Consistent error handling
- Proper status codes
- Complete request validation

**Security (25%):**
- Authentication correctly implemented
- Authorization on every endpoint
- Secrets properly managed
- Rate limiting in place

**Quality (25%):**
- Tests pass and are meaningful
- Code is readable and documented where necessary
- Edge cases handled
- Performance acceptable

## Deliverables

1. **GitHub repository** with complete source code
2. **README** with:
   - Setup instructions
   - Environment variable documentation
   - Architecture overview
3. **API documentation** (OpenAPI spec or equivalent)
4. **AI review log** documenting prompts and insights

## Stretch Goals

If you finish early:

- Add real-time updates via WebSocket or SSE
- Implement full-text search with PostgreSQL or Typesense
- Add audit logging for compliance
- Build an admin dashboard for queue monitoring
- Implement soft deletes with restoration

## What You've Learned

Phase 2 taught you how to:

- Structure backend code for maintainability
- Implement authentication with providers and authorization yourself
- Build reliable background job systems
- Design APIs that frontend developers want to use
- Write tests that catch bugs without slowing you down

The capstone proves you can combine these skills into a working system. That's what "full-stack" actually means — not knowing every technology, but knowing how to build complete systems.

Phase 3 shifts focus from code to infrastructure: containers, CI/CD, cloud deployment, and observability. You'll learn to ship what you've built and keep it running.

## Common Pitfalls to Avoid

Teams typically hit these issues during the capstone:

**Authorization gaps:** It's easy to miss an endpoint. Create a checklist of every route and verify each has authorization. Use middleware to enforce default-deny.

**Over-engineering:** The capstone should work, not be perfect. Don't add features not in the requirements. Don't refactor working code for theoretical improvements.

**Test paralysis:** Don't aim for 100% coverage. Focus on critical paths first. If a test is hard to write, consider whether you're testing the right thing.

**Scope creep:** The feature list is fixed. Don't add "nice to have" features. Real projects have deadlines.

## Checkpoint

Before submitting your capstone, verify:

- [ ] All acceptance criteria marked complete
- [ ] Tests pass with `npm test`
- [ ] API documentation is complete
- [ ] Docker Compose starts all services
- [ ] README explains setup and architecture
- [ ] No secrets committed to the repository
- [ ] AI review log includes at least 3 sessions

This capstone represents everything from Phase 2. Take it seriously — the skills you've built are the foundation for everything that follows.
