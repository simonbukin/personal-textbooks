# Studying Real-World Architectures

## Why This Matters

Theory gets you frameworks. Practice gets you intuition. The fastest path to good architectural instincts is studying what worked (and didn't) for real companies.

This chapter examines how actual systems were built, why they made certain choices, and what you can learn from their decisions. The goal isn't to copy their architecture — it's to understand the reasoning so you can apply similar thinking to your own constraints.

## How to Learn From Case Studies

When studying a company's architecture:

1. **Understand the constraints.** What scale were they operating at? What was their team size? What were their non-negotiables?

2. **Find the key decisions.** Every architecture has 2-3 pivotal choices that shaped everything else.

3. **Look for the trade-offs.** What did they give up to get what they needed?

4. **Consider your context.** Would the same choice make sense for you?

## Stripe: Building for Reliability

Stripe processes billions of dollars in payments. Downtime means merchants can't accept money. Their architecture reflects this constraint.

### Key Decisions

**1. Request isolation**
Every API request is isolated. If processing one request causes an error, it doesn't affect other requests. No shared state that could cascade failures.

**2. Idempotency everywhere**
Payment operations are inherently dangerous to retry. Stripe's APIs use idempotency keys to make retries safe:

```http
POST /v1/charges HTTP/1.1
Idempotency-Key: unique-request-id-12345

{
  "amount": 1000,
  "currency": "usd"
}
```

The same idempotency key always returns the same result. Network failures don't create duplicate charges.

**3. Synchronous writes, asynchronous reads**
Critical operations (charge a card) are synchronous — the API returns when the operation is durably complete. Non-critical operations (analytics, webhooks) are asynchronous.

### What You Can Apply

Even without Stripe's scale, idempotency keys are valuable for any operation that's dangerous to duplicate. Implement them for:
- Payment processing
- Email sending
- Resource creation with side effects
- Webhook delivery

```typescript
// Simple idempotency implementation
async function processWithIdempotency(
  key: string,
  operation: () => Promise<Result>
): Promise<Result> {
  // Check if we've seen this key
  const existing = await db.query.idempotencyKeys.findFirst({
    where: eq(idempotencyKeys.key, key)
  })

  if (existing) {
    return JSON.parse(existing.response)
  }

  // Process the operation
  const result = await operation()

  // Store the result
  await db.insert(idempotencyKeys).values({
    key,
    response: JSON.stringify(result),
    createdAt: new Date(),
  })

  return result
}
```

## Slack: Real-Time at Scale

Slack delivers messages to millions of concurrent users in real-time. Their architecture balances low latency with durability.

### Key Decisions

**1. Separate read and write paths**
Messages go to a durable store (MySQL) AND to the real-time system (their custom message router). The paths are independent — slow writes don't block real-time delivery.

**2. Channel-based partitioning**
Users connect to edge servers. Each channel (conversation) is assigned to a specific message server. This allows horizontal scaling — more channels means more servers, not larger servers.

**3. Optimistic delivery, eventual consistency**
Messages appear instantly in the UI before confirmation. If delivery fails, the UI updates to show the failure. This feels faster than waiting for acknowledgment.

### What You Can Apply

For real-time features:

```typescript
// Optimistic delivery pattern
async function sendMessage(message: Message) {
  // 1. Send to real-time immediately (optimistic)
  await pubsub.publish(`channel:${message.channelId}`, {
    type: 'message',
    data: message,
    status: 'sending'
  })

  try {
    // 2. Persist durably
    await db.insert(messages).values(message)

    // 3. Confirm delivery
    await pubsub.publish(`channel:${message.channelId}`, {
      type: 'message_confirmed',
      messageId: message.id
    })
  } catch (error) {
    // 4. Notify of failure
    await pubsub.publish(`channel:${message.channelId}`, {
      type: 'message_failed',
      messageId: message.id,
      error: error.message
    })
  }
}
```

## GitHub: Git at Scale

GitHub hosts millions of repositories. Their challenge: storing and serving Git data efficiently while supporting the full Git protocol.

### Key Decisions

**1. Git's distributed nature as an advantage**
Git repositories are self-contained. This allows geographic distribution — repositories can live on different servers, even in different regions.

**2. Packfile storage optimization**
Git stores objects in packfiles. GitHub extends this with custom storage layers that deduplicate common objects across repositories (forks share base objects).

**3. Read replicas for heavy operations**
Operations like `git clone` are read-heavy and expensive. Read replicas handle this load while writes go to primary servers.

### What You Can Apply

If you store large files or have heavy read patterns:

```typescript
// Route reads vs writes to different backends
async function handleRepoRequest(req: Request) {
  const isRead = ['GET', 'HEAD'].includes(req.method) ||
                 req.path.includes('/git-upload-pack')

  const backend = isRead
    ? getReadReplica(req.params.repo)
    : getPrimary(req.params.repo)

  return proxy(req, backend)
}
```

## Linear: Sync Engine Architecture

Linear is an issue tracker known for its speed. Their architecture prioritizes perceived performance through aggressive syncing.

### Key Decisions

**1. Local-first data**
The desktop and mobile apps maintain a local database (SQLite). UI renders from local data, not network requests. Operations are instant.

**2. Sync, don't fetch**
Changes sync bidirectionally between client and server. The client doesn't make API calls for data — it receives sync updates.

**3. Conflict resolution built-in**
With multiple clients editing, conflicts are inevitable. Linear uses CRDTs (Conflict-free Replicated Data Types) for automatic conflict resolution.

### What You Can Apply

Even without full local-first architecture, you can apply these principles:

```typescript
// Optimistic updates with background sync
const useTask = (taskId: string) => {
  const [task, setTask] = useState(cache.get(taskId))

  const updateTask = async (updates: Partial<Task>) => {
    // 1. Update local state immediately
    const optimistic = { ...task, ...updates }
    setTask(optimistic)
    cache.set(taskId, optimistic)

    try {
      // 2. Sync to server
      const confirmed = await api.updateTask(taskId, updates)
      cache.set(taskId, confirmed)
      setTask(confirmed)
    } catch (error) {
      // 3. Revert on failure
      cache.set(taskId, task)
      setTask(task)
      throw error
    }
  }

  return { task, updateTask }
}
```

## Discord: Scaling Elixir

Discord handles millions of concurrent voice and text connections. They chose Elixir/Erlang for its concurrency model.

### Key Decisions

**1. Process-per-user**
Each connected user is an Erlang process. Processes are lightweight (2KB each) and isolated. One misbehaving user can't crash others.

**2. Guild-based sharding**
Servers (Guilds) are the unit of sharding. Each Guild lives on specific nodes. Moving a Guild moves all its users.

**3. Ring architecture for consistency**
Discord uses consistent hashing to route requests to the right node. Nodes form a ring, and failures cause minimal redistribution.

### What You Can Apply

You probably won't build in Elixir, but the principles transfer:

```typescript
// Process isolation in Node.js using worker threads
import { Worker } from 'worker_threads'

class IsolatedProcessor {
  private workers: Worker[] = []

  async process(data: any) {
    const worker = new Worker('./processor.js', {
      workerData: data
    })

    return new Promise((resolve, reject) => {
      worker.on('message', resolve)
      worker.on('error', reject)
      worker.on('exit', (code) => {
        if (code !== 0) reject(new Error(`Worker exited with code ${code}`))
      })
    })
  }
}
```

## Architecture Patterns Across Companies

Common patterns emerge when you study enough systems:

### Pattern: CQRS (Command Query Responsibility Segregation)

Separate the write model from the read model. Writes go to a normalized database. Reads come from denormalized views.

**Used by:** LinkedIn, Twitter, many e-commerce systems

```typescript
// Write path: normalized
await db.insert(orders).values({
  id: orderId,
  userId: user.id,
  total: calculateTotal(items),
})
await db.insert(orderItems).values(
  items.map(item => ({ orderId, ...item }))
)

// Read path: denormalized view
const orderView = await db.query.orderViews.findFirst({
  where: eq(orderViews.id, orderId)
})
// Returns { id, user, items: [...], total, status } in one query
```

### Pattern: Event Sourcing

Store events, not state. Current state is computed by replaying events.

**Used by:** Banking systems, audit-heavy applications, Linear

```typescript
// Instead of UPDATE users SET balance = balance + 100
await db.insert(accountEvents).values({
  accountId: user.accountId,
  type: 'credit',
  amount: 100,
  metadata: { source: 'deposit', reference: depositId }
})

// Current balance = sum of all events
const balance = await db.execute(sql`
  SELECT SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END)
  FROM account_events
  WHERE account_id = ${accountId}
