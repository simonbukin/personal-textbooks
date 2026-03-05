# Redis and the Art of Caching

## Why This Matters

Every backend engineer eventually reaches for caching. A query that takes 100ms is suddenly needed 1,000 times per second. A calculation that hits three external APIs adds latency to every request. A rate limiter needs to track requests per user per second.

Redis solves these problems. It's an in-memory data structure server — think of it as very fast shared state that multiple application instances can access. It's not a database (data is ephemeral by default, even with persistence options), but it's an essential tool in the backend engineer's toolkit.

Here's the catch: caching is easy to add and hard to get right. The actual Redis commands are simple. The hard part is deciding *what* to cache, *when* to invalidate, and *how* to handle the inevitable consistency issues. A bad caching strategy creates bugs that are incredibly difficult to reproduce and debug.

By the end of this chapter, you'll know when caching helps, when it doesn't, and how to implement it without creating a debugging nightmare.

## Redis Mental Model

Redis is an in-memory key-value store, but "key-value" undersells it. Redis stores *data structures* — strings, hashes, lists, sets, sorted sets — and provides atomic operations on them.

The mental model: Redis is a giant, blazingly fast dictionary that lives outside your application process. Multiple application instances can read and write to it. Operations are atomic. Data lives in RAM, so it's fast but limited by memory.

How fast? A Redis `GET` typically takes 0.1-0.5 milliseconds. Compare that to a database query that might take 5-50 milliseconds. That 100x speed difference is why Redis is useful for caching — you trade complexity for speed on hot paths.

But Redis is not a database replacement. It's complementary. Your data lives in Postgres (durable, queryable, consistent). Redis holds copies of hot data, temporary state, and coordination structures (rate limits, locks, queues).

### Key Data Structures and Their Use Cases

**Strings** — The simplest type. Store any value under a key.

```typescript
// Basic caching: store a JSON blob
await redis.set('user:123:profile', JSON.stringify(userProfile));
await redis.set('user:123:profile', JSON.stringify(userProfile), 'EX', 3600); // Expires in 1 hour

const cached = await redis.get('user:123:profile');
if (cached) {
  return JSON.parse(cached);
}
```

**Hashes** — A key that maps to a dictionary of fields. Good for caching objects where you might want to access individual fields.

```typescript
// Store user session data
await redis.hset('session:abc123', {
  userId: '123',
  role: 'admin',
  lastActive: Date.now().toString(),
});

// Get specific fields
const userId = await redis.hget('session:abc123', 'userId');

// Get all fields
const session = await redis.hgetall('session:abc123');
```

**Sets** — Unordered collection of unique strings. Good for membership checks and tracking unique items.

```typescript
// Track which users have seen a feature announcement
await redis.sadd('feature:announcement-v2:seen', userId);

// Check if user has seen it
const hasSeen = await redis.sismember('feature:announcement-v2:seen', userId);

// Count unique viewers
const viewerCount = await redis.scard('feature:announcement-v2:seen');
```

**Sorted Sets** — Like sets, but each member has a score. Members are sorted by score. Perfect for rate limiting, leaderboards, and time-based data.

```typescript
// Store with timestamp as score
await redis.zadd('workspace:abc:activity', Date.now(), JSON.stringify(event));

// Get recent activity (last 100 items)
const recent = await redis.zrevrange('workspace:abc:activity', 0, 99);

// Get activity from the last hour
const hourAgo = Date.now() - (60 * 60 * 1000);
const recentActivity = await redis.zrangebyscore('workspace:abc:activity', hourAgo, '+inf');

// Remove old entries
await redis.zremrangebyscore('workspace:abc:activity', '-inf', hourAgo);
```

**Lists** — Ordered collection with push/pop operations. Good for simple queues and recent items.

```typescript
// Add to a list (left push = newest first)
await redis.lpush('user:123:notifications', JSON.stringify(notification));

// Trim to keep only last 100
await redis.ltrim('user:123:notifications', 0, 99);

// Get all notifications
const notifications = await redis.lrange('user:123:notifications', 0, -1);
```

## The Four Use Cases You'll Actually Use

### 1. Cache-Aside for Hot Queries

The most common caching pattern. Your application checks the cache first; if the data isn't there, it fetches from the database and stores the result in the cache.

