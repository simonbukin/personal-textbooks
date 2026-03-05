# Capstone: Production-Ready TaskFlow

## The Challenge

You've learned the pieces: containers, CI/CD, cloud infrastructure, observability, and load testing. Now you'll combine them into a production-ready deployment of your TaskFlow API.

The goal is not just "running in the cloud" but running in the cloud with confidence — you can deploy changes safely, monitor for problems, and understand your system's capacity.

## Requirements

### Infrastructure

Deploy TaskFlow to a cloud platform with:

1. **Containerized application** running on Fly.io (or equivalent)
2. **Managed PostgreSQL** with automated daily backups
3. **Managed Redis** for caching and background job queues
4. **Custom domain** with HTTPS (e.g., `api.taskflow.dev`)
5. **Environment separation** — staging and production with separate databases

### CI/CD Pipeline

Build a GitHub Actions pipeline that:

1. **On every PR:**
   - Runs linting and type checking
   - Runs tests with real PostgreSQL and Redis
   - Runs security audit (`npm audit`)
   - Builds Docker image (but doesn't push)

2. **On merge to main:**
   - All PR checks pass
   - Deploys to staging automatically
   - Runs smoke test against staging

3. **Production deployment:**
   - Requires manual approval
   - Runs database migrations safely
   - Deploys with zero downtime
   - Verifies health check passes

### Observability

Implement comprehensive observability:

1. **Structured logging** with request ID correlation
2. **Prometheus metrics** for the four golden signals
3. **Error tracking** with Sentry (or equivalent)
4. **Dashboard** with at least:
   - Request rate and error rate
   - Latency percentiles (p50, p95, p99)
   - Active database connections
5. **Alerts** for:
   - Error rate > 5% for 5 minutes (critical)
   - p95 latency > 2s for 10 minutes (warning)

### Load Testing

Validate your deployment can handle real traffic:

1. **Load test script** that simulates realistic usage
2. **Documented baseline** showing:
   - Maximum sustainable RPS before degradation
   - Resource utilization at various load levels
   - The first bottleneck you would hit
3. **CI integration** that runs load test against staging

### Reliability

Build in fault tolerance:

1. **Retry logic** for external API calls
2. **Timeouts** on all database and external calls
3. **Health check endpoint** that verifies dependencies
4. **Feature flag** for at least one feature with rollout percentage

## Deliverables

### 1. Infrastructure as Code

```
infrastructure/
├── fly.toml           # Application configuration
├── Dockerfile         # Production container
├── docker-compose.yml # Local development
└── README.md          # Setup instructions
```

### 2. CI/CD Configuration

```
.github/workflows/
├── ci.yml             # PR checks
├── deploy-staging.yml # Auto-deploy to staging
└── deploy-prod.yml    # Manual production deploy
```

### 3. Observability Setup

```
observability/
├── dashboard.json     # Grafana dashboard export
├── alerts.yml         # Alert rules
└── README.md          # How to access monitoring
```

### 4. Load Test Suite

```
load-tests/
├── smoke.js           # Quick validation
├── stress.js          # Find breaking points
├── baseline.md        # Documented capacity baseline
└── README.md          # How to run tests
```

### 5. Architecture Document

A single document (`ARCHITECTURE.md`) covering:

- System diagram showing all components
- Data flow for a typical request
- Deployment process step-by-step
- Rollback procedure
- Known limitations and future improvements

## Evaluation Criteria

Your capstone succeeds if you can confidently answer:

**Deployment:**
- [ ] Can you deploy a code change to production in under 15 minutes?
- [ ] Can you roll back a bad deployment in under 5 minutes?
- [ ] Do migrations run without downtime?

**Monitoring:**
- [ ] If the API starts returning errors, will you know within 5 minutes?
- [ ] Can you trace a slow request to find the bottleneck?
- [ ] Do you know your current error rate and p95 latency?

**Capacity:**
- [ ] Do you know the maximum RPS your system handles?
- [ ] Do you know what fails first under extreme load?
- [ ] Would you notice if traffic doubled overnight?

**Reliability:**
- [ ] What happens if the database is slow for 30 seconds?
- [ ] What happens if Redis is completely down?
- [ ] Can you disable a problematic feature without deploying?

## Suggested Timeline

This capstone takes 1-2 weeks of part-time work:

**Week 1:**
- Day 1-2: Deploy to Fly.io with database
- Day 3: Set up CI/CD pipeline
- Day 4-5: Add logging and metrics

**Week 2:**
- Day 1-2: Set up dashboard and alerts
- Day 3: Write and run load tests
- Day 4: Add reliability patterns
- Day 5: Write architecture document

## Common Pitfalls

**Deploying without staging first**
Always deploy to staging, verify, then promote to production. Never go straight to production.

**Alerts that fire constantly**
If an alert fires more than once a week without requiring action, it's noise. Fix the threshold or delete the alert.

**Load testing against production**
Don't. Run load tests against staging or a separate test environment. Load testing production impacts real users.

**Skipping the architecture document**
Writing forces clarity. If you can't explain your deployment process in a document, you'll struggle to explain it at 3am when something is broken.

## Extension Challenges

If you complete the core requirements:

1. **Blue-green deployments** — Run two production environments and switch traffic between them

2. **Database read replicas** — Add a read replica and route read traffic to it

3. **Geographic distribution** — Deploy to multiple regions with latency-based routing

4. **Chaos testing** — Randomly kill containers in staging and verify the system recovers

## What You've Built

By completing this capstone, you've built something real: a production-ready API with professional infrastructure. You can:

- Ship code changes with confidence
- Know when things break before users tell you
- Understand your system's limits
- Recover from failures quickly

This is what "full-stack with infrastructure skills" looks like. You're no longer dependent on someone else to deploy your code or debug production issues. That's a significant capability upgrade.
