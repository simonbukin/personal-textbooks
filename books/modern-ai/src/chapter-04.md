# Chapter 4: RAG & Knowledge Systems

## Why This Matters

RAG (Retrieval-Augmented Generation) is probably the most commonly deployed AI architecture in production today, and also the most commonly botched. The pattern is deceptively simple: take a user's question, find relevant documents, stuff them into a prompt, and let the model answer grounded in real data. Every tutorial makes this look like a weekend project. Chunk your PDFs, embed them, throw them in a vector database, done. And it does work on the demo. Then you deploy it to real users with real documents and real questions, and retrieval precision collapses, the model hallucinates while citing sources, and nobody can figure out whether the problem is the retrieval, the generation, or the documents themselves.

The gap between a working RAG demo and a production RAG system is one of the widest in all of AI engineering. The problems are distributed across the entire pipeline: document preprocessing, chunking, embedding, indexing, retrieval, re-ranking, prompt construction, generation, and evaluation. A failure at any stage produces the same symptom: bad answers. You can't debug what you can't decompose, and most teams never learn to decompose their RAG pipeline into independently measurable stages.

This chapter goes deep on retrieval quality, beyond just mechanics. You'll learn why most RAG failures trace back to decisions made before any model is ever called — decisions about how documents are split, how metadata is preserved, and how retrieval is evaluated. You'll also learn when RAG is the wrong tool entirely, which is more often than the industry wants to admit.

## Why LLMs Hallucinate and What RAG Actually Fixes

To understand RAG, you first need to understand the problem it solves and the problems it doesn't. A language model's knowledge comes from two different sources. **Parametric knowledge** is information encoded in the model's weights during training. When GPT-4 or Claude tells you that the capital of France is Paris, it's not looking that up anywhere. It learned that statistical association during training and encoded it as a pattern in billions of parameters. **Non-parametric knowledge** is information retrieved at runtime from an external source and provided to the model as context.

Parametric knowledge has three critical limitations. First, it has a **knowledge cutoff**: the model only knows what existed in its training data. Second, it's **unverifiable**: you can't trace a model's answer back to a specific source document, because the information has been compressed and distributed across weights in ways that resist attribution. Third, it's **generic**: the model knows public information but nothing about your company's internal documentation, your product's changelog, or your customer's specific data. RAG addresses all three of these limitations by retrieving relevant documents at query time and providing them as context.

RAG provides three things. **Grounding**: the model answers based on specific, retrievable source material rather than compressed training data. **Recency**: your retrieval corpus can be updated continuously without retraining the model. **Proprietary data access**: the model can answer questions about documents it was never trained on, because those documents are injected into the context at runtime.

But RAG does *not* fix everything, and teams regularly get into trouble here. RAG doesn't fix **reasoning errors**. If a model can't perform multi-step logical reasoning, giving it more documents won't help; it'll just have more material to reason about incorrectly. RAG doesn't fix **bias**. If retrieved documents contain biased information, the model will faithfully reproduce that bias, now with citations. RAG doesn't fix **multi-hop inference**: questions that require synthesizing information across many documents in complex ways are hard for current architectures regardless of retrieval quality. And RAG doesn't fix **out-of-distribution queries**. If the user asks a question that your corpus simply doesn't cover, retrieval will return the least-irrelevant documents, and the model will either confabulate an answer from tangentially related content or correctly say "I don't know" — and you can't reliably predict which.

Most tutorials miss this: RAG can actually *introduce* new forms of hallucination that don't exist in vanilla LLM usage. You're trading one type for another, and the new type is often harder to catch. The first and most insidious form: **misattributed citations**. The model retrieves a real document and cites it in its answer, but it misrepresents what the document actually says. Maybe it paraphrases too loosely, conflates two claims, or attributes a conclusion the source never drew. The user sees a citation, assumes the answer is verified, and trusts it — but the model's summary of the source is wrong. This is strictly worse than having no citation at all, because it creates false confidence in an incorrect answer. The second form: **wrong-chunk confidence**. When your retrieval returns a chunk that's semantically similar to the query but not actually relevant (and this happens constantly in production), the model will often construct a plausible-sounding answer from that irrelevant context. The answer looks grounded because it references real content from your corpus, but it's answering a question the chunk doesn't address. It passes the smell test, which is exactly what makes it dangerous. The third form: **cross-chunk confabulation**. When the model receives multiple retrieved chunks that each contain partial information about a topic, it sometimes fills in the gaps by interpolating between them, generating content that isn't in *any* source document but sounds like a natural bridge between things that are. It's synthesis without warrant, and it's nearly impossible to catch without comparing the output against every retrieved chunk individually.

The takeaway: RAG changes the *type* of hallucination you deal with, from "the model makes things up from nothing" to "the model misrepresents real sources." The second type is often harder to catch precisely because it looks legitimate. There's a real document behind the answer; it's just not saying what the model claims it says. Retrieval evals, which we'll cover later in this chapter, are non-negotiable. You need to measure **faithfulness** (whether the model's output is actually supported by the retrieved content) independently from **retrieval quality** (whether you fetched the right documents in the first place). They're separate failure modes and you have to evaluate them separately.

> **🤔 Taste Moment:** Before you build a RAG system, ask three questions. First, is your corpus small enough to fit in context? If you have fewer than 50 pages of content and the information is relatively stable, just put it all in the prompt — the retrieval step adds latency, complexity, and a new failure mode for no benefit. Second, is the data structured? If users are asking questions that could be answered by a SQL query, build a text-to-SQL system instead — RAG over structured data is almost always worse than just querying the database. Third, is latency critical? Retrieval adds 200-500ms minimum to every request, and re-ranking adds more. If you're building a real-time system where response time matters, that overhead might be unacceptable.