```typescript
// src/services/projects.service.ts
import { redis } from '../lib/redis';
import { db } from '../db';

export async function getProjectWithTaskCounts(projectId: string) {
  const cacheKey = `project:${projectId}:with-counts`;

  // Check cache first
  const cached = await redis.get(cacheKey);
  if (cached) {
    return JSON.parse(cached);
  }

  // Cache miss: fetch from database
  const project = await db.execute(sql`
    SELECT p.*,
      (SELECT count(*) FROM tasks WHERE project_id = p.id AND status != 'done') as open_tasks,
      (SELECT count(*) FROM tasks WHERE project_id = p.id AND status = 'done') as done_tasks
    FROM projects p
    WHERE p.id = ${projectId}
  `);

  if (!project.length) {
    return null;
  }

  // Store in cache with TTL
  await redis.set(cacheKey, JSON.stringify(project[0]), 'EX', 300); // 5 minutes

  return project[0];
}
```

The TTL (time-to-live) is crucial. Without it, cached data lives forever and becomes stale. With it, data eventually refreshes itself.

🤔 **Taste Moment:** TTL is a trade-off between freshness and cache hit rate. A 5-minute TTL means data can be up to 5 minutes stale, but you'll serve most requests from cache. A 10-second TTL keeps data fresher but causes more cache misses. Choose based on how stale your users can tolerate the data being.

### 2. Session Storage

Sessions need to be fast (checked on every request) and shared across application instances. Redis is a natural fit.

```typescript
// Session middleware
import { redis } from '../lib/redis';
import { nanoid } from 'nanoid';

export async function sessionMiddleware(c, next) {
  const sessionId = c.req.header('Authorization')?.replace('Bearer ', '');

  if (!sessionId) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const session = await redis.hgetall(`session:${sessionId}`);

  if (!session || !session.userId) {
    return c.json({ error: 'Invalid session' }, 401);
  }

  // Extend session TTL on activity
  await redis.expire(`session:${sessionId}`, 86400); // 24 hours

  c.set('session', session);
  c.set('userId', session.userId);

  await next();
}

// Create session on login
export async function createSession(userId: string, metadata: object) {
  const sessionId = nanoid(32);

  await redis.hset(`session:${sessionId}`, {
    userId,
    createdAt: Date.now().toString(),
    ...metadata,
  });
  await redis.expire(`session:${sessionId}`, 86400);

  return sessionId;
}

// Destroy session on logout
export async function destroySession(sessionId: string) {
  await redis.del(`session:${sessionId}`);
}
```

💸 **Startup Cost Callout:** Session data is typically small (a few KB per user). 10,000 concurrent sessions at 5KB each is only 50MB of Redis memory. This is cheap — even the smallest managed Redis instance handles it easily.

**Session invalidation patterns:**

When a user logs out, destroy their session. When a user changes their password, destroy all their sessions (force re-authentication everywhere). When security requires it (compromised account), destroy sessions immediately.

```typescript
// Destroy all sessions for a user
async function invalidateAllUserSessions(userId: string) {
  const sessionKeys = await redis.keys(`session:*`);
  for (const key of sessionKeys) {
    const session = await redis.hgetall(key);
    if (session.userId === userId) {
      await redis.del(key);
    }
  }
}
```

This is O(n) in session count — fine for thousands of sessions, problematic at millions. For larger scale, maintain a secondary index: `user:${userId}:sessions` as a set of session IDs.

### 3. Rate Limiting with Sliding Window

Protect your API from abuse with rate limiting. The sliding window algorithm using sorted sets is both accurate and efficient.

```typescript
// Rate limiter: 100 requests per minute per user
export async function checkRateLimit(userId: string): Promise<boolean> {
  const key = `ratelimit:${userId}`;
  const now = Date.now();
  const windowMs = 60 * 1000; // 1 minute
  const maxRequests = 100;

  // Use a Redis transaction for atomicity
  const multi = redis.multi();

  // Remove entries older than the window
  multi.zremrangebyscore(key, '-inf', now - windowMs);

  // Add the current request
  multi.zadd(key, now, `${now}-${Math.random()}`);

  // Count requests in the window
  multi.zcard(key);

  // Set key expiry (cleanup)
  multi.expire(key, Math.ceil(windowMs / 1000) + 1);

  const results = await multi.exec();
  const requestCount = results[2][1] as number;

  return requestCount <= maxRequests;
}

// Usage in middleware
export async function rateLimitMiddleware(c, next) {
  const userId = c.get('userId') || c.req.header('X-Forwarded-For') || 'anonymous';

  const allowed = await checkRateLimit(userId);
  if (!allowed) {
    return c.json({ error: 'Rate limit exceeded' }, 429);
  }

  await next();
}
```

