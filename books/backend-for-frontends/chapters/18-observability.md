# Observability

## Why This Matters

Your application is running in production. Users are hitting it. Something is slow — or broken — and you need to figure out why.

Without observability, you're debugging blind. You add `console.log`, redeploy, wait for the problem to happen again, read the logs, realize you logged the wrong thing, add more logs, redeploy again. This cycle is painful and slow.

Observability means your system tells you what's happening inside it. When something breaks, you can see where and why without deploying new code.

The three pillars of observability are **logs** (discrete events), **metrics** (aggregated measurements), and **traces** (request flows across services). This chapter teaches you to implement all three without drowning in data or vendor lock-in.

## Structured Logging

`console.log('User created')` is not production logging. You can't search it, filter it, or alert on it.

Structured logging means every log entry is a JSON object with consistent fields:

```typescript
// src/lib/logger.ts
import pino from 'pino'

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  base: {
    service: 'my-api',
    environment: process.env.NODE_ENV,
    version: process.env.APP_VERSION,
  },
})

// Create child loggers with request context
export function createRequestLogger(requestId: string, userId?: string) {
  return logger.child({
    requestId,
    userId,
  })
}
```

```typescript
// Usage in your application
import { createRequestLogger } from '../lib/logger'

app.use(async (c, next) => {
  const requestId = c.req.header('x-request-id') || crypto.randomUUID()
  const log = createRequestLogger(requestId, c.get('user')?.id)

  c.set('log', log)
  c.set('requestId', requestId)

  const start = Date.now()

  try {
    await next()
  } finally {
    log.info({
      method: c.req.method,
      path: c.req.path,
      status: c.res.status,
      duration: Date.now() - start,
    }, 'request completed')
  }
})
```

Output:
```json
{
  "level": "info",
  "time": "2025-01-15T10:23:45.123Z",
  "service": "my-api",
  "environment": "production",
  "version": "1.2.3",
  "requestId": "abc-123",
  "userId": "user_456",
  "method": "POST",
  "path": "/api/tasks",
  "status": 201,
  "duration": 45,
  "msg": "request completed"
}
```

Now you can:
- Search for all logs from a specific request: `requestId:abc-123`
- Find slow requests: `duration:>1000`
- Track a user's activity: `userId:user_456`
- Filter by error level: `level:error`

### What to Log

**Always log:**
- Request start/end with duration
- Errors with full stack traces
- Authentication events (login, logout, failed attempts)
- External API calls with response times
- Database query failures
- Background job start/complete/fail

**Never log:**
- Passwords or credentials
- Full credit card numbers
- Personal health information
- Session tokens or API keys
- Anything that violates GDPR/CCPA

```typescript
// ❌ Don't do this
log.info({ user: req.body })  // May contain password

// ✅ Do this instead
log.info({
  userId: user.id,
  email: user.email,
  action: 'user_created'
})
```

🔒 **Security Callout:** Log scrubbing is critical. Use a library like `pino-noir` to automatically redact sensitive fields. Assume your logs will be read by attackers if they gain access.

### Log Aggregation

Logs spread across multiple containers are useless. You need them in one place.

**For Fly.io:**
Fly ships logs to their dashboard automatically. For more features, forward to an external service:

```bash
fly logs --app my-api  # Stream logs
```

**For production scale:**
Use a log aggregation service. Options, roughly ordered by startup-friendliness:

| Service | Free Tier | Good For |
|---------|-----------|----------|
| Axiom | 500GB/month | Best free tier, great DX |
| Better Stack | 1GB/month | Good UI, easy setup |
| Datadog | None | Enterprise, expensive |
| Self-hosted (Loki) | ∞ | If you have ops bandwidth |

```typescript
// Shipping logs to Axiom
import pino from 'pino'

const transport = pino.transport({
  target: '@axiomhq/pino',
  options: {
    dataset: 'my-api',
    token: process.env.AXIOM_TOKEN,
  },
})

export const logger = pino(transport)
```

