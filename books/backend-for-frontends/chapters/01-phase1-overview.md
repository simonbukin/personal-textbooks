# Phase 1: The Data Layer

## Why Data Comes First

For a senior frontend engineer learning backend, the biggest real gap isn't writing route handlers — you can pick that up in an afternoon. The gap is the data layer.

You've consumed APIs for years. You know what a good response shape looks like, how to handle loading states, how to cache data on the client. But the other side — how that data is structured, stored, queried, and evolved — is where the most consequential decisions live.

Bad data modeling compounds faster than any other technical debt. A poorly designed schema doesn't just slow down queries; it shapes what features you can build and how hard they are to build. It influences every API endpoint, every business rule, every migration you'll ever write against that database. Fix a bad schema after two years of production data and you're looking at weeks of careful migration work and testing.

Get the data layer right and everything else is easier. Get it wrong and you'll fight it forever.

## What You'll Learn

Phase 1 covers the complete data stack for a modern backend:

**Chapter 2: PostgreSQL as Your Default Answer.** Why Postgres specifically — not just "use a relational database." You'll learn schema design for real products, migrations as a first-class concern, indexes that actually help, and transactions that prevent data corruption.

**Chapter 3: Queries, Performance, and the N+1 Problem.** You've seen slow APIs from the frontend. Now you'll find and fix the query-level problems that cause them. SQL fluency, reading EXPLAIN ANALYZE like a diagnostic tool, and the ORM trade-offs you're making.

**Chapter 4: Redis and the Art of Caching.** When to cache, what to cache, and how to invalidate without causing stale data bugs. Rate limiting, session storage, and the decision framework for whether caching even helps.

**Chapter 5: Beyond Postgres: When and Why.** Document stores, search engines, blob storage, vector databases. The real triggers for reaching for something other than Postgres, and the operational cost of each additional system.

**Chapter 6: Phase 1 Capstone.** Build the complete data layer for a SaaS project management tool, integrating everything from the phase.

## What You'll Build

By the end of Phase 1, you'll have built the complete data layer for a SaaS project management tool:

- A PostgreSQL schema with workspaces, users, projects, tasks, comments, and activity logs — designed for multi-tenancy and schema evolution
- Redis caching on hot paths, with a cache invalidation strategy that doesn't cause stale data bugs
- S3 integration for file attachments, with presigned URLs for secure upload and download
- pgvector for a "find similar tasks" feature — your first AI-native capability
- A migration history that could handle a zero-downtime deployment
- 100,000+ rows of realistic seed data to performance-test against

This isn't a toy project. It's the foundation a real product could be built on.

## The Skill This Phase Builds

The single most important skill you'll develop in Phase 1: looking at a schema or data architecture and knowing whether it'll age well.

You'll learn to ask the questions that experienced backend engineers ask instinctively:

- What happens when this product requirement changes?
- What queries will this schema make painful?
- Where will this get slow at 10x the data?
- What's the migration path when we need to add this feature?
- What are the failure modes when two operations happen concurrently?

That instinct — the ability to see the second-order consequences of data decisions — is what separates engineers who can own the backend from those who just write code against it.

## Prerequisites

This phase assumes you can:
- Read and write TypeScript comfortably
- Use the terminal for basic navigation and commands
- Run Docker containers (we'll use Docker Compose for local Postgres and Redis)
- Understand basic SQL syntax (SELECT, INSERT, UPDATE, WHERE, JOIN)

If you've done any backend work, you probably have these. If you haven't touched SQL in years, spend an hour refreshing yourself before diving in — the chapter explanations will make more sense.

Let's start with the foundation: PostgreSQL.
