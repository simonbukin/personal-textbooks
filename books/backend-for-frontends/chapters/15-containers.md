# Containers and Local Development

## Why This Matters

"It works on my machine."

This phrase has haunted software development for decades. Your code runs perfectly locally, then breaks in staging. Someone joins the team and spends two days setting up their environment. A system update breaks something mysteriously.

Containers solve this by packaging your application with its entire runtime environment. The same container that runs on your laptop runs in CI, staging, and production. No more environment drift. No more setup documentation that's always out of date.

Docker has become so standard that knowing containers isn't optional anymore — it's baseline competency. This chapter teaches you to containerize Node.js applications effectively and use Docker Compose to manage complex local development environments.

## Docker Mental Model

A container is a lightweight, isolated environment that runs your application. Think of it as a virtual machine, but much smaller and faster because it shares the host's kernel.

Key concepts:

**Image:** A read-only template containing your application and its dependencies. You build images from Dockerfiles.

**Container:** A running instance of an image. You can have multiple containers from the same image.

**Registry:** A storage location for images. Docker Hub is public; Amazon ECR, Google Artifact Registry, and GitHub Container Registry are common private options.

**Volume:** Persistent storage that survives container restarts. Essential for databases and file uploads.

The workflow:

```
Dockerfile → docker build → Image → docker run → Container
```

## Your First Dockerfile

Here's a Dockerfile for a Node.js/TypeScript application:

```dockerfile
# Dockerfile
FROM node:20-alpine

WORKDIR /app

# Copy package files first (layer caching optimization)
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build TypeScript
RUN npm run build

# Expose port
EXPOSE 3000

# Start the application
CMD ["node", "dist/index.js"]
```

Build and run it:

```bash
docker build -t my-api .
docker run -p 3000:3000 my-api
```

The `-t` flag tags the image with a name. The `-p` flag maps ports (host:container).

This works, but it's not production-ready. Let's improve it.

### Multi-Stage Builds

The image above includes TypeScript source, devDependencies, and build tools — none of which are needed at runtime. Multi-stage builds fix this:

```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS runner

WORKDIR /app

# Copy only production dependencies
COPY package*.json ./
RUN npm ci --omit=dev

# Copy built application
COPY --from=builder /app/dist ./dist

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 hono
USER hono

EXPOSE 3000

CMD ["node", "dist/index.js"]
```

Results:
- Builder stage: Install everything, compile TypeScript
- Runner stage: Only production dependencies and compiled output
- Image size drops from ~400MB to ~150MB
- No dev tools or source code in production image

This pattern works for any compiled language. The builder does the heavy lifting; the runner contains only what's needed at runtime.

### Choosing Base Images

The base image affects size, security, and compatibility:

**node:20** (Debian-based, ~900MB)
- Full-featured, most compatible
- Large size, slower pulls
- Good for debugging, development

**node:20-slim** (Debian slim, ~200MB)
- Smaller, fewer utilities
- Missing some C libraries
- Good middle ground

**node:20-alpine** (Alpine Linux, ~145MB)
- Smallest, fastest pulls
- Uses musl instead of glibc
- Most native modules work, some don't
- Best for production

For most Node.js apps, Alpine works fine. Switch to slim if you hit compatibility issues with native modules.

🔒 **Security Callout:** Always run containers as non-root. The `USER` directive switches to a limited user, so even if an attacker compromises your app, they can't modify system files.

### Optimizing Layer Caching

Docker caches each layer. If a layer hasn't changed, Docker reuses it. Order your Dockerfile to maximize cache hits:

```dockerfile
# ✅ Good: Dependencies change less often than code
COPY package*.json ./
RUN npm ci
COPY . .

# ❌ Bad: Any code change invalidates npm install cache
COPY . .
RUN npm ci
```

For even better caching, copy specific files:

```dockerfile
COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build
```

### Environment Variables

Never hardcode configuration. Use environment variables:

```dockerfile
# Set defaults (can be overridden at runtime)
ENV NODE_ENV=production
ENV PORT=3000

CMD ["node", "dist/index.js"]
```

Pass environment variables at runtime:

```bash
docker run -p 3000:3000 \
  -e DATABASE_URL=postgres://... \
  -e REDIS_URL=redis://... \
  my-api
```

Or use an env file:

```bash
docker run -p 3000:3000 --env-file .env.production my-api
```

### Health Checks