## Embeddings — Geometrically, Not Just as API Calls

Most developers encounter embeddings as an API call: you send text in, you get a vector out, and you compute similarity between vectors to find related content. Sufficient for getting started, but not for debugging retrieval failures. You need to understand what's actually happening geometrically.

An **embedding model** maps text to a point in high-dimensional space, typically 768, 1024, 1536, or 3072 dimensions depending on the model. The model is trained so that texts with similar meaning end up at nearby points in this space. When you compute **cosine similarity** between two embedding vectors, you're measuring the angle between them. Vectors pointing in the same direction have similarity near 1.0, orthogonal vectors have similarity near 0.0, and vectors pointing in opposite directions have similarity near -1.0.

The critical intuition most people miss: "similar meaning" as learned by the embedding model may not match "similar meaning" as understood by your domain. General-purpose embedding models like OpenAI's `text-embedding-3-large` or Cohere's `embed-v3` are trained on broad internet text. They're excellent at capturing general semantic similarity — "the cat sat on the mat" will be close to "a feline rested on the rug." But they struggle with domain-specific content where the same words carry specialized meanings. In a legal corpus, "consideration" means something very specific. In a medical corpus, "discharge" means something very different from everyday usage. In a codebase, variable names and function signatures carry semantic weight that general models don't capture well.

Retrieval quality degrades when you move from demo data to production data for exactly this reason. Your demo probably used clean, well-written, general-knowledge text. Your production data is full of jargon, abbreviations, internal terminology, and domain-specific conventions that the embedding model wasn't trained on. The embeddings still capture *something*, but the similarity rankings become noisy — relevant documents end up further from the query than irrelevant ones that happen to share surface-level vocabulary.