## Metrics

Logs tell you what happened. Metrics tell you how often and how much.

### Essential Application Metrics

Every backend should track:

```typescript
// src/lib/metrics.ts
import { Counter, Histogram, Gauge, Registry } from 'prom-client'

export const registry = new Registry()

// Request metrics
export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'path', 'status'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [registry],
})

export const httpRequestTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [registry],
})

// Business metrics
export const tasksCreated = new Counter({
  name: 'tasks_created_total',
  help: 'Total tasks created',
  labelNames: ['workspace_id'],
  registers: [registry],
})

// Resource metrics
export const dbPoolSize = new Gauge({
  name: 'db_pool_connections',
  help: 'Number of database pool connections',
  labelNames: ['state'],  // idle, active
  registers: [registry],
})
```

```typescript
// Middleware to track request metrics
app.use(async (c, next) => {
  const start = Date.now()
  await next()

  const duration = (Date.now() - start) / 1000
  const labels = {
    method: c.req.method,
    path: routePattern(c.req.path),  // Normalize /users/123 → /users/:id
    status: c.res.status.toString(),
  }

  httpRequestDuration.observe(labels, duration)
  httpRequestTotal.inc(labels)
})

// Expose metrics endpoint
app.get('/metrics', async (c) => {
  const metrics = await registry.metrics()
  return c.text(metrics, 200, {
    'Content-Type': registry.contentType,
  })
})
```

### Four Golden Signals

Google's SRE handbook defines four signals that cover most monitoring needs:

1. **Latency** — How long requests take (the `http_request_duration_seconds` histogram)
2. **Traffic** — Request rate (the `http_requests_total` counter)
3. **Errors** — Error rate (filter by `status=~"5.."`)
4. **Saturation** — How full your resources are (DB connections, memory, CPU)

If you track these four things, you'll catch most problems.

### The /metrics Endpoint

Prometheus-format metrics are the industry standard. Your app exposes `/metrics`, and a metrics collector scrapes it periodically.

**For Fly.io:**
Enable built-in metrics in `fly.toml`:

```toml
[metrics]
  port = 9091
  path = "/metrics"
```

**For AWS with Grafana Cloud:**

```typescript
// Push metrics to Grafana Cloud
import { pushgateway } from 'prom-client'

const gateway = new pushgateway.Pushgateway(
  process.env.GRAFANA_PUSH_URL,
  {
    headers: {
      Authorization: `Bearer ${process.env.GRAFANA_TOKEN}`,
    },
  },
  registry
)

// Push every 15 seconds
setInterval(() => {
  gateway.pushAdd({ jobName: 'my-api' })
}, 15000)
```

💸 **Startup Cost Callout:** Grafana Cloud has a generous free tier (10K metrics, 50GB logs). It's the best option for startups until you outgrow it.

## Distributed Tracing

When a request touches multiple services (or makes multiple database queries), tracing shows you the full picture.

A trace is a tree of **spans**. Each span represents a unit of work with a start time, duration, and metadata.

```
Request: POST /api/projects
├── HTTP Handler (2ms)
│   ├── Auth middleware (0.5ms)
│   ├── Parse body (0.2ms)
│   └── createProject() (45ms)
│       ├── DB: INSERT project (12ms)
│       ├── DB: INSERT membership (8ms)
│       └── sendWelcomeEmail() (25ms)
│           └── HTTP: POST mailgun.api (24ms)
```

### Setting Up Tracing

OpenTelemetry is the standard. It's vendor-agnostic — same instrumentation works with any backend.

```typescript
// src/instrumentation.ts — run before any other imports
import { NodeSDK } from '@opentelemetry/sdk-node'
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'

const sdk = new NodeSDK({
  serviceName: 'my-api',
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
    headers: {
      Authorization: `Bearer ${process.env.OTEL_TOKEN}`,
    },
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      // Automatically traces HTTP, database, etc.
      '@opentelemetry/instrumentation-fs': { enabled: false },
    }),
  ],
})

sdk.start()
```

