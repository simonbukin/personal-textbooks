# RAG Pipelines

## Why This Matters

LLMs know a lot, but they don't know about your data. They can't answer "What was our Q3 revenue?" or "What does our API documentation say about authentication?"

**Retrieval-Augmented Generation (RAG)** solves this by finding relevant context from your data and including it in the prompt. The LLM generates answers grounded in your actual documents, not its training data.

RAG is the foundation of most AI-powered search, chatbots, and knowledge assistants. By the end of this chapter, you'll be able to build one.

## How RAG Works

```
User Query: "How do I authenticate API requests?"
          │
          ▼
    ┌─────────────┐
    │  Embedding  │  Convert query to vector
    │    Model    │
    └──────┬──────┘
           │
           ▼
    ┌─────────────┐
    │   Vector    │  Find similar documents
    │  Database   │
    └──────┬──────┘
           │ Top 5 relevant chunks
           ▼
    ┌─────────────┐
    │     LLM     │  Generate answer using context
    │             │
    └──────┬──────┘
           │
           ▼
    Answer: "Authentication uses Bearer tokens..."
```

## Vector Embeddings

Embeddings convert text into numerical vectors. Similar texts have similar vectors. This enables semantic search — finding documents by meaning, not just keywords.

### Generating Embeddings

```typescript
// src/lib/embeddings.ts
import Anthropic from '@anthropic-ai/sdk'

// Anthropic recommends Voyage AI for embeddings
import { VoyageAIClient } from 'voyageai'

const voyage = new VoyageAIClient({
  apiKey: process.env.VOYAGE_API_KEY,
})

export async function embed(text: string): Promise<number[]> {
  const response = await voyage.embed({
    input: text,
    model: 'voyage-2',
  })

  return response.data[0].embedding
}

export async function embedBatch(texts: string[]): Promise<number[][]> {
  const response = await voyage.embed({
    input: texts,
    model: 'voyage-2',
  })

  return response.data.map(d => d.embedding)
}
```

### Storing Embeddings with pgvector

PostgreSQL with pgvector is sufficient for most RAG applications:

```sql
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Documents table with embedding
CREATE TABLE documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    content text NOT NULL,
    embedding vector(1024),  -- Voyage-2 dimension
    metadata jsonb DEFAULT '{}',
    created_at timestamptz DEFAULT now()
);

-- Approximate nearest neighbor index
CREATE INDEX idx_documents_embedding
ON documents USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);  -- Tune based on dataset size
```

```typescript
// src/lib/vectorStore.ts
import { sql } from 'drizzle-orm'

export async function addDocument(content: string, metadata: object = {}) {
  const embedding = await embed(content)

  return db.insert(documents).values({
    content,
    embedding: sql`${JSON.stringify(embedding)}::vector`,
    metadata,
  }).returning()
}

export async function search(
  query: string,
  limit = 5,
  threshold = 0.7
): Promise<Document[]> {
  const queryEmbedding = await embed(query)

  return db.execute(sql`
    SELECT
      id,
      content,
      metadata,
      1 - (embedding <=> ${JSON.stringify(queryEmbedding)}::vector) as similarity
    FROM documents
    WHERE 1 - (embedding <=> ${JSON.stringify(queryEmbedding)}::vector) > ${threshold}
    ORDER BY embedding <=> ${JSON.stringify(queryEmbedding)}::vector
    LIMIT ${limit}
  `)
}
```

## Document Processing

Real documents need preprocessing before embedding.

### Chunking

LLMs have context limits. Long documents must be split into chunks:

```typescript
interface Chunk {
  content: string
  metadata: {
    sourceId: string
    chunkIndex: number
    startChar: number
    endChar: number
  }
}

export function chunkDocument(
  document: { id: string; content: string },
  options: { chunkSize?: number; overlap?: number } = {}
): Chunk[] {
  const { chunkSize = 1000, overlap = 200 } = options
  const chunks: Chunk[] = []

  let start = 0
  let index = 0

  while (start < document.content.length) {
    const end = Math.min(start + chunkSize, document.content.length)

    // Try to break at sentence boundary
    let breakPoint = end
    if (end < document.content.length) {
      const lastPeriod = document.content.lastIndexOf('.', end)
      if (lastPeriod > start + chunkSize / 2) {
        breakPoint = lastPeriod + 1
      }
    }

    chunks.push({
      content: document.content.slice(start, breakPoint).trim(),
      metadata: {
        sourceId: document.id,
        chunkIndex: index,
        startChar: start,
        endChar: breakPoint,
      },
    })

    start = breakPoint - overlap
    index++
  }

  return chunks
}
```

### Ingestion Pipeline