This sliding window approach is more accurate than a fixed window (no burst at window boundaries) and uses minimal memory (one sorted set entry per request, cleaned up automatically).

### 4. Simple Job Queues (BullMQ Preview)

Redis powers BullMQ, the job queue we'll use in Chapter 10. Here's a preview of how it works under the hood:

```typescript
// BullMQ uses Redis lists and sorted sets internally
// Simplified version of what's happening:

// Producer adds a job
const jobId = nanoid();
await redis.lpush('queue:emails:waiting', JSON.stringify({
  id: jobId,
  data: { to: 'user@example.com', template: 'welcome' },
  createdAt: Date.now(),
}));

// Worker picks up jobs
async function processJobs() {
  while (true) {
    // Blocking pop: wait for a job, then atomically move it to processing
    const job = await redis.brpoplpush('queue:emails:waiting', 'queue:emails:processing', 30);

    if (job) {
      const jobData = JSON.parse(job);

      try {
        await sendEmail(jobData.data);
        // Remove from processing on success
        await redis.lrem('queue:emails:processing', 1, job);
      } catch (error) {
        // Move to failed or retry queue
        await redis.lrem('queue:emails:processing', 1, job);
        await redis.lpush('queue:emails:failed', job);
      }
    }
  }
}
```

In practice, use BullMQ rather than implementing queue logic yourself. But understanding the underlying Redis operations helps you debug issues.

### Combining Data Structures

Real-world Redis usage often combines multiple data structures:

```typescript
// Leaderboard with additional data
// Sorted set for ranking, hash for user details

async function updateScore(userId: string, score: number) {
  const multi = redis.multi();

  // Update the leaderboard (sorted set)
  multi.zadd('leaderboard:weekly', score, userId);

  // Store additional user data (hash)
  multi.hset(`user:${userId}:stats`, {
    lastScore: score.toString(),
    updatedAt: Date.now().toString(),
  });

  await multi.exec();
}

async function getLeaderboard(limit: number = 10) {
  // Get top users with scores
  const topUsers = await redis.zrevrange('leaderboard:weekly', 0, limit - 1, 'WITHSCORES');

  // Fetch additional data for each user
  const result = [];
  for (let i = 0; i < topUsers.length; i += 2) {
    const userId = topUsers[i];
    const score = parseInt(topUsers[i + 1]);
    const stats = await redis.hgetall(`user:${userId}:stats`);
    result.push({ userId, score, ...stats });
  }

  return result;
}
```

## Cache Invalidation: The Actually Hard Part

Phil Karlton famously said there are only two hard things in computer science: cache invalidation and naming things. He wasn't wrong.

### TTL-Based Invalidation (Simple)

Set a TTL on every cached value. When it expires, the next request fetches fresh data.

```typescript
await redis.set('project:123', data, 'EX', 300); // Expires in 5 minutes
```

**Pros:** Simple, automatic, no coordination needed.
**Cons:** Data can be stale for up to TTL duration.

Use when: Data changes infrequently, staleness is acceptable for that TTL, or perfect consistency isn't required.

### Event-Based Invalidation (More Complex)

Invalidate the cache when the underlying data changes.

```typescript
// When a project is updated, invalidate its cache
export async function updateProject(projectId: string, data: UpdateData) {
  // Update database
  await db.update(projects).set(data).where(eq(projects.id, projectId));

  // Invalidate cache
  await redis.del(`project:${projectId}`);
  await redis.del(`project:${projectId}:with-counts`);

  // Also invalidate any list caches that include this project
  const project = await db.query.projects.findFirst({
    where: eq(projects.id, projectId),
  });
  await redis.del(`workspace:${project.workspaceId}:projects`);
}
```

**Pros:** Data is fresh immediately after changes.
**Cons:** You must remember to invalidate everywhere. Missing one invalidation = stale data bugs.

Use when: Consistency matters, you have clear ownership of data mutations, and the invalidation patterns are manageable.

### Write-Through Caching (Most Consistent)

Update the cache whenever you update the database.

```typescript
export async function updateProject(projectId: string, data: UpdateData) {
  // Update database
  const [updated] = await db.update(projects)
    .set(data)
    .where(eq(projects.id, projectId))
    .returning();

  // Write to cache
  await redis.set(`project:${projectId}`, JSON.stringify(updated), 'EX', 300);

  return updated;
}
```

