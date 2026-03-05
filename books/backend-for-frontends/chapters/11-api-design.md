# API Design

## Why This Matters

You've been consuming APIs your entire career. Every frontend feature you've built talks to some backend through some API. You know what good APIs feel like from the client side — predictable URLs, consistent error formats, sensible pagination.

Now you're on the other side. You're designing the API that other developers will consume. Maybe it's your own frontend team. Maybe it's mobile developers. Maybe it's third-party integrations. The principles are the same: make it predictable, make it consistent, make it hard to misuse.

Bad API design creates ongoing pain. Inconsistent naming means developers constantly check documentation. Missing pagination creates performance disasters. Unclear error messages turn debugging into archaeology. Every poor decision compounds as more code depends on your API.

Good API design is a gift to your future self and everyone who uses your system. This chapter covers the patterns that make APIs pleasant to work with.

## REST Done Right

REST isn't a specification — it's a set of conventions. The conventions vary. Some teams use camelCase, some use snake_case. Some nest resources deeply, others keep them flat. What matters is consistency.

Here's a sensible baseline for RESTful APIs:

### URL Structure

Resources are nouns, plural. Actions are HTTP verbs.

```
GET    /api/workspaces              # List workspaces
POST   /api/workspaces              # Create workspace
GET    /api/workspaces/:id          # Get specific workspace
PUT    /api/workspaces/:id          # Update workspace
DELETE /api/workspaces/:id          # Delete workspace

GET    /api/workspaces/:id/projects # List projects in workspace
POST   /api/workspaces/:id/projects # Create project in workspace
```

Nest one level deep maximum. Deeper nesting gets unwieldy:

```
# ❌ Too deeply nested
GET /api/workspaces/:wid/projects/:pid/tasks/:tid/comments/:cid

# ✅ Flatten when resources have their own identity
GET /api/comments/:id
```

🤔 **Taste Moment:** A resource can be accessed through multiple paths if it makes sense. A task belongs to a project, but if tasks have unique IDs, `/api/tasks/:id` is cleaner for direct access. Both paths can coexist: `/api/projects/:id/tasks` for listing, `/api/tasks/:id` for direct operations.

### Naming Conventions

Pick one naming style and stick to it everywhere:

**URLs:** Use kebab-case for multi-word resources: `/api/workspace-members`, not `/api/workspaceMembers` or `/api/workspace_members`.

**Query parameters:** Use camelCase: `?sortBy=createdAt&includeArchived=true`.

**Response bodies:** Use camelCase for JSON properties (this matches JavaScript conventions):

```json
{
  "id": "task-123",
  "createdAt": "2026-01-15T10:30:00Z",
  "assigneeId": "user-456",
  "isCompleted": false
}
```

**Timestamps:** Always use ISO 8601 format with timezone: `2026-01-15T10:30:00Z`. Never return timestamps as Unix epochs or locale-specific strings.

```typescript
// In your serializers
function serializeTask(task: Task) {
  return {
    id: task.id,
    title: task.title,
    createdAt: task.createdAt.toISOString(),
    updatedAt: task.updatedAt.toISOString(),
    dueDate: task.dueDate?.toISOString() || null
  }
}
```

### HTTP Methods

Use them correctly:

| Method | Purpose | Idempotent? | Safe? |
|--------|---------|-------------|-------|
| GET | Retrieve resources | Yes | Yes |
| POST | Create resources | No | No |
| PUT | Replace resources | Yes | No |
| PATCH | Partial update | Yes* | No |
| DELETE | Remove resources | Yes | No |

**GET** requests should never modify state. This sounds obvious, but don't be tempted to create shortcuts like `GET /api/tasks/:id/mark-complete`. Use `PATCH /api/tasks/:id` with `{ status: 'complete' }`.

**PUT** replaces the entire resource. **PATCH** updates specific fields. For most updates, PATCH is what you want:

```typescript
// PUT /api/tasks/123 - Replace entire task
// Request body must include ALL fields
{
  "title": "Updated task",
  "description": "New description",
  "status": "in_progress",
  "priority": "high",
  "assigneeId": "user-456",
  "dueDate": "2026-02-01"
}

// PATCH /api/tasks/123 - Update specific fields
// Only include fields being changed
{
  "status": "complete"
}
```

### Response Status Codes

Use appropriate status codes. Clients rely on them for control flow.

