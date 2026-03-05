# Beyond Postgres: When and Why

## Why This Matters

Postgres is your default. The previous chapters made the case. But defaults have exceptions, and knowing when to reach for something else is part of developing taste.

The danger isn't using the wrong tool — it's using the wrong tool for the wrong reason. "MongoDB is webscale" is a meme for a reason. "Let's use Elasticsearch because search" without understanding the operational cost is how startups end up with fragile, complex systems that are impossible to debug.

This chapter isn't advocacy for adding more systems. It's a guide to recognizing when you've genuinely hit Postgres's limits, what the alternatives are, and what you're signing up for when you adopt them. The goal is to give you the judgment to push back on unnecessary complexity while recognizing when additional tools genuinely earn their place.

By the end, you'll have a decision framework for data infrastructure that will serve you through most of your career. You'll also be better equipped to have productive conversations with teammates who propose adding new data stores — whether to support good proposals with concrete reasoning or to redirect premature ones toward simpler solutions.

## The Cost of Adding a Data Store

Before we talk about specific technologies, internalize this: every new data store is operational overhead.

A new data store means:
- **Another thing to back up.** What's the backup strategy? How do you test restores?
- **Another thing to monitor.** What metrics matter? What alerts do you need?
- **Another thing to secure.** Network access, authentication, encryption at rest, encryption in transit.
- **Another thing to update.** Security patches, version upgrades, breaking changes.
- **Another thing to debug.** When something is slow, you have another suspect.
- **Another thing to explain.** New engineers need to understand why it exists.

For a 5-person startup, each additional system is a significant burden. For a 50-person company with dedicated infrastructure engineers, it's more manageable — but still has cost.

The bar for adding a data store should be high. Start with "can Postgres handle this?" and only move on when the answer is genuinely no. The burden of proof is on the new system, not on keeping things simple.

🤔 **Taste Moment:** When someone proposes adding a new data store, ask: "What specific problem does this solve that Postgres cannot?" If the answer is vague ("it's faster," "it's more scalable"), push for specifics. If the answer is specific ("we need to run vector similarity search over 10 million embeddings with <50ms latency"), you have something to evaluate.

## Document Stores (MongoDB)

MongoDB and similar document databases store JSON-like documents instead of rows in tables. Each document can have a different structure.

### The Real Use Case

Document stores shine when:

1. **Data is naturally document-shaped.** You read and write entire documents at once. You rarely need to query across documents or join data from different collections.

2. **Schema varies by instance.** Each document legitimately has different fields based on its type or configuration.

3. **Deep nesting is fundamental.** The data is hierarchical in a way that would require many tables and complex joins in a relational model.

**Good examples:**
- Form builder responses (each form has different fields)
- CMS content blocks (each block type has different properties)
- IoT device configurations (each device type has unique settings)
- Log entries (varying fields by event type)

**What this looks like:**

```javascript
// MongoDB: Form responses with varying structures
{
  _id: ObjectId("..."),
  formId: "contact-form",
  submittedAt: ISODate("2026-01-15T10:30:00Z"),
  responses: {
    name: "Alice",
    email: "alice@example.com",
    message: "Hello there"
  }
}

{
  _id: ObjectId("..."),
  formId: "job-application",
  submittedAt: ISODate("2026-01-15T11:45:00Z"),
  responses: {
    fullName: "Bob Smith",
    resumeUrl: "https://...",
    coverLetter: "...",
    yearsExperience: 5,
    skills: ["TypeScript", "React", "Node.js"]
  }
}
```

Each form submission has completely different fields. In Postgres, you'd need either a dynamic schema or JSONB. Document databases make this the natural path.

**CMS content blocks** are another classic example:

```javascript
// A page with different block types
{
  _id: ObjectId("..."),
  slug: "about-us",
  blocks: [
    { type: "hero", title: "About Us", backgroundImage: "..." },
    { type: "text", content: "We are a company that..." },
    { type: "team-grid", members: ["alice", "bob", "charlie"] },
    { type: "cta", buttonText: "Contact Us", link: "/contact" }
  ]
}
```

Each block type has different properties. The page structure is hierarchical. You always load and save entire pages. This is a genuine document database use case.

