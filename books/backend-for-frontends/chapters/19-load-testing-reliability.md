# Load Testing and Reliability

## Why This Matters

Your application works with 10 users. Will it work with 1,000? 10,000? You won't know until you test it — or until it breaks in production.

Load testing answers questions before your users ask them painfully:
- How many concurrent requests can we handle?
- Where does the system break first?
- How does performance degrade under load?

Reliability patterns keep the system running when parts fail:
- What happens when the database is slow?
- How do we handle a downstream service being down?
- How do we recover gracefully instead of crashing?

By the end of this chapter, you'll know how to stress-test your application and build basic fault tolerance.

## Load Testing with k6

**k6** is the right tool for most backend load testing. It's scriptable in JavaScript, runs from the command line, and integrates with CI/CD.

```bash
# Install k6
brew install k6
```

### Your First Load Test

```javascript
// load-tests/smoke.js
import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  vus: 10,           // 10 virtual users
  duration: '30s',   // for 30 seconds
}

export default function () {
  const res = http.get('http://localhost:3000/api/health')

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  })

  sleep(1)  // Wait 1 second between requests per user
}
```

```bash
k6 run load-tests/smoke.js
```

Output:
```
  scenarios: (100.00%) 1 scenario, 10 max VUs, 1m0s max duration
           * default: 10 looping VUs for 30s

  ✓ status is 200
  ✓ response time < 200ms

  http_req_duration..............: avg=45ms  min=12ms  med=38ms  max=234ms  p(90)=89ms   p(95)=112ms
  http_req_waiting...............: avg=44ms  min=11ms  med=37ms  max=233ms  p(90)=88ms   p(95)=111ms
  http_reqs......................: 290    9.66/s
  vus............................: 10     min=10  max=10
```

### Ramping Load Test

A smoke test confirms the system works. A ramp test finds the breaking point:

```javascript
// load-tests/stress.js
import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '3m', target: 50 },   // Hold at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '3m', target: 100 },  // Hold at 100 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests < 500ms
    http_req_failed: ['rate<0.01'],    // Error rate < 1%
  },
}

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000'

export default function () {
  // Simulate realistic user behavior
  const tasks = http.get(`${BASE_URL}/api/tasks`)
  check(tasks, { 'get tasks ok': (r) => r.status === 200 })

  sleep(Math.random() * 3 + 1)  // Random 1-4 second pause

  if (Math.random() > 0.7) {
    // 30% of users create a task
    const payload = JSON.stringify({
      title: `Task ${Date.now()}`,
      status: 'pending',
    })

    const create = http.post(`${BASE_URL}/api/tasks`, payload, {
      headers: { 'Content-Type': 'application/json' },
    })
    check(create, { 'create task ok': (r) => r.status === 201 })
  }

  sleep(1)
}
```

### Testing with Authentication

Most APIs require authentication. Generate a token before the test:

```javascript
// load-tests/authenticated.js
import http from 'k6/http'
import { check } from 'k6'

export const options = {
  vus: 20,
  duration: '1m',
}

// Setup runs once before the test
export function setup() {
  const loginRes = http.post('http://localhost:3000/api/auth/login', JSON.stringify({
    email: 'loadtest@example.com',
    password: 'loadtest123',
  }), {
    headers: { 'Content-Type': 'application/json' },
  })

  const token = loginRes.json('token')
  return { token }
}

export default function (data) {
  const res = http.get('http://localhost:3000/api/tasks', {
    headers: {
      Authorization: `Bearer ${data.token}`,
    },
  })

  check(res, { 'status is 200': (r) => r.status === 200 })
}
```

### Interpreting Results

Key metrics to watch:

| Metric | Healthy | Concerning | Failing |
|--------|---------|------------|---------|
| p95 latency | <500ms | 500ms-2s | >2s |
| Error rate | <0.1% | 0.1-1% | >1% |
| Throughput | Increasing with VUs | Flat | Decreasing |

**Signs of saturation:**
- Latency increases but throughput stays flat (system is maxed out)
- Error rate spikes suddenly (a component hit its limit)
- p99 is much higher than p95 (tail latency = queuing)

### Finding Bottlenecks

When load testing reveals problems, here's how to find them:

**1. Check database first**
Most performance problems are database problems.

```sql
-- Show slow queries (Postgres)
SELECT query, calls, mean_time, total_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

**2. Check connection pools**
If your connection pool is exhausted, requests queue up:

```typescript
// Log pool status during load test
setInterval(() => {
  console.log({
    totalConnections: pool.totalCount,
    idleConnections: pool.idleCount,
    waitingClients: pool.waitingCount,
  })
}, 5000)
```

**3. Profile memory and CPU**
Node.js has built-in profiling:

```bash
node --prof app.js
# After load test, process the log:
node --prof-process isolate-*.log > profile.txt
```

### CI Integration

Run load tests in CI to catch regressions:

```yaml
# .github/workflows/load-test.yml
name: Load Test

on:
  push:
    branches: [main]

