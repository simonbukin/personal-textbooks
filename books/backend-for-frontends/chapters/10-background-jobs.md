# Background Jobs, Queues, and Async Processing

## Why This Matters

A user clicks "Export to PDF." The PDF takes 30 seconds to generate. Do you make them stare at a loading spinner for 30 seconds?

No. You return immediately with "Your export is processing" and generate the PDF in the background. When it's ready, you notify them.

This pattern — offloading work that doesn't need to happen during the request — is fundamental to building responsive applications. Without it, your API becomes a bottleneck. Users wait. Requests timeout. Servers overload.

Background jobs solve this by decoupling the request ("please generate a PDF") from the work (actually generating it). The request returns immediately. The work happens asynchronously. The user stays happy.

By the end of this chapter, you'll understand when to use background jobs, how to implement them reliably with BullMQ, and how to handle the edge cases that make or break production systems.

## When to Use Background Jobs

Not everything needs to be a background job. Use them when:

**The work takes more than a few seconds.** PDF generation, video processing, large file uploads, complex calculations. Anything that would make users wait.

**The work can fail and needs retries.** Sending emails, calling external APIs, processing webhooks. Network failures happen. Background jobs can retry automatically.

**The work needs to happen later.** Scheduled reports, reminder emails, subscription renewals. Jobs can be delayed to a specific time.

**The work doesn't need to happen in request order.** Ten users request exports. Process them in parallel, not sequentially.

**The work is expensive and needs throttling.** LLM API calls have rate limits. Batch them through a queue to stay under limits.

Don't use background jobs when:

**The user needs the result immediately.** If the response depends on the work completing, you can't background it. (Though you can use WebSockets or SSE to push the result when ready.)

**The work is simple and fast.** Updating a database record, incrementing a counter — just do it inline. The overhead of queuing isn't worth it.

**You're overcomplicating simple workflows.** Sometimes synchronous code is the right answer.

## The Mental Model: Producers and Consumers

Background job systems have two parts:

**Producers** create jobs. Your API endpoint is a producer — it receives a request and creates a job to handle the work.

**Consumers** (or workers) process jobs. They pull jobs from the queue, execute them, and mark them complete (or failed).

Between them sits a **queue** — a data structure (usually Redis) that holds jobs waiting to be processed.

```
┌─────────────┐      ┌─────────┐      ┌──────────────┐
│   API       │──────│  Queue  │──────│   Worker     │
│  (Producer) │ add  │ (Redis) │ get  │  (Consumer)  │
└─────────────┘      └─────────┘      └──────────────┘
      │                                      │
      │ HTTP Response                        │ Process job
      │ "Export started"                     │ Generate PDF
      ▼                                      ▼
   ┌──────┐                            ┌──────────┐
   │ User │                            │ Storage  │
   └──────┘                            └──────────┘
```

This separation is powerful:

- **Scaling:** Run more workers to process jobs faster. The queue acts as a buffer.
- **Reliability:** If a worker crashes, the job remains in the queue for another worker.
- **Decoupling:** Producers don't need to know how jobs are processed.

## Why Redis for Queues?

You might wonder: why not just use Postgres for job queues? You already have a database.

Redis wins for queues because:

1. **Speed.** Redis operations are sub-millisecond. Enqueueing a job adds virtually no latency to your API response.

2. **Atomic operations.** Redis provides primitives like `BLPOP` (blocking pop) that let workers wait for jobs efficiently without polling.

3. **Pub/sub.** Redis can notify workers instantly when new jobs arrive instead of workers constantly checking.

4. **Built-in expiration.** Job metadata can automatically expire, keeping Redis clean.

Postgres can work for simple queues (look up "SKIP LOCKED" patterns), but BullMQ + Redis is purpose-built for this. Use the right tool.

🤔 **Taste Moment:** Some teams use Postgres for queues to avoid running Redis. This is fine for low-volume jobs (hundreds per hour), but adds complexity at scale. If you're already running Redis for caching (from Chapter 4), use it for queues too. One less piece of infrastructure to worry about.