**2xx — Success:**
- `200 OK` — Request succeeded, response body has data
- `201 Created` — Resource created, response body has new resource
- `202 Accepted` — Request accepted for async processing (background jobs)
- `204 No Content` — Success with no response body (DELETE)

**4xx — Client errors:**
- `400 Bad Request` — Malformed request or validation failed
- `401 Unauthorized` — Missing or invalid authentication
- `403 Forbidden` — Authenticated but not authorized
- `404 Not Found` — Resource doesn't exist (or user can't access it)
- `409 Conflict` — Request conflicts with current state (duplicate, version conflict)
- `422 Unprocessable Entity` — Request is well-formed but semantically invalid
- `429 Too Many Requests` — Rate limited

**5xx — Server errors:**
- `500 Internal Server Error` — Something broke on our side
- `502 Bad Gateway` — Upstream service failed
- `503 Service Unavailable` — Temporarily overloaded or in maintenance

```typescript
// src/modules/task/routes.ts
taskRoutes.post('/', async (c) => {
  const body = await c.req.json()

  const validation = createTaskSchema.safeParse(body)
  if (!validation.success) {
    return c.json({
      error: 'Validation failed',
      details: validation.error.flatten().fieldErrors
    }, 400)
  }

  try {
    const task = await taskService.create(validation.data)
    return c.json(task, 201)  // 201 Created
  } catch (error) {
    if (error instanceof DuplicateTaskError) {
      return c.json({ error: error.message }, 409)  // 409 Conflict
    }
    throw error  // Let error handler return 500
  }
})
```

## Consistent Error Responses

Every error response should follow the same format. Clients shouldn't have to handle different error structures for different endpoints.

```typescript
// src/types/api.ts
interface ApiError {
  error: string           // Human-readable message
  code?: string           // Machine-readable error code
  details?: Record<string, string[]>  // Field-level validation errors
  requestId?: string      // For support/debugging
}
```

```typescript
// Examples:

// Validation error (400)
{
  "error": "Validation failed",
  "code": "VALIDATION_ERROR",
  "details": {
    "title": ["Title is required"],
    "dueDate": ["Must be a future date"]
  },
  "requestId": "req_1234567890"
}

// Not found (404)
{
  "error": "Task not found",
  "code": "RESOURCE_NOT_FOUND",
  "requestId": "req_1234567890"
}

// Rate limited (429)
{
  "error": "Rate limit exceeded",
  "code": "RATE_LIMITED",
  "details": {
    "retryAfter": ["60"]
  },
  "requestId": "req_1234567890"
}
```

Centralize error handling:

```typescript
// src/middleware/errorHandler.ts
import { Context } from 'hono'
import { HTTPException } from 'hono/http-exception'
import { ZodError } from 'zod'

export async function errorHandler(err: Error, c: Context) {
  const requestId = c.get('requestId') || 'unknown'

  // Validation errors
  if (err instanceof ZodError) {
    return c.json({
      error: 'Validation failed',
      code: 'VALIDATION_ERROR',
      details: err.flatten().fieldErrors,
      requestId
    }, 400)
  }

  // Application errors
  if (err instanceof AppError) {
    return c.json({
      error: err.message,
      code: err.code,
      requestId
    }, err.statusCode)
  }

  // HTTP exceptions from middleware
  if (err instanceof HTTPException) {
    return c.json({
      error: err.message,
      code: 'HTTP_ERROR',
      requestId
    }, err.status)
  }

  // Unexpected errors - don't leak details
  logger.error('Unhandled error', { error: err, requestId })
  return c.json({
    error: 'Internal server error',
    code: 'INTERNAL_ERROR',
    requestId
  }, 500)
}
```

🔒 **Security Callout:** Never expose stack traces or internal error details in production error responses. Log them server-side with the request ID so you can correlate them, but return only a generic message to clients.

## Pagination

Any endpoint that returns a list needs pagination. Even if you only have 10 items today, you'll have 10,000 tomorrow.

### Offset-Based Pagination

The simplest approach. Clients specify `offset` and `limit`:

```
GET /api/tasks?limit=20&offset=40
```

```typescript
interface PaginatedResponse<T> {
  data: T[]
  pagination: {
    total: number    // Total items available
    limit: number    // Items per page
    offset: number   // Current offset
    hasMore: boolean // Are there more items?
  }
}
```