### The Anti-Pattern

Using MongoDB because you don't want to think about schemas:

```javascript
// ❌ This is not a good reason to use MongoDB
// Users collection with inconsistent structure
{ name: "Alice", email: "alice@example.com", created: "2026-01-15" }
{ name: "Bob", email_address: "bob@example.com", createdAt: new Date() }
{ userName: "Charlie", emailAddress: "charlie@example.com" }
```

Three documents, three different field names for the same concepts. This isn't flexibility — it's chaos. When you query for users by email, which field do you check?

Schema uncertainty is not a reason to use MongoDB. It's a reason to use Postgres with JSONB for the genuinely flexible parts and typed columns for the structured parts.

### Postgres JSONB as an Alternative

Most "document store" use cases work fine with Postgres JSONB:

```sql
-- Postgres: Same form responses use case
CREATE TABLE form_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id TEXT NOT NULL,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  responses JSONB NOT NULL
);

-- Index for querying by form
CREATE INDEX idx_submissions_form ON form_submissions (form_id);

-- Index into JSONB for specific fields
CREATE INDEX idx_submissions_email ON form_submissions ((responses->>'email'));

-- Query submissions with a specific response value
SELECT * FROM form_submissions
WHERE responses->>'email' = 'alice@example.com';
```

You get document flexibility in the `responses` column plus relational features (consistent `form_id`, proper timestamps, joins with forms table if needed).

### When MongoDB Actually Wins

Choose MongoDB when:
- You're storing millions of documents that are always accessed as complete units
- You never need to join data across collections
- You have strong operational expertise with MongoDB specifically
- The query patterns are simple (get by ID, query by indexed field)

Choose Postgres + JSONB when:
- You need some flexibility within a mostly-relational model
- You'll need to join this data with other tables
- You want one database to manage
- You're not sure yet (start with Postgres, migrate if needed)

### A Note on "Scaling"

You'll sometimes hear that MongoDB "scales better" than Postgres. This is a half-truth at best.

MongoDB's horizontal scaling story (sharding) is indeed more mature and built-in. But:

1. **Most startups don't need horizontal scaling.** A properly configured Postgres instance handles millions of rows easily. RDS read replicas handle read scaling. You're unlikely to hit Postgres's limits before your Series B.

2. **Horizontal scaling is complex regardless.** MongoDB sharding isn't free — you need to choose shard keys carefully, understand how queries hit shards, and deal with cross-shard operations. This complexity is similar to Postgres table partitioning.

3. **The "scale" you need is often vertical.** Bigger instance, better indexes, optimized queries. These work on both databases.

Don't choose a database for scaling problems you don't have. If you reach the point where Postgres genuinely can't handle your load, you'll have the engineering resources to address it.

## Search Engines (Elasticsearch, Typesense, Meilisearch)

### When Postgres Full-Text Search Isn't Enough

Before adding a search engine, make sure you've actually tried Postgres full-text search. Many teams assume they need Elasticsearch without testing what Postgres can do.

Postgres FTS handles:
- Basic search across text fields
- Stemming (finds "running" when you search "run")
- Ranking by relevance
- Phrase search
- Boosting by field (title matches count more than body matches)

That covers a lot. It breaks down when you need:

- **Typo tolerance.** User searches "managment" and should find "management."
- **Sophisticated relevance ranking.** Multiple factors (recency, popularity, exact match vs partial) combined.
- **Faceted search.** "Show me results, and also count how many in each category."
- **Search-as-you-type.** Sub-10ms responses as the user types.
- **Multi-language search.** Different stemming rules per language.

If your search feature is "search tasks by title," Postgres is fine. If your search feature is "search everything with typo tolerance, filters, and relevance ranking," you need a search engine.

### Choosing a Search Engine

**Elasticsearch** — The incumbent. Powerful, complex, resource-hungry. Requires operational expertise. Good if you have dedicated infrastructure engineers.

**Typesense** — Modern, simpler to operate, excellent typo tolerance. Great for startups. Less flexible than Elasticsearch for complex use cases.

**Meilisearch** — Similar to Typesense. Very fast, easy to set up. Limited advanced features.

