# Design Pattern Drills

## Why This Matters

System design is a skill, and skills improve with practice. This chapter works through common design exercises — not to prepare you for interviews, but to build the mental muscles for thinking through systems.

Each exercise follows a pattern: understand the requirements, identify the core challenges, design a solution, and examine the trade-offs. By the end, you'll have a framework for approaching any system design problem.

## How to Use These Drills

For each exercise:

1. **Read the requirements** and think through your approach before reading the solution
2. **Sketch a diagram** on paper or whiteboard
3. **Identify the hardest part** — what makes this problem non-trivial?
4. **Compare with the solution** and note where your thinking differed

The solutions presented are not "the answer" — they're one reasonable approach with clear trade-offs. Your approach might be equally valid.

## Exercise 1: URL Shortener

### Requirements

Build a service that:
- Accepts a long URL and returns a short URL (e.g., `sho.rt/abc123`)
- Redirects short URLs to their original destination
- Tracks click analytics (total clicks, clicks per day)
- Supports 100M URLs with 1B clicks per month

### The Core Challenge

Two problems matter here: **ID generation** and **read scalability**.

### Design

```
┌─────────────────────────────────────────────────────────────┐
│                      Load Balancer                          │
└────────────────────────────┬────────────────────────────────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
       ┌─────────┐      ┌─────────┐      ┌─────────┐
       │ API     │      │ API     │      │ API     │
       │ Server  │      │ Server  │      │ Server  │
       └────┬────┘      └────┬────┘      └────┬────┘
            │                │                │
            └────────────────┼────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
    ┌─────────┐        ┌──────────┐        ┌─────────┐
    │  Redis  │        │ Postgres │        │  Kafka  │
    │ (cache) │        │ (source) │        │ (clicks)│
    └─────────┘        └──────────┘        └─────────┘
```

**Schema:**
```sql
create table urls (
  id bigint primary key,
  short_code varchar(10) unique not null,
  original_url text not null,
  user_id uuid references users(id),
  created_at timestamptz default now()
);

create index idx_urls_short_code on urls(short_code);

-- Analytics in a separate table, async populated
create table url_clicks (
  url_id bigint references urls(id),
  clicked_at timestamptz not null,
  country varchar(2),
  referrer text
) partition by range (clicked_at);
```

**Short code generation:**
```typescript
// Generate short codes from auto-increment ID using base62
const ALPHABET = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

function toBase62(num: number): string {
  let result = ''
  while (num > 0) {
    result = ALPHABET[num % 62] + result
    num = Math.floor(num / 62)
  }
  return result || '0'
}

// ID 1000000 → "4c92" (4 chars)
// ID 56800235584 → "ZZZZZZ" (6 chars, ~57B URLs)
```

**Request flow (write):**
1. Validate URL
2. Insert row, get auto-increment ID
3. Generate short code from ID
4. Update row with short code
5. Return short URL

**Request flow (read):**
1. Check Redis cache for short code
2. If miss, query Postgres
3. Populate cache (TTL 24h)
4. Publish click event to Kafka
5. Return redirect

**Analytics processing:**
Kafka consumer batches clicks and inserts to `url_clicks` every minute. Separate from the hot path.

### Trade-offs

- **Auto-increment vs UUID:** Auto-increment is predictable (attacker could enumerate URLs). Add a random suffix or use a PRNG with a secret seed if this matters.
- **Sync vs async analytics:** Async adds complexity but keeps redirects fast. 10ms vs 50ms matters when you serve 1B clicks.
- **Redis cache:** Essential for read-heavy workload. Without it, you'd need many Postgres read replicas.

---

## Exercise 2: Chat Application

### Requirements

Build a chat service that:
- Supports 1-on-1 and group chats (up to 100 members)
- Messages delivered in real-time
- Offline users receive messages when they reconnect
- Message history persisted indefinitely
- Typing indicators

### The Core Challenge

**Real-time delivery at scale.** You need to know which server each user is connected to and route messages there.

### Design

```
┌──────────────────────────────────────────────────────────────┐
│                      WebSocket Gateway                        │
│   (routes connections to correct chat server)                 │
└──────────────────────────┬───────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
    ┌──────────┐      ┌──────────┐      ┌──────────┐
    │  Chat    │      │  Chat    │      │  Chat    │
    │  Server  │◄────►│  Server  │◄────►│  Server  │
    └────┬─────┘      └────┬─────┘      └────┬─────┘
         │                 │                 │
         └─────────────────┼─────────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         ┌─────────┐  ┌─────────┐  ┌──────────┐
         │  Redis  │  │Postgres │  │   S3     │
         │ (pub/sub│  │(history)│  │ (media)  │
         │ + state)│  │         │  │          │
         └─────────┘  └─────────┘  └──────────┘
```

