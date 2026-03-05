# Project Structure and the Modular Monolith

## Why This Matters

How you structure a backend codebase matters more than which framework you pick.

A well-structured codebase is easy to navigate, test, and modify. A poorly structured one becomes a "big ball of mud" — everything depends on everything, changes in one place break things elsewhere, and new engineers are afraid to touch anything.

The difference isn't visible in the first month. It compounds over time. At 50,000 lines of code, a good structure means you can still ship features quickly. A bad structure means every change is a minefield.

You've experienced this on the frontend. Remember that React codebase where components were 500 lines long, props drilled through seven levels, and state lived in random places? Backend codebases have the same failure modes. The patterns to avoid them are different, but the principles are the same: clear boundaries, explicit dependencies, single responsibilities.

This chapter gives you a specific, opinionated structure that works for startups. It's not the only way, but it's a proven way. The goal isn't architectural purity — it's building something you can maintain and extend over years of product development.

## Why Microservices Are Wrong for You (Right Now)

Let's address the elephant in the room. You've heard "microservices" pitched as the modern way to build backends. Here's why that's wrong for most startups:

**Network calls instead of function calls.** When service A needs to call service B, you're making an HTTP or gRPC request instead of a function call. That's 1-10ms of latency per call, plus serialization, plus error handling for network failures. A chain of 5 service calls that would take 0.1ms as function calls takes 20-100ms over the network.

**Distributed transactions don't exist.** When you need to update data in two services atomically, you can't just wrap it in a database transaction. You need sagas, compensating transactions, or eventual consistency. This is hard to get right.

**Deployment complexity.** Each service needs its own deployment pipeline, its own monitoring, its own scaling configuration. A 10-service architecture has 10x the deployment complexity of a monolith.

**Operational overhead.** More services means more things that can fail independently. When the user reports "the app is slow," you need distributed tracing to figure out which service is the problem.

**Team coordination.** If every feature requires changes to multiple services owned by different teams, you spend more time coordinating than coding.

These costs are worth it at scale — when you have 50+ engineers, when different parts of the system have wildly different scaling requirements, when organizational boundaries require technical boundaries.

For a startup with 5-15 engineers, the costs outweigh the benefits. You don't have the scale to justify the complexity.

🤔 **Taste Moment:** When someone proposes microservices, ask: "What specific problem does this solve that a well-structured monolith doesn't?" If the answer is about future scale or "best practices," push back. If the answer is about specific, current pain (like "we need to scale the image processing separately from the API"), that's worth discussing.

### The "Modular Monolith to Microservices" Escape Hatch

Here's the best argument for the modular monolith approach: if you later decide you need microservices, the extraction is straightforward.

A well-structured module has:
- Clear boundaries (enforced by the index.ts public API)
- Explicit dependencies (injected, not hardcoded)
- Its own data access (repository pattern)