```typescript
// Implementation
taskRoutes.get('/', async (c) => {
  const limit = Math.min(parseInt(c.req.query('limit') || '20'), 100)
  const offset = parseInt(c.req.query('offset') || '0')

  const [tasks, total] = await Promise.all([
    taskService.list({ limit, offset }),
    taskService.count()
  ])

  return c.json({
    data: tasks,
    pagination: {
      total,
      limit,
      offset,
      hasMore: offset + tasks.length < total
    }
  })
})
```

Offset pagination has a flaw: if items are added or removed between pages, results can shift. Users might see the same item twice or miss items entirely.

### Cursor-Based Pagination

For real-time data, use cursors. A cursor is an opaque pointer to a position in the result set:

```
GET /api/tasks?limit=20
GET /api/tasks?limit=20&cursor=eyJpZCI6MTIzfQ==
```

```typescript
interface CursorPaginatedResponse<T> {
  data: T[]
  pagination: {
    nextCursor: string | null
    hasMore: boolean
  }
}
```

```typescript
// Using task ID as cursor (encoded as base64)
taskRoutes.get('/', async (c) => {
  const limit = Math.min(parseInt(c.req.query('limit') || '20'), 100)
  const cursor = c.req.query('cursor')

  let afterId: string | undefined
  if (cursor) {
    const decoded = JSON.parse(Buffer.from(cursor, 'base64').toString())
    afterId = decoded.id
  }

  const tasks = await taskService.list({
    limit: limit + 1,  // Fetch one extra to check hasMore
    afterId
  })

  const hasMore = tasks.length > limit
  const data = hasMore ? tasks.slice(0, -1) : tasks

  const nextCursor = hasMore
    ? Buffer.from(JSON.stringify({ id: data[data.length - 1].id })).toString('base64')
    : null

  return c.json({
    data,
    pagination: { nextCursor, hasMore }
  })
})
```

Use cursor pagination when:
- Data is frequently added/removed
- You have infinite scroll UIs
- Offset would become expensive (OFFSET 10000 LIMIT 20 in SQL is slow)

Use offset pagination when:
- You need to jump to specific pages
- Data is relatively static
- You need a total count

🤔 **Taste Moment:** Many APIs support both. Use offset for admin dashboards where users jump between pages, cursors for user-facing feeds where they scroll continuously.

## Filtering and Sorting

Lists often need filtering. Keep the syntax consistent:

```
# Single value filter
GET /api/tasks?status=complete

# Multiple values (OR)
GET /api/tasks?status=pending,in_progress

# Date range
GET /api/tasks?createdAfter=2026-01-01&createdBefore=2026-02-01

# Sorting
GET /api/tasks?sort=createdAt:desc
GET /api/tasks?sort=priority:asc,createdAt:desc
```

```typescript
taskRoutes.get('/', async (c) => {
  const filters = {
    status: c.req.query('status')?.split(','),
    assigneeId: c.req.query('assigneeId'),
    createdAfter: c.req.query('createdAfter')
      ? new Date(c.req.query('createdAfter')!)
      : undefined,
    createdBefore: c.req.query('createdBefore')
      ? new Date(c.req.query('createdBefore')!)
      : undefined
  }

  const sort = parseSort(c.req.query('sort') || 'createdAt:desc')

  const tasks = await taskService.list({ filters, sort, ...pagination })
  return c.json(tasks)
})

function parseSort(sortParam: string): Array<{ field: string; order: 'asc' | 'desc' }> {
  return sortParam.split(',').map(part => {
    const [field, order = 'asc'] = part.split(':')
    return { field, order: order as 'asc' | 'desc' }
  })
}
```

🔒 **Security Callout:** Validate that sort fields are allowed columns. Don't let users sort by arbitrary columns — some might be expensive (unindexed) or leak information through timing attacks.

## Partial Responses and Field Selection

Large resources have many fields. Sometimes clients only need a few. Let them specify:

```
GET /api/tasks/123?fields=id,title,status
GET /api/projects/456?include=tasks,members
```

```typescript
const taskRoutes = new Hono()

taskRoutes.get('/:id', async (c) => {
  const { id } = c.req.param()
  const fields = c.req.query('fields')?.split(',')
  const include = c.req.query('include')?.split(',')

  const task = await taskService.get(id, { fields, include })

  if (fields) {
    // Filter response to requested fields
    const filtered = pick(task, fields)
    return c.json(filtered)
  }

  return c.json(task)
})
```

This reduces payload size and can improve database query performance if you push field selection down to the SQL layer.

## Streaming Responses