```bash
# Start your app with instrumentation
node --require ./dist/instrumentation.js ./dist/index.js
```

Auto-instrumentation handles most cases. For custom spans:

```typescript
import { trace } from '@opentelemetry/api'

const tracer = trace.getTracer('my-api')

export async function processOrder(order: Order) {
  return tracer.startActiveSpan('processOrder', async (span) => {
    try {
      span.setAttribute('order.id', order.id)
      span.setAttribute('order.total', order.total)

      await validateInventory(order)
      await chargePayment(order)
      await createShipment(order)

      span.setStatus({ code: SpanStatusCode.OK })
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message,
      })
      span.recordException(error)
      throw error
    } finally {
      span.end()
    }
  })
}
```

### When You Need Tracing

Tracing has overhead (both performance and cost). Start without it and add when:

- You have multiple services that call each other
- Request latency is inconsistent and you can't find the slow part
- You need to understand complex request flows

For a single-service API, detailed logging with request IDs often suffices.

## Error Tracking

Errors need special treatment. You want to:
- See every error with full context
- Group similar errors together
- Track error rates over time
- Get alerted on new errors

### Sentry Setup

Sentry is the standard for error tracking. The free tier handles most startups.

```typescript
// src/lib/sentry.ts
import * as Sentry from '@sentry/node'

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.APP_VERSION,

  // Sample 10% of transactions for performance monitoring
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,

  // Don't send PII
  beforeSend(event) {
    if (event.request?.headers) {
      delete event.request.headers['authorization']
      delete event.request.headers['cookie']
    }
    return event
  },
})

export { Sentry }
```

```typescript
// Error handling middleware
app.onError((err, c) => {
  const log = c.get('log')

  // Log the error
  log.error({
    error: err.message,
    stack: err.stack,
    requestId: c.get('requestId'),
  })

  // Send to Sentry with context
  Sentry.withScope((scope) => {
    scope.setTag('requestId', c.get('requestId'))
    scope.setUser({ id: c.get('user')?.id })
    scope.setContext('request', {
      method: c.req.method,
      path: c.req.path,
      query: c.req.query(),
    })
    Sentry.captureException(err)
  })

  // Return appropriate response
  if (err instanceof AppError) {
    return c.json({ error: err.message }, err.statusCode)
  }

  return c.json({ error: 'Internal server error' }, 500)
})
```

### Grouping and Noise

Sentry groups errors by stack trace fingerprint. Sometimes this is wrong — different root causes get grouped together, or the same error creates thousands of separate issues.

Custom fingerprinting helps:

```typescript
Sentry.withScope((scope) => {
  // Group by error type + endpoint, not full stack
  scope.setFingerprint([
    err.constructor.name,
    c.req.path,
  ])
  Sentry.captureException(err)
})
```

## Dashboards

Dashboards should answer questions, not just display numbers.

### A Minimal Effective Dashboard

Your primary dashboard needs three panels:

**1. Request Rate and Errors**
```promql
# Requests per second
rate(http_requests_total[5m])

# Error rate (%)
rate(http_requests_total{status=~"5.."}[5m])
  / rate(http_requests_total[5m]) * 100
```

**2. Latency Distribution**
```promql
# p50, p95, p99 latency
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

**3. Resource Saturation**
```promql
# Database connection pool utilization
db_pool_connections{state="active"}
  / (db_pool_connections{state="active"} + db_pool_connections{state="idle"})