Tell Docker how to check if your container is healthy:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1
```

Your app needs a health endpoint:

```typescript
// src/routes/health.ts
app.get('/health', (c) => {
  return c.json({ status: 'ok', timestamp: new Date().toISOString() })
})
```

Orchestrators (Kubernetes, ECS) use health checks to detect and replace unhealthy containers.

## Docker Compose for Local Development

Running `docker run` with multiple flags is tedious. Docker Compose defines multi-container environments in YAML:

```yaml
# docker-compose.yml
services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgres://postgres:postgres@db:5432/app
      - REDIS_URL=redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - ./src:/app/src  # Hot reload in development
    command: npm run dev

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data

volumes:
  postgres-data:
  redis-data:
```

Start everything:

```bash
docker compose up
```

Rebuild after Dockerfile changes:

```bash
docker compose up --build
```

Run in background:

```bash
docker compose up -d
```

Stop everything:

```bash
docker compose down
```

Delete volumes too (reset database):

```bash
docker compose down -v
```

### Development vs. Production Compose Files

Use multiple Compose files for different environments:

```yaml
# docker-compose.yml (base)
services:
  api:
    build: .
    environment:
      - NODE_ENV=production

  db:
    image: postgres:16-alpine
```

```yaml
# docker-compose.override.yml (development overrides, auto-loaded)
services:
  api:
    environment:
      - NODE_ENV=development
    volumes:
      - ./src:/app/src
    command: npm run dev

  db:
    ports:
      - "5432:5432"  # Expose for local tools
```

```yaml
# docker-compose.prod.yml (production overrides)
services:
  api:
    image: ghcr.io/myorg/my-api:latest  # Use pre-built image
    restart: always

  db:
    # No exposed ports in production
    restart: always
```

Run with specific files:

```bash
# Development (uses docker-compose.yml + docker-compose.override.yml)
docker compose up

# Production
docker compose -f docker-compose.yml -f docker-compose.prod.yml up
```

💸 **Startup Cost Callout:** Docker Desktop is free for personal use and small businesses. For larger organizations, alternatives like Podman, Colima, or Rancher Desktop are free and compatible.

## Hot Reloading in Containers

For development, you want code changes to appear immediately without rebuilding:

```yaml
# docker-compose.override.yml
services:
  api:
    volumes:
      # Mount source code
      - ./src:/app/src
      - ./package.json:/app/package.json
      # Prevent node_modules from being overwritten
      - /app/node_modules
    command: npm run dev
```

Your dev script should use a file watcher:

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts"
  }
}
```

Changes to files in `./src` on your host machine immediately reflect in the container because of the volume mount.

### Debugging in Containers

Attach a debugger to a containerized Node.js process:

```yaml
services:
  api:
    command: node --inspect=0.0.0.0:9229 dist/index.js
    ports:
      - "3000:3000"
      - "9229:9229"  # Debug port
```

In VS Code, create a debug configuration:

```json
{
  "type": "node",
  "request": "attach",
  "name": "Docker: Attach",
  "port": 9229,
  "address": "localhost",
  "localRoot": "${workspaceFolder}",
  "remoteRoot": "/app"
}
```

## Database Migrations in Docker

Run migrations before your app starts:

```yaml
services:
  api:
    depends_on:
      migrate:
        condition: service_completed_successfully

  migrate:
    build: .
    command: npm run db:migrate
    environment:
      - DATABASE_URL=postgres://postgres:postgres@db:5432/app
    depends_on:
      db:
        condition: service_healthy
```

Or run migrations as part of the entrypoint:

```dockerfile
# Create an entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["node", "dist/index.js"]
```

```bash
#!/bin/sh
# entrypoint.sh
set -e

echo "Running migrations..."
npm run db:migrate

echo "Starting application..."
exec "$@"
```

🤔 **Taste Moment:** For local development, running migrations in a separate service is cleaner — you can see migration output easily and restart just the app without re-running migrations. For production, the entrypoint approach ensures migrations always run before the app starts.

## .dockerignore

Like `.gitignore`, `.dockerignore` excludes files from the build context. This matters for two reasons:

1. **Speed:** Docker sends the entire build context to the daemon. If `node_modules` is included, that's hundreds of megabytes.
2. **Security:** Prevent accidentally including secrets or sensitive files.

```
# .dockerignore
node_modules
npm-debug.log
.env
.env.*
.git
.gitignore
Dockerfile*
docker-compose*
README.md
*.md
.vscode
.idea
coverage
.nyc_output
dist
```

Always include `.dockerignore` in your projects. It makes builds faster and safer.

## Building for Production

### Image Tagging Strategy

Tag images meaningfully:

```bash
# Don't use :latest in production
docker build -t my-api:latest .  # ❌ Ambiguous

# Use commit SHA for traceability
docker build -t my-api:abc123f .  # ✅ Traceable

# Use semantic versioning for releases
docker build -t my-api:1.2.3 .    # ✅ Clear version
```

A common pattern:

```bash
VERSION=$(git rev-parse --short HEAD)
docker build -t my-api:${VERSION} -t my-api:latest .
```

This creates two tags: the commit SHA (for rollbacks) and `latest` (for convenience).

### Scanning for Vulnerabilities

Check your images for known security vulnerabilities:

```bash
# Docker Scout (built into Docker Desktop)
docker scout cves my-api:latest

# Trivy (open source, widely used)
trivy image my-api:latest
```

Integrate scanning into CI to catch issues before deployment.

### Reducing Image Size

Smaller images mean faster deployments and reduced attack surface.

Strategies:
1. **Use Alpine base images:** `node:20-alpine` instead of `node:20`
2. **Multi-stage builds:** Only include what's needed at runtime
3. **Clean up in the same layer:** `RUN npm ci && npm cache clean --force`
4. **Use .dockerignore:** Don't copy unnecessary files

Compare sizes:

```bash
docker images my-api
REPOSITORY   TAG         SIZE
my-api       alpine      145MB
my-api       full        892MB
```

### Minimizing Layers

Each Dockerfile instruction creates a layer. Combine commands to reduce layers:

```dockerfile
# ❌ Multiple layers
RUN addgroup --system nodejs
RUN adduser --system hono
RUN chown -R hono:nodejs /app

# ✅ Single layer
RUN addgroup --system nodejs \
    && adduser --system hono \
    && chown -R hono:nodejs /app
```

However, don't sacrifice readability for minimal layers. Docker's layer caching often benefits from more granular layers.

## Resource Limits

Containers can consume unlimited host resources by default. In production, set limits:

```yaml
services:
  api:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
```

**limits:** Maximum resources the container can use
**reservations:** Guaranteed minimum resources

For Node.js, also set the heap limit:

```dockerfile
ENV NODE_OPTIONS="--max-old-space-size=384"
```

Set this to about 75% of your memory limit, leaving room for other memory usage.

### Graceful Shutdown

Containers receive signals when stopping. Handle them properly:

```typescript
// src/index.ts
const server = app.listen(3000)

function shutdown() {
  console.log('Shutting down gracefully...')

  server.close(() => {
    console.log('HTTP server closed')
    // Close database connections, etc.
    process.exit(0)
  })

  // Force exit after timeout
  setTimeout(() => {
    console.error('Forced shutdown after timeout')
    process.exit(1)
  }, 10000)
}

process.on('SIGTERM', shutdown)
process.on('SIGINT', shutdown)
```

Docker sends SIGTERM first, waits (default 10 seconds), then sends SIGKILL. Handle SIGTERM to close connections gracefully.

## Container Logging

Application logs go to stdout/stderr. Docker captures them:

```typescript
// ✅ Log to stdout
console.log('Server started on port 3000')

// ❌ Don't log to files in containers
fs.appendFileSync('/var/log/app.log', message)
```

Docker Compose aggregates logs:

```bash
docker compose logs api        # Logs from api service
docker compose logs -f         # Follow all service logs
docker compose logs --tail=100 # Last 100 lines
```

For production, ship logs to a logging service (CloudWatch, Datadog, etc.) — covered in Chapter 18.

### Structured Logging

Use JSON logs for production. They're easier to parse and query:

```typescript
// Development: human-readable
console.log('User created: john@example.com')

// Production: structured JSON
console.log(JSON.stringify({
  level: 'info',
  message: 'User created',
  email: 'john@example.com',
  timestamp: new Date().toISOString()
}))
```

Use a logging library (Pino, Winston) to switch formats by environment.

## Container Networking

Docker Compose creates a network where services can reach each other by name:

- `db` resolves to the database container
- `redis` resolves to the Redis container
- `api` resolves to the API container

From your API container:

```
postgres://postgres:postgres@db:5432/app  ← "db" is the service name
redis://redis:6379                        ← "redis" is the service name
```

To expose services to your host machine, use `ports`:

```yaml
services:
  db:
    ports:
      - "5432:5432"  # host:container
```

Now your local database tools can connect to `localhost:5432`.

### Network Isolation

By default, services can reach each other. For more control, define networks:

```yaml
services:
  api:
    networks:
      - frontend
      - backend

  db:
    networks:
      - backend  # Only accessible from backend network

  nginx:
    networks:
      - frontend  # Can reach api, not db

networks:
  frontend:
  backend:
```