For startups: start with Typesense or Meilisearch. They're simpler to operate and cover most use cases. Graduate to Elasticsearch if you hit their limits.

### The Sync Pattern

Postgres remains your source of truth. The search index is derived.

```typescript
// src/jobs/sync-search-index.ts
import { db } from '../db';
import { searchClient } from '../lib/search';

export async function syncTasksToSearch() {
  // Fetch tasks from Postgres
  const tasks = await db.query.tasks.findMany({
    where: eq(tasks.deletedAt, null),
    with: {
      project: true,
      assignee: true,
    },
  });

  // Transform for search
  const searchDocs = tasks.map((task) => ({
    id: task.id,
    title: task.title,
    description: task.description,
    projectName: task.project?.name,
    assigneeName: task.assignee?.name,
    status: task.status,
    createdAt: task.createdAt.getTime(),
  }));

  // Upsert to search index
  await searchClient.collections('tasks').documents().import(searchDocs, {
    action: 'upsert',
  });
}

// Run on task create/update/delete
// Or run periodically for eventual consistency
```

Event-driven sync (update index on every change) is more consistent. Batch sync (rebuild periodically) is simpler. Choose based on how stale your search results can be.

### Search Engine Operational Considerations

Adding a search engine means:

**Typesense/Meilisearch:**
- Simpler to operate (single binary, embedded storage)
- Memory-bound (index lives in RAM)
- Limited clustering (Typesense has it, Meilisearch is getting it)
- Managed options available (Typesense Cloud, Meilisearch Cloud)

**Elasticsearch:**
- Complex to operate (JVM tuning, cluster management)
- More flexible (custom analyzers, complex queries)
- Requires dedicated expertise
- AWS OpenSearch or Elastic Cloud as managed options

For a startup, the managed Typesense or Meilisearch options are usually the right choice. Pay the operational cost with money rather than engineering time.

💸 **Startup Cost Callout:** Self-hosted Elasticsearch typically needs at least 4GB RAM per node, and you want multiple nodes for reliability. That's ~$100-200/month minimum in cloud compute. Managed Elasticsearch starts around $80/month. Typesense Cloud starts at $30/month. Choose based on your needs, not on the "enterprise-grade" label.

## Blob Storage (S3 and Friends)

Files don't belong in your database. They belong in blob storage. The database stores metadata and references.

### The Pattern

```typescript
// Schema: file metadata in Postgres
export const attachments = pgTable('attachments', {
  id: uuid('id').primaryKey().defaultRandom(),
  taskId: uuid('task_id').references(() => tasks.id),
  filename: text('filename').notNull(),
  contentType: text('content_type').notNull(),
  sizeBytes: integer('size_bytes').notNull(),
  s3Key: text('s3_key').notNull(), // Reference to the actual file
  uploadedBy: uuid('uploaded_by').references(() => users.id),
  uploadedAt: timestamp('uploaded_at', { withTimezone: true }).defaultNow(),
});
```

```typescript
// Generate presigned URL for upload
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

export async function getUploadUrl(filename: string, contentType: string) {
  const key = `uploads/${nanoid()}/${filename}`;

  const command = new PutObjectCommand({
    Bucket: process.env.S3_BUCKET,
    Key: key,
    ContentType: contentType,
  });

  const uploadUrl = await getSignedUrl(s3Client, command, {
    expiresIn: 3600, // URL valid for 1 hour
  });

  return { uploadUrl, key };
}

// Generate presigned URL for download
export async function getDownloadUrl(key: string) {
  const command = new GetObjectCommand({
    Bucket: process.env.S3_BUCKET,
    Key: key,
  });

  return getSignedUrl(s3Client, command, {
    expiresIn: 3600,
  });
}
```

The frontend uploads directly to S3 using the presigned URL, bypassing your server entirely. This is more efficient and allows for large file uploads without server memory constraints.

### The Complete Upload Flow

Here's the full flow for file uploads:

```typescript
// 1. Frontend requests an upload URL
// POST /api/upload-url
app.post('/api/upload-url', async (c) => {
  const { filename, contentType, taskId } = await c.req.json();

  // Generate presigned URL
  const { uploadUrl, key } = await getUploadUrl(filename, contentType);

  // Create a pending attachment record
  const attachment = await db.insert(attachments).values({
    taskId,
    filename,
    contentType,
    s3Key: key,
    status: 'pending', // Will be 'complete' after upload
    uploadedBy: c.get('userId'),
  }).returning();

  return c.json({
    uploadUrl,
    attachmentId: attachment.id,
  });
});

// 2. Frontend uploads directly to S3 using the presigned URL
// (This happens in browser JavaScript, not your server)

// 3. Frontend confirms upload complete
// POST /api/upload-complete
app.post('/api/upload-complete', async (c) => {
  const { attachmentId, sizeBytes } = await c.req.json();

  // Optionally verify the file exists in S3
  // Update attachment status
  await db.update(attachments)
    .set({
      status: 'complete',
      sizeBytes,
      uploadedAt: new Date(),
    })
    .where(eq(attachments.id, attachmentId));

  return c.json({ success: true });
});
```

This three-step flow ensures your server never handles file bytes while maintaining a complete record of all uploads.

### S3 Alternatives

**Cloudflare R2** — S3-compatible API, no egress fees. If you're paying significant S3 egress costs, R2 can save money.

**MinIO** — Self-hosted S3-compatible storage. Useful for local development or when you can't use cloud storage.

**GCS / Azure Blob Storage** — Cloud-provider equivalents. Use them if you're in those ecosystems.

**Backblaze B2** — Budget option for archival storage. S3-compatible API, about 1/4 the cost of S3. Good for backups and infrequently accessed files.

For most cases, S3 or R2 is the right choice. The API is standardized; pick based on cost and existing infrastructure. Use MinIO locally for development to avoid S3 costs and latency during testing.

```yaml
# docker-compose.yml - MinIO for local development
services:
  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"
      - "9001:9001"  # Admin console
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - minio_data:/data

volumes:
  minio_data:
```

Configure your S3 client to use MinIO in development:

```typescript
const s3Client = new S3Client({
  endpoint: process.env.S3_ENDPOINT || 'http://localhost:9000',
  region: 'us-east-1', // MinIO requires a region, use any valid one
  credentials: {
    accessKeyId: process.env.S3_ACCESS_KEY || 'minioadmin',
    secretAccessKey: process.env.S3_SECRET_KEY || 'minioadmin',
  },
  forcePathStyle: true, // Required for MinIO
});
```

💸 **Startup Cost Callout:** S3 storage is cheap (~$0.023/GB/month). S3 egress is not (~$0.09/GB). If users frequently download large files, egress costs add up. Cloudflare R2 has no egress fees, making it attractive for download-heavy applications.

## Vector Storage for AI Features (pgvector)

AI features in 2026 often involve embeddings: converting text (or images, or audio) into vectors and finding similar items.

### What pgvector Does

pgvector is a Postgres extension that adds vector data types and similarity search operators.

```sql
-- Enable the extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Add an embedding column to tasks
ALTER TABLE tasks ADD COLUMN embedding vector(1536);  -- 1536 dimensions for OpenAI embeddings

-- Create an index for fast similarity search
CREATE INDEX ON tasks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

```typescript
// Store embeddings
async function saveTaskWithEmbedding(taskId: string, text: string) {
  const embedding = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: text,
  });

  await db.execute(sql`
    UPDATE tasks
    SET embedding = ${JSON.stringify(embedding.data[0].embedding)}::vector
    WHERE id = ${taskId}
  `);
}