## BullMQ: The Queue Library

BullMQ is the standard for Node.js job queues. It uses Redis as its backend, supports retries, delays, priorities, rate limiting, and job dependencies. It's battle-tested and actively maintained.

```bash
npm install bullmq
```

### Setting Up a Queue

```typescript
// src/queues/index.ts
import { Queue } from 'bullmq'
import { redis } from '../redis'

// Connection options (reuse your Redis connection)
const connection = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
}

// Create a queue for export jobs
export const exportQueue = new Queue('exports', { connection })

// Create a queue for email jobs
export const emailQueue = new Queue('emails', { connection })

// Create a queue for webhook delivery
export const webhookQueue = new Queue('webhooks', { connection })
```

### Adding Jobs to a Queue

```typescript
// src/modules/export/service.ts
import { exportQueue } from '../../queues'

interface ExportJobData {
  workspaceId: string
  userId: string
  format: 'pdf' | 'csv' | 'xlsx'
  filters: {
    projectIds?: string[]
    dateRange?: { start: Date; end: Date }
  }
}

export async function requestExport(
  userId: string,
  workspaceId: string,
  format: 'pdf' | 'csv' | 'xlsx',
  filters: ExportJobData['filters']
): Promise<{ jobId: string }> {
  const job = await exportQueue.add(
    'generate-export',  // Job name
    {                   // Job data
      workspaceId,
      userId,
      format,
      filters
    },
    {                   // Job options
      attempts: 3,      // Retry up to 3 times on failure
      backoff: {
        type: 'exponential',
        delay: 1000     // 1s, 2s, 4s between retries
      },
      removeOnComplete: {
        age: 24 * 60 * 60,  // Keep completed jobs for 24 hours
        count: 1000         // Keep last 1000 completed jobs
      },
      removeOnFail: {
        age: 7 * 24 * 60 * 60  // Keep failed jobs for 7 days (for debugging)
      }
    }
  )

  return { jobId: job.id! }
}
```

```typescript
// src/modules/export/routes.ts
import { Hono } from 'hono'
import { requestExport } from './service'

const exportRoutes = new Hono()

exportRoutes.post('/', async (c) => {
  const user = c.get('user')
  const { format, filters } = await c.req.json()

  const { jobId } = await requestExport(
    user.id,
    user.workspaceId,
    format,
    filters
  )

  // Return immediately with job ID
  return c.json({
    message: 'Export started',
    jobId,
    statusUrl: `/api/exports/status/${jobId}`
  }, 202)  // 202 Accepted
})
```

The key insight: the API returns immediately with HTTP 202 (Accepted). The work happens later.

### Processing Jobs with Workers

Workers run separately from your API server. They can be in the same codebase but run as a different process.

```typescript
// src/workers/export.worker.ts
import { Worker, Job } from 'bullmq'
import { generatePdf, generateCsv, generateXlsx } from '../services/export'
import { uploadToStorage } from '../services/storage'
import { notifyUser } from '../services/notification'

interface ExportJobData {
  workspaceId: string
  userId: string
  format: 'pdf' | 'csv' | 'xlsx'
  filters: {
    projectIds?: string[]
    dateRange?: { start: Date; end: Date }
  }
}

const connection = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
}

const worker = new Worker<ExportJobData>(
  'exports',  // Queue name
  async (job: Job<ExportJobData>) => {
    const { workspaceId, userId, format, filters } = job.data

    // Update progress
    await job.updateProgress(10)

    // Generate the export
    let buffer: Buffer
    switch (format) {
      case 'pdf':
        buffer = await generatePdf(workspaceId, filters)
        break
      case 'csv':
        buffer = await generateCsv(workspaceId, filters)
        break
      case 'xlsx':
        buffer = await generateXlsx(workspaceId, filters)
        break
    }

    await job.updateProgress(70)

    // Upload to storage
    const filename = `export-${workspaceId}-${Date.now()}.${format}`
    const url = await uploadToStorage(buffer, filename)

    await job.updateProgress(90)

    // Notify the user
    await notifyUser(userId, {
      type: 'export_complete',
      downloadUrl: url,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)  // 7 days
    })

    await job.updateProgress(100)

    // Return value is stored with the job
    return { url, filename }
  },
  {
    connection,
    concurrency: 5,  // Process up to 5 jobs in parallel
  }
)

// Error handling
worker.on('completed', (job) => {
  console.log(`Job ${job.id} completed`)
})

worker.on('failed', (job, error) => {
  console.error(`Job ${job?.id} failed:`, error)
})

// Graceful shutdown
process.on('SIGTERM', async () => {
  await worker.close()
  process.exit(0)
})
```

