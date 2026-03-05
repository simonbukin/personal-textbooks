# Phase 5: AI-Native Engineering

## What This Phase Adds

AI isn't a feature you bolt on — it's a capability that changes how you build software. This phase teaches you to build AI-powered features and use AI in your engineering workflow.

You've already used AI throughout this book as a learning tool: generating test data, reviewing schemas, challenging your designs. Now you'll integrate AI into your products, building features that weren't possible two years ago.

## What You'll Learn

**Chapter 27: LLM Integration Patterns.** Connect to language models, handle streaming responses, manage costs, and implement common patterns like summarization and extraction.

**Chapter 28: RAG Pipelines.** Build retrieval-augmented generation systems. Embed documents, search semantically, and ground LLM responses in your data.

**Chapter 29: Agent Backends.** Create AI systems that take actions. Tool use, function calling, and orchestrating multi-step workflows.

**Chapter 30: AI in Your Engineering Workflow.** Use AI effectively as an engineer — code generation, debugging, documentation, and knowing when AI helps vs. hurts.

**Chapter 31: Phase 5 Capstone.** Build a complete AI-powered feature from scratch, demonstrating everything you've learned.

## The Skill This Phase Builds

The single most important skill from Phase 5: **AI pragmatism**.

AI is powerful but not magic. It hallucinates. It's expensive. It's slow compared to traditional code. The skill is knowing when AI is the right tool and when it isn't.

After this phase, you'll be able to evaluate AI feature requests critically, build AI features that actually work, and avoid the common pitfalls that turn AI projects into expensive experiments.

## Prerequisites

Before starting Phase 5, you should have:
- Completed previous phases (you have a production-ready backend)
- Accounts with at least one AI provider (OpenAI, Anthropic, or similar)
- Basic understanding of what LLMs can and can't do

> **A Note on Model Currency:** AI models evolve rapidly. The model names in this book (Claude Sonnet 4.5, GPT-5, etc.) reflect what's current at the time of writing. By the time you read this, newer versions likely exist. The patterns and integration techniques remain stable; the specific model identifiers don't. Always check provider documentation for current model names and pricing. The code examples use constants for model names — update them once rather than scattered throughout your codebase.

## Why AI Matters for Backend Engineers

Frontend engineers often interact with AI through pre-built components — chatbots, autocomplete, image generation widgets. The backend is where AI gets interesting:

- **Integration complexity:** LLMs are external APIs with unique characteristics (streaming, variable latency, rate limits)
- **Cost management:** AI calls are expensive compared to database queries — your architecture must account for this
- **Data grounding:** RAG systems require backend infrastructure — vector databases, embedding pipelines, retrieval logic
- **Agent orchestration:** AI that takes actions needs backend coordination — tool execution, state management, safety controls

AI features are backend problems first, frontend problems second.

## What AI Changes

Building AI features differs from traditional backend work:

**Non-deterministic outputs.** The same input produces different outputs. Testing, caching, and debugging all become harder.

**Latency expectations change.** LLM calls take seconds, not milliseconds. Users expect this for AI features — streaming makes the wait feel productive.

**Cost per request matters.** A database query costs fractions of a cent. An LLM call costs cents to dollars. Your architecture must minimize unnecessary AI calls.

**Prompt engineering is development.** The prompts you write are part of your system. They need versioning, testing, and iteration.

## The AI-Native Stack

By the end of this phase, you'll be comfortable with:

| Component | Purpose | Examples |
|-----------|---------|----------|
| LLM Provider | Generate text | OpenAI, Anthropic, Google |
| Vector Database | Semantic search | pgvector, Pinecone, Qdrant |
| Embedding Model | Convert text to vectors | OpenAI embeddings, Cohere |
| Prompt Templates | Structure LLM inputs | Handlebars, custom |
| Output Parsers | Extract structured data | Zod, JSON schema |
| Orchestrators | Coordinate multi-step AI | LangChain, custom |

You don't need all of these for every feature. Simple features need only an LLM API. Complex features layer more components.

## A Warning About AI Hype

AI companies want you to believe every feature needs AI. It doesn't.

**Don't use AI for:**
- Deterministic logic (calculations, lookups, CRUD)
- Latency-critical paths (AI is slow)
- High-volume low-value operations (AI is expensive)
- Situations where accuracy is non-negotiable (AI makes mistakes)

**Do use AI for:**
- Understanding unstructured input (natural language, documents)
- Generating content (summaries, drafts, suggestions)
- Fuzzy matching and semantic search
- Tasks where good-enough beats perfect

The best AI features are ones where AI enables something new, not where AI replaces something that worked fine.

Let's start with the fundamentals of connecting to language models.