For LLM integrations and long-running operations, streaming responses let you send data incrementally instead of waiting for everything to complete.

### Server-Sent Events (SSE)

SSE is the simplest streaming protocol. The server sends events; the client receives them. No bidirectional communication, but that's fine for most use cases.

```typescript
// src/modules/ai/routes.ts
import { streamSSE } from 'hono/streaming'

aiRoutes.post('/chat', async (c) => {
  const { message } = await c.req.json()
  const user = c.get('user')

  return streamSSE(c, async (stream) => {
    // Call LLM with streaming
    const response = await llm.chat({
      messages: [{ role: 'user', content: message }],
      stream: true
    })

    for await (const chunk of response) {
      await stream.writeSSE({
        event: 'chunk',
        data: JSON.stringify({ content: chunk.text })
      })
    }

    await stream.writeSSE({
      event: 'done',
      data: JSON.stringify({ finishReason: 'complete' })
    })
  })
})
```

Client-side consumption:

```typescript
const eventSource = new EventSource('/api/ai/chat', {
  method: 'POST',
  body: JSON.stringify({ message: 'Explain async/await' })
})

eventSource.addEventListener('chunk', (event) => {
  const { content } = JSON.parse(event.data)
  appendToUI(content)
})

eventSource.addEventListener('done', (event) => {
  eventSource.close()
})

eventSource.addEventListener('error', (event) => {
  console.error('Stream error:', event)
})
```

⚡ **AI Shortcut:** SSE is the standard pattern for streaming LLM responses. The OpenAI, Anthropic, and most other LLM APIs use it. When building AI features, always stream responses — users see immediate feedback instead of waiting for the full response.

### Job Progress Updates

For background jobs (from Chapter 10), combine SSE with job status:

```typescript
exportRoutes.get('/:jobId/progress', async (c) => {
  const { jobId } = c.req.param()

  return streamSSE(c, async (stream) => {
    const job = await exportQueue.getJob(jobId)
    if (!job) {
      await stream.writeSSE({
        event: 'error',
        data: JSON.stringify({ error: 'Job not found' })
      })
      return
    }

    // Poll for updates (in production, use Redis pub/sub)
    while (true) {
      const state = await job.getState()
      const progress = job.progress

      await stream.writeSSE({
        event: 'progress',
        data: JSON.stringify({ state, progress })
      })

      if (state === 'completed') {
        await stream.writeSSE({
          event: 'complete',
          data: JSON.stringify({ result: job.returnvalue })
        })
        break
      }

      if (state === 'failed') {
        await stream.writeSSE({
          event: 'failed',
          data: JSON.stringify({ error: job.failedReason })
        })
        break
      }

      await new Promise(r => setTimeout(r, 1000))  // Poll every second
    }
  })
})
```

## Versioning

APIs evolve. You'll need to make breaking changes. How do you handle existing clients?

### URL Versioning

The simplest approach:

```
/api/v1/tasks
/api/v2/tasks
```

```typescript
// src/routes/v1/tasks.ts
const v1TaskRoutes = new Hono()
v1TaskRoutes.get('/', async (c) => {
  // v1 behavior
})

// src/routes/v2/tasks.ts
const v2TaskRoutes = new Hono()
v2TaskRoutes.get('/', async (c) => {
  // v2 behavior with breaking changes
})

// src/index.ts
app.route('/api/v1/tasks', v1TaskRoutes)
app.route('/api/v2/tasks', v2TaskRoutes)
```

### Header Versioning

Version in the `Accept` header:

```
Accept: application/vnd.myapp.v2+json
```