Run this worker as a separate process:

```json
// package.json
{
  "scripts": {
    "start": "node dist/index.js",
    "worker:export": "node dist/workers/export.worker.js"
  }
}
```

💸 **Startup Cost Callout:** Workers don't need much memory or CPU for most jobs. On AWS, a single t3.micro ($8/month) can handle thousands of lightweight jobs per hour. Scale workers based on queue depth, not anticipation.

### Checking Job Status

Users will want to know if their export is ready:

```typescript
// src/modules/export/routes.ts
import { exportQueue } from '../../queues'

exportRoutes.get('/status/:jobId', async (c) => {
  const { jobId } = c.req.param()

  const job = await exportQueue.getJob(jobId)
  if (!job) {
    return c.json({ error: 'Job not found' }, 404)
  }

  const state = await job.getState()
  const progress = job.progress

  if (state === 'completed') {
    return c.json({
      status: 'completed',
      result: job.returnvalue
    })
  }

  if (state === 'failed') {
    return c.json({
      status: 'failed',
      error: job.failedReason
    })
  }

  return c.json({
    status: state,  // 'waiting', 'active', 'delayed'
    progress
  })
})
```

🤔 **Taste Moment:** For better UX, consider using Server-Sent Events (SSE) or WebSockets to push status updates instead of making the client poll. We'll cover this in the API Design chapter.

### Priority Queues

Not all jobs are equally urgent. Password reset emails should jump ahead of weekly digest emails:

```typescript
// High priority - process first
await emailQueue.add(
  'password-reset',
  { userId, token },
  { priority: 1 }  // Lower number = higher priority
)

// Normal priority
await emailQueue.add(
  'weekly-digest',
  { userId },
  { priority: 10 }
)

// Low priority - process when queue is empty
await emailQueue.add(
  'marketing-email',
  { userId },
  { priority: 100 }
)
```

Priorities work within a single queue. For complete isolation (e.g., guaranteeing password resets process even during high load), use separate queues with dedicated workers:

```typescript
export const criticalEmailQueue = new Queue('emails-critical', { connection })
export const bulkEmailQueue = new Queue('emails-bulk', { connection })
```

### Sandboxed Processors

By default, job handlers run in the main worker process. If a job consumes too much CPU or crashes, it affects all jobs. For isolation, use sandboxed processors:

```typescript
// src/workers/export.worker.ts
import { Worker } from 'bullmq'
import path from 'path'

const worker = new Worker(
  'exports',
  path.join(__dirname, 'processors/export.processor.js'),  // Runs in child process
  {
    connection,
    concurrency: 3,
    useWorkerThreads: true  // Or false for child processes
  }
)
```

```typescript
// src/workers/processors/export.processor.ts
import { Job } from 'bullmq'

// This runs in an isolated process/thread
export default async function (job: Job) {
  const { workspaceId, format } = job.data
  // Heavy processing here won't affect other jobs
  return await generateExport(workspaceId, format)
}
```

Sandboxed processors are especially useful for:
- CPU-intensive work (image processing, PDF generation)
- Untrusted code execution (user-provided templates)
- Jobs with memory leaks you can't easily fix

## Job Patterns and Best Practices

### Idempotency: Jobs Should Be Safe to Retry

Network blips, worker crashes, Redis failovers — jobs can be processed multiple times. Make them idempotent: running a job twice should produce the same result as running it once.