jobs:
  load-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci
      - run: npm run db:migrate
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/postgres

      - name: Start server
        run: npm start &
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/postgres
          PORT: 3000

      - name: Wait for server
        run: npx wait-on http://localhost:3000/health

      - uses: grafana/k6-action@v0.3.1
        with:
          filename: load-tests/smoke.js
          flags: --out json=results.json

      - name: Check thresholds
        run: |
          if grep -q '"thresholds":{".*":{"ok":false' results.json; then
            echo "Load test thresholds failed"
            exit 1
          fi
```

💸 **Startup Cost Callout:** Run load tests against production-like infrastructure. Testing against a beefy CI runner while production runs on a small instance gives false confidence.

## Reliability Patterns

Your application will face failures: network timeouts, overloaded databases, crashed services. Reliability patterns help you handle failures gracefully.

### Timeouts

Every external call needs a timeout. Without one, a slow dependency can hang your entire system.

```typescript
// ❌ No timeout — can hang forever
const response = await fetch('https://api.external.com/data')

// ✅ With timeout
const controller = new AbortController()
const timeout = setTimeout(() => controller.abort(), 5000)

try {
  const response = await fetch('https://api.external.com/data', {
    signal: controller.signal,
  })
  return await response.json()
} catch (error) {
  if (error.name === 'AbortError') {
    throw new Error('External API timeout')
  }
  throw error
} finally {
  clearTimeout(timeout)
}
```

Or use a utility:

```typescript
// src/lib/http.ts
export async function fetchWithTimeout(
  url: string,
  options: RequestInit & { timeout?: number } = {}
): Promise<Response> {
  const { timeout = 5000, ...fetchOptions } = options

  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeout)

  try {
    return await fetch(url, {
      ...fetchOptions,
      signal: controller.signal,
    })
  } finally {
    clearTimeout(timeoutId)
  }
}
```

**Timeout guidelines:**
- Database queries: 5-30 seconds depending on complexity
- External APIs: 5-10 seconds
- Internal services: 1-5 seconds
- Health checks: 1-2 seconds

### Retries with Exponential Backoff

Transient failures (network blips, brief overload) often succeed on retry:

```typescript
// src/lib/retry.ts
interface RetryOptions {
  maxRetries?: number
  baseDelay?: number
  maxDelay?: number
  shouldRetry?: (error: Error) => boolean
}

export async function retry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const {
    maxRetries = 3,
    baseDelay = 100,
    maxDelay = 5000,
    shouldRetry = () => true,
  } = options

  let lastError: Error

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error as Error

      if (attempt === maxRetries || !shouldRetry(lastError)) {
        throw lastError
      }

      // Exponential backoff with jitter
      const delay = Math.min(
        baseDelay * Math.pow(2, attempt) + Math.random() * 100,
        maxDelay
      )
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }

  throw lastError!
}
```

```typescript
// Usage
const data = await retry(
  () => fetchWithTimeout('https://api.example.com/data'),
  {
    maxRetries: 3,
    shouldRetry: (err) => {
      // Only retry network/timeout errors, not 4xx
      return err.name === 'AbortError' ||
             err.message.includes('ECONNREFUSED')
    },
  }
)
```

🔒 **Security Callout:** Never retry non-idempotent operations without care. Retrying a payment API call could charge the user twice. Make sure the downstream API is idempotent, or use idempotency keys.

### Circuit Breakers

When a dependency is failing consistently, stop calling it. A circuit breaker "opens" after repeated failures and "closes" after successful probes.

```typescript
// src/lib/circuit-breaker.ts
type CircuitState = 'closed' | 'open' | 'half-open'

export function createCircuitBreaker(options: {
  failureThreshold: number  // Failures before opening
  resetTimeout: number      // Ms before trying again
  name: string
}) {
  let state: CircuitState = 'closed'
  let failures = 0
  let lastFailureTime = 0
  let nextAttemptTime = 0

  return async function breaker<T>(fn: () => Promise<T>): Promise<T> {
    if (state === 'open') {
      if (Date.now() < nextAttemptTime) {
        throw new Error(`Circuit breaker ${options.name} is open`)
      }
      state = 'half-open'
    }

    try {
      const result = await fn()
      // Success: reset the breaker
      state = 'closed'
      failures = 0
      return result
    } catch (error) {
      failures++
      lastFailureTime = Date.now()

      if (failures >= options.failureThreshold) {
        state = 'open'
        nextAttemptTime = Date.now() + options.resetTimeout
        console.warn(`Circuit breaker ${options.name} opened after ${failures} failures`)
      }

      throw error
    }
  }
}
```

```typescript
// Usage
const paymentBreaker = createCircuitBreaker({
  name: 'stripe',
  failureThreshold: 5,
  resetTimeout: 30000,  // 30 seconds
})