// Find similar tasks
async function findSimilarTasks(taskId: string, limit: number = 5) {
  const results = await db.execute(sql`
    WITH target AS (
      SELECT embedding FROM tasks WHERE id = ${taskId}
    )
    SELECT t.id, t.title, t.embedding <=> target.embedding AS distance
    FROM tasks t, target
    WHERE t.id != ${taskId}
      AND t.embedding IS NOT NULL
    ORDER BY t.embedding <=> target.embedding
    LIMIT ${limit}
  `);

  return results;
}
```

The `<=>` operator is cosine distance. Lower is more similar.

### When to Use pgvector vs Dedicated Vector Databases

**Use pgvector when:**
- You have fewer than ~5 million vectors
- Query latency requirements are >50ms
- You want to keep everything in Postgres (simpler operations)
- You need to join vector results with other data

**Consider dedicated vector DBs (Pinecone, Weaviate, Qdrant) when:**
- You have tens of millions of vectors
- You need sub-10ms latency at scale
- You need advanced vector operations (filtering, hybrid search)
- You have dedicated infrastructure capacity

For most startups building AI features, pgvector is sufficient. It handles 1-5 million vectors comfortably, which covers most use cases. Graduate to a dedicated solution when you've proven you need it — and "proven" means actual benchmarks at your scale, not speculation about future needs.

### Vector Search Index Types

pgvector supports two index types:

**IVFFlat** — Inverted File Index. Divides vectors into clusters and searches the nearest clusters. Requires training on existing data. Faster to build, less accurate.

```sql
-- IVFFlat: specify the number of lists (clusters)
-- Rule of thumb: lists = sqrt(row_count) for up to 1M rows
CREATE INDEX ON tasks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

**HNSW** — Hierarchical Navigable Small World. Graph-based index. More accurate, uses more memory, slower to build.

```sql
-- HNSW: more accurate but more memory
CREATE INDEX ON tasks USING hnsw (embedding vector_cosine_ops);
```

For most applications, HNSW provides better recall (finding the true nearest neighbors). Start with HNSW. Switch to IVFFlat if memory becomes a constraint.

### Embedding Cost Considerations

Vector similarity search has two cost components:

1. **Embedding generation.** OpenAI's text-embedding-3-small costs about $0.02 per million tokens. A typical paragraph is ~100 tokens, so 10,000 documents cost about $2 to embed. Not expensive for most use cases.