```typescript
// ❌ Not idempotent - sends duplicate emails
async function processWelcomeEmail(job: Job<{ userId: string }>) {
  const user = await getUser(job.data.userId)
  await sendEmail(user.email, 'Welcome!')  // Sends every time
}

// ✅ Idempotent - checks before sending
async function processWelcomeEmail(job: Job<{ userId: string }>) {
  const user = await getUser(job.data.userId)

  // Check if we already sent this email
  const alreadySent = await redis.get(`welcome_sent:${user.id}`)
  if (alreadySent) {
    return { skipped: true, reason: 'already_sent' }
  }

  await sendEmail(user.email, 'Welcome!')

  // Mark as sent with TTL (in case we need to resend later)
  await redis.setex(`welcome_sent:${user.id}`, 60 * 60 * 24 * 30, '1')

  return { sent: true }
}
```

For database operations, use unique constraints or upserts:

```typescript
// ✅ Idempotent database operation
async function processImport(job: Job<{ fileId: string }>) {
  const records = await parseFile(job.data.fileId)

  // Use upsert to handle duplicates
  for (const record of records) {
    await db
      .insert(imports)
      .values(record)
      .onConflictDoUpdate({
        target: imports.externalId,
        set: { ...record, updatedAt: new Date() }
      })
  }
}
```

### Job Data Should Be Minimal

Jobs are serialized to Redis. Keep the data small:

```typescript
// ❌ Don't store large data in jobs
await exportQueue.add('generate', {
  workspaceId,
  allProjects: projects,      // Could be megabytes
  allTasks: tasks,            // Even more megabytes
  userData: currentUser       // Might contain sensitive data
})

// ✅ Store references, fetch data in the worker
await exportQueue.add('generate', {
  workspaceId,
  userId,
  filters: { projectIds: ['abc', 'def'] }
})
```

Why?

1. Large payloads slow down Redis
2. Data might change between enqueue and processing — fetch fresh data
3. Sensitive data in Redis creates security exposure

### Handling Failures Gracefully

Some failures are retryable (network timeouts), others aren't (invalid input). Handle them differently:

```typescript
import { Worker, Job, UnrecoverableError } from 'bullmq'

const worker = new Worker('webhooks', async (job: Job) => {
  const { url, payload } = job.data

  // Validate input - don't retry if invalid
  if (!isValidUrl(url)) {
    throw new UnrecoverableError('Invalid webhook URL')  // Won't retry
  }

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(10000)  // 10s timeout
    })

    if (response.status >= 500) {
      // Server error - worth retrying
      throw new Error(`Server error: ${response.status}`)
    }

    if (response.status >= 400) {
      // Client error - don't retry
      throw new UnrecoverableError(`Client error: ${response.status}`)
    }

    return { delivered: true, status: response.status }
  } catch (error) {
    if (error instanceof UnrecoverableError) throw error

    // Network errors are retryable
    throw error
  }
})
```

### Rate Limiting with Job Options

When calling rate-limited APIs (like LLM providers), use BullMQ's rate limiter:

```typescript
// src/queues/llm.ts
export const llmQueue = new Queue('llm', {
  connection,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 2000 }
  }
})

// Worker with rate limiting
const llmWorker = new Worker(
  'llm',
  async (job) => {
    const { prompt, model } = job.data
    return await callLLM(prompt, model)
  },
  {
    connection,
    limiter: {
      max: 50,           // 50 jobs
      duration: 60000    // per minute
    }
  }
)
```

⚡ **AI Shortcut:** LLM API calls are the perfect use case for background jobs. Users submit a prompt, the job calls the LLM, and results are delivered via notification or WebSocket. This pattern handles rate limits, retries, and prevents user-facing timeouts.

### Job Dependencies and Flows

Sometimes jobs depend on other jobs. BullMQ supports this with flows:

```typescript
import { FlowProducer } from 'bullmq'

const flowProducer = new FlowProducer({ connection })

// Create a flow: process images, then generate thumbnails, then notify
await flowProducer.add({
  name: 'notify-upload-complete',
  queueName: 'notifications',
  data: { userId, message: 'Your upload is ready' },
  children: [
    {
      name: 'generate-thumbnails',
      queueName: 'images',
      data: { imageIds },
      children: [
        {
          name: 'process-upload',
          queueName: 'uploads',
          data: { uploadId }
        }
      ]
    }
  ]
})
```

The flow executes bottom-up: process upload → generate thumbnails → notify. Each step only runs when its children complete successfully.

### Delayed and Scheduled Jobs

Jobs don't have to run immediately:

```typescript
// Delay for 5 minutes
await emailQueue.add(
  'send-reminder',
  { userId, taskId },
  { delay: 5 * 60 * 1000 }
)

// Run at a specific time
const runAt = new Date('2026-01-15T09:00:00Z')
await reportQueue.add(
  'weekly-report',
  { workspaceId },
  { delay: runAt.getTime() - Date.now() }
)
```

For recurring jobs, use BullMQ's repeat feature:

```typescript
// Run every day at 9am
await reportQueue.add(
  'daily-digest',
  { workspaceId },
  {
    repeat: {
      pattern: '0 9 * * *'  // Cron syntax
    }
  }
)

// Run every 5 minutes
await healthCheckQueue.add(
  'check-services',
  {},
  {
    repeat: {
      every: 5 * 60 * 1000
    }
  }
)
```

🔒 **Security Callout:** Scheduled jobs run with whatever permissions they had at creation time. If a user schedules a job and then loses access, the job still runs. For sensitive operations, re-verify permissions inside the job.

### Dead Letter Queues

What happens to jobs that fail all their retries? By default, they sit in the "failed" state forever. For critical workflows, move them to a dead letter queue (DLQ) for manual review or alternative processing:

```typescript
// src/queues/dlq.ts
export const deadLetterQueue = new Queue('dead-letter', { connection })

// Worker that moves failed jobs to DLQ after exhausting retries
const worker = new Worker(
  'webhooks',
  async (job) => {
    // ... webhook delivery logic
  },
  {
    connection,
    settings: {
      backoffStrategy: (attemptsMade) => {
        // After 5 attempts, give up
        if (attemptsMade >= 5) return -1  // Stop retrying
        return Math.pow(2, attemptsMade) * 1000  // Exponential backoff
      }
    }
  }
)

// Listen for final failures
worker.on('failed', async (job, error) => {
  if (!job) return

  // Check if all retries exhausted
  const attemptsMade = job.attemptsMade
  const maxAttempts = job.opts.attempts || 1

  if (attemptsMade >= maxAttempts) {
    // Move to dead letter queue
    await deadLetterQueue.add('failed-webhook', {
      originalJob: {
        id: job.id,
        name: job.name,
        data: job.data,
        attemptsMade: job.attemptsMade,
        failedReason: error.message
      },
      failedAt: new Date().toISOString()
    })

    logger.error('Job moved to DLQ', {
      jobId: job.id,
      queue: 'webhooks',
      error: error.message
    })
  }
})
```

You can then build admin tooling to review DLQ jobs, fix the underlying issue, and requeue them:

```typescript
// Admin endpoint to retry a DLQ job
app.post('/admin/dlq/:jobId/retry', requireAdmin, async (c) => {
  const { jobId } = c.req.param()

  const dlqJob = await deadLetterQueue.getJob(jobId)
  if (!dlqJob) {
    return c.json({ error: 'Job not found' }, 404)
  }

  const { originalJob } = dlqJob.data

  // Re-add to original queue
  await webhookQueue.add(originalJob.name, originalJob.data, {
    attempts: 3  // Fresh attempts
  })

  // Remove from DLQ
  await dlqJob.remove()

  return c.json({ success: true, message: 'Job requeued' })
})
```

### Timeouts and Stalled Jobs

Jobs can get stuck. Maybe the worker crashed mid-processing, or an external API is hanging. BullMQ detects stalled jobs and can auto-retry them:

```typescript
const worker = new Worker(
  'exports',
  async (job) => {
    // This job has 5 minutes to complete
    // ...
  },
  {
    connection,
    lockDuration: 300000,  // 5 minutes
    stalledInterval: 30000,  // Check every 30 seconds
    maxStalledCount: 2  // Retry stalled jobs up to 2 times
  }
)
```

For jobs that call external APIs, add explicit timeouts:

```typescript
async function processWebhook(job: Job) {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 10000)  // 10s timeout

  try {
    const response = await fetch(job.data.url, {
      method: 'POST',
      body: JSON.stringify(job.data.payload),
      signal: controller.signal
    })
    return { status: response.status }
  } finally {
    clearTimeout(timeout)
  }
}
```

## Monitoring and Observability

Jobs fail silently if you're not watching. Set up monitoring:

### Job Events

```typescript
import { QueueEvents } from 'bullmq'

const queueEvents = new QueueEvents('exports', { connection })

queueEvents.on('completed', ({ jobId, returnvalue }) => {
  logger.info('Job completed', { jobId, result: returnvalue })
  metrics.increment('jobs.completed', { queue: 'exports' })
})

queueEvents.on('failed', ({ jobId, failedReason }) => {
  logger.error('Job failed', { jobId, error: failedReason })
  metrics.increment('jobs.failed', { queue: 'exports' })
})

queueEvents.on('stalled', ({ jobId }) => {
  logger.warn('Job stalled', { jobId })
  metrics.increment('jobs.stalled', { queue: 'exports' })
})
```

### Queue Metrics

```typescript
// Periodically check queue health
async function reportQueueMetrics() {
  const waiting = await exportQueue.getWaitingCount()
  const active = await exportQueue.getActiveCount()
  const delayed = await exportQueue.getDelayedCount()
  const failed = await exportQueue.getFailedCount()

  metrics.gauge('queue.waiting', waiting, { queue: 'exports' })
  metrics.gauge('queue.active', active, { queue: 'exports' })
  metrics.gauge('queue.delayed', delayed, { queue: 'exports' })
  metrics.gauge('queue.failed', failed, { queue: 'exports' })
}

setInterval(reportQueueMetrics, 30000)  // Every 30 seconds
```

### Bull Board for Debugging

Bull Board provides a web UI for monitoring queues:

```typescript
// src/admin/bullboard.ts
import { createBullBoard } from '@bull-board/api'
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter'
import { HonoAdapter } from '@bull-board/hono'
import { exportQueue, emailQueue, webhookQueue } from '../queues'

const serverAdapter = new HonoAdapter('/admin/queues')

createBullBoard({
  queues: [
    new BullMQAdapter(exportQueue),
    new BullMQAdapter(emailQueue),
    new BullMQAdapter(webhookQueue)
  ],
  serverAdapter
})

export const bullBoardRoutes = serverAdapter.registerPlugin()
```

Protect the Bull Board with admin authentication — it shows job data and allows retrying/deleting jobs.

💸 **Startup Cost Callout:** Bull Board is free and runs in your existing process. No additional infrastructure needed. Add it from day one.

## Deployment Considerations

### Separate Workers from API Servers

Workers should run as separate processes, potentially on separate machines:

```yaml
# docker-compose.yml
services:
  api:
    build: .
    command: npm run start
    ports:
      - "3000:3000"
    environment:
      - REDIS_HOST=redis

  worker-exports:
    build: .
    command: npm run worker:export
    environment:
      - REDIS_HOST=redis
    deploy:
      replicas: 2  # Run multiple workers

  worker-emails:
    build: .
    command: npm run worker:email
    environment:
      - REDIS_HOST=redis

  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data
```

### Graceful Shutdown

When deploying new versions, workers need time to finish current jobs:

```typescript
// In your worker file
let isShuttingDown = false

process.on('SIGTERM', async () => {
  if (isShuttingDown) return
  isShuttingDown = true

  console.log('Shutting down worker gracefully...')

  // Stop accepting new jobs
  await worker.pause()

  // Wait for active jobs to complete (with timeout)
  const timeout = setTimeout(() => {
    console.log('Shutdown timeout, forcing exit')
    process.exit(1)
  }, 30000)  // 30 second timeout

  await worker.close()
  clearTimeout(timeout)

  console.log('Worker shut down cleanly')
  process.exit(0)
})
```