`)
```

### Pattern: Outbox Pattern

Write to a database and publish events atomically. Avoids distributed transaction issues.

**Used by:** Any system with events + database consistency requirements

```typescript
// In a single transaction:
await db.transaction(async (tx) => {
  // 1. Write the business data
  await tx.insert(orders).values(order)

  // 2. Write the event to an outbox table
  await tx.insert(eventOutbox).values({
    id: crypto.randomUUID(),
    eventType: 'order.created',
    payload: JSON.stringify(order),
    publishedAt: null
  })
})

// Separate worker publishes and marks as sent
async function publishOutboxEvents() {
  const pending = await db.query.eventOutbox.findMany({
    where: isNull(eventOutbox.publishedAt),
    limit: 100
  })

  for (const event of pending) {
    await kafka.send(event.eventType, event.payload)
    await db.update(eventOutbox)
      .set({ publishedAt: new Date() })
      .where(eq(eventOutbox.id, event.id))
  }
}
```

## When Patterns Don't Apply

These companies operate at scales most startups will never reach. Be careful about cargo-culting:

**Event sourcing** adds complexity. You need it for audit trails or temporal queries. You probably don't need it for a CRUD app.

**CQRS** makes sense when read and write patterns diverge significantly. If you're reading what you just wrote, it's overhead.