This prevents the web tier from directly accessing the database — only the API can.

## Secrets Management in Docker

Don't put secrets in images or Compose files. Options:

**Environment files:**
```yaml
services:
  api:
    env_file:
      - .env.production  # gitignored
```

**Docker secrets (Swarm mode):**
```yaml
services:
  api:
    secrets:
      - db_password

secrets:
  db_password:
    external: true  # Created with `docker secret create`
```

**External secret managers:**
Fetch secrets at runtime from AWS Secrets Manager, HashiCorp Vault, or Doppler. This is the production-grade approach covered in Chapter 9.

## Development Workflow Tips

### Shell into Running Containers

```bash
# Get a shell in a running container
docker compose exec api sh

# Run a one-off command
docker compose exec api npm run db:seed
```

### Watching Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f api

# Last 100 lines then follow
docker compose logs --tail=100 -f api
```

### Rebuilding a Single Service

```bash
# Rebuild and restart just the API
docker compose up --build api
```

### Fresh Start

```bash
# Stop, remove volumes, rebuild everything
docker compose down -v
docker compose up --build
```

### Running Tests

```bash
# Run tests in a container with test database
docker compose run --rm api npm test

# Or use a separate test compose file
docker compose -f docker-compose.test.yml up --abort-on-container-exit
```

🔒 **Security Callout:** Never use `privileged: true` in production. It gives the container root access to the host. Even in development, avoid it unless absolutely necessary for specific tooling.

## Dev Containers

For teams, consider Dev Containers (`.devcontainer/devcontainer.json`). They let VS Code or other editors run inside a container, ensuring everyone has identical development environments:

```json
// .devcontainer/devcontainer.json
{
  "name": "TaskFlow Dev",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "api",
  "workspaceFolder": "/app",
  "customizations": {
    "vscode": {
      "extensions": [
        "esbenp.prettier-vscode",
        "dbaeumer.vscode-eslint"
      ]
    }
  },
  "postCreateCommand": "npm install"
}
```

New team members clone the repo, open in VS Code, click "Reopen in Container," and they're ready to code. No setup documentation required.

## The Taste Test

**Scenario 1:** A Dockerfile copies the entire project directory, then runs `npm install`. Every code change rebuilds all dependencies.

*What's wrong?* Layer caching is broken. Copy `package*.json` first, run `npm ci`, then copy the rest. Dependencies only reinstall when `package.json` changes.

**Scenario 2:** A production container runs as root.

*What's the risk?* If the application is compromised, the attacker has root access. Add a non-root user with `adduser` and switch to it with `USER`.

**Scenario 3:** Database credentials are hardcoded in docker-compose.yml.

*What would you change?* Use an `.env` file that's gitignored, or environment variable interpolation: `POSTGRES_PASSWORD=${DB_PASSWORD}`.

**Scenario 4:** A developer complains that Docker builds are slow, taking 5+ minutes each time.

*How do you speed it up?* Check layer ordering, add a `.dockerignore` file to exclude `node_modules` and other large directories from the build context, and consider using BuildKit for parallel builds.

**Scenario 5:** The API container starts before the database is ready, causing connection errors.

*The fix?* Use `depends_on` with `condition: service_healthy` and add a healthcheck to the database service.

## Practical Exercise

Containerize your Phase 2 capstone project:

**Requirements:**

1. **Dockerfile:**
   - Multi-stage build
   - Production-optimized (no dev dependencies, non-root user)
   - Health check endpoint
   - Under 200MB final image size

2. **Docker Compose:**
   - API, PostgreSQL, and Redis services
   - Development overrides with hot reloading
   - Database health check
   - Volume persistence for data

3. **Development workflow:**
   - `docker compose up` starts everything
   - Code changes reflect immediately (no rebuild)
   - Debugger can attach

4. **Production readiness:**
   - Separate production Compose file
   - No exposed database ports
   - Environment variables for all configuration

**Acceptance criteria:**
- `docker compose up` starts a working development environment
- Code changes hot reload without container restart
- `docker compose down -v && docker compose up` starts fresh (clean database)
- Production build passes security scan (no root, no dev dependencies)

5. **Documentation:**
   - README includes Docker setup instructions
   - Document all environment variables
   - Include troubleshooting section

**Bonus challenges:**
- Add Adminer or pgAdmin for database management
- Set up Redis Commander for Redis inspection
- Create a Makefile with common commands
- Add container health monitoring

**AI Integration:**

Have Claude review your Dockerfile:

```
Review this Dockerfile for a Node.js/TypeScript API:

[paste your Dockerfile]