Configure your orchestrator (Kubernetes, ECS) to wait for graceful shutdown:

```yaml
# kubernetes deployment
spec:
  terminationGracePeriodSeconds: 60
```

### Redis Persistence

Jobs live in Redis. If Redis loses data, you lose jobs. Configure Redis for persistence:

```conf
# redis.conf
appendonly yes
appendfsync everysec
```

Or use a managed Redis service (AWS ElastiCache, Upstash, Railway) that handles this for you.

## Testing Background Jobs

Jobs are code — they need tests. The challenge is that they run asynchronously and depend on Redis.

### Unit Testing Job Handlers

Extract the job logic into a testable function:

```typescript
// src/workers/processors/export.logic.ts
export async function generateExportLogic(
  workspaceId: string,
  format: 'pdf' | 'csv',
  deps: { db: Database; storage: Storage }
): Promise<{ url: string }> {
  const data = await deps.db.getWorkspaceData(workspaceId)
  const buffer = format === 'pdf'
    ? await generatePdf(data)
    : await generateCsv(data)
  const url = await deps.storage.upload(buffer)
  return { url }
}
```

```typescript
// src/workers/processors/export.logic.test.ts
import { describe, it, expect, vi } from 'vitest'
import { generateExportLogic } from './export.logic'

describe('generateExportLogic', () => {
  it('generates PDF and uploads to storage', async () => {
    const mockDb = {
      getWorkspaceData: vi.fn().mockResolvedValue({ tasks: [] })
    }
    const mockStorage = {
      upload: vi.fn().mockResolvedValue('https://s3.example.com/export.pdf')
    }

    const result = await generateExportLogic('workspace-1', 'pdf', {
      db: mockDb,
      storage: mockStorage
    })

    expect(result.url).toBe('https://s3.example.com/export.pdf')
    expect(mockStorage.upload).toHaveBeenCalled()
  })
})
```

### Integration Testing with a Real Queue

For integration tests, use a test Redis instance:

```typescript
// src/workers/export.integration.test.ts
import { Queue, Worker } from 'bullmq'
import { describe, it, expect, beforeAll, afterAll } from 'vitest'

const testConnection = {
  host: process.env.TEST_REDIS_HOST || 'localhost',
  port: 6379
}

describe('Export Queue Integration', () => {
  let queue: Queue
  let worker: Worker

  beforeAll(async () => {
    queue = new Queue('test-exports', { connection: testConnection })
    worker = new Worker('test-exports', async (job) => {
      return { processed: true, data: job.data }
    }, { connection: testConnection })
  })

  afterAll(async () => {
    await worker.close()
    await queue.obliterate({ force: true })  // Clean up test queue
  })

  it('processes jobs end-to-end', async () => {
    const job = await queue.add('test-job', { workspaceId: 'test' })

    // Wait for job to complete
    const result = await job.waitUntilFinished(queue.events)

    expect(result.processed).toBe(true)
  })
})
```

## The Taste Test

**Scenario 1:** A developer adds a background job for sending Slack notifications. The job takes 50ms to run. Is this necessary?

*What do you think?* Probably overkill. A 50ms operation won't noticeably delay a request. The overhead of job serialization, Redis round-trips, and worker scheduling adds more latency than it saves. Keep it synchronous unless the external call is unreliable and needs retries.

**Scenario 2:** A job processes user uploads. It stores the user's email address in the job data so it can send a notification when done.

*What's the issue?* Job data persists in Redis and can be viewed in monitoring tools. Store the user ID instead and fetch the email in the worker. This also ensures you send to their current email if they changed it.

**Scenario 3:** An export job fails after 2 retries with "Rate limit exceeded." The third retry is scheduled for 4 seconds later.

*What would you change?* The backoff is too aggressive for rate limits. Rate limit errors often require waiting 60+ seconds. Either increase the backoff delay or check the `Retry-After` header and use `job.moveToDelayed()` to reschedule appropriately.