**Microservices** solve team coordination problems more than technical problems. A startup with 5 engineers doesn't need service boundaries.

🤔 **Taste Moment:** Study these architectures to understand the trade-offs, not to copy the solutions. The right architecture for a 10-person startup looks nothing like the right architecture for a 10,000-person company.

## The Taste Test

**Scenario 1:** A startup with 1,000 users wants to implement event sourcing "to be ready for scale."

*Premature.* Event sourcing adds complexity (snapshots, projection rebuilds, eventual consistency). Start with a regular database. Add event sourcing if/when you need audit trails or time-travel queries.

**Scenario 2:** A team implements CQRS with separate databases for reads and writes. They have one developer and ship one feature per month.

*Overengineered.* CQRS is for when read and write patterns differ significantly AND you have the team to maintain two data models. One developer should use one database.

**Scenario 3:** A chat application stores messages in Kafka and reads them back from Kafka.

*Misuse of Kafka.* Kafka is for event streaming between services, not as a primary data store. Store messages in a database, use Kafka for cross-service events.

**Scenario 4:** An e-commerce site uses optimistic UI updates for the cart but waits for confirmation on checkout.

*Good balance.* Optimistic updates where failures are recoverable, synchronous confirmation where money is involved. Matches user expectations.

## Practical Exercise

Research and document the architecture of a product you use daily:

**Requirements:**
1. Choose a product (Notion, Figma, Spotify, etc.)
2. Find their engineering blog, conference talks, or technical posts
3. Document:
   - What's the core technical challenge for this product?
   - What 2-3 key architectural decisions did they make?
   - What trade-offs did each decision involve?
   - What could you apply to your own projects?

**Deliverable:** A 1-page architecture summary

**⚡ AI Shortcut:**

Have Claude help you find relevant resources:

```
I want to understand how [Product] works architecturally.
Find me their engineering blog posts, conference talks,
or technical writeups about their infrastructure.

Focus on:
- Database and storage choices
- Real-time features (if any)
- Scaling challenges they've discussed
```

Then read the primary sources yourself — don't rely on AI summaries for technical architecture.

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can identify key architectural decisions in systems I study
- [ ] I understand when idempotency, CQRS, and event sourcing are appropriate
- [ ] I can distinguish patterns that apply to my scale from those that don't
- [ ] I know how to research a company's technical architecture
- [ ] I can articulate trade-offs between different architectural approaches

Learning from others' mistakes is cheaper than making your own. Study widely, apply selectively.