```

That's it. Three panels cover the four golden signals. Add more only when you have specific questions.

🤔 **Taste Moment:** The worst dashboards have 50 panels that nobody looks at. The best have 3-5 panels that everyone checks daily. Start minimal and add panels only when you actually use them.

## Alerting

Alerts should wake you up for things that need immediate action. Everything else is noise.

### What to Alert On

**Page-worthy (wake someone up):**
- Error rate >5% for 5 minutes
- p99 latency >10s for 5 minutes
- Service completely unreachable
- Database connection pool exhausted

**Warning (check during business hours):**
- Error rate >1% for 15 minutes
- p95 latency >2s for 15 minutes
- Disk usage >80%
- Certificate expiring in <7 days

### Alerting Rules

```yaml
# alerts.yml (for Prometheus/Grafana)
groups:
  - name: api
    rules:
      - alert: HighErrorRate
        expr: |
          rate(http_requests_total{status=~"5.."}[5m])
          / rate(http_requests_total[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate: {{ $value | humanizePercentage }}"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            rate(http_request_duration_seconds_bucket[5m])
          ) > 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "p99 latency above 10s: {{ $value | humanizeDuration }}"

      - alert: DatabasePoolExhausted
        expr: |
          db_pool_connections{state="idle"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "No idle database connections available"
```

### Avoiding Alert Fatigue

If alerts fire frequently but don't require action, people stop responding to them. Every alert should have:

1. A clear action to take
2. A threshold that means "something is wrong" not "something is slightly suboptimal"
3. Documentation on how to investigate and resolve

```yaml
# ❌ Bad: alerts on normal variation
- alert: HighMemoryUsage
  expr: process_memory_bytes > 500000000
  # Fires whenever memory is above 500MB — probably normal

# ✅ Good: alerts on actionable condition
- alert: MemoryGrowthAnomaly
  expr: |
    deriv(process_memory_bytes[1h]) > 10000000
    and process_memory_bytes > 800000000
  for: 30m
  # Fires when memory is growing steadily AND already high
```

## The Taste Test

**Scenario 1:** A team adds logging for every function entry and exit: "Entering validateUser", "Exiting validateUser".

*Too verbose.* This creates log noise without insight. Log meaningful events (user validated, validation failed with reason), not function boundaries.

**Scenario 2:** The dashboard shows 50 metrics including "total number of GET requests to /health."

*Trim it.* Health check metrics are noise. Focus on metrics that indicate user impact. If nobody looks at a metric, remove it.

**Scenario 3:** An alert fires every Monday morning when traffic spikes at 9am.

*Fix the threshold.* If the behavior is normal, the alert shouldn't fire. Use rate-of-change alerting or higher thresholds during known busy periods.

**Scenario 4:** Errors are logged but not sent to Sentry because "we check the logs anyway."

*Add Sentry.* Logs are for investigation. Error tracking is for discovery. You need to know an error is happening before you investigate it. Scrolling through logs hoping to spot errors doesn't scale.

## Practical Exercise

Add observability to your TaskFlow API:

**Requirements:**
1. Structured logging with request IDs that propagate through the entire request
2. Prometheus metrics for request rate, latency, and errors
3. Sentry integration for error tracking
4. A dashboard with the three essential panels
5. One critical alert (error rate) and one warning alert (latency)

**Acceptance criteria:**
- You can search logs by request ID across all log lines for a single request
- Metrics endpoint returns Prometheus-format data
- Errors appear in Sentry with full context
- Dashboard shows real-time request rate, latency percentiles, and error rate
- Alert fires when you artificially spike error rate (e.g., return 500 for all requests temporarily)

**⚡ AI Shortcut:**

Generate your Grafana dashboard JSON:

```
Create a Grafana dashboard JSON with these panels:
1. Request rate over time (line chart)
2. Error rate percentage (stat panel with thresholds: green <1%, yellow <5%, red >5%)
3. p50/p95/p99 latency (line chart)
4. Active database connections (gauge)

Use Prometheus queries. My metrics are prefixed with http_request_ and db_pool_.
```

Import the JSON into Grafana. Adjust queries if your metric names differ.

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can implement structured logging with request context
- [ ] I understand the four golden signals and how to measure them
- [ ] I can set up error tracking that captures full context
- [ ] I know how to create dashboards that answer real questions
- [ ] I can write alerts that are actionable, not noisy

Observability is your debugging multiplier. When something breaks at 3am, you want the system to tell you what's wrong — not hunt through logs hoping for clues.