**Pros:** Cache is always consistent with the latest write.
**Cons:** More writes, and you still need to handle list invalidation.

### The Invalidation Trap

The most dangerous caching bugs happen when you forget to invalidate:

```typescript
// User A updates their name
await updateUser('user-123', { name: 'Alice Updated' });

// User B loads a project list that shows user names
// The cache for this list was not invalidated
// User B sees the old name "Alice Original"
```

The cache key `project:list:workspace-456` wasn't invalidated when user 123's name changed, because the code that updates users doesn't know about the project list cache.

**Strategies to avoid this:**

1. **Keep cache scope narrow.** Don't cache derived/denormalized data. Cache `user:123` and `project:456` separately, and join them in the application. Then invalidating user data doesn't affect project caches.

2. **Use cache tags.** Some caching libraries support tagging cache entries. Tag `project:list:workspace-456` with both "workspace-456" and all the user IDs it contains. Invalidate by tag.

3. **Accept bounded staleness.** If user names can be 5 minutes stale in project lists, use TTL-only invalidation. This is often the pragmatic choice.

4. **Document cache dependencies.** If you must cache denormalized data, document which caches need invalidation when which entities change. Review during code review.

🔒 **Security Callout:** Cache bugs can cause data leakage. If you cache user-specific data under the wrong key, or forget to scope cache keys by workspace/tenant, one user might see another's data. Always include user/workspace identifiers in cache keys.

### When Each Strategy Is Right

| Strategy | Use When |
|----------|----------|
| TTL-only | Data changes rarely, staleness of X minutes is acceptable |
| Event-based | Clear mutation paths, consistency matters, small invalidation surface |
| Write-through | High read volume, data changes through a single service |
| No caching | Data changes constantly, staleness causes real problems |

### Cache Stampede

A subtle problem: what happens when a popular cache key expires and 1,000 concurrent requests all hit the database at once?

```
T0: Cache expires
T0: Request 1 checks cache -> miss -> queries DB
T0: Request 2 checks cache -> miss -> queries DB
T0: Request 3 checks cache -> miss -> queries DB
... (hundreds more)
T0.1s: All requests hit DB simultaneously -> DB overloaded
```

**Solution 1: Probabilistic early expiration**

```typescript
async function getCachedWithProbabilisticRefresh(key: string, ttl: number) {
  const cached = await redis.get(key);
  const keyTTL = await redis.ttl(key);

  // If TTL is low, probabilistically refresh early
  if (cached && keyTTL > 0 && keyTTL < ttl * 0.1) {
    // 10% chance to refresh if < 10% TTL remaining
    if (Math.random() < 0.1) {
      // Refresh in background, return stale data now
      refreshCache(key).catch(console.error);
    }
  }

  return cached;
}
```

**Solution 2: Lock on cache miss**

```typescript
async function getCachedWithLock(key: string, fetchFn: () => Promise<any>) {
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached);

  const lockKey = `lock:${key}`;
  const acquired = await redis.set(lockKey, '1', 'NX', 'EX', 10); // Lock for 10s

  if (!acquired) {
    // Another request is fetching, wait a bit and check cache again
    await new Promise(r => setTimeout(r, 100));
    const retryCache = await redis.get(key);
    if (retryCache) return JSON.parse(retryCache);
    // Still no cache, fetch anyway (fallback)
  }

  try {
    const data = await fetchFn();
    await redis.set(key, JSON.stringify(data), 'EX', 300);
    return data;
  } finally {
    if (acquired) await redis.del(lockKey);
  }
}
```

For most applications, simple TTL-based caching is sufficient. Add stampede protection when you have genuinely hot keys with known expiration patterns.

## When NOT to Cache

Caching adds complexity. Before adding it, ask:

**Is the query already optimized?**

A query that takes 200ms might take 5ms with the right index. Fix the query first.

```typescript
// Before: 200ms (no index)
SELECT * FROM tasks WHERE workspace_id = 'x' ORDER BY created_at;

// After: 5ms (with index)
CREATE INDEX idx_tasks_workspace_created ON tasks (workspace_id, created_at);
SELECT * FROM tasks WHERE workspace_id = 'x' ORDER BY created_at;
```

At 5ms, do you need a cache? Maybe not. The database is fast enough.

**Is the data actually hot?**