The **MTEB benchmark** ([https://huggingface.co/spaces/mteb/leaderboard](https://huggingface.co/spaces/mteb/leaderboard)) is your best resource for comparing embedding models. It evaluates models across multiple retrieval tasks, and you should pay attention to performance on tasks that resemble your use case. A model that ranks #1 on general-purpose retrieval may rank #15 on domain-specific retrieval. Always test candidate models on your actual data before committing.

**Embedding dimensions** involve a real tradeoff. Higher-dimensional embeddings (3072-d) capture more nuance but cost more to store, index, and search. Lower-dimensional embeddings (384-d) are cheaper and faster but may lose fine-grained distinctions for your domain. For most production systems, 1024 or 1536 dimensions hit the sweet spot. OpenAI's `text-embedding-3` models support dimension reduction via the `dimensions` parameter — you can generate a 3072-d embedding and truncate it to 1024-d with surprisingly little quality loss, thanks to Matryoshka representation learning.

A complete example of generating embeddings and computing similarity:

```python
# embeddings_demo.py
import numpy as np
from openai import OpenAI

client = OpenAI()  # Uses OPENAI_API_KEY env var

def get_embeddings(texts: list[str], model: str = "text-embedding-3-large", dimensions: int = 1536) -> list[list[float]]:
    """Generate embeddings for a list of texts."""
    response = client.embeddings.create(
        input=texts,
        model=model,
        dimensions=dimensions
    )
    return [item.embedding for item in response.data]

def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Compute cosine similarity between two vectors."""
    a_arr = np.array(a)
    b_arr = np.array(b)
    return float(np.dot(a_arr, b_arr) / (np.linalg.norm(a_arr) * np.linalg.norm(b_arr)))

# Compare three sentences
texts = [
    "The patient was discharged with antibiotics.",
    "The patient left the hospital with a prescription.",
    "The battery discharged completely overnight."
]

embeddings = get_embeddings(texts)

# Medical sentence vs. paraphrase — should be high similarity
print(f"Medical vs. paraphrase: {cosine_similarity(embeddings[0], embeddings[1]):.4f}")
# Medical sentence vs. battery sentence — should be lower (different domain of 'discharged')
print(f"Medical vs. battery:    {cosine_similarity(embeddings[0], embeddings[2]):.4f}")
# Paraphrase vs. battery — should be lowest
print(f"Paraphrase vs. battery: {cosine_similarity(embeddings[1], embeddings[2]):.4f}")
```

Run this and you'll see that even good embedding models sometimes rank the battery sentence closer to the medical sentence than you'd want. The word "discharged" creates a surface-level similarity that competes with the deeper semantic difference. This is the kind of failure that's invisible in demos and devastating in production.

> **⚡ Production Tip:** Batch your embedding calls. OpenAI's API accepts up to 2048 texts per request, and batching is far faster than sending one text at a time. For a corpus of 100K documents, the difference between batched and sequential embedding generation is hours vs. minutes. Also, cache your embeddings — re-embedding unchanged documents is pure waste.

## Vector Databases and Retrieval Infrastructure

Once you have embeddings, you need somewhere to store and search them. The vector database market has exploded, and the options can feel overwhelming. The honest tradeoff map:

**pgvector** is a PostgreSQL extension that adds vector similarity search to your existing Postgres database. If you're already running Postgres — and most startups are — this is the default choice. You don't need a new piece of infrastructure. You get the full power of SQL for filtering, joining, and querying metadata alongside vector search. The operational complexity is near zero because your team already knows how to run Postgres. The limitation is scale: pgvector works well up to roughly 5-10 million vectors. Beyond that, query performance degrades unless you invest heavily in index tuning.

**Pinecone** is a fully managed vector database. You don't run anything — you send vectors in and query them back. It scales well, it's fast, and the operational burden is minimal. The tradeoff is cost (it's not cheap at scale), vendor lock-in (your data is in their cloud), and limited query flexibility compared to SQL. Pinecone is a good choice when you want to move fast and your team doesn't have database expertise.

**Weaviate** is an open-source vector database with a strong feature set including built-in vectorization, hybrid search, and flexible filtering. You can self-host it or use their managed cloud. It's more operationally complex than pgvector (it's a separate service to run) but more capable at scale. Weaviate is a good choice for teams that need advanced features and are comfortable running infrastructure.

**Chroma** is designed for simplicity and local development. It's excellent for prototyping and small-scale applications. It's not the right choice for high-scale production systems, but it's perfect for building and testing your RAG pipeline before committing to heavier infrastructure.

**Qdrant** is an open-source vector database written in Rust with excellent performance characteristics. It supports filtering, payload storage, and has a well-designed API. It's a strong choice for teams that need high performance and are comfortable with self-hosting.

The choice between **Approximate Nearest Neighbor (ANN)** search and exact search matters at scale. ANN algorithms like HNSW (Hierarchical Navigable Small World) don't guarantee finding the absolute closest vectors. They find vectors that are *very probably* close, with configurable accuracy/speed tradeoffs. At 10,000 vectors, exact search is fast enough and gives perfect results. At 10 million vectors, you need ANN. At 100 million vectors, you need ANN with careful index tuning, and your choice of vector database starts to matter a lot.

> **💸 Cost:** Vector databases at scale are not cheap. A 10M vector collection with 1536-d embeddings requires roughly 60GB of storage just for the vectors, plus index overhead. Managed services charge for storage, compute, and queries. At 100M vectors, you're looking at serious infrastructure costs. Do the math before you commit to a scale-out architecture — many teams over-index their corpus and could achieve better results with a smaller, higher-quality collection.

A practical setup using pgvector:

```python
# pgvector_setup.py
import psycopg2
from pgvector.psycopg2 import register_vector

# Connect to your Postgres database (pgvector extension must be installed)
conn = psycopg2.connect("postgresql://localhost:5432/ragdb")
register_vector(conn)

cur = conn.cursor()

# Enable the extension and create the table
cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
cur.execute("""
    CREATE TABLE IF NOT EXISTS documents (
        id SERIAL PRIMARY KEY,
        content TEXT NOT NULL,
        embedding vector(1536),
        source_file TEXT,
        chunk_index INTEGER,
        created_at TIMESTAMP DEFAULT NOW(),
        tenant_id TEXT  -- For multi-tenant filtering
    )
""")

# Create an HNSW index for fast approximate search
# m = max connections per node (higher = more accurate, more memory)
# ef_construction = search depth during index build (higher = better index, slower build)
cur.execute("""
    CREATE INDEX IF NOT EXISTS documents_embedding_idx
    ON documents USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
""")
conn.commit()


def insert_document(content: str, embedding: list[float], source_file: str,
                    chunk_index: int, tenant_id: str):
    """Insert a document chunk with its embedding."""
    cur.execute(
        """INSERT INTO documents (content, embedding, source_file, chunk_index, tenant_id)
           VALUES (%s, %s::vector, %s, %s, %s)""",
        (content, embedding, source_file, chunk_index, tenant_id)
    )
    conn.commit()


def search_documents(query_embedding: list[float], tenant_id: str,
                     limit: int = 5) -> list[dict]:
    """Search for similar documents, filtered by tenant."""
    cur.execute(
        """SELECT id, content, source_file, chunk_index,
                  1 - (embedding <=> %s::vector) AS similarity
           FROM documents
           WHERE tenant_id = %s
           ORDER BY embedding <=> %s::vector
           LIMIT %s""",
        (query_embedding, tenant_id, query_embedding, limit)
    )
    columns = ["id", "content", "source_file", "chunk_index", "similarity"]
    return [dict(zip(columns, row)) for row in cur.fetchall()]
```

Notice the `tenant_id` filter in the search query. This is not optional for production systems; we'll cover why in the permissions section. Also notice that pgvector uses the `<=>` operator for cosine distance (not similarity; you subtract from 1 to get similarity). These are the kinds of details that trip people up in production.

> **⚡ Production Tip:** Set `ef_search` at query time to control the accuracy/speed tradeoff for HNSW search. Higher values search more of the graph and return more accurate results, but take longer. Start with `SET hnsw.ef_search = 100` and tune from there based on your latency budget and recall requirements.

## Chunking Strategies — Where Most Quality Problems Originate

If I had to pick a single piece of advice for improving RAG quality, it would be this: spend more time on chunking. The way you split documents into chunks determines the upper bound on your retrieval quality. No embedding model, no vector database, no re-ranking algorithm can recover information that was destroyed during chunking.

**Fixed-size chunking** is the default approach: split the document every N tokens (or characters), optionally with overlap between chunks. Simple to implement and predictable in chunk size, but also the source of most retrieval quality problems. Fixed-size chunking doesn't respect semantic boundaries. It'll split a paragraph in the middle of a sentence, separate a heading from its content, or divide a code block across two chunks. When the embedding model processes these fragments, the resulting embeddings don't capture the meaning of the original content because the meaning has been destroyed by the split.

**Semantic chunking** splits documents at natural boundaries: paragraph breaks, section headings, topic changes. It preserves meaning within each chunk at the cost of variable chunk sizes. The simplest version uses structural cues: split on double newlines, headers, or horizontal rules. More sophisticated approaches use embedding similarity — embed each sentence, then split where the similarity between consecutive sentences drops below a threshold, indicating a topic change.

**Chunk size** involves a genuine tradeoff and there's no universal answer. Smaller chunks (100-200 tokens) give you more precise retrieval: the embedding captures a specific idea, and when that idea matches the query, it ranks high. But smaller chunks provide less context; the model sees a sentence or two without the surrounding explanation. Larger chunks (500-1000 tokens) provide more context but noisier retrieval. The embedding is an average of multiple ideas, and a query matching one idea in the chunk might not be enough to surface it. For most use cases, 200-500 tokens per chunk with 10-20% overlap is a reasonable starting point, but you should measure with your actual data.

**Parent-child chunking** is one of the most effective strategies for production RAG, and under-used. Create small chunks for retrieval precision, but when you retrieve a small chunk, return its parent (larger) chunk to the model. You embed sentences or small paragraphs for search, but you include the full section or page as context. This gives you the precision of small chunks with the context of large chunks. The implementation requires maintaining a mapping from child chunks to parent chunks, but it's straightforward.

**Document structure preservation** is the most commonly neglected aspect of chunking. Tables, code blocks, lists, and nested headers all carry structural meaning that's lost when you flatten a document to plain text. A table row that says "Q3 Revenue: $4.2M" only makes sense if you know the column headers. A code block only makes sense as a unit. A subsection heading provides critical context for the paragraphs beneath it. Your chunking strategy must handle these structures explicitly — keep tables intact, keep code blocks intact, and prepend section headers to their child chunks so the embedding model (and the language model) has the context needed to interpret the content.

A practical implementation showing multiple chunking strategies:

```python
# chunking_strategies.py
import re
from dataclasses import dataclass

@dataclass
class Chunk:
    content: str
    metadata: dict
    parent_id: str | None = None

def fixed_size_chunk(text: str, chunk_size: int = 400, overlap: int = 80,
                     source: str = "") -> list[Chunk]:
    """Fixed-size chunking with token-approximate splitting."""
    words = text.split()
    chunks = []
    start = 0
    idx = 0
    while start < len(words):
        end = min(start + chunk_size, len(words))
        chunk_text = " ".join(words[start:end])
        chunks.append(Chunk(
            content=chunk_text,
            metadata={"source": source, "chunk_index": idx, "strategy": "fixed"},
        ))
        start += chunk_size - overlap
        idx += 1
    return chunks


def semantic_chunk(text: str, source: str = "") -> list[Chunk]:
    """Split on structural boundaries: headings, double newlines, horizontal rules."""
    # Split on markdown headings, double newlines, or horizontal rules
    pattern = r'(?=\n#{1,6}\s)|\n{2,}|\n---+\n'
    raw_sections = re.split(pattern, text)
    sections = [s.strip() for s in raw_sections if s.strip()]

    chunks = []
    for idx, section in enumerate(sections):
        chunks.append(Chunk(
            content=section,
            metadata={"source": source, "chunk_index": idx, "strategy": "semantic"},
        ))
    return chunks


def parent_child_chunk(text: str, source: str = "") -> tuple[list[Chunk], list[Chunk]]:
    """Create small child chunks for retrieval, linked to larger parent chunks for context."""
    # First, create parent chunks from major sections
    parent_pattern = r'(?=\n#{1,2}\s)'
    parent_sections = re.split(parent_pattern, text)
    parent_sections = [s.strip() for s in parent_sections if s.strip()]

    parents = []
    children = []

    for p_idx, section in enumerate(parent_sections):
        parent_id = f"{source}::parent::{p_idx}"
        parents.append(Chunk(
            content=section,
            metadata={
                "source": source,
                "chunk_index": p_idx,
                "strategy": "parent",
                "chunk_id": parent_id,
            },
        ))

        # Split parent into child chunks at paragraph boundaries
        paragraphs = [p.strip() for p in section.split("\n\n") if p.strip()]

        # Prepend section heading to each child for context
        heading_match = re.match(r'^(#{1,2}\s+.+)', section)
        heading_prefix = f"{heading_match.group(1)}\n\n" if heading_match else ""

        for c_idx, para in enumerate(paragraphs):
            if para.startswith("#"):
                continue  # Skip the heading itself — it's the prefix
            children.append(Chunk(
                content=heading_prefix + para,
                metadata={
                    "source": source,
                    "chunk_index": c_idx,
                    "strategy": "child",
                    "parent_chunk_id": parent_id,
                },
                parent_id=parent_id,
            ))

    return parents, children


def chunk_with_structure_preservation(text: str, source: str = "") -> list[Chunk]:
    """Chunking that preserves code blocks and tables as atomic units."""
    chunks = []
    # Extract code blocks and tables first, replace with placeholders
    code_blocks = []
    def replace_code(match):
        code_blocks.append(match.group(0))
        return f"__CODE_BLOCK_{len(code_blocks) - 1}__"

    # Preserve fenced code blocks
    processed = re.sub(r'```[\s\S]*?```', replace_code, text)

    # Now chunk the processed text semantically
    sections = [s.strip() for s in re.split(r'\n{2,}', processed) if s.strip()]

    for idx, section in enumerate(sections):
        # Restore any code blocks in this section
        restored = section
        for i, block in enumerate(code_blocks):
            restored = restored.replace(f"__CODE_BLOCK_{i}__", block)

        chunks.append(Chunk(
            content=restored,
            metadata={"source": source, "chunk_index": idx,
                       "strategy": "structure_preserved"},
        ))

    return chunks
```

The parent-child strategy deserves special attention. In practice, you'd embed the children, store both parents and children in your database, and at retrieval time, search against child embeddings but return the parent content. This is a small implementation detail that often produces a 10-20% improvement in answer quality because the model gets the context it needs to interpret the retrieved passage.

> **⚡ Production Tip:** Always log your chunks during development. Actually look at them. Read 50 random chunks from your corpus and ask: "If I saw only this chunk, would I have enough context to answer a question about its content?" If the answer is frequently "no," your chunking strategy needs work. This manual inspection catches problems that automated metrics miss.

## Hybrid Search and Re-ranking

Pure semantic search (embed the query, find the nearest vectors) is not enough for production RAG. It fails in predictable ways that are easy to fix once you understand them. The first failure mode is **vocabulary mismatch**: the user searches for "HIPAA compliance requirements" and the most relevant document uses the phrase "healthcare data privacy regulations" throughout. Semantically related, but the embedding similarity might not rank it highly enough. The second failure mode is **specificity loss**: embeddings compress meaning into a fixed-size vector, and specific details — names, dates, part numbers, error codes — get averaged away.

**BM25** is the traditional keyword-matching algorithm that powers search engines like Elasticsearch. It ranks documents based on term frequency and inverse document frequency: how often the query words appear in the document relative to how common they are across all documents. BM25 is excellent at matching specific terms and terrible at understanding meaning. Semantic search is excellent at understanding meaning and terrible at matching specific terms. Combining them — **hybrid search** — almost always outperforms either alone.

The typical implementation: run both a BM25 search and a semantic search against your corpus, then combine the results using **Reciprocal Rank Fusion (RRF)** or a simple weighted score. RRF works by assigning each result a score based on its rank in each list (1/(k + rank)), then summing scores for results that appear in both lists. The constant k (typically 60) controls how much weight is given to rank vs. mere presence.

**Re-ranking** adds another layer: after your initial retrieval returns a candidate set (say, 20-50 documents), a **cross-encoder** model scores each query-document pair directly. Unlike embedding models, which encode queries and documents independently, cross-encoders process the query and document together, enabling much richer comparison. They can detect negation, qualification, and subtle relevance signals that bi-encoder embeddings miss. The tradeoff is speed: cross-encoders are orders of magnitude slower than vector similarity, so you can only apply them to a small candidate set.

**Cohere Rerank** and open-source cross-encoders from the `sentence-transformers` library are the two practical options. Cohere Rerank is an API call: easy to integrate, good quality, adds latency and cost. Open-source cross-encoders (like `cross-encoder/ms-marco-MiniLM-L-6-v2`) can run locally, giving you better latency at the cost of hosting a model. For most teams, Cohere Rerank is the right starting point — the latency is 100-200ms, which is acceptable for most applications, and the quality improvement over raw retrieval is substantial.

**Query expansion** and **HyDE (Hypothetical Document Embeddings)** address the query side of the relevance gap. Query expansion uses the language model to generate alternative phrasings of the user's question before retrieval; searching for multiple formulations increases the chance of matching relevant documents. HyDE goes further: instead of searching with the user's question, you ask the model to generate a hypothetical answer, then embed and search with *that*. A hypothetical answer is linguistically closer to the actual documents than a question is. HyDE is effective for factual queries and can improve retrieval recall by 10-30%, but it adds a full LLM call to the retrieval pipeline, which means latency and cost.

**Maximal Marginal Relevance (MMR)** addresses a different problem: diversity. Standard retrieval often returns five chunks that are all from the same section of the same document, highly relevant but redundant. MMR re-ranks results to balance relevance with diversity, penalizing candidates that are too similar to already-selected results. This is especially valuable when your context window is limited and you want each retrieved chunk to contribute new information.

```typescript
// hybrid_search.ts
interface SearchResult {
  id: string;
  content: string;
  score: number;
  source: "semantic" | "keyword" | "hybrid";
}

function reciprocalRankFusion(
  semanticResults: SearchResult[],
  keywordResults: SearchResult[],
  k: number = 60,
  semanticWeight: number = 0.6
): SearchResult[] {
  const scores = new Map<string, { score: number; content: string }>();

  // Score semantic results
  semanticResults.forEach((result, rank) => {
    const rrfScore = semanticWeight * (1 / (k + rank + 1));
    const existing = scores.get(result.id);
    scores.set(result.id, {
      score: (existing?.score ?? 0) + rrfScore,
      content: result.content,
    });
  });

  // Score keyword results
  const keywordWeight = 1 - semanticWeight;
  keywordResults.forEach((result, rank) => {
    const rrfScore = keywordWeight * (1 / (k + rank + 1));
    const existing = scores.get(result.id);
    scores.set(result.id, {
      score: (existing?.score ?? 0) + rrfScore,
      content: result.content,
    });
  });

  // Sort by fused score
  return Array.from(scores.entries())
    .map(([id, { score, content }]) => ({
      id,
      content,
      score,
      source: "hybrid" as const,
    }))
    .sort((a, b) => b.score - a.score);
}

// Usage with a reranker
async function searchWithReranking(
  query: string,
  semanticResults: SearchResult[],
  keywordResults: SearchResult[],
  cohereApiKey: string
): Promise<SearchResult[]> {
  // Step 1: Fuse results from both retrieval methods
  const fusedResults = reciprocalRankFusion(semanticResults, keywordResults);

  // Step 2: Take top candidates for re-ranking (reranking is expensive)
  const candidates = fusedResults.slice(0, 25);

  // Step 3: Re-rank with Cohere
  const response = await fetch("https://api.cohere.ai/v1/rerank", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${cohereApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "rerank-english-v3.0",
      query: query,
      documents: candidates.map((r) => r.content),
      top_n: 5,
    }),
  });

  const reranked = await response.json();

  return reranked.results.map(
    (r: { index: number; relevance_score: number }) => ({
      ...candidates[r.index],
      score: r.relevance_score,
    })
  );
}
```

> **🤔 Taste Moment:** How much retrieval complexity is justified? Start with pure semantic search. Measure retrieval precision. If it's above 90% for your use cases, you may not need hybrid search or re-ranking. If it's below 80%, add BM25 hybrid search first — it's the highest-impact, lowest-effort improvement. Only add re-ranking if hybrid search doesn't close the gap, and only add HyDE if you have a latency budget that can absorb an extra LLM call.

## Evals for Retrieval

You cannot improve what you cannot measure, and most teams measure RAG systems wrong. The most common mistake: evaluating the system end-to-end, asking questions and checking whether the final answers are correct. End-to-end evaluation is necessary, but insufficient because it doesn't tell you *where* failures occur. When the system gives a wrong answer, is it because retrieval returned the wrong documents, or because the model misinterpreted the right documents? These are different problems with different fixes, and treating them as one problem guarantees slow progress.

The **RAGAS framework** ([https://docs.ragas.io](https://docs.ragas.io)) provides a structured approach to RAG evaluation with four core metrics. **Faithfulness** measures whether the generated answer is supported by the retrieved context; a low faithfulness score means the model is hallucinating information that isn't in the retrieved documents. **Answer relevancy** measures whether the generated answer actually addresses the user's question; a low score here means the model is discussing retrieved content that doesn't relate to the query. **Context precision** measures whether the retrieved documents are relevant to the question; low precision means your retrieval is returning noise. **Context recall** measures whether the retrieved documents contain the information needed to answer the question; low recall means relevant documents exist in your corpus but retrieval isn't finding them.

These four metrics let you diagnose failures precisely. Low context precision + high context recall = your retrieval finds relevant documents but also returns too much noise. Fix by improving re-ranking or tightening similarity thresholds. High context precision + low context recall = your retrieval is precise but misses relevant documents. Fix by improving query expansion, adding hybrid search, or revisiting your chunking strategy. High context precision + high context recall + low faithfulness = retrieval is working fine but the model is hallucinating. Fix by improving your prompt, reducing context window stuffing, or switching to a more reliable model.

**Building ground truth datasets** is the hardest and most important part of RAG evaluation. You need a set of questions, the documents that should be retrieved to answer them, and the correct answers. There's no shortcut here — someone with domain expertise needs to create these. The minimum viable ground truth dataset is 50-100 question-answer-context triples that cover the diversity of your use cases. Anything less and your metrics will be too noisy to act on. Anything over 500 and you're probably spending more time on eval maintenance than on system improvement.

One effective approach: take 100 real user questions (from logs, support tickets, or internal stakeholders), manually identify the correct source documents for each, write the ideal answer, and store these as your ground truth. Update this dataset quarterly as your corpus evolves.

```python
# ragas_eval.py
from ragas import evaluate
from ragas.metrics import (
    faithfulness,
    answer_relevancy,
    context_precision,
    context_recall,
)
from datasets import Dataset

# Your ground truth test set
eval_data = {
    "question": [
        "What is the refund policy for annual subscriptions?",
        "How do I configure SSO with Okta?",
        "What are the rate limits for the API?",
    ],
    "answer": [
        # Generated answers from your RAG pipeline
        "Annual subscriptions can be refunded within 30 days of purchase...",
        "To configure SSO with Okta, navigate to Settings > Security...",
        "The API allows 1000 requests per minute per API key...",
    ],
    "contexts": [
        # Retrieved documents (list of strings for each question)
        ["Refund Policy: Annual subscriptions are eligible for a full refund within "
         "30 days of the initial purchase date. After 30 days, refunds are prorated "
         "based on the remaining subscription period..."],
        ["SSO Configuration Guide: Our platform supports SAML 2.0 SSO with major "
         "identity providers including Okta, Azure AD, and OneLogin. To begin setup, "
         "go to Settings > Security > Single Sign-On..."],
        ["API Rate Limits: All API endpoints are subject to rate limiting. The default "
         "limit is 1000 requests per minute per API key. Enterprise plans can request "
         "higher limits by contacting support..."],
    ],
    "ground_truth": [
        # The correct answers (for measuring answer quality)
        "Annual subscriptions can be refunded in full within 30 days. After 30 days, "
        "refunds are prorated based on remaining time.",
        "Go to Settings > Security > Single Sign-On, select Okta as the provider, "
        "enter your Okta domain and client ID, then test the connection.",
        "The default rate limit is 1000 requests per minute per API key. Enterprise "
        "plans can request higher limits.",
    ],
}

dataset = Dataset.from_dict(eval_data)

results = evaluate(
    dataset,
    metrics=[faithfulness, answer_relevancy, context_precision, context_recall],
)

print(results)
# Output: {'faithfulness': 0.95, 'answer_relevancy': 0.88,
#          'context_precision': 0.92, 'context_recall': 0.87}
```

> **⚡ Production Tip:** Run retrieval evals on every pipeline change: model changes, chunking changes, index parameter changes, and corpus updates. A new batch of documents can shift your embedding space and degrade retrieval quality for existing queries. Treat retrieval evals like regression tests: if precision drops below your threshold, the change doesn't ship.

## Permission-Aware Retrieval

This section is short but critical, especially for enterprise applications. If your RAG system serves multiple users or tenants, **you must enforce access control at retrieval time, not at generation time**. A security requirement, not a nice-to-have.

Imagine your corpus includes HR documents, financial reports, and engineering documentation. A junior engineer asks a question, and your retrieval returns an HR document about upcoming layoffs that's only supposed to be visible to senior leadership. If you try to handle this at generation time, instructing the model to "only share information the user is authorized to see," you've already failed. The confidential document is in the prompt. It's in the API logs. It's in the model's context. A sufficiently clever prompt can extract it. Even without adversarial intent, the model might reference it indirectly. **The only safe approach is to never retrieve documents the user isn't authorized to see.**

> **🔒 Security:** Permission filtering must happen in the database query, not in post-processing. If your vector database returns 20 results and you filter 15 of them for permissions, you're left with 5 results that may not include the most relevant authorized documents. Instead, filter during retrieval so the database returns the top 20 *authorized* results. The `tenant_id` filter in the pgvector code earlier wasn't an afterthought; it's a core requirement.

In practice, permission-aware retrieval requires **tagging every document chunk with access control metadata at ingestion time**. This might be a tenant ID for multi-tenant SaaS, a list of authorized roles for internal tools, or a full ACL (Access Control List) that mirrors your existing authorization system. Your vector database's access control must stay in sync with your source system's access control. When permissions change in Google Drive or Confluence, they must change in your vector store too.

The **Glean architecture** is the most instructive real-world example of permission-aware enterprise RAG. Glean indexes content across dozens of enterprise data sources (Slack, Google Drive, Confluence, Jira, email, and more) and maintains a real-time permissions mirror. When a user searches, Glean doesn't just find semantically relevant documents — it only returns documents that the specific user has access to in the source system. This requires continuous synchronization of permissions, which is one of the hardest engineering challenges in enterprise search. The lesson: if you're building enterprise RAG, plan to spend as much engineering time on permission synchronization as on retrieval quality.

For multi-tenant SaaS applications, row-level security in your vector store is the minimum viable approach. With pgvector, you can leverage PostgreSQL's built-in Row Level Security (RLS) policies:

```python
# rls_setup.py — Row Level Security for multi-tenant RAG
import psycopg2

conn = psycopg2.connect("postgresql://localhost:5432/ragdb")
cur = conn.cursor()

# Enable row level security on the documents table
cur.execute("ALTER TABLE documents ENABLE ROW LEVEL SECURITY")

# Create a policy that restricts access based on the current session's tenant
cur.execute("""
    CREATE POLICY tenant_isolation ON documents
    FOR SELECT
    USING (tenant_id = current_setting('app.current_tenant'))
""")

conn.commit()

# At query time, set the tenant context before searching
def search_as_tenant(tenant_id: str, query_embedding: list[float], limit: int = 5):
    """Search documents with automatic tenant isolation via RLS."""
    cur.execute("SET app.current_tenant = %s", (tenant_id,))
    cur.execute(
        """SELECT id, content, source_file,
                  1 - (embedding <=> %s::vector) AS similarity
           FROM documents
           ORDER BY embedding <=> %s::vector
           LIMIT %s""",
        (query_embedding, query_embedding, limit)
    )
    columns = ["id", "content", "source_file", "similarity"]
    return [dict(zip(columns, row)) for row in cur.fetchall()]
```

With RLS enabled, even if your application code has a bug that forgets to filter by tenant, PostgreSQL will enforce the isolation at the database level. Defense in depth matters. Your security posture shouldn't depend on every query remembering to include a WHERE clause.

## Reality Check

> Most RAG failures trace back to chunking decisions and document preprocessing, not retrieval algorithms or model choice. A week spent on document cleaning and chunking will improve results more than switching vector databases. Before you evaluate embedding models, look at your chunks. Before you add re-ranking, look at your chunks. Before you switch from pgvector to Pinecone, look at your chunks.
>
> And here's the uncomfortable truth that the RAG ecosystem doesn't emphasize enough: **RAG doesn't eliminate hallucination — it changes the source.** Without RAG, a model hallucinates from its training data. With RAG, a model can hallucinate *while citing retrieved documents*. It might misinterpret a passage, combine two passages in a way that produces a false conclusion, or state something with confidence that the source document only mentions tentatively. Users who see citations assume accuracy, which makes RAG hallucinations more dangerous than vanilla hallucinations — they carry the appearance of verification.
>
> Finally, RAG is not always the right architecture. If your corpus fits in context, skip RAG. If your data is structured, query the database. If your use case requires real-time responses, the retrieval overhead might be unacceptable. The best RAG system is the one you don't build when you don't need it.

## Case Study: Perplexity — RAG at Product Scale

Perplexity built its entire product on the premise that RAG can replace traditional search — and in doing so, discovered every failure mode described in this chapter, live, in front of millions of users.

Perplexity's architecture is conceptually straightforward: take a user's question, search the web for relevant pages, retrieve and process the content, then generate an answer with inline citations. Every answer includes numbered references to its sources, which users can click to verify. This citation mechanism is the product's core trust signal, the thing that differentiates Perplexity from simply asking ChatGPT, which provides no source attribution.

But citations create a new failure mode: **misrepresentation**. When Perplexity cites a source, users click through and read the original. If the generated answer doesn't accurately reflect what the source says, if it overstates a finding, omits a crucial caveat, or synthesizes two sources in a misleading way, users notice. And they don't just notice quietly. They screenshot the discrepancy and post it on social media. The citation mechanism that builds trust also creates accountability, and any gap between the cited source and the generated claim erodes both.

This pressure has pushed Perplexity to invest in retrieval quality, not just generation quality. Their challenge spans the full spectrum of RAG problems at massive scale: web content that's poorly structured, queries that require multi-hop reasoning across sources, freshness requirements measured in minutes not days, and an adversarial environment where SEO-optimized pages may rank highly in retrieval but contain low-quality or misleading information.

The lesson for practitioners is twofold. First, if your RAG system surfaces citations to users, you've committed to a higher standard of faithfulness. The model's answers will be checked against the sources, and discrepancies will be caught. Design your eval pipeline accordingly. Second, RAG at product scale means every component of the pipeline, from web crawling to chunking to retrieval to generation, is a potential quality bottleneck, and you need metrics at every stage.

## Case Study: Glean — Enterprise RAG with Permissions

Glean represents the enterprise end of the RAG spectrum, and its architecture illustrates why permission-aware retrieval is an engineering challenge, not just a checkbox.

Glean indexes content across an organization's entire SaaS stack: Slack messages, Google Drive documents, Confluence pages, Jira tickets, email threads, GitHub repos, and dozens more sources. Each of these systems has its own permission model. Google Drive has sharing settings, Slack has channel membership, Confluence has space-level and page-level restrictions, and email is inherently private to specific recipients. Glean must understand and enforce all of these permission models simultaneously.

The core engineering challenge is **permission synchronization**. When a Google Drive document's sharing settings change (a common occurrence in any organization), Glean's index must reflect that change before the next query. If an employee leaves and their access is revoked, Glean must immediately stop surfacing documents they could previously see to prevent data leakage in the other direction. This real-time synchronization across dozens of data sources, each with different APIs and permission models, is arguably harder than the retrieval problem itself.

Glean's approach involves building a unified permissions graph that maps users to the content they can access across all connected systems. At query time, retrieval results are filtered through this graph before reaching the generation model. This filtering happens at the database level — unauthorized documents never enter the retrieval results, the prompt, or the response.

The practical takeaway: if you're building RAG for an enterprise context, start with your permission model. Before you write a single line of retrieval code, answer these questions. How are permissions represented in each source system? How will you synchronize permission changes? What's your acceptable latency between a permission change in the source system and its reflection in your index? What happens when synchronization fails — do you fail open (risking data leakage) or fail closed (risking missing results)? The answers to these questions shape your entire architecture.

## Practical Exercise

**Build a RAG System, Then Deliberately Break It** (estimated: ~8 hours)

This exercise has you build a RAG pipeline over a real document corpus, evaluate it with RAGAS, and then systematically break it to understand failure modes. Use a corpus of at least 50 pages of real documentation — your company's internal docs, a technical specification, an open-source project's documentation, or a collection of research papers. Do not use toy datasets. The whole point is to encounter real-world chunking and retrieval challenges.

**Phase 1: Build (3 hours).** Set up a complete RAG pipeline with the following components: document loading and preprocessing, a chunking strategy (start with semantic chunking), embedding generation (use `text-embedding-3-large`), a vector store (pgvector or Chroma for local development), a retrieval function that returns the top 5 chunks, and a generation step that uses the retrieved chunks to answer questions. Write 20 questions that your corpus should be able to answer — mix simple factual lookups with questions that require synthesizing information from multiple sections.

**Phase 2: Evaluate (2 hours).** Create a ground truth dataset with your 20 questions, the correct answers, and the specific document sections that contain those answers. Run RAGAS evaluation and record your baseline scores for faithfulness, answer relevancy, context precision, and context recall. Separately measure retrieval precision at k=5: for each question, what fraction of the 5 retrieved chunks are actually relevant?

**Phase 3: Break It Three Ways (3 hours).** Introduce three deliberate failures and document each one.

First, **destroy chunking quality**. Switch to fixed-size chunking with a 100-token chunk size and no overlap. Re-run your evaluation. Document which questions fail and why — you'll likely see context recall plummet because important information is split across chunks.

Second, **poison the corpus**. Add 500 short, high-similarity noise documents to your vector store — documents that use the same vocabulary as your real corpus but contain incorrect information. Re-run your evaluation. Document which questions are affected — you'll see context precision drop as noise documents infiltrate the retrieval results, and faithfulness may drop as the model generates answers based on incorrect retrieved content.

Third, **disable hybrid search** (if implemented) or **reduce the retrieval count to k=1**. Re-run your evaluation. Document which questions require multiple chunks or keyword matching to answer correctly — these are the questions that fail when retrieval is too narrow.

For each failure mode, write a paragraph explaining: what broke, how you detected it in the metrics, and what you would do to fix it in a production system. This exercise builds the diagnostic intuition that separates RAG practitioners from RAG consumers.

## Checkpoint

After completing this chapter and the exercise, you should be able to confidently claim the following.

I can design a chunking strategy appropriate for my document types. I understand the tradeoffs between fixed-size, semantic, and parent-child chunking, and I know that chunking quality is the single biggest lever on retrieval quality.

I can implement hybrid search. I understand why combining BM25 keyword search with semantic search outperforms either alone, and I can explain Reciprocal Rank Fusion and when to add re-ranking.

I can evaluate retrieval quality separately from generation quality. I understand the RAGAS metrics (faithfulness, answer relevancy, context precision, context recall) and can use them to diagnose whether a bad answer is a retrieval failure or a generation failure.

I can explain why permission-aware retrieval matters for enterprise. I understand that access control must happen at retrieval time, not generation time, and I can describe the engineering challenges of permission synchronization across multiple data sources.

I understand when RAG is the wrong tool. I can identify cases where in-context learning, direct database queries, or other architectures are more appropriate than retrieval-augmented generation.

---

*Key sources: "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks" (Lewis et al., 2020). "Lost in the Middle: How Language Models Use Long Contexts" (Liu et al., 2023). RAGAS framework: [https://docs.ragas.io](https://docs.ragas.io). MTEB Leaderboard: [https://huggingface.co/spaces/mteb/leaderboard](https://huggingface.co/spaces/mteb/leaderboard).*
