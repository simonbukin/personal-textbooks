# Phase 3: Infrastructure & Operations

## What This Phase Adds

You have a working backend. You can run it locally, test it, and it does what it's supposed to do.

But it's stuck on your laptop.

Phase 3 teaches you to ship it. Containers, CI/CD pipelines, cloud infrastructure, monitoring — the skills that turn a project into a product. This is where many frontend engineers hit a wall. The concepts feel foreign. The tooling is complex. The stakes feel high.

Good news: it's more approachable than it looks. Modern infrastructure tooling has gotten remarkably good. You don't need to understand Linux kernel internals to deploy a container. You don't need a DevOps degree to set up a CI pipeline.

## What You'll Learn

**Chapter 15: Containers and Local Development.** Docker isn't just for deployment — it standardizes your development environment. Learn to containerize your application and run complex local setups with Docker Compose.

**Chapter 16: CI/CD Pipelines.** Every push should trigger tests. Every merge to main should deploy. GitHub Actions makes this straightforward. You'll build a pipeline that gives you confidence in every release.

**Chapter 17: Cloud Infrastructure for Startups.** AWS, GCP, Cloudflare — where should you run your code? This chapter cuts through the complexity with opinionated recommendations and real cost analysis.

**Chapter 18: Observability.** Your app will break in production. Logs, metrics, and traces help you figure out why. Learn to instrument your application and build dashboards that actually help.

**Chapter 19: Load Testing and Reliability.** How do you know your app handles traffic? Load testing before launch beats finding out from angry users. Plus: basic reliability practices that prevent common failure modes.

**Chapter 20: Phase 3 Capstone.** Deploy your TaskFlow backend to the cloud with full observability, automated deployments, and confidence it can handle real traffic.

## The Skill This Phase Builds

The single most important skill from Phase 3: shipping with confidence.

Confidence that:
- Your code works (CI runs tests on every change)
- Deployments are safe (you can roll back in minutes)
- Problems are visible (monitoring catches issues before users report them)
- The system scales (you've tested it under load)

This isn't about becoming an infrastructure expert. It's about removing the fear of deployment. Pushing to production should feel routine, not risky.

## Prerequisites

Before starting Phase 3, you should have:
- Completed the Phase 2 capstone (working backend application)
- Basic command-line comfort
- A GitHub account
- Willingness to create cloud provider accounts (AWS free tier is sufficient)

If you're nervous about cloud costs: everything in this phase can be done within free tiers or for less than $20/month. We'll show you how to set budget alerts and avoid surprises.

## The Frontend Engineer Advantage

You might think infrastructure is unfamiliar territory. But consider what you already know:

- **Build processes.** Webpack, Vite, Babel — you've configured complex build pipelines. Docker builds aren't that different.
- **Environment management.** You've dealt with environment variables, feature flags, and deployment environments.
- **Performance optimization.** You've profiled React components and optimized bundle sizes. Backend profiling uses similar concepts.
- **Monitoring.** Frontend error tracking (Sentry, LogRocket) works the same way as backend observability.

You're not starting from zero. You're extending skills you already have into new territory.

## What Changes From Local to Production

Running code locally is forgiving. Your machine has predictable resources, network access, and you can restart anything at will.

Production is harsher:

**Multiple instances.** Your code runs on several machines simultaneously. Anything stored in memory is machine-specific. File uploads don't automatically appear on other instances.

**Ephemeral environments.** Containers get replaced. Servers restart. Your code must handle being killed and restarted without warning.

**Network boundaries.** Your database isn't on localhost anymore. DNS resolution, connection pooling, and timeouts matter.

**Real users.** Mistakes affect people. Downtime costs money or trust or both.

Phase 3 teaches patterns that make production less scary: containers for consistency, CI/CD for safe deployments, monitoring for visibility, and testing for confidence.

Let's start with containers — the foundation of modern deployment.