async function chargeCustomer(amount: number) {
  return paymentBreaker(() =>
    stripe.charges.create({ amount, currency: 'usd' })
  )
}
```

### Graceful Degradation

When a non-critical service fails, degrade gracefully instead of failing entirely.

```typescript
// Feature that can work without recommendations
async function getProductPage(productId: string) {
  const product = await db.query.products.findFirst({
    where: eq(products.id, productId),
  })

  if (!product) {
    throw new NotFoundError('Product not found')
  }

  // Recommendations are nice-to-have, not critical
  let recommendations = []
  try {
    recommendations = await recommendationService.getRelated(productId)
  } catch (error) {
    // Log but don't fail the request
    logger.warn({ error, productId }, 'Failed to fetch recommendations')
    // Maybe set a flag to hide the recommendations section
  }

  return {
    product,
    recommendations,
    recommendationsAvailable: recommendations.length > 0,
  }
}
```

### Health Checks

Health checks tell load balancers and orchestrators whether your service can handle traffic.

**Liveness check** — Is the process running?
```typescript
app.get('/health/live', (c) => c.json({ status: 'ok' }))
```

**Readiness check** — Can the service handle requests?
```typescript
app.get('/health/ready', async (c) => {
  const checks = {
    database: false,
    redis: false,
  }

  try {
    await db.execute(sql`SELECT 1`)
    checks.database = true
  } catch (e) {
    logger.error(e, 'Database health check failed')
  }

  try {
    await redis.ping()
    checks.redis = true
  } catch (e) {
    logger.error(e, 'Redis health check failed')
  }

  const healthy = Object.values(checks).every(Boolean)

  return c.json({ status: healthy ? 'ok' : 'degraded', checks }, healthy ? 200 : 503)
})
```

Configure your orchestrator to use these:

```yaml
# fly.toml
[[services.http_checks]]
  interval = "10s"
  timeout = "2s"
  path = "/health/ready"
```

🤔 **Taste Moment:** Don't check dependencies you can survive without. If Redis being down shouldn't take your API offline, don't include it in the readiness check. Return 503 only for truly critical dependencies.

## Capacity Planning

Load testing tells you current limits. Capacity planning projects future needs.

**Know your baseline:**
```
Current: 100 RPM (requests per minute)
With 10 VUs: 1,000 RPM before degradation
Headroom: 10x
```

**Project growth:**
```
If users grow 3x this quarter:
New baseline: 300 RPM
Remaining headroom: 3.3x
Action: Monitor, but no changes needed
```

**Scale proactively when:**
- Headroom drops below 3x
- P95 latency is creeping up at current traffic
- You're planning a launch or marketing push

**Common scaling moves:**
1. Add more instances (horizontal)
2. Increase instance size (vertical)
3. Add read replicas for database
4. Add caching for hot paths
5. Optimize slow queries (often the best ROI)

## The Taste Test

**Scenario 1:** Load test shows the API handles 500 RPS on developer laptops. The team deploys to production (a small cloud instance) confident it will handle launch traffic.

*Dangerous assumption.* Always load test production-like infrastructure. Developer laptops are often more powerful than cloud instances.

**Scenario 2:** A service has retry logic but no circuit breaker. A downstream dependency is completely down.

*Problem:* Retries will keep hammering the dead service, wasting resources and potentially DDoSing it when it recovers. Add a circuit breaker to fail fast.

**Scenario 3:** Health checks verify database connectivity every 10 seconds by running `SELECT 1`.

*Probably fine.* Simple health checks are good. Don't make them complex queries that could timeout or add load. The goal is "can we connect?" not "is the query optimizer working?"

**Scenario 4:** The team wants to add chaos engineering with random pod kills in production.

*Not yet.* Chaos engineering is powerful but advanced. Start with load testing and basic reliability patterns. Chaos engineering makes sense when you have solid observability and need to find unknown failure modes.

## Practical Exercise

Add load testing and reliability patterns to your TaskFlow API:

**Requirements:**
1. k6 load test that simulates realistic user behavior (read tasks, create tasks, complete tasks)
2. CI job that runs load test and fails if thresholds are missed
3. Retry logic for external API calls with exponential backoff
4. Health check endpoint that verifies database and Redis connectivity
5. Document your capacity baseline (max RPS before degradation)

**Acceptance criteria:**
- Load test runs in CI on every push to main
- Thresholds: p95 < 500ms, error rate < 1%
- External API calls retry up to 3 times with backoff
- `/health/ready` returns 503 if database is unreachable

**⚡ AI Shortcut:**

Generate a k6 script from your API spec:

```
Generate a k6 load test script for this API:
- GET /api/tasks - list tasks (70% of requests)
- POST /api/tasks - create task (20% of requests)
- PATCH /api/tasks/:id - update task (10% of requests)

Use realistic think time between requests (1-3 seconds).
Include ramping from 10 to 100 VUs over 5 minutes.
Set thresholds for p95 latency < 500ms and error rate < 1%.
```

Review the generated script and adjust authentication and payload shapes to match your actual API.

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can write and run k6 load tests that simulate realistic traffic
- [ ] I know how to interpret load test results and find bottlenecks
- [ ] I can implement timeouts, retries, and circuit breakers
- [ ] I understand when to use different reliability patterns
- [ ] I can set up health checks that accurately reflect service readiness

Load testing removes the mystery from capacity. Reliability patterns transform failures from catastrophes into handled exceptions. Together, they let you sleep better when your code is in production.
