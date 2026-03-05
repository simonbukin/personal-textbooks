# Capstone: System Design Portfolio

## The Challenge

You've studied design patterns, learned from real-world architectures, and built a scaling playbook. Now apply it all to create a system design portfolio piece.

This capstone is different from previous phases — it's primarily a design exercise, not a coding one. You'll design a complete system, document your decisions, and defend your choices.

## The Task

Design a **collaborative document editor** (like Notion or Google Docs) from requirements to architecture.

### Requirements

**Core features:**
- Users create and edit documents
- Real-time collaboration (multiple users editing simultaneously)
- Document history with version tracking
- Comments and mentions
- Folders and organization

**Scale targets:**
- 100K monthly active users
- 1M documents
- 50 concurrent editors per document (typical: 2-5)
- 99.9% availability

**Constraints:**
- Small engineering team (5-10 people)
- Limited initial budget (cloud costs < $5K/month)
- Must ship MVP in 3 months

## Deliverables

### 1. Architecture Document (Primary Deliverable)

A comprehensive document covering:

**System Overview**
- High-level architecture diagram
- Core components and their responsibilities
- Technology choices with justification

**Data Model**
- Entity relationships
- Database schema (key tables)
- How you handle document content

**Real-Time Collaboration**
- How concurrent edits are handled
- Conflict resolution approach
- WebSocket architecture

**Scaling Strategy**
- Current bottlenecks at target scale
- First three scaling moves when limits are hit
- What you'd change with 10x users

**Trade-off Analysis**
- Key decisions and what alternatives you rejected
- What you'd reconsider with different constraints

### 2. Technical Prototype (Optional)

Build one challenging component to validate your design:
- Real-time sync for a single document
- Operational transform or CRDT implementation
- Version history with diff visualization

### 3. Design Defense

Prepare to answer:
- Why this database choice?
- How do you handle a document with 100 concurrent editors?
- What fails first under extreme load?
- How would your design change if you needed offline support?

## Evaluation Criteria

Your design succeeds if:

**Completeness**
- [ ] All major components are addressed
- [ ] Data flows are clear
- [ ] Edge cases are considered

**Justified decisions**
- [ ] Technology choices have clear reasoning
- [ ] Trade-offs are explicitly stated
- [ ] Alternatives are acknowledged

**Appropriate scope**
- [ ] Design matches team size and budget
- [ ] MVP features prioritized over nice-to-haves
- [ ] Scaling path is realistic, not over-engineered

**Demonstrates understanding**
- [ ] Real-time collaboration challenges are addressed
- [ ] Consistency vs availability trade-offs are clear
- [ ] Operational concerns (monitoring, debugging) are mentioned

## Hints and Guidance

### Real-Time Collaboration

This is the hardest part. Two main approaches:

**Operational Transformation (OT):** Transform operations to maintain consistency. Used by Google Docs. Complex but battle-tested.

**CRDTs (Conflict-free Replicated Data Types):** Data structures that merge automatically. Used by Figma, Linear. Simpler semantically but can be memory-intensive.

For an MVP, consider simpler approaches:
- Lock-based editing (one editor at a time)
- Last-write-wins with conflict markers
- Granular locking (paragraph-level)

### Document Storage

Options to consider:
- **Structured JSON:** Store document as JSON, edit via JSON operations
- **Block-based:** Documents as arrays of blocks (Notion approach)
- **Plain text with markup:** Markdown or similar
- **Dedicated rich text storage:** ProseMirror/Slate document format

### Don't Over-Engineer

A 3-month MVP doesn't need:
- Multi-region deployment
- Custom database sharding
- Kubernetes
- Event sourcing (unless version history is critical)

Start simple. A monolith with PostgreSQL and Redis handles this scale.

## Resources

Study these before designing:
- How Figma's multiplayer works
- Notion's data model (blocks)
- Google Docs and Operational Transformation
- Yjs/Automerge (CRDT libraries)

## Timeline

**Week 1:**
- Research real-time collaboration approaches
- Draft high-level architecture
- Define data model

**Week 2:**
- Detail each component
- Write trade-off analysis
- Optional: Build prototype of hardest component

**Week 3:**
- Refine documentation
- Prepare design defense
- Get feedback from peers

## What You're Proving

This capstone demonstrates that you can:
- Break down a complex problem into tractable components
- Make and justify architectural decisions
- Balance ideal solutions against practical constraints
- Communicate technical designs clearly

These skills matter more than memorizing specific technologies. They're what distinguish senior engineers from intermediate ones.