Check for:
1. Security issues (root user, exposed secrets)
2. Layer caching inefficiencies
3. Image size optimization opportunities
4. Best practices for production deployment

Suggest specific improvements with explanations.
```

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can write a multi-stage Dockerfile that builds optimized production images
- [ ] I understand Docker layer caching and how to structure Dockerfiles for fast builds
- [ ] I can use Docker Compose to run multi-service local environments
- [ ] I can set up hot reloading for development in containers
- [ ] I know how to run containers securely (non-root user, no exposed secrets)
- [ ] I can debug applications running inside containers
- [ ] I understand container networking and service discovery
- [ ] I can troubleshoot common Docker issues

Containers are the unit of deployment for modern applications. Once you're comfortable with Docker, deployment becomes moving the same container from your laptop to the cloud. The environment is identical — the only thing that changes is where it runs.

## Common Docker Commands Reference

```bash
# Building
docker build -t name:tag .              # Build image
docker build --no-cache -t name:tag .   # Rebuild from scratch

# Running
docker run -d -p 3000:3000 name:tag     # Run in background
docker run -it name:tag /bin/sh         # Interactive shell
docker run --rm name:tag                # Remove after exit

# Managing containers
docker ps                               # List running containers
docker ps -a                            # List all containers
docker stop <container>                 # Stop container
docker rm <container>                   # Remove container
docker logs <container>                 # View logs
docker logs -f <container>              # Follow logs

# Managing images
docker images                           # List images
docker rmi <image>                      # Remove image
docker image prune                      # Remove unused images

# Docker Compose
docker compose up                       # Start services
docker compose up -d                    # Start in background
docker compose up --build               # Rebuild and start
docker compose down                     # Stop services
docker compose down -v                  # Stop and remove volumes
docker compose logs -f                  # Follow all logs
docker compose exec api sh              # Shell into running service
docker compose ps                       # List service status
```

## Working with Registries

Push images to registries for deployment:

```bash
# Docker Hub
docker login
docker tag my-api:latest username/my-api:latest
docker push username/my-api:latest

# GitHub Container Registry
docker login ghcr.io -u USERNAME -p TOKEN
docker tag my-api:latest ghcr.io/username/my-api:latest
docker push ghcr.io/username/my-api:latest

# AWS ECR
aws ecr get-login-password | docker login --username AWS --password-stdin 123456.dkr.ecr.us-east-1.amazonaws.com
docker tag my-api:latest 123456.dkr.ecr.us-east-1.amazonaws.com/my-api:latest
docker push 123456.dkr.ecr.us-east-1.amazonaws.com/my-api:latest
```

💸 **Startup Cost Callout:** Docker Hub has a free tier for public images. GitHub Container Registry is free for public repos and has generous limits for private repos. AWS ECR charges ~$0.10/GB/month for storage plus data transfer.

## Troubleshooting Common Issues

**"Cannot connect to Docker daemon"**
Docker Desktop isn't running. Start it.

**Build fails with "no space left on device"**
```bash
docker system prune -a  # Remove all unused images, containers, volumes
```

**Container exits immediately**
Check logs:
```bash
docker logs <container>
```
Common causes: missing environment variables, port already in use, application crash.

**Cannot connect to service from another container**
Use the service name, not `localhost`:
```typescript
// ❌ Won't work in container
const db = 'postgres://localhost:5432/app'

// ✅ Correct
const db = 'postgres://db:5432/app'
```

**Hot reload not working**
Check volume mounts, file watching configuration, and that your dev server supports watching.

**Permissions errors with volumes**
Linux host + macOS containers can have permission mismatches. Solutions:
- Run as root in development (not production)
- Use named volumes instead of bind mounts
- Match container user UID with host user

⚡ **AI Shortcut:** Docker errors can be cryptic. Paste the full error message into Claude and ask for debugging steps. Include your Dockerfile and docker-compose.yml for context.

## Next Steps: Container Orchestration

Docker runs containers. But in production, you need:
- Multiple container instances for reliability
- Load balancing between instances
- Automatic restarts when containers fail
- Rolling deployments with zero downtime

Container orchestrators (Kubernetes, AWS ECS, Docker Swarm) provide these. For startups, managed services like AWS App Runner, Railway, or Fly.io abstract most orchestration complexity away.

We'll cover deployment options in Chapter 17. For now, focus on building good containers — the orchestration layer sits on top of the skills you've learned here.

The key insight: a well-designed container works anywhere. Whether you deploy to a $5/month VPS or a global Kubernetes cluster, the container is the same. That portability is Docker's real value.