**Connection management:**
```typescript
// Track which server each user is connected to
// Redis hash: user_connections -> { user_id: server_id }

async function handleConnection(userId: string, serverId: string) {
  await redis.hset('user_connections', userId, serverId)
  // Subscribe to user's channel for cross-server messages
  await redis.subscribe(`user:${userId}`)
}

async function handleDisconnect(userId: string) {
  await redis.hdel('user_connections', userId)
  await redis.unsubscribe(`user:${userId}`)
}
```

**Message delivery:**
```typescript
async function sendMessage(message: Message) {
  // 1. Persist to database (source of truth)
  await db.insert(messages).values(message)

  // 2. Get all members of the chat
  const members = await db.query.chatMembers.findMany({
    where: eq(chatMembers.chatId, message.chatId)
  })

  // 3. Find connected members and their servers
  const connections = await redis.hmget(
    'user_connections',
    members.map(m => m.userId)
  )

  // 4. Publish to each connected user's channel
  for (const [i, serverId] of connections.entries()) {
    if (serverId) {
      await redis.publish(`user:${members[i].userId}`, JSON.stringify(message))
    }
  }

  // 5. Queue push notifications for offline users
  const offlineMembers = members.filter((_, i) => !connections[i])
  if (offlineMembers.length > 0) {
    await pushNotificationQueue.add('send', {
      userIds: offlineMembers.map(m => m.userId),
      message: message.preview,
    })
  }
}
```

**Typing indicators:**
```typescript
// Ephemeral, don't persist
async function sendTypingIndicator(chatId: string, userId: string) {
  // Publish directly to chat channel, no database
  await redis.publish(`chat:${chatId}:typing`, JSON.stringify({
    userId,
    timestamp: Date.now(),
  }))
}
// Recipients ignore typing events older than 3 seconds
```

### Trade-offs

- **Redis Pub/Sub vs dedicated message broker:** Redis is simpler. Kafka would be overkill here since messages aren't replayed — either they're delivered live or they come from the database on reconnect.
- **Server-assigned chat servers vs sticky sessions:** Server-assigned is more flexible but requires pub/sub between servers. Sticky sessions are simpler but complicate scaling.
- **Typing indicators ephemeral:** No persistence means lost typing events on server restart. Acceptable for typing indicators, not for messages.

---

## Exercise 3: File Upload Service

### Requirements