If an endpoint gets 10 requests per day, caching adds no value. The overhead of managing the cache exceeds the benefit.

Calculate: `(requests per second) × (cache hit rate) × (time saved per hit) > (complexity cost)`

For 10 requests/day at 90% hit rate saving 100ms: `0.0001 × 0.9 × 0.1 = 0.000009 seconds saved per second`. Not worth it.

**Is staleness acceptable?**

Some data cannot be stale:
- Account balances
- Inventory counts
- Permission checks (can user X access resource Y?)

If showing stale data causes business problems or security issues, either don't cache it or use write-through with careful invalidation.

**Can you tolerate cache failure?**

If Redis goes down, what happens?
- Good: App falls back to database, gets slower but works
- Bad: App crashes because it can't find data in cache

Always implement cache-aside with fallback:

```typescript
async function getData(id: string) {
  try {
    const cached = await redis.get(`data:${id}`);
    if (cached) return JSON.parse(cached);
  } catch (error) {
    // Redis is down, log and continue
    console.warn('Redis unavailable, falling back to database');
  }

  // Fetch from database (works even if Redis is down)
  const data = await db.query.things.findFirst({ where: eq(things.id, id) });

  try {
    await redis.set(`data:${id}`, JSON.stringify(data), 'EX', 300);
  } catch (error) {
    // Redis still down, continue without caching
  }

  return data;
}
```

💸 **Startup Cost Callout:** Redis pricing is based on memory. At $6/GB/month on ElastiCache, a 1GB cache is $6/month — trivial. But if you cache everything "just in case" and end up with 50GB, that's $300/month for something that might not be necessary. Cache intentionally.

## Redis in Docker Compose and Production

### Local Development

```yaml
# docker-compose.yml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    volumes:
      - redis_data:/data

volumes:
  redis_data:
```

Connect from your application:

```typescript
// src/lib/redis.ts
import Redis from 'ioredis';

export const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

redis.on('error', (error) => {
  console.error('Redis connection error:', error);
});
```

### Production Considerations

**Use a managed service:** AWS ElastiCache, Upstash, or Redis Cloud. Don't run Redis yourself in production — the operational overhead isn't worth it for a startup.

**Configure memory limits:** Redis is in-memory. If it runs out of RAM, it either crashes or starts evicting data. Set `maxmemory` and `maxmemory-policy`:

- `volatile-lru` — Evict least recently used keys that have TTL
- `allkeys-lru` — Evict least recently used keys (any key)
- `noeviction` — Return errors when memory limit reached

**Consider persistence needs:** By default, Redis data is ephemeral. For caching, that's fine — if Redis restarts, caches warm up again. For session storage, you might want persistence (`appendonly yes` or RDB snapshots). For job queues, persistence is usually required.

### Redis Client Best Practices

**Use connection pooling** (ioredis handles this by default):

```typescript
import Redis from 'ioredis';

// Single client, reuse across requests
export const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  maxRetriesPerRequest: 3,
  retryDelayOnFailover: 100,
});

// Handle connection errors
redis.on('error', (err) => console.error('Redis Client Error', err));
redis.on('connect', () => console.log('Redis Client Connected'));
```

**Use pipelining for multiple operations:**

```typescript
// Instead of 5 round trips:
const val1 = await redis.get('key1');
const val2 = await redis.get('key2');
// ...

// Use pipeline: 1 round trip
const pipeline = redis.pipeline();
pipeline.get('key1');
pipeline.get('key2');
pipeline.get('key3');
pipeline.get('key4');
pipeline.get('key5');
const results = await pipeline.exec();
```

**Use MULTI/EXEC for atomic operations:**

```typescript
// These operations either all succeed or all fail
const multi = redis.multi();
multi.incr('counter');
multi.expire('counter', 3600);
multi.sadd('active-users', 'user-123');
await multi.exec();
```

## The Taste Test

**Scenario 1:** A query takes 50ms. Someone proposes adding caching to "improve performance."

*Your instinct should be:* 50ms is already fast. Caching adds complexity. Unless this endpoint is called thousands of times per second, the database can handle it. Measure whether caching actually helps before adding it.

**Scenario 2:** You see this caching pattern:

```typescript
const data = await cache.get(key);
if (!data) {
  const result = await expensiveQuery();
  await cache.set(key, result);
  return result;
}
// Missing: what if expensiveQuery() returns null/empty?
```