```typescript
// src/services/ingestion.ts
export async function ingestDocument(doc: { id: string; content: string; title: string }) {
  // 1. Chunk the document
  const chunks = chunkDocument(doc)

  // 2. Batch embed chunks
  const embeddings = await embedBatch(chunks.map(c => c.content))

  // 3. Store in vector database
  await db.insert(documentChunks).values(
    chunks.map((chunk, i) => ({
      documentId: doc.id,
      content: chunk.content,
      embedding: sql`${JSON.stringify(embeddings[i])}::vector`,
      metadata: chunk.metadata,
    }))
  )

  console.log(`Ingested ${chunks.length} chunks from ${doc.title}`)
}

// Process documents in background
documentQueue.process('ingest', async (job) => {
  const doc = await db.query.documents.findFirst({
    where: eq(documents.id, job.data.documentId)
  })
  await ingestDocument(doc)
})
```

## RAG Query Pipeline

### Basic RAG

```typescript
// src/services/rag.ts
export async function queryWithContext(
  question: string,
  options: { maxChunks?: number } = {}
): Promise<string> {
  const { maxChunks = 5 } = options

  // 1. Find relevant chunks
  const chunks = await search(question, maxChunks)

  if (chunks.length === 0) {
    return "I couldn't find any relevant information to answer your question."
  }

  // 2. Build context
  const context = chunks
    .map((c, i) => `[Source ${i + 1}]\n${c.content}`)
    .join('\n\n')

  // 3. Generate answer
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    system: `You are a helpful assistant that answers questions based on the provided context.
If the context doesn't contain enough information to answer, say so.
Always cite which source(s) you used by referencing [Source N].`,
    messages: [{
      role: 'user',
      content: `Context:
${context}

Question: ${question}

Provide a helpful answer based only on the context above.`
    }],
    max_tokens: 1024,
  })

  return response.content[0].type === 'text' ? response.content[0].text : ''
}
```

### Conversational RAG

Maintain conversation history for follow-up questions:

```typescript
interface Message {
  role: 'user' | 'assistant'
  content: string
}

export async function conversationalQuery(
  question: string,
  history: Message[]
): Promise<{ answer: string; sources: string[] }> {
  // 1. Rewrite question with context from history
  const rewrittenQuestion = await rewriteWithHistory(question, history)

  // 2. Search with rewritten question
  const chunks = await search(rewrittenQuestion, 5)

  // 3. Generate with full history
  const context = chunks.map(c => c.content).join('\n\n---\n\n')

  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    system: `You are a helpful assistant. Answer based on the provided context.
If the context doesn't have the answer, say so.`,
    messages: [
      ...history,
      {
        role: 'user',
        content: `Context:\n${context}\n\nQuestion: ${question}`
      }
    ],
    max_tokens: 1024,
  })

  return {
    answer: response.content[0].type === 'text' ? response.content[0].text : '',
    sources: chunks.map(c => c.metadata.sourceId),
  }
}

async function rewriteWithHistory(
  question: string,
  history: Message[]
): Promise<string> {
  if (history.length === 0) return question

  // Rewrite to be standalone
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-5-20251015',  // Fast model for rewrite
    messages: [{
      role: 'user',
      content: `Given this conversation history:
${history.map(m => `${m.role}: ${m.content}`).join('\n')}

Rewrite this follow-up question to be standalone (include context from history):
"${question}"

Return only the rewritten question, nothing else.`
    }],
    max_tokens: 256,
  })

  return response.content[0].type === 'text'
    ? response.content[0].text.trim()
    : question
}
```

## Improving RAG Quality

### Hybrid Search

Combine vector search with keyword search for better results:

```typescript
export async function hybridSearch(
  query: string,
  limit = 5
): Promise<Document[]> {
  const queryEmbedding = await embed(query)

  // Combine vector similarity and text search
  return db.execute(sql`
    WITH vector_results AS (
      SELECT id, content, metadata,
             1 - (embedding <=> ${JSON.stringify(queryEmbedding)}::vector) as vector_score
      FROM documents
      ORDER BY embedding <=> ${JSON.stringify(queryEmbedding)}::vector
      LIMIT ${limit * 2}
    ),
    text_results AS (
      SELECT id, content, metadata,
             ts_rank(to_tsvector('english', content), websearch_to_tsquery('english', ${query})) as text_score
      FROM documents
      WHERE to_tsvector('english', content) @@ websearch_to_tsquery('english', ${query})
      LIMIT ${limit * 2}
    )
    SELECT
      COALESCE(v.id, t.id) as id,
      COALESCE(v.content, t.content) as content,
      COALESCE(v.metadata, t.metadata) as metadata,
      COALESCE(v.vector_score, 0) * 0.7 + COALESCE(t.text_score, 0) * 0.3 as combined_score
    FROM vector_results v
    FULL OUTER JOIN text_results t ON v.id = t.id
    ORDER BY combined_score DESC
    LIMIT ${limit}
  `)
}
```

### Metadata Filtering

Filter by source, date, or other attributes:

```typescript
interface SearchFilters {
  sourceType?: 'docs' | 'blog' | 'support'
  dateAfter?: Date
  tags?: string[]
}