More elegant but harder to test (can't just paste URLs in a browser).

### Sunset Policy

When deprecating a version:

1. Announce deprecation with a timeline
2. Add `Sunset` and `Deprecation` headers to responses
3. Log usage of deprecated versions
4. Eventually return 410 Gone

```typescript
// Deprecated endpoint middleware
function deprecated(sunsetDate: string) {
  return async (c: Context, next: Next) => {
    c.header('Deprecation', 'true')
    c.header('Sunset', sunsetDate)
    c.header('Link', '</api/v2/tasks>; rel="successor-version"')

    logger.info('Deprecated API accessed', {
      path: c.req.path,
      clientId: c.get('apiKey')?.id
    })

    await next()
  }
}

v1TaskRoutes.use('*', deprecated('Sun, 01 Jun 2027 00:00:00 GMT'))
```

💸 **Startup Cost Callout:** Don't over-version. Most startups never need more than two versions active at once. Add versioning when you have paying customers who can't immediately migrate, not preemptively.

## Rate Limiting

Protect your API from abuse and ensure fair usage:

```typescript
// src/middleware/rateLimit.ts
import { RateLimiterRedis } from 'rate-limiter-flexible'
import { redis } from '../redis'

// Different limits for different operations
const limiters = {
  // General API: 100 requests per minute
  general: new RateLimiterRedis({
    storeClient: redis,
    keyPrefix: 'rl:general',
    points: 100,
    duration: 60
  }),

  // Expensive operations: 10 per minute
  expensive: new RateLimiterRedis({
    storeClient: redis,
    keyPrefix: 'rl:expensive',
    points: 10,
    duration: 60
  }),

  // Auth endpoints: 5 per 15 minutes
  auth: new RateLimiterRedis({
    storeClient: redis,
    keyPrefix: 'rl:auth',
    points: 5,
    duration: 900
  })
}

export function rateLimit(tier: keyof typeof limiters = 'general') {
  return async (c: Context, next: Next) => {
    const key = c.get('userId') || c.req.header('x-forwarded-for') || 'anonymous'

    try {
      const result = await limiters[tier].consume(key)

      // Add rate limit headers
      c.header('X-RateLimit-Limit', String(limiters[tier].points))
      c.header('X-RateLimit-Remaining', String(result.remainingPoints))
      c.header('X-RateLimit-Reset', String(Math.ceil(result.msBeforeNext / 1000)))

      await next()
    } catch (error) {
      if (error instanceof Error && 'msBeforeNext' in error) {
        const retryAfter = Math.ceil((error as any).msBeforeNext / 1000)
        c.header('Retry-After', String(retryAfter))
        c.header('X-RateLimit-Remaining', '0')

        return c.json({
          error: 'Rate limit exceeded',
          code: 'RATE_LIMITED',
          retryAfter
        }, 429)
      }
      throw error
    }
  }
}
```

Apply different rate limits to different endpoints:

```typescript
// Fast operations
app.get('/api/tasks', rateLimit('general'), taskHandler)

// Slow/expensive operations
app.post('/api/exports', rateLimit('expensive'), exportHandler)

// Auth operations
app.post('/api/auth/login', rateLimit('auth'), loginHandler)
```

### Rate Limit Response Headers

Always include rate limit information in responses:

```
HTTP/1.1 200 OK
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1705320000
```

When rate limited:

```
HTTP/1.1 429 Too Many Requests
Retry-After: 45
X-RateLimit-Remaining: 0

{
  "error": "Rate limit exceeded",
  "code": "RATE_LIMITED",
  "retryAfter": 45
}
```

## Idempotency Keys

For operations that create resources or charge money, clients need a way to safely retry requests. Idempotency keys ensure the same request processed twice has the same effect as processing it once.

```typescript
// src/middleware/idempotency.ts
import { redis } from '../redis'

const IDEMPOTENCY_TTL = 24 * 60 * 60  // 24 hours

export async function idempotency(c: Context, next: Next) {
  const idempotencyKey = c.req.header('Idempotency-Key')

  if (!idempotencyKey) {
    // No key provided - process normally
    await next()
    return
  }

  const cacheKey = `idempotency:${c.get('userId')}:${idempotencyKey}`

  // Check for cached response
  const cached = await redis.get(cacheKey)
  if (cached) {
    const { status, body } = JSON.parse(cached)
    return c.json(body, status)
  }

  // Process request
  await next()

  // Cache the response
  const responseBody = await c.res.json()
  await redis.setex(
    cacheKey,
    IDEMPOTENCY_TTL,
    JSON.stringify({
      status: c.res.status,
      body: responseBody
    })
  )
}
```

```typescript
// Apply to mutation endpoints
app.post('/api/payments', idempotency, rateLimit('expensive'), paymentHandler)
app.post('/api/tasks', idempotency, taskHandler)
```

Clients use it like this:

```typescript
// Client-side retry with idempotency
async function createTask(data: CreateTaskData) {
  const idempotencyKey = crypto.randomUUID()

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await fetch('/api/tasks', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey  // Same key for all retries
        },
        body: JSON.stringify(data)
      })

      if (response.ok) return response.json()

      if (response.status >= 500) {
        // Server error - retry
        await sleep(Math.pow(2, attempt) * 1000)
        continue
      }

      // Client error - don't retry
      throw new Error(await response.text())
    } catch (error) {
      if (attempt === 2) throw error
      await sleep(Math.pow(2, attempt) * 1000)
    }
  }
}
```

🤔 **Taste Moment:** Stripe pioneered the idempotency key pattern. For any operation where double-execution would be harmful (charging a card, sending an email, creating an order), require idempotency keys. For read-only operations, they're unnecessary.

## HATEOAS and Hypermedia

HATEOAS (Hypermedia as the Engine of Application State) is the idea that API responses should include links to related actions and resources:

```json
{
  "id": "task-123",
  "title": "Implement API",
  "status": "in_progress",
  "_links": {
    "self": { "href": "/api/tasks/task-123" },
    "project": { "href": "/api/projects/proj-456" },
    "assignee": { "href": "/api/users/user-789" },
    "complete": { "href": "/api/tasks/task-123/complete", "method": "POST" },
    "comments": { "href": "/api/tasks/task-123/comments" }
  }
}
```

In practice, most APIs don't implement full HATEOAS. It adds verbosity and most clients ignore the links anyway. But including pagination links is widely adopted:

```json
{
  "data": [...],
  "pagination": {
    "nextCursor": "abc123",
    "hasMore": true
  },
  "_links": {
    "next": { "href": "/api/tasks?cursor=abc123" },
    "self": { "href": "/api/tasks" }
  }
}
```

## Webhooks: The Reverse API

So far we've discussed APIs where clients call you. Webhooks flip this — you call the client when events occur.

```typescript
// src/modules/webhook/service.ts
interface WebhookPayload {
  event: string
  timestamp: string
  data: Record<string, unknown>
}

export async function deliverWebhook(
  endpoint: WebhookEndpoint,
  event: string,
  data: Record<string, unknown>
): Promise<void> {
  const payload: WebhookPayload = {
    event,
    timestamp: new Date().toISOString(),
    data
  }

  const signature = signPayload(payload, endpoint.secret)

  await webhookQueue.add('deliver', {
    url: endpoint.url,
    payload,
    signature,
    endpointId: endpoint.id
  })
}

function signPayload(payload: WebhookPayload, secret: string): string {
  const body = JSON.stringify(payload)
  return crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('hex')
}
```

Include signature verification instructions in your docs:

```typescript
// Example: Verifying a webhook in the receiver's code
function verifyWebhook(body: string, signature: string, secret: string): boolean {
  const expected = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('hex')

  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expected)
  )
}
```

🔒 **Security Callout:** Always sign webhook payloads. Without signatures, attackers can forge webhook calls to your customers' servers. Use HMAC-SHA256 with a per-endpoint secret that only you and the customer know.

## API Documentation

Document your API so others can use it. OpenAPI (Swagger) is the standard:

```typescript
// Using Hono's built-in OpenAPI support
import { createRoute, OpenAPIHono } from '@hono/zod-openapi'
import { z } from 'zod'

const app = new OpenAPIHono()

const createTaskRoute = createRoute({
  method: 'post',
  path: '/api/tasks',
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            title: z.string().min(1).max(200),
            description: z.string().optional(),
            projectId: z.string().uuid()
          })
        }
      }
    }
  },
  responses: {
    201: {
      description: 'Task created',
      content: {
        'application/json': {
          schema: z.object({
            id: z.string().uuid(),
            title: z.string(),
            status: z.enum(['pending', 'in_progress', 'complete'])
          })
        }
      }
    },
    400: {
      description: 'Validation error'
    }
  }
})

app.openapi(createTaskRoute, async (c) => {
  const body = c.req.valid('json')
  const task = await taskService.create(body)
  return c.json(task, 201)
})

// Generate OpenAPI spec
app.doc('/api/docs', {
  openapi: '3.0.0',
  info: {
    title: 'Task Management API',
    version: '1.0.0'
  }
})
```

Host interactive documentation with Swagger UI or Scalar.

### Documentation Best Practices

Good API documentation includes:

1. **Authentication guide** — How to get credentials, where to include them
2. **Quick start** — Working example in under 5 minutes
3. **Error reference** — All error codes with explanations and fixes
4. **Changelog** — What changed and when
5. **Rate limits** — Clear documentation of limits per endpoint
6. **Examples** — Request/response examples for every endpoint

```yaml
# Example OpenAPI operation with thorough documentation
/api/tasks:
  post:
    summary: Create a new task
    description: |
      Creates a task in the specified project. The authenticated user
      must have write access to the project.

      Tasks are created with status "pending" by default.
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/CreateTask'
          examples:
            basic:
              summary: Basic task
              value:
                title: "Review pull request"
                projectId: "proj-123"
            full:
              summary: Task with all fields
              value:
                title: "Review pull request"
                description: "Check for security issues"
                projectId: "proj-123"
                assigneeId: "user-456"
                priority: "high"
                dueDate: "2026-02-01T17:00:00Z"
    responses:
      201:
        description: Task created successfully
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Task'
      400:
        description: Validation error
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Error'
            example:
              error: "Validation failed"
              code: "VALIDATION_ERROR"
              details:
                title: ["Title is required"]
```

⚡ **AI Shortcut:** Use Claude to generate OpenAPI specs from your TypeScript types and Zod schemas. Paste your type definitions and ask it to generate the corresponding OpenAPI YAML. Review the output carefully — AI is good at the tedious parts but may miss nuances.

## API Versioning

Most startups don't need API versioning initially. If your only clients are your own apps, coordinate deployments and skip versioning.

When you do need it (public API, third-party integrations), prefer URL versioning:

```
/api/v1/tasks
/api/v2/tasks
```

It's explicit and easy to route. Header-based versioning (`Accept: application/vnd.api+json;version=2`) is cleaner in theory but harder to debug and test.

**Keep it simple:**
- Version the whole API, not individual endpoints
- Support at most two versions simultaneously (current + deprecated)
- Give clients 6-12 months to migrate, then remove old versions
- Don't version until you have a breaking change that requires it

🤔 **Taste Moment:** Adding `/v1/` to URLs from day one is premature. It suggests versioning you may never need. Start without versioning; add it when you have actual clients who can't update immediately.

## The Taste Test

**Scenario 1:** An endpoint returns `200 OK` for every response, with `{ success: false, error: "..." }` for errors.

*What's wrong?* HTTP status codes exist for a reason. Clients use them for control flow, caching, and retry logic. Returning 200 for errors breaks standard HTTP clients and monitoring tools. Use proper status codes.

**Scenario 2:** The task API has `GET /api/getTaskById/:id` and `POST /api/createNewTask`.

*What would you change?* These are RPC-style URLs, not RESTful. Use `GET /api/tasks/:id` and `POST /api/tasks`. Resources are nouns; HTTP methods are verbs.

**Scenario 3:** Error responses look like `{ message: "error" }` on some endpoints and `{ error: { code: "...", message: "..." } }` on others.

*What's the impact?* Clients have to handle multiple error formats. Every endpoint should return the same error structure. Consistency reduces integration friction.

**Scenario 4:** A search endpoint takes filters as a JSON body: `POST /api/tasks/search { "status": "complete" }`.

*Is this okay?* It's debatable. GET requests with query params are more cacheable and bookmarkable. POST bodies are cleaner for complex filters. For simple filters, prefer GET. For complex search (full-text, nested conditions), POST is acceptable.

**Scenario 5:** The API has no pagination. "We only have 50 tasks, it's fine."

*Your response?* Add pagination now while it's easy. When you have 5,000 tasks and no pagination, you'll face a breaking change that requires all clients to update. Future-proofing pagination is cheap; retrofitting is expensive.

## Practical Exercise

Design and implement a complete REST API for the project management application:

**Requirements:**

1. **Task CRUD:**
   - Full create, read, update, delete operations
   - Support filtering by status, assignee, project
   - Support sorting by created date, priority, due date
   - Implement cursor-based pagination

2. **Nested resources:**
   - Tasks belong to projects
   - Projects belong to workspaces
   - Comments belong to tasks
   - Design URL structure that's navigable and consistent

3. **Real-time features:**
   - SSE endpoint for task updates within a project
   - Progress streaming for export jobs

4. **Documentation:**
   - Generate OpenAPI spec from your route definitions
   - Host Swagger UI for interactive testing

5. **Error handling:**
   - Consistent error response format across all endpoints
   - Proper status codes for all error conditions
   - Request ID in all responses

**Acceptance criteria:**
- All endpoints follow REST conventions
- Pagination works correctly (test with 1000+ records)
- SSE streams deliver updates within 1 second
- OpenAPI spec is valid and complete
- Error responses are consistent across all endpoints

**AI Integration:**

Use Claude to review your API design:

```
Here is my REST API design for a task management system.

[paste your route definitions or OpenAPI spec]

Review for:
1. RESTful convention violations
2. Inconsistent naming or structure
3. Missing error cases
4. Pagination edge cases
5. Security concerns with the endpoint design

Suggest improvements with explanations.
```

Implement at least 3 of Claude's suggestions.

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can design RESTful URLs with proper resource naming and HTTP method usage
- [ ] I understand when to use different HTTP status codes and use them correctly
- [ ] I can implement both offset and cursor-based pagination and know when to use each
- [ ] I can design consistent error responses that include useful debugging information
- [ ] I understand how to implement filtering and sorting in list endpoints
- [ ] I can build streaming endpoints with Server-Sent Events
- [ ] I know how to version APIs and deprecate old versions gracefully
- [ ] I can generate OpenAPI documentation from my route definitions

APIs are contracts. Every decision you make affects everyone who builds on your API. The patterns in this chapter — consistent URLs, proper status codes, pagination, error handling — aren't just best practices. They're professional courtesy to the developers who will consume your work.

## Beyond REST: When to Consider Alternatives

REST isn't the only option. Here's when alternatives make sense:

**GraphQL** — When clients have varied data needs and you want to avoid over-fetching. Mobile apps with bandwidth constraints, or dashboards that aggregate data from many sources. The tradeoff: more complexity, harder caching, potential for expensive queries.

**gRPC** — For internal service-to-service communication where performance matters. Strong typing with Protocol Buffers, efficient binary serialization, bidirectional streaming. Not suitable for browser clients without a proxy.

**WebSockets** — For real-time bidirectional communication. Chat applications, collaborative editing, multiplayer games. More complex than SSE but supports two-way traffic.

For most startups, REST is the right default. It's well-understood, tooling is excellent, and it covers 90% of use cases. Add alternatives when you have specific requirements that REST doesn't meet, not because they're trendy.

## Request/Response Logging

Log enough to debug issues without exposing sensitive data:

```typescript
// src/middleware/requestLogger.ts
export async function requestLogger(c: Context, next: Next) {
  const requestId = crypto.randomUUID()
  c.set('requestId', requestId)
  c.header('X-Request-Id', requestId)

  const start = Date.now()

  await next()

  const duration = Date.now() - start

  logger.info('request', {
    requestId,
    method: c.req.method,
    path: c.req.path,
    status: c.res.status,
    duration,
    userId: c.get('userId'),
    // Don't log full request bodies - they may contain PII
    // Log enough to identify the request type
    contentLength: c.req.header('content-length')
  })
}
```

For debugging, allow clients to request verbose logging:

```typescript
// Debug mode for specific requests
if (c.req.header('X-Debug') === 'true' && isAdminUser(c)) {
  logger.debug('request_body', {
    requestId,
    body: await c.req.json()
  })
}
```

Request IDs are essential. When a user reports "the API returned an error," you need to trace exactly what happened. Include the request ID in every error response, and make it easy to search logs by ID.

## Bulk Operations

Sometimes clients need to operate on many resources at once. Provide bulk endpoints:

```typescript
// Bulk create
taskRoutes.post('/bulk', async (c) => {
  const { tasks } = await c.req.json()

  if (tasks.length > 100) {
    return c.json({ error: 'Maximum 100 tasks per request' }, 400)
  }

  const results = await Promise.allSettled(
    tasks.map(task => taskService.create(task))
  )

  return c.json({
    created: results.filter(r => r.status === 'fulfilled').map(r => r.value),
    errors: results
      .map((r, i) => r.status === 'rejected' ? { index: i, error: r.reason.message } : null)
      .filter(Boolean)
  }, results.some(r => r.status === 'rejected') ? 207 : 201)  // 207 Multi-Status
})

// Bulk update
taskRoutes.patch('/bulk', async (c) => {
  const { taskIds, update } = await c.req.json()

  const updated = await taskService.bulkUpdate(taskIds, update)

  return c.json({ updated: updated.length })
})

// Bulk delete
taskRoutes.delete('/bulk', async (c) => {
  const { taskIds } = await c.req.json()

  await taskService.bulkDelete(taskIds)

  return c.json({ deleted: taskIds.length })
})
```

💸 **Startup Cost Callout:** Bulk operations save API calls, which saves client-side latency and server-side load. If users commonly operate on multiple items (select all, bulk edit), build bulk endpoints from the start.
