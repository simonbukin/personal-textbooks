# Appendix A: Tool Recommendations

This appendix collects the opinionated tool recommendations from throughout the book. These are defaults — the tools to choose when you don't have a specific reason to choose otherwise.

## Core Stack

| Category | Recommendation | Why |
|----------|----------------|-----|
| Language | TypeScript (Node.js) | Same language as frontend, excellent ecosystem |
| Framework | Hono or Fastify | Modern, fast, good DX |
| ORM | Drizzle | Type-safe, close to SQL, good performance |
| Database | PostgreSQL | Does everything, excellent ecosystem |
| Cache/Queue | Redis | Simple, fast, solves multiple problems |

## Database Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| pgvector | Vector embeddings | Use for RAG, semantic search |
| pg_stat_statements | Query analysis | Essential for optimization |
| pgBouncer | Connection pooling | Required for serverless/high-instance deployments |

## Infrastructure

| Category | Recommendation | Alternative |
|----------|----------------|-------------|
| Hosting (simple) | Fly.io | Railway, Render |
| Hosting (scale) | AWS ECS Fargate | GCP Cloud Run |
| Database hosting | Fly Postgres, RDS | Supabase, Neon |
| Object storage | Cloudflare R2 | AWS S3 |
| DNS | Cloudflare | Route53 |
| IaC | Terraform | Pulumi, SST |

## CI/CD

| Tool | Purpose |
|------|---------|
| GitHub Actions | CI/CD pipelines |
| Docker | Containerization |
| act | Local GitHub Actions testing |

## Observability

| Category | Recommendation | Free Tier |
|----------|----------------|-----------|
| Logs | Axiom | 500GB/month |
| Metrics | Grafana Cloud | 10K metrics |
| Errors | Sentry | 5K events/month |
| Tracing | OpenTelemetry → Grafana | Included |

## AI/ML

| Category | Recommendation | Alternative |
|----------|----------------|-------------|
| LLM Provider | Anthropic (Claude) | OpenAI |
| Embeddings | Voyage AI | OpenAI embeddings |
| Vector DB | pgvector | Pinecone for scale |

## Development Tools

| Tool | Purpose |
|------|---------|
| pnpm | Package management (faster than npm) |
| Vitest | Testing (faster than Jest) |
| Biome | Linting/formatting (faster than ESLint+Prettier) |
| k6 | Load testing |

## Authentication

| Approach | When to Use |
|----------|-------------|
| Clerk/Auth0 | Quick setup, don't want to manage auth |
| Custom + bcrypt | Full control, specific requirements |
| Passport.js | Complex OAuth needs |

## API Documentation

| Tool | Notes |
|------|-------|
| Scalar | Modern OpenAPI documentation |
| Swagger UI | Classic, widely supported |

## Secrets Management

| Environment | Recommendation |
|-------------|----------------|
| Local | dotenv + .env files (gitignored) |
| Fly.io | `fly secrets` |
| AWS | Secrets Manager or SSM Parameter Store |

## Monitoring Services

| Service | Strength |
|---------|----------|
| Better Stack | Clean UI, good alerting |
| Datadog | Full-featured, expensive |
| Grafana Cloud | Good free tier, OSS-friendly |

## Background Jobs

| Tool | When |
|------|------|
| BullMQ | Default choice for Node.js |
| Inngest | Event-driven, good DX |
| Temporal | Complex, long-running workflows |

## Cost Reference (Monthly)

| Service | Free Tier | Typical Startup |
|---------|-----------|-----------------|
| Fly.io (app) | ~$5/month | $30-100 |
| Fly.io Postgres | — | $15-50 |
| Redis (Upstash) | 10K commands/day | $10-50 |
| Sentry | 5K events | Free |
| Anthropic API | — | $20-200 |
| GitHub Actions | 2K minutes | Free |

## What to Avoid

| Tool | Why |
|------|-----|
| Express.js | Legacy, slower, less ergonomic than alternatives |
| MongoDB (as default) | Postgres does what you need with better guarantees |
| Kubernetes (early) | Operational complexity without the team to support it |
| AWS Lambda (for APIs) | Cold starts, complexity, vendor lock-in |
| Microservices (early) | Coordination overhead exceeds benefits at small scale |
| GraphQL (without need) | Complexity without clear benefit for simple APIs |

## Making Different Choices

These recommendations assume a TypeScript-heavy, startup-focused environment. Valid reasons to choose differently:

- **Team expertise:** If your team knows Python well, use FastAPI
- **Compliance requirements:** Some industries mandate specific providers
- **Existing infrastructure:** Don't migrate working systems without reason
- **Scale requirements:** What works at seed stage may not at Series C
- **Specific features:** Sometimes a specialized tool is worth its complexity

The goal isn't to follow these recommendations blindly. It's to have a sensible default that you deviate from consciously and for good reasons.