export async function filteredSearch(
  query: string,
  filters: SearchFilters,
  limit = 5
): Promise<Document[]> {
  const queryEmbedding = await embed(query)

  let whereClause = sql`1=1`

  if (filters.sourceType) {
    whereClause = sql`${whereClause} AND metadata->>'sourceType' = ${filters.sourceType}`
  }
  if (filters.dateAfter) {
    whereClause = sql`${whereClause} AND created_at > ${filters.dateAfter}`
  }
  if (filters.tags?.length) {
    whereClause = sql`${whereClause} AND metadata->'tags' ?| ${filters.tags}`
  }

  return db.execute(sql`
    SELECT id, content, metadata,
           1 - (embedding <=> ${JSON.stringify(queryEmbedding)}::vector) as similarity
    FROM documents
    WHERE ${whereClause}
    ORDER BY embedding <=> ${JSON.stringify(queryEmbedding)}::vector
    LIMIT ${limit}
  `)
}
```

### Re-ranking

Use a reranker model to improve result ordering:

```typescript
export async function searchWithRerank(
  query: string,
  limit = 5
): Promise<Document[]> {
  // 1. Initial retrieval (get more than needed)
  const candidates = await search(query, limit * 3)

  // 2. Rerank with cross-encoder
  const reranked = await voyage.rerank({
    query,
    documents: candidates.map(c => c.content),
    model: 'rerank-1',
    returnDocuments: false,
  })

  // 3. Return top results in new order
  return reranked.data
    .slice(0, limit)
    .map(r => candidates[r.index])
}
```

## Production Considerations

### Chunk Overlap and Size

```
Smaller chunks (200-500 chars):
  + More precise retrieval
  - Loss of context
  - More storage/compute

Larger chunks (1000-2000 chars):
  + More context in each chunk
  - Less precise matching
  - May include irrelevant text
```

Experiment with your specific use case. Start with ~1000 characters and adjust.

### Index Management

```sql
-- Rebuild index periodically for accuracy
REINDEX INDEX idx_documents_embedding;

-- Monitor index usage
SELECT relname, indexrelname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE indexrelname LIKE '%embedding%';
```

### Handling Updates

When source documents change:

```typescript
export async function updateDocument(docId: string, newContent: string) {
  // Delete old chunks
  await db.delete(documentChunks)
    .where(eq(documentChunks.documentId, docId))

  // Re-ingest
  await ingestDocument({ id: docId, content: newContent, title: '' })
}
```

## The Taste Test

**Scenario 1:** A RAG system chunks PDF documents by page.

*Suboptimal.* Pages are arbitrary boundaries. Chunk by semantic units (paragraphs, sections) with overlap for better retrieval.

**Scenario 2:** Every user query makes an embedding API call, even for identical queries.

*Cache embeddings.* Query embeddings are deterministic. Cache them to reduce costs and latency.

**Scenario 3:** A support chatbot retrieves 20 chunks and sends them all to the LLM.

*Too many.* Context limits and cost suffer. Retrieve more candidates, then rerank and select top 3-5.

**Scenario 4:** The system returns "I don't know" when the answer exists but the user phrased the question differently.

*Improve retrieval.* Try query expansion (generate multiple phrasings), hybrid search, or fine-tuned embeddings.

## Practical Exercise

Build a documentation Q&A system for your TaskFlow API:

**Requirements:**
1. Ingest your API documentation (markdown files or OpenAPI spec)
2. Chunk documents appropriately
3. Store embeddings in Postgres with pgvector
4. Build a search endpoint that returns relevant chunks
5. Build a Q&A endpoint that uses RAG to answer questions

**Acceptance criteria:**
- Documentation is chunked with overlap
- Similarity search returns relevant results
- Q&A responses cite their sources
- Duplicate queries use cached embeddings

**⚡ AI Shortcut:**

Have Claude help design your chunking strategy:

```
I'm building a RAG system for API documentation.
Here's a sample document structure:

[paste example markdown]

Recommend:
1. How to split this into chunks
2. What metadata to extract
3. Chunk size and overlap settings
4. Any special handling for code blocks or headers
```

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I understand how RAG combines retrieval with generation
- [ ] I can generate and store embeddings with pgvector
- [ ] I know how to chunk documents for effective retrieval
- [ ] I can build a basic RAG query pipeline
- [ ] I understand techniques for improving RAG quality

RAG grounds LLMs in your data. It's the bridge between AI capabilities and your specific domain knowledge.