*Your instinct should be:* This doesn't handle cache miss vs "legitimately empty." If `expensiveQuery()` returns `null`, the cache isn't set, so every request re-runs the expensive query. Cache the absence too:

```typescript
const cached = await cache.get(key);
if (cached !== null) {
  return cached === 'null' ? null : JSON.parse(cached);
}
const result = await expensiveQuery();
await cache.set(key, result === null ? 'null' : JSON.stringify(result), 'EX', 300);
return result;
```

**Scenario 3:** A user reports seeing another user's data briefly. Investigation shows the cache key didn't include the user ID.

*Your instinct should be:* This is a security bug. Cache keys must include all scoping identifiers. `task:${taskId}` is wrong if tasks are workspace-scoped; it should be `workspace:${workspaceId}:task:${taskId}`. Review all cache keys for similar issues.

**Scenario 4:** Cache hit rates are 40%. The team proposes increasing TTL from 5 minutes to 1 hour.

*Your instinct should be:* Longer TTL increases hit rate but increases staleness. Ask: why is the hit rate low? Is it because data changes frequently (longer TTL makes staleness worse), or because the cache is too small (increase Redis memory), or because each request is for different data (caching might not help)?

**Scenario 5:** Rate limiting is implemented but doesn't seem to be working — some users are exceeding limits.

*Your instinct should be:* Check the rate limit key. Is it based on user ID? IP address? If users share an IP (corporate proxy, VPN), they share the rate limit. If it's based on a session that can be regenerated, users can bypass limits by getting new sessions. Design rate limit keys based on what you're actually trying to limit.

## Practical Exercise

Implement caching for the project management API from Chapter 3.

**Requirements:**

1. Add Redis caching to these endpoints:
   - `GET /projects/:id` — Cache individual project data
   - `GET /workspaces/:id/projects` — Cache project list per workspace
   - `GET /projects/:id/tasks` — Cache task list per project

2. Implement cache invalidation:
   - Invalidate project cache when project is updated
   - Invalidate task list cache when task is created/updated/deleted
   - Invalidate workspace project list when project is created/deleted

3. Implement rate limiting:
   - 100 requests per minute per user
   - 1000 requests per minute per workspace

4. Add a `/debug/cache-stats` endpoint showing:
   - Number of keys per cache category
   - Memory usage
   - Hit/miss rates (if you implement tracking)

**Debugging Checklist:**

When caching isn't working as expected:

```bash
# Check if key exists
redis-cli EXISTS project:123

# Check TTL remaining
redis-cli TTL project:123

# See the actual value
redis-cli GET project:123

# Find all keys matching a pattern (careful in production - use SCAN instead)
redis-cli KEYS "project:*"

# Memory usage for a key
redis-cli MEMORY USAGE project:123

# Server stats
redis-cli INFO stats
```

**AI Integration Point:**

After implementing caching, ask Claude to review your cache invalidation strategy:

```
Here's my caching implementation for a project management API:

[paste your code]

Analyze this for:
1. Cache consistency issues — are there scenarios where stale data is served?
2. Missing invalidation — when data changes, which caches need to be invalidated?
3. Security issues — could one user see another's cached data?
4. Performance issues — am I caching too aggressively or not aggressively enough?
```

**Acceptance Criteria:**
- Cache hit rate > 80% for repeated requests
- Cache invalidation works: after update, next request gets fresh data
- Rate limiting rejects requests over the limit
- Application works (slower) if Redis is unavailable
- No security issues with cache key scoping

## Checkpoint

After completing this chapter and the exercise, you should be able to agree with these statements:

- [ ] I understand the main Redis data structures and when to use each
- [ ] I can implement cache-aside pattern with proper TTL and error handling
- [ ] I know the three invalidation strategies (TTL, event-based, write-through) and when each is appropriate
- [ ] I can implement sliding window rate limiting with Redis sorted sets
- [ ] I have a decision framework for whether caching will actually help in a given situation
- [ ] I can identify cache invalidation bugs and security issues in cache key design
- [ ] I can set up Redis locally with Docker Compose and connect from Node.js
- [ ] I understand that caching adds complexity and should be a deliberate choice, not a default
- [ ] I know how to debug cache issues: inspect keys, check TTLs, verify hit/miss rates
- [ ] I can explain the difference between cache-aside, write-through, and read-through caching patterns
- [ ] I understand cache stampede and can implement solutions when needed
- [ ] I can use Redis pipelines and transactions for efficient multi-operation scenarios