2. **Storage and query.** Embeddings are large. A 1536-dimensional embedding (OpenAI's default) is about 6KB. 1 million embeddings = 6GB just for vectors. Plan accordingly.

Cache embeddings — if the text hasn't changed, don't regenerate the embedding.

## The Decision Framework

Here's the flowchart for data store decisions:

```
Start with Postgres
│
├─ Need caching or rate limiting?
│  └─ Add Redis
│
├─ Need file storage?
│  └─ Add S3 (or R2)
│
├─ Need full-text search beyond Postgres FTS?
│  └─ Add Typesense/Meilisearch (simple) or Elasticsearch (complex)
│
├─ Need vector similarity search?
│  └─ Use pgvector (start here)
│  │  └─ Need >5M vectors or <10ms latency?
│  │     └─ Consider Pinecone/Weaviate
│
├─ Have genuinely schema-less, document-oriented data?
│  └─ Consider MongoDB (but try Postgres JSONB first)
│
└─ Everything else?
   └─ Keep it in Postgres
```

This covers 95% of startup data infrastructure needs. The remaining 5% are edge cases you'll recognize when you hit them.

### What This Framework Doesn't Cover

Some data stores we deliberately excluded:

**Time-series databases (InfluxDB, TimescaleDB):** If you're building heavy analytics or IoT with millions of time-stamped events per day, time-series databases are optimized for this workload. But for typical application metrics and logs, Postgres with proper partitioning (or external observability tools) is usually sufficient.

**Graph databases (Neo4j):** If your core problem is graph traversal (social networks, recommendation engines, fraud detection), graph databases make sense. But "data has relationships" is not a reason to use a graph DB — relational databases handle relationships fine. Graph databases are for when relationship traversal is the primary operation.

**DynamoDB/Cassandra:** Wide-column stores optimized for massive write throughput and global distribution. If you're operating at a scale where Postgres read replicas aren't enough, you'll know. Until then, the operational complexity isn't worth it.

## The Taste Test

**Scenario 1:** A team member proposes MongoDB because "we're iterating fast and don't want to write migrations."

*Your instinct should be:* Red flag. Migrations take minutes to write. Schema chaos takes months to fix. The "flexibility" of schemaless databases becomes a liability when you need to query consistently or debug data issues. Counter-propose Postgres with JSONB for genuinely variable parts.

**Scenario 2:** Search results are getting slow. The table has 500,000 records with Postgres full-text search.

*Your instinct should be:* First, check if the GIN index exists and is being used. Optimize the Postgres search before adding another system. If you've truly optimized and still need typo tolerance or better relevance, then evaluate a dedicated search engine.

**Scenario 3:** The team wants to add Elasticsearch for "future-proofing" even though current search needs are simple.

*Your instinct should be:* Premature. Elasticsearch requires significant operational investment — cluster management, index design, query tuning. If Postgres FTS handles current needs, ship with Postgres. Add Elasticsearch when you have concrete needs it addresses.

**Scenario 4:** File uploads are going directly to Postgres as bytea columns.

*Your instinct should be:* This will cause problems. Postgres isn't optimized for blob storage. Large files will bloat the database, slow backups, and degrade performance. Move to S3/R2 with presigned URLs. Store metadata in Postgres.

**Scenario 5:** Someone proposes DynamoDB because "it scales automatically."

*Your instinct should be:* What are the actual scaling requirements? DynamoDB has a steep learning curve (partition key design, capacity planning), vendor lock-in, and weird pricing. For most startups, RDS Postgres with read replicas handles way more load than you'll see for years. Use DynamoDB only if you have specific needs it addresses (single-digit millisecond latency at massive scale, serverless architecture).

**Scenario 6:** A new engineer is excited about using graph database for "social features" like following users and feed generation.

*Your instinct should be:* This is almost certainly overkill. Social graphs with millions of edges are handled fine by Postgres. Twitter's initial feed system ran on MySQL. The complexity of operating a graph database (Neo4j, etc.) isn't justified until you're doing complex multi-hop graph traversals as a core feature. Start with Postgres, measure, and reconsider only if you hit real limitations.

## Practical Exercise

Design a complete data architecture for a document collaboration app (like Notion or Coda):

**Requirements:**
- Rich text documents with nested blocks
- Real-time collaboration (multiple editors)
- Full-text search across all documents
- File attachments within documents
- AI-powered "find related documents" feature
- User workspace isolation

**Deliverables:**

1. Write an Architecture Decision Record (ADR) that covers:
   - Which data stores you'll use and why
   - What goes in each data store
   - The alternatives you considered and why you rejected them
   - The operational implications of your choices

2. Create Postgres schema for the core data model

3. Implement the search sync pattern (Postgres to search engine)

4. Implement the "find related documents" feature using pgvector

**AI Integration Point:**

After designing your architecture, use Claude as an adversary:

```
Here's my data architecture for a document collaboration app:

[paste your ADR]

Argue against my decisions:
1. Where will this architecture struggle at 10x scale?
2. What operational problems am I not anticipating?
3. Which decisions would you make differently and why?
4. What happens if [specific data store] goes down?
```

Revise your architecture based on valid criticisms.

**Bonus challenges:**

1. **Multiple embedding models:** How would your architecture change if you needed to support different embedding models (e.g., OpenAI for English, a different model for other languages)?

2. **Search index migration:** Imagine you started with Postgres full-text search and need to migrate to Typesense. Design the migration strategy that doesn't require downtime.

3. **Multi-region files:** Users are global. Some want files stored in EU, others in US. How do you handle this with S3?

**Acceptance Criteria:**
- ADR clearly justifies each data store choice
- Schema handles nested document structure efficiently
- Search syncs from Postgres source of truth
- Vector similarity returns relevant results
- Architecture is appropriately simple for current scale
- You can articulate what would change at 10x scale

## Checkpoint

After completing this chapter and the exercise, you should be able to agree with these statements:

- [ ] I understand the operational cost of adding a new data store and can articulate it clearly
- [ ] I know when document stores are the right choice vs Postgres with JSONB
- [ ] I can implement a search sync pattern from Postgres to a search engine
- [ ] I understand presigned URLs and the pattern for file storage with S3
- [ ] I can use pgvector for basic similarity search and know when to consider dedicated vector DBs
- [ ] I have a decision framework for data store choices that starts with "can Postgres handle this?"
- [ ] I can write an Architecture Decision Record that justifies data infrastructure choices
- [ ] I understand the operational trade-offs between self-hosted and managed options
- [ ] I can explain why "it scales better" is not a sufficient reason to choose a database
- [ ] I have evaluated what Postgres can do before considering alternatives for any feature