Build a service that:
- Accepts file uploads up to 5GB
- Supports resumable uploads (network failures don't lose progress)
- Generates thumbnails for images
- Scans files for malware
- Works with 100K uploads per day

### The Core Challenge

**Large file handling without blocking.** You can't hold a 5GB file in memory or process it synchronously.

### Design

```
┌────────────────────────────────────────────────────────────────┐
│                           Client                                │
│   1. Request upload URL                                         │
│   2. Upload directly to S3 (multipart)                          │
│   3. Notify API of completion                                   │
└──────────────────────────────┬─────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────┐
│                         API Server                              │
│   - Generate presigned URLs                                     │
│   - Track upload state                                          │
│   - Trigger processing                                          │
└───────────────────────────────┬────────────────────────────────┘
                                │
         ┌──────────────────────┼───────────────────────┐
         ▼                      ▼                       ▼
    ┌─────────┐           ┌──────────┐           ┌──────────┐
    │   S3    │           │ Postgres │           │ BullMQ   │
    │ (files) │           │ (state)  │           │ (jobs)   │
    └─────────┘           └──────────┘           └──────────┘
                                                       │
                               ┌───────────────────────┼─────────┐
                               ▼                       ▼         ▼
                         ┌──────────┐           ┌──────────┐  ┌──────────┐
                         │Thumbnail │           │ Malware  │  │ Metadata │
                         │ Worker   │           │ Scanner  │  │ Extractor│
                         └──────────┘           └──────────┘  └──────────┘
```

**Presigned URL flow:**
```typescript
// Generate multipart upload
app.post('/api/uploads', async (c) => {
  const { filename, contentType, size } = await c.req.json()

  // Create upload record
  const upload = await db.insert(uploads).values({
    id: crypto.randomUUID(),
    filename,
    contentType,
    size,
    status: 'pending',
    userId: c.get('user').id,
  }).returning()

  // Initiate S3 multipart upload
  const { UploadId } = await s3.send(new CreateMultipartUploadCommand({
    Bucket: BUCKET,
    Key: `uploads/${upload[0].id}/${filename}`,
    ContentType: contentType,
  }))

  // Generate presigned URLs for each part (100MB chunks)
  const partCount = Math.ceil(size / (100 * 1024 * 1024))
  const parts = await Promise.all(
    Array.from({ length: partCount }, (_, i) =>
      getSignedUrl(s3, new UploadPartCommand({
        Bucket: BUCKET,
        Key: `uploads/${upload[0].id}/${filename}`,
        UploadId,
        PartNumber: i + 1,
      }), { expiresIn: 3600 })
    )
  )

  return c.json({
    uploadId: upload[0].id,
    s3UploadId: UploadId,
    parts: parts.map((url, i) => ({ partNumber: i + 1, url })),
  })
})

// Client uploads parts directly to S3, then notifies completion
app.post('/api/uploads/:id/complete', async (c) => {
  const { s3UploadId, parts } = await c.req.json()

  // Complete multipart upload
  await s3.send(new CompleteMultipartUploadCommand({
    Bucket: BUCKET,
    Key: `uploads/${c.req.param('id')}/${filename}`,
    UploadId: s3UploadId,
    MultipartUpload: { Parts: parts },
  }))

  // Update status and trigger processing
  await db.update(uploads)
    .set({ status: 'uploaded' })
    .where(eq(uploads.id, c.req.param('id')))

  await processingQueue.add('process-upload', {
    uploadId: c.req.param('id'),
  })

  return c.json({ status: 'processing' })
})
```

**Processing pipeline:**
```typescript
// Worker processes uploads through stages
processingQueue.process('process-upload', async (job) => {
  const { uploadId } = job.data

  // Stage 1: Malware scan
  await updateStatus(uploadId, 'scanning')
  const scanResult = await scanFile(uploadId)
  if (scanResult.infected) {
    await updateStatus(uploadId, 'infected')
    await deleteFile(uploadId)
    return
  }

  // Stage 2: Generate thumbnail (if image/video)
  const upload = await getUpload(uploadId)
  if (isMedia(upload.contentType)) {
    await updateStatus(uploadId, 'generating-thumbnail')
    await generateThumbnail(uploadId)
  }

  // Stage 3: Extract metadata
  await updateStatus(uploadId, 'extracting-metadata')
  await extractMetadata(uploadId)

  // Complete
  await updateStatus(uploadId, 'ready')
})
```

### Trade-offs

- **Direct-to-S3 vs proxy through API:** Direct avoids memory pressure on API servers but requires CORS configuration and client-side multipart handling.
- **Sync vs async processing:** Async is necessary for large files but adds status polling complexity.
- **Malware scanning:** Third-party services (ClamAV, VirusTotal) add latency but are essential for user-generated content.

---

## Exercise 4: Notification System

### Requirements

Build a notification service that:
- Sends push notifications, emails, and SMS
- Supports user preferences (which channels for which event types)
- Handles 10M notifications per day
- Retries failed deliveries
- Provides delivery status tracking

### The Core Challenge

**Reliable delivery across unreliable channels.** Each notification channel has different failure modes, rate limits, and retry semantics.

### Design

```
┌──────────────────────────────────────────────────────────────┐
│                   Notification API                            │
│   - Accepts notification requests                             │
│   - Checks user preferences                                   │
│   - Routes to appropriate queues                              │
└───────────────────────────────┬──────────────────────────────┘
                                │
                                ▼
                          ┌──────────┐
                          │ Postgres │  (preferences, status)
                          └──────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         ▼                      ▼                      ▼
   ┌───────────┐          ┌───────────┐          ┌───────────┐
   │Push Queue │          │Email Queue│          │SMS Queue  │
   │(priority) │          │(batched)  │          │(rate-lim) │
   └─────┬─────┘          └─────┬─────┘          └─────┬─────┘
         │                      │                      │
         ▼                      ▼                      ▼
   ┌───────────┐          ┌───────────┐          ┌───────────┐
   │   FCM/    │          │  SendGrid │          │   Twilio  │
   │   APNS    │          │           │          │           │
   └───────────┘          └───────────┘          └───────────┘
```

**Notification routing:**
```typescript
interface NotificationRequest {
  userId: string
  type: 'comment' | 'mention' | 'reminder' | 'security'
  title: string
  body: string
  data?: Record<string, unknown>
}

async function sendNotification(req: NotificationRequest) {
  // Get user's preferences
  const prefs = await db.query.notificationPreferences.findFirst({
    where: eq(notificationPreferences.userId, req.userId)
  })

  // Determine which channels to use
  const channels = getChannelsForType(prefs, req.type)
  // e.g., 'security' might force all channels
  // 'comment' might be push-only if user disabled email

  // Create notification record
  const notification = await db.insert(notifications).values({
    id: crypto.randomUUID(),
    userId: req.userId,
    type: req.type,
    title: req.title,
    body: req.body,
    channels,
    status: 'pending',
  }).returning()

  // Queue for each channel
  const jobs = channels.map(channel => ({
    channel,
    notificationId: notification[0].id,
    ...req,
  }))

  await Promise.all([
    channels.includes('push') && pushQueue.add('send', jobs.find(j => j.channel === 'push')),
    channels.includes('email') && emailQueue.add('send', jobs.find(j => j.channel === 'email')),
    channels.includes('sms') && smsQueue.add('send', jobs.find(j => j.channel === 'sms')),
  ])

  return notification[0]
}
```

**Channel-specific workers:**
```typescript
// Push notifications — realtime, retry quickly
pushQueue.process('send', async (job) => {
  const { userId, title, body, data } = job.data

  const tokens = await db.query.pushTokens.findMany({
    where: eq(pushTokens.userId, userId)
  })

  const results = await Promise.allSettled(
    tokens.map(token =>
      sendPushNotification(token.token, { title, body, data })
    )
  )

  // Remove invalid tokens
  const invalidTokens = results
    .map((r, i) => r.status === 'rejected' && r.reason.code === 'INVALID_TOKEN' ? tokens[i].id : null)
    .filter(Boolean)

  if (invalidTokens.length > 0) {
    await db.delete(pushTokens).where(inArray(pushTokens.id, invalidTokens))
  }
})

// Email — batch-friendly, longer retry window
emailQueue.process('send', async (job) => {
  const { userId, title, body, notificationId } = job.data

  const user = await db.query.users.findFirst({
    where: eq(users.id, userId)
  })

  try {
    await sendGrid.send({
      to: user.email,
      subject: title,
      html: renderEmailTemplate(body),
    })
    await updateDeliveryStatus(notificationId, 'email', 'delivered')
  } catch (error) {
    if (error.code === 'RATE_LIMITED') {
      throw error  // BullMQ will retry
    }
    await updateDeliveryStatus(notificationId, 'email', 'failed')
  }
}, {
  limiter: { max: 100, duration: 1000 },  // SendGrid rate limit
})
```

### Trade-offs

- **Per-channel queues:** More complex but allows different retry/rate-limit logic per channel.
- **Preference checking at send time:** Adds latency but preferences are always up to date. Alternative: denormalize preferences into user events.
- **Delivery tracking:** Adds storage cost but essential for debugging delivery issues.

---

## Design Exercise Framework

Use this framework when approaching any design problem:

### 1. Clarify Requirements

- What are the core use cases?
- What's the expected scale (users, requests, data volume)?
- What's the acceptable latency?
- What consistency guarantees are needed?

### 2. Identify the Hard Parts

Every system has 2-3 genuinely difficult problems. Find them early:
- What's the bottleneck (CPU, memory, network, storage)?
- What's the failure mode?
- What's the consistency challenge?

### 3. Design the Core Flow

Sketch the happy path first:
- How does data enter the system?
- Where is it stored?
- How is it retrieved?

### 4. Add Robustness

- What happens when components fail?
- How do you handle spikes?
- How do you recover from data loss?

### 5. Consider Operations

- How do you deploy changes?
- How do you debug problems?
- How do you scale up?

## The Taste Test

**Scenario 1:** A design uses Redis as the primary data store for user profiles.

*Risky.* Redis is memory-bound and typically not configured for durability. Use Postgres as the source of truth, Redis as cache.

**Scenario 2:** A chat system sends every message through Kafka before delivering to users.

*Overengineered for chat.* Kafka adds latency and is designed for replay/durability. Chat messages need speed; they're replayed from the database, not the queue.

**Scenario 3:** A file upload system streams uploads through the API server to S3.

*Works but doesn't scale.* Large uploads tie up server resources. Presigned URLs let clients upload directly to S3.

**Scenario 4:** A notification system creates a separate job for each of 1M users receiving a broadcast message.

*Consider fanout strategies.* 1M jobs is expensive. For broadcasts, consider topic-based pub/sub or hierarchical fanout (queue per region → queue per shard).

## Practical Exercise

Design a **rate-limiting service** for your TaskFlow API:

**Requirements:**
- Rate limit by user and by IP address
- Different limits for different endpoints (100/min for reads, 10/min for writes)
- Return appropriate headers (X-RateLimit-Remaining, Retry-After)
- Handle 10K requests per second

**Deliverables:**
1. System diagram
2. Data model (how/where limits are stored)
3. Request flow (how limits are checked and updated)
4. Trade-off analysis (why you chose this approach)

**⚡ AI Shortcut:**

Have Claude challenge your design:

```
Here's my design for a rate limiting service:
[paste your design]

Act as a senior engineer reviewing this design. Identify:
1. Potential failure modes I haven't considered
2. Scalability bottlenecks
3. Edge cases in the rate limiting logic
4. Simpler alternatives I might have missed
```

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can break down a system design problem into core challenges
- [ ] I understand common patterns for URL shortening, real-time messaging, file uploads, and notifications
- [ ] I can identify trade-offs in architectural decisions
- [ ] I know when to use queues, caches, and direct database access
- [ ] I can articulate why a design decision is appropriate for given constraints

System design is pattern recognition plus trade-off analysis. The more patterns you've seen, the faster you can evaluate options and choose wisely.