Extracting this to a microservice means:
1. Create a new service with the module's code
2. Replace direct function calls with API calls
3. Handle the distributed data problem (the hard part, but you'd face it anyway)

Compare this to extracting from a spaghetti monolith, where code is tangled and dependencies are hidden. That extraction is a rewrite. You're not building toward microservices; you're building a codebase that's structured well enough that microservices become a minor refactor if you ever need them.

The modular monolith gives you speed now and options later. Premature microservices give you pain now and maybe options later.

## The Modular Monolith

The alternative: a modular monolith. One deployable unit, but with clear internal boundaries.

The key insight: you can have most of the organizational benefits of microservices (clear module boundaries, team ownership, independent development) without the operational costs (network calls, distributed data, deployment complexity).

The boundaries are enforced by convention and code review, not by network calls. When (if) you need to extract a service later, the boundaries are already clear.

Think of it like React components. A well-designed component has a clear interface (props), encapsulates its implementation, and doesn't reach into other components' internals. Modules in a modular monolith follow the same principles, just at a larger scale.

### The Structure

```
src/
├── modules/
│   ├── workspaces/
│   │   ├── routes.ts         # HTTP route handlers
│   │   ├── service.ts        # Business logic
│   │   ├── repository.ts     # Data access
│   │   ├── types.ts          # TypeScript types and Zod schemas
│   │   └── index.ts          # Public API (what other modules can import)
│   ├── projects/
│   │   ├── routes.ts
│   │   ├── service.ts
│   │   ├── repository.ts
│   │   ├── types.ts
│   │   └── index.ts
│   ├── tasks/
│   │   ├── routes.ts
│   │   ├── service.ts
│   │   ├── repository.ts
│   │   ├── types.ts
│   │   └── index.ts
│   └── users/
│       ├── routes.ts
│       ├── service.ts
│       ├── repository.ts
│       ├── types.ts
│       └── index.ts
├── shared/
│   ├── middleware/
│   │   ├── auth.ts           # Authentication middleware
│   │   ├── error-handler.ts  # Global error handling
│   │   └── logging.ts        # Request logging
│   ├── utils/
│   │   ├── pagination.ts     # Cursor pagination helpers
│   │   └── dates.ts          # Date formatting
│   └── errors.ts             # Application error types
├── infrastructure/
│   ├── db/
│   │   ├── index.ts          # Drizzle client
│   │   └── schema.ts         # Full schema (re-exports from modules)
│   ├── cache/
│   │   └── index.ts          # Redis client
│   ├── queue/
│   │   └── index.ts          # BullMQ client
│   └── storage/
│       └── index.ts          # S3 client
├── jobs/
│   ├── email.job.ts          # Email sending worker
│   └── sync.job.ts           # Search sync worker
├── app.ts                    # Hono app setup
└── index.ts                  # Entry point
```

### The Dependency Rule

Modules can depend on `shared/` and `infrastructure/`. Modules cannot depend directly on other modules.

```typescript
// ✅ Allowed: module depends on shared
import { AuthMiddleware } from '@/shared/middleware/auth';
import { NotFoundError } from '@/shared/errors';

// ✅ Allowed: module depends on infrastructure
import { db } from '@/infrastructure/db';
import { redis } from '@/infrastructure/cache';

// ❌ Not allowed: module depends on another module directly
import { ProjectService } from '@/modules/projects/service'; // Don't do this
```

If module A needs data from module B, there are two approaches:

**Option 1: Pass data at the route level.**

The route handler fetches what it needs and passes it to the service.

```typescript
// src/modules/tasks/routes.ts
import { projectsService } from '@/modules/projects';

app.post('/tasks', async (c) => {
  const { projectId, ...taskData } = await c.req.json();

  // Fetch project at the route level
  const project = await projectsService.getById(projectId);
  if (!project) {
    throw new NotFoundError('Project not found');
  }

  // Pass project info to task service
  const task = await tasksService.create({
    ...taskData,
    projectId,
    workspaceId: project.workspaceId, // Data from another module
  });

  return c.json(task);
});
```

**Option 2: Shared database queries.**

For read-only access, query the shared schema directly.

```typescript
// src/modules/tasks/repository.ts
// Accessing projects table is allowed — schema is shared infrastructure
import { db, schema } from '@/infrastructure/db';

export async function getTasksWithProjects(workspaceId: string) {
  return db.query.tasks.findMany({
    where: eq(schema.tasks.workspaceId, workspaceId),
    with: {
      project: true, // Join from shared schema
    },
  });
}
```

The rule isn't "no data sharing" — it's "no hidden dependencies." Module B doesn't know or care that module A uses its data. The coupling is at the data layer (shared schema), not the code layer (importing services).

### Events for Cross-Module Communication

For more complex interactions, use events:

```typescript
// src/shared/events.ts
import { EventEmitter } from 'events';

export const eventBus = new EventEmitter();

export const events = {
  TASK_CREATED: 'task.created',
  TASK_COMPLETED: 'task.completed',
  PROJECT_ARCHIVED: 'project.archived',
} as const;
```

```typescript
// src/modules/tasks/service.ts - emit event
import { eventBus, events } from '@/shared/events';

async function complete(id: string) {
  const task = await repository.update(id, {
    status: 'done',
    completedAt: new Date()
  });

  eventBus.emit(events.TASK_COMPLETED, { taskId: task.id, projectId: task.projectId });

  return task;
}
```

```typescript
// src/modules/analytics/listeners.ts - listen for events
import { eventBus, events } from '@/shared/events';

eventBus.on(events.TASK_COMPLETED, async ({ taskId, projectId }) => {
  await updateProjectCompletionMetrics(projectId);
});
```

Events decouple the emitter from the listener. The tasks module doesn't need to know that analytics cares about task completion. When you add more listeners later, the tasks module doesn't change.

This pattern is especially useful for:
- Sending notifications (email on task assignment)
- Updating derived data (recalculate project progress)
- Logging and analytics
- Triggering background jobs

For background job integration, see Chapter 10. Events and background jobs work together naturally — the event triggers a job that does the work asynchronously.

### Choosing Between Options

How do you decide between direct calls, shared schema queries, and events?

| Approach | Use When | Example |
|----------|----------|---------|
| Pass at route level | Simple data from another module | Get project's workspaceId before creating a task |
| Shared schema query | Read-only access to related data | JOIN tasks with projects for a listing |
| Events | Side effects that shouldn't block | Send email when task is assigned |

The rule of thumb: prefer the simplest approach that keeps dependencies explicit. Direct calls are simplest but create dependencies. Events are most decoupled but add indirection. Choose based on the actual relationship between modules.

### What Each File Does

**`routes.ts`** — HTTP route handlers. Parse requests, call services, format responses. Thin layer — no business logic.

```typescript
// src/modules/tasks/routes.ts
import { Hono } from 'hono';
import { z } from 'zod';
import { tasksService } from './service';
import { CreateTaskSchema, UpdateTaskSchema } from './types';
import { authMiddleware } from '@/shared/middleware/auth';

export const tasksRoutes = new Hono()
  .use(authMiddleware)

  .get('/', async (c) => {
    const workspaceId = c.req.query('workspaceId');
    const tasks = await tasksService.list({ workspaceId });
    return c.json(tasks);
  })

  .post('/', async (c) => {
    const data = CreateTaskSchema.parse(await c.req.json());
    const task = await tasksService.create(data, c.get('userId'));
    return c.json(task, 201);
  })

  .patch('/:id', async (c) => {
    const id = c.req.param('id');
    const data = UpdateTaskSchema.parse(await c.req.json());
    const task = await tasksService.update(id, data);
    return c.json(task);
  })

  .delete('/:id', async (c) => {
    const id = c.req.param('id');
    await tasksService.delete(id);
    return c.body(null, 204);
  });
```

**`service.ts`** — Business logic. Orchestrates repository calls, enforces rules, handles cross-cutting concerns.

```typescript
// src/modules/tasks/service.ts
import { tasksRepository } from './repository';
import { Task, CreateTaskInput, UpdateTaskInput } from './types';
import { NotFoundError, ForbiddenError } from '@/shared/errors';
import { activityService } from '@/modules/activity';

export const tasksService = {
  async list(filters: { workspaceId?: string; assigneeId?: string }) {
    return tasksRepository.findMany(filters);
  },

  async getById(id: string): Promise<Task> {
    const task = await tasksRepository.findById(id);
    if (!task) {
      throw new NotFoundError('Task not found');
    }
    return task;
  },

  async create(input: CreateTaskInput, creatorId: string): Promise<Task> {
    const task = await tasksRepository.create({
      ...input,
      creatorId,
      status: 'todo',
    });

    // Log activity (cross-cutting concern)
    await activityService.log({
      type: 'task.created',
      targetId: task.id,
      actorId: creatorId,
    });

    return task;
  },

  async update(id: string, input: UpdateTaskInput): Promise<Task> {
    const existing = await this.getById(id);

    const updated = await tasksRepository.update(id, input);

    if (input.status && input.status !== existing.status) {
      // Status changed — log it
      await activityService.log({
        type: 'task.status_changed',
        targetId: id,
        metadata: { from: existing.status, to: input.status },
      });
    }

    return updated;
  },

  async delete(id: string): Promise<void> {
    await this.getById(id); // Ensure exists
    await tasksRepository.softDelete(id);
  },
};
```

**`repository.ts`** — Data access. All database queries go here. No business logic.

```typescript
// src/modules/tasks/repository.ts
import { db, schema } from '@/infrastructure/db';
import { eq, and, isNull } from 'drizzle-orm';

export const tasksRepository = {
  async findById(id: string) {
    return db.query.tasks.findFirst({
      where: and(
        eq(schema.tasks.id, id),
        isNull(schema.tasks.deletedAt)
      ),
    });
  },

  async findMany(filters: { workspaceId?: string; assigneeId?: string }) {
    return db.query.tasks.findMany({
      where: and(
        filters.workspaceId ? eq(schema.tasks.workspaceId, filters.workspaceId) : undefined,
        filters.assigneeId ? eq(schema.tasks.assigneeId, filters.assigneeId) : undefined,
        isNull(schema.tasks.deletedAt)
      ),
      orderBy: (tasks, { desc }) => [desc(tasks.createdAt)],
    });
  },

  async create(data: typeof schema.tasks.$inferInsert) {
    const [task] = await db.insert(schema.tasks).values(data).returning();
    return task;
  },

  async update(id: string, data: Partial<typeof schema.tasks.$inferInsert>) {
    const [task] = await db
      .update(schema.tasks)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(schema.tasks.id, id))
      .returning();
    return task;
  },

  async softDelete(id: string) {
    await db
      .update(schema.tasks)
      .set({ deletedAt: new Date() })
      .where(eq(schema.tasks.id, id));
  },
};
```

**`types.ts`** — TypeScript types and Zod schemas. Single source of truth for data shapes.

```typescript
// src/modules/tasks/types.ts
import { z } from 'zod';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import { schema } from '@/infrastructure/db';

// Generate schemas from Drizzle
export const TaskSchema = createSelectSchema(schema.tasks);
export type Task = z.infer<typeof TaskSchema>;

// Input schemas for validation
export const CreateTaskSchema = z.object({
  title: z.string().min(1).max(500),
  description: z.string().optional(),
  projectId: z.string().uuid().optional(),
  assigneeId: z.string().uuid().optional(),
  dueDate: z.string().datetime().optional(),
  priority: z.enum(['low', 'medium', 'high', 'urgent']).default('medium'),
});
export type CreateTaskInput = z.infer<typeof CreateTaskSchema>;

export const UpdateTaskSchema = CreateTaskSchema.partial().extend({
  status: z.enum(['todo', 'in_progress', 'review', 'done']).optional(),
});
export type UpdateTaskInput = z.infer<typeof UpdateTaskSchema>;
```

**`index.ts`** — Public API. What other modules can import.

```typescript
// src/modules/tasks/index.ts
export { tasksRoutes } from './routes';
export { tasksService } from './service';
export type { Task, CreateTaskInput, UpdateTaskInput } from './types';
```

The `index.ts` pattern is crucial. It defines what's public and what's private. Internal implementation details (helper functions, internal types) stay hidden. Other modules import through the public API.

This is similar to how you'd structure a React component library: the index.ts exports the public components, and internal components stay internal. The pattern scales from libraries to modules to entire services.

### Wiring It Together

All modules get composed in `app.ts`:

```typescript
// src/app.ts
import { Hono } from 'hono';
import { logger } from 'hono/logger';
import { requestId } from 'hono/request-id';

import { workspacesRoutes } from '@/modules/workspaces';
import { projectsRoutes } from '@/modules/projects';
import { tasksRoutes } from '@/modules/tasks';
import { usersRoutes } from '@/modules/users';
import { errorHandler } from '@/shared/middleware/error-handler';

const app = new Hono();

// Global middleware
app.use('*', requestId());
app.use('*', logger());

// Mount module routes
app.route('/api/workspaces', workspacesRoutes);
app.route('/api/projects', projectsRoutes);
app.route('/api/tasks', tasksRoutes);
app.route('/api/users', usersRoutes);

// Global error handler
app.onError(errorHandler);

export default app;
```

This is the composition root. All the pieces come together here, but each piece is defined in its own module.

## Dependency Injection Without a Framework

Some teams use DI frameworks (NestJS's IoC container, tsyringe, etc.). These add complexity and magic.

A simpler approach: factory functions and explicit arguments.

```typescript
// src/modules/tasks/service.ts
import type { TasksRepository } from './repository';
import type { ActivityService } from '@/modules/activity';

export function createTasksService(
  repository: TasksRepository,
  activityService: ActivityService
) {
  return {
    async create(input, creatorId) {
      const task = await repository.create({ ...input, creatorId });
      await activityService.log({ type: 'task.created', targetId: task.id });
      return task;
    },
    // ... other methods
  };
}

// In production setup
// src/modules/tasks/index.ts
import { createTasksService } from './service';
import { tasksRepository } from './repository';
import { activityService } from '@/modules/activity';

export const tasksService = createTasksService(tasksRepository, activityService);
```

For testing, you can inject mocks:

```typescript
// src/modules/tasks/service.test.ts
import { createTasksService } from './service';

describe('TasksService', () => {
  const mockRepository = {
    create: vi.fn(),
    findById: vi.fn(),
  };
  const mockActivityService = {
    log: vi.fn(),
  };

  const service = createTasksService(mockRepository, mockActivityService);

  it('creates a task and logs activity', async () => {
    mockRepository.create.mockResolvedValue({ id: '123', title: 'Test' });

    await service.create({ title: 'Test' }, 'user-123');

    expect(mockRepository.create).toHaveBeenCalled();
    expect(mockActivityService.log).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'task.created' })
    );
  });
});
```

This is explicit DI — no decorators, no containers, no magic. You can trace where every dependency comes from.

### When to Use a DI Framework

DI frameworks like NestJS's IoC container become useful when:
- Your application has 50+ services with complex dependency graphs
- You need advanced features like request-scoped services
- Your team is already familiar with the patterns

For most startups, explicit factory functions are sufficient. They're easier to understand, easier to debug, and work well up to medium-sized applications. If you outgrow them, you can add a DI container later — the refactoring is straightforward because your dependencies are already explicit.

## Error Handling Strategy

Scattered try/catch blocks and inconsistent error responses are a code smell. Centralize error handling.

### Define Error Types

```typescript
// src/shared/errors.ts
export class AppError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public code: string
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found') {
    super(message, 404, 'NOT_FOUND');
  }
}

export class ValidationError extends AppError {
  constructor(message: string, public details?: unknown) {
    super(message, 400, 'VALIDATION_ERROR');
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Access denied') {
    super(message, 403, 'FORBIDDEN');
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 401, 'UNAUTHORIZED');
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 409, 'CONFLICT');
  }
}
```

### Global Error Handler

```typescript
// src/shared/middleware/error-handler.ts
import { Context } from 'hono';
import { ZodError } from 'zod';
import { AppError, ValidationError } from '@/shared/errors';

export async function errorHandler(err: Error, c: Context) {
  console.error('Error:', err);

  // Zod validation errors
  if (err instanceof ZodError) {
    return c.json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid request data',
        details: err.errors,
      },
    }, 400);
  }

  // Known application errors
  if (err instanceof AppError) {
    return c.json({
      error: {
        code: err.code,
        message: err.message,
        details: err instanceof ValidationError ? err.details : undefined,
      },
    }, err.statusCode);
  }

  // Unknown errors — don't leak details
  return c.json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
    },
  }, 500);
}

// Wire up in app.ts
app.onError(errorHandler);
```

Now services can throw typed errors:

```typescript
// In service code
if (!task) {
  throw new NotFoundError('Task not found');
}

if (task.workspaceId !== userWorkspaceId) {
  throw new ForbiddenError('Cannot access tasks from another workspace');
}
```

The global handler converts these to consistent JSON responses. No try/catch in route handlers.

### Logging Errors

Centralized error handling is also where you add logging:

```typescript
// src/shared/middleware/error-handler.ts
import { logger } from '@/infrastructure/logging';

export async function errorHandler(err: Error, c: Context) {
  // Log the error with context
  logger.error({
    error: err.message,
    stack: err.stack,
    requestId: c.get('requestId'),
    path: c.req.path,
    method: c.req.method,
    userId: c.get('userId'),
  });

  // ... rest of error handling
}
```

Every error is logged with context: what request it happened during, who made the request, what went wrong. This makes debugging production issues dramatically easier.

### Result Types vs Exceptions

Some codebases use `Result` types (like Rust's `Result<T, E>`) instead of throwing exceptions:

```typescript
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

async function getTask(id: string): Promise<Result<Task, 'not_found' | 'forbidden'>> {
  const task = await repository.findById(id);
  if (!task) return { ok: false, error: 'not_found' };
  return { ok: true, value: task };
}
```

This makes error handling explicit — callers must handle the error case. But it's verbose and TypeScript's type system isn't as helpful as Rust's for this pattern.

The recommendation: use exceptions for exceptional cases (not found, forbidden, validation errors) and reserve Result types for expected alternatives (like parsing that might fail). Exceptions with a global handler are more idiomatic in TypeScript.

## The Taste Test

**Scenario 1:** A colleague proposes extracting the "notifications" feature into a separate microservice.

*Your instinct should be:* Why? What problem does this solve? If notifications need different scaling characteristics (unlikely) or are owned by a different team (maybe), it could make sense. If it's just "microservices are better," push back. Start with a module. Extract later if there's a real reason.

**Scenario 2:** You see a route handler with 150 lines of code including database queries, validation, and business logic.

*Your instinct should be:* This needs splitting. Route handlers should be thin — parse request, call service, format response. Move the business logic to a service, the database queries to a repository. The route handler should be 10-20 lines.

**Scenario 3:** A service method imports directly from another service's internal files (not through `index.ts`).

*Your instinct should be:* This violates module boundaries. The import should go through the public API. If the needed functionality isn't exported, either export it or reconsider whether the dependency is appropriate.

**Scenario 4:** Unit tests for a service require starting a database connection.

*Your instinct should be:* The service is too coupled to infrastructure. It should accept dependencies (repository, cache client) as arguments, allowing tests to inject mocks. Refactor to use dependency injection.

**Scenario 5:** Every error response in the API has a different shape.

*Your instinct should be:* Centralize error handling. Define error types, create a global error handler, and ensure consistent response shapes. Frontend developers will thank you.

**Scenario 6:** A developer adds a new endpoint directly in `app.ts` instead of in a module.

*Your instinct should be:* Every endpoint belongs to a module. Even if it's a one-off utility endpoint, create a module for it (or find an existing module it fits in). `app.ts` should only compose modules, not contain business logic.

**Scenario 7:** A colleague suggests using inheritance to share code between services.

*Your instinct should be:* Composition over inheritance. If services share code, extract it to a shared utility function or a base repository pattern. Class inheritance creates tight coupling and makes testing harder. Prefer passing dependencies and composing behaviors.

## Practical Exercise

Restructure the data layer from Phase 1 into a modular monolith.

**Requirements:**

1. Create the module structure for: workspaces, users, projects, tasks, comments, activity
2. Each module has: routes.ts, service.ts, repository.ts, types.ts, index.ts
3. Implement dependency injection for services (factory functions, explicit dependencies)
4. Set up global error handling with typed errors
5. Wire up all routes in app.ts with proper middleware

**Constraints:**
- No direct imports between modules except through index.ts
- All database queries in repository files
- All business logic in service files
- Route handlers under 30 lines each

**AI Integration Point:**

Have Claude review your module structure:

```
Here's my backend project structure for a project management app:

[paste your directory tree and key files]

Review for:
1. Module boundary violations — are there hidden dependencies?
2. Layer violations — is business logic leaking into routes or repositories?
3. Testability — can modules be tested in isolation?
4. Consistency — do all modules follow the same patterns?
```

**Acceptance Criteria:**
- Clean separation between modules
- Services can be tested with mocked dependencies
- Error handling is centralized and consistent
- A new engineer could understand where to add a new feature within 30 minutes

**Evaluation questions:**

When reviewing your structure, ask:
1. If I need to change how tasks are stored, how many files do I need to touch? (Should be: repository.ts only)
2. If I need to add a new field to task creation, where do I make changes? (Should be: types.ts for validation, repository.ts for storage, maybe service.ts for business logic)
3. Can I test the tasks service without a database? (Should be: yes, with mocked repository)
4. Can I understand the tasks module without reading other modules? (Should be: yes, the index.ts defines its public interface)

If the answers are "many files," "unclear," "no," or "no," your structure needs work.

## Checkpoint

After completing this chapter and the exercise, you should be able to agree with these statements:

- [ ] I understand why microservices are premature for most startups and can articulate the trade-offs
- [ ] I can structure a backend as a modular monolith with clear module boundaries
- [ ] I know the responsibilities of each layer: routes (thin), services (business logic), repositories (data access)
- [ ] I can implement dependency injection without a framework
- [ ] I have a centralized error handling strategy with typed errors
- [ ] I can evaluate a codebase structure and identify boundary violations or layer leaks
- [ ] I understand when explicit DI is sufficient vs when a DI framework might help
- [ ] I can set up a consistent logging strategy for error tracking
- [ ] I can use events for decoupled cross-module communication
- [ ] I know the difference between composition and inheritance and prefer composition