**Scenario 4:** A worker processes 100 jobs successfully, then crashes. The team discovers all 100 jobs ran twice.

*What went wrong?* The jobs weren't acknowledged until the worker process exited. Use BullMQ's default behavior where jobs are acknowledged after the handler returns, or ensure your jobs are idempotent.

**Scenario 5:** A queue has 10,000 waiting jobs. A developer suggests increasing worker concurrency from 5 to 100.

*Your response?* Not so fast. High concurrency can overwhelm databases, APIs, or memory. Start by checking why jobs are accumulating — is each job slow? Are there failures? Add more worker instances rather than cranking up concurrency, which gives better isolation and can be scaled across machines.

## Practical Exercise

Build a complete background job system for a project management application:

**Requirements:**

1. **Export system:**
   - Users can request exports in PDF, CSV, or Excel format
   - Exports are processed in the background
   - Progress is tracked and visible to users
   - Completed exports are uploaded to S3 and users are notified

2. **Email queue:**
   - Invitation emails when users are added to workspaces
   - Daily digest emails (scheduled)
   - Password reset emails (high priority, low retry delay)

3. **Webhook delivery:**
   - Workspaces can configure webhook URLs
   - Events (task created, task completed) trigger webhook delivery
   - Failed webhooks retry with exponential backoff
   - Webhooks are disabled after repeated failures

4. **Monitoring:**
   - Set up Bull Board for admin access
   - Log job completion and failure rates
   - Alert when queue depth exceeds threshold

**Acceptance criteria:**
- Export jobs are idempotent (re-running produces same result)
- Email jobs don't send duplicates
- Webhook jobs respect rate limits and disable failing endpoints
- Workers shut down gracefully without losing jobs
- All job types have appropriate retry configurations

**AI Integration:**

Use Claude to generate test scenarios for your job system:

```
I'm building a background job system with these queues:
- exports (PDF/CSV generation, ~30 seconds per job)
- emails (transactional emails, ~1 second per job)
- webhooks (HTTP POST to external URLs, variable latency)

Generate 10 failure scenarios I should test:
1. What could go wrong?
2. How should the system behave?
3. How do I verify correct behavior?

Focus on edge cases around retries, idempotency, and graceful degradation.
```

Implement tests for at least 5 of the scenarios Claude suggests.

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I understand when to use background jobs vs. synchronous processing
- [ ] I can set up BullMQ queues and workers with appropriate configuration
- [ ] I know how to make jobs idempotent to handle retries safely
- [ ] I can implement job progress tracking and status endpoints
- [ ] I understand how to configure retries, backoff, and rate limiting
- [ ] I can set up monitoring and alerting for job queues
- [ ] I know how to handle graceful shutdown in workers
- [ ] I can design job flows with dependencies between jobs

Background jobs are the workhorse of scalable applications. They let you respond quickly to users while handling heavy lifting behind the scenes. The patterns here — idempotency, proper retry configuration, monitoring — separate reliable systems from fragile ones.

The next chapter covers API design, including how to communicate job status back to users through polling, webhooks, and real-time updates.

## Common Patterns Recap

Here's a quick reference for the patterns covered in this chapter:

**Basic job creation:**
```typescript
await queue.add('job-name', { data }, { attempts: 3 })
```

**Delayed job:**
```typescript
await queue.add('job-name', { data }, { delay: 60000 })
```

**Priority job:**
```typescript
await queue.add('job-name', { data }, { priority: 1 })
```

**Rate-limited worker:**
```typescript
new Worker(queue, handler, { limiter: { max: 10, duration: 1000 } })
```

**Idempotency check:**
```typescript
const processed = await redis.get(`processed:${job.id}`)
if (processed) return { skipped: true }
```

**Graceful shutdown:**
```typescript
process.on('SIGTERM', () => worker.close())
```

These patterns compose. A job can be delayed, prioritized, rate-limited, and idempotent all at once. Start simple, add complexity only when needed.
