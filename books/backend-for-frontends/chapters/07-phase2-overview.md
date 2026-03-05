# Phase 2: Server Architecture

## What This Phase Adds

You have a solid data layer: Postgres schema, optimized queries, Redis caching, and the judgment to know when to add other data stores. That's the foundation.

Now you need the architecture around it.

Phase 2 is about building a backend codebase that's maintainable, secure, and pleasant to work in. This is where frontend engineers often struggle — not because the concepts are hard, but because the patterns are unfamiliar. On the frontend, you have well-established conventions for component structure, state management, and API consumption. Backend codebases need similar conventions, but they look different.

## What You'll Learn

**Chapter 8: Project Structure and the Modular Monolith.** How to organize a backend codebase so it can evolve without becoming a mess. Why microservices are wrong for you right now, and what to do instead.

**Chapter 9: Authentication, Authorization, and Security.** Use auth providers for identity; build authorization yourself. The OWASP checklist made practical. How to not get hacked.

**Chapter 10: Background Jobs, Queues, and Async Processing.** If the user doesn't need to wait for it, it shouldn't block the response. Building reliable async systems with BullMQ.

**Chapter 11: API Design.** You've consumed APIs for years. Now build ones that frontend engineers actually want to use. REST done right, pagination, streaming, error handling.

**Chapter 12: Testing Strategy.** Not "should I test?" but "what should I test?" A pragmatic approach to testing that gives you confidence without wasting time.

**Chapter 13: Phase 2 Capstone.** The complete backend: your data layer plus authentication, authorization, background jobs, a RESTful API with streaming, and comprehensive tests.

## The Skill This Phase Builds

The single most important skill from Phase 2: structuring a backend so it can evolve without becoming a mess.

A well-structured codebase has:
- Clear boundaries between modules
- Explicit dependencies (no hidden coupling)
- Testable components (you can test a module without starting the entire application)
- Navigable code (a new engineer can figure out where to put new code within 30 minutes)

The goal isn't architectural perfection. It's sustainable velocity — being able to ship features a year from now as fast as you ship them today.

## Prerequisites

Before starting Phase 2, you should be comfortable with:
- Everything from Phase 1 (Postgres, queries, caching)
- Basic HTTP concepts (requests, responses, middleware)
- Async programming in JavaScript/TypeScript

If the Phase 1 capstone gave you trouble, revisit those chapters. Phase 2 builds directly on that foundation.

## What Changes From Frontend to Backend

If you're coming from frontend development, some mental model shifts will help:

**State lives in the database, not in memory.** Frontend apps often keep state in memory (Redux, React Context, component state). Backend state lives in the database. If your server restarts, nothing is lost because state isn't in memory.

**Requests are independent.** Each request is a fresh start. Unlike frontend apps where you build up state over a user session, backend code handles one request at a time, fetches what it needs from the database, does its work, and returns. This is actually simpler once you internalize it.

**Errors have consequences.** A frontend bug might show the wrong text. A backend bug might corrupt data, expose private information, or charge customers incorrectly. The stakes are higher, so the discipline around testing and error handling is more rigorous.

**Multiple users simultaneously.** Frontend code runs for one user. Backend code handles many users at once. This introduces concurrency concerns you didn't have to think about on the frontend. (We covered some of this with database transactions in Phase 1.)

These aren't harder than frontend patterns — they're different. Once you internalize them, backend development feels natural.

Let's start with how to organize the code.
