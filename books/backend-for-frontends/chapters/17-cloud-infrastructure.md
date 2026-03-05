# Cloud Infrastructure for Startups

## Why This Matters

You've containerized your application and built a CI/CD pipeline. Now you need somewhere to run it.

The cloud infrastructure landscape is overwhelming. AWS alone has over 200 services. GCP, Azure, Cloudflare, Vercel, Fly.io, Railway — each with their own mental models and pricing structures. It's easy to get paralyzed by choices or over-engineer your setup.

Here's the uncomfortable truth: most startups don't need sophisticated infrastructure. They need something that works, costs less than $500/month, and lets them focus on their product. This chapter gives you opinionated recommendations for that stage, plus guidance on when to graduate to more complex setups.

By the end of this chapter, you'll know where to run your code, where to put your database, and how to avoid surprise bills.

## The Two-Stage Model

Think about your infrastructure in two stages:

**Stage 1: Ship fast (0-100 users, or $0-10K MRR)**
Use platforms that handle infrastructure for you. Fly.io, Railway, Render, or Vercel + managed database. You're paying a premium per compute unit, but you're buying back engineering time.

**Stage 2: Optimize costs (100+ paying users, real revenue)**
Move to AWS/GCP with Terraform. You'll spend more engineering time, but compute costs drop significantly. Only do this when infrastructure costs are actually a meaningful expense.

Most startups should stay in Stage 1 longer than they think. If you're spending $300/month on Fly.io but your engineers are shipping features instead of debugging Kubernetes, that's a good trade.

> Don't optimize infrastructure costs until infrastructure is actually expensive. Engineer time costs more than cloud compute.

## Where to Run Your Code

### The Recommendation: Fly.io

For most backend applications, **Fly.io** is the right starting point. Here's why:

```toml
# fly.toml - that's your entire infrastructure config
app = "my-api"
primary_region = "sjc"

[build]
  dockerfile = "Dockerfile"

[http_service]
  internal_port = 3000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1

[env]
  NODE_ENV = "production"
```

Deploy with `fly deploy`. That's it.

**What Fly.io gives you:**
- Global deployment (your code runs close to users)
- Automatic HTTPS
- Zero-downtime deployments
- Built-in metrics and logging
- Postgres and Redis as managed add-ons

**What it costs:**
- ~$5/month for a small app (256MB RAM, shared CPU)
- ~$30/month for a production app (1GB RAM, dedicated CPU)
- Database starts at ~$15/month

**When to leave Fly.io:**
- You need specific AWS services (SQS, Lambda, etc.)
- Compliance requirements mandate specific cloud providers
- Your infrastructure bill exceeds $1K/month and you have time to optimize

### Alternatives and When to Use Them

**Railway** — Similar to Fly.io, slightly better DX for hobby projects. Less mature for production workloads. Good for internal tools and side projects.

**Render** — Good middle ground. More AWS-like but still managed. Better if you need background workers alongside web services.

**Vercel** — If your "backend" is mostly API routes in a Next.js app, Vercel makes sense. Don't use it for traditional backend services.

**AWS/GCP directly** — When you need specific services (ML, data pipelines, enterprise compliance) or when cost optimization matters. Skip the learning curve until you have to.

🤔 **Taste Moment:** Platform choice matters less than you think. The best platform is the one that gets out of your way. If you're spending more than 10% of engineering time on infrastructure in Year 1, something is wrong.

## Database Hosting

### The Recommendation: Managed Postgres

Run your own Postgres only if you have a specific reason to. Otherwise, use a managed service.

**For Fly.io deployments:**
Fly Postgres is the obvious choice. It's a click to provision and lives close to your app.

```bash
fly postgres create --name my-db --region sjc
fly postgres attach my-db --app my-api
```

**For AWS deployments:**
Use RDS Postgres. Not Aurora (too expensive for startups), not self-managed EC2 (too much ops work).

```hcl
# Terraform for RDS
resource "aws_db_instance" "main" {
  identifier     = "my-api-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"  # ~$15/month

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "myapi"
  username = "postgres"
  password = var.db_password  # From secrets manager

  # Critical settings
  backup_retention_period = 7
  multi_az               = false  # Enable when you need HA
  skip_final_snapshot    = false

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
}
```

**Cost reference:**
- Fly Postgres: ~$15-50/month depending on size
- RDS db.t4g.micro: ~$15/month
- RDS db.t4g.small: ~$30/month
- Neon (serverless): Free tier generous, then ~$20/month
- Supabase: Free tier, then ~$25/month (includes more than just DB)

💸 **Startup Cost Callout:** Database is usually your biggest infrastructure cost after compute. Start with the smallest instance that works. Postgres scales vertically surprisingly well — you can 10x your traffic before needing to think about read replicas.

### Connection Pooling

In serverless or multi-instance environments, you need connection pooling. Each database connection consumes memory on the Postgres server, and many small connections are worse than few large ones.

**PgBouncer** is the standard solution. Fly.io includes it automatically. For AWS:

```hcl
# RDS Proxy handles connection pooling
resource "aws_db_proxy" "main" {
  name                   = "my-api-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  require_tls            = true
  vpc_subnet_ids         = var.subnet_ids

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.db.arn
  }
}
```

Connect your application to the proxy, not the database directly. This becomes essential when you have multiple instances or use serverless functions.

## Object Storage

Every application eventually needs to store files — user uploads, generated reports, backups.

### The Recommendation: Cloudflare R2

**R2** is S3-compatible but with no egress fees. This matters more than you think.

```typescript
// src/lib/storage.ts
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'

// Works with both S3 and R2 — same SDK
const storage = new S3Client({
  region: 'auto',
  endpoint: process.env.R2_ENDPOINT,  // or S3 endpoint
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY!,
    secretAccessKey: process.env.R2_SECRET_KEY!,
  },
})

export async function uploadFile(key: string, body: Buffer, contentType: string) {
  await storage.send(new PutObjectCommand({
    Bucket: process.env.STORAGE_BUCKET,
    Key: key,
    Body: body,
    ContentType: contentType,
  }))

  return `${process.env.STORAGE_PUBLIC_URL}/${key}`
}

export async function getPresignedUploadUrl(key: string, contentType: string) {
  const command = new PutObjectCommand({
    Bucket: process.env.STORAGE_BUCKET,
    Key: key,
    ContentType: contentType,
  })

  return getSignedUrl(storage, command, { expiresIn: 3600 })
}
```

**Why R2 over S3:**
- No egress fees (S3 charges $0.09/GB for data out)
- S3-compatible (same SDK, easy migration)
- Generous free tier (10GB storage, 10M requests/month)

**When to use S3:**
- You need S3-specific features (S3 Select, Glacier)
- Your data must stay within AWS for compliance
- You're heavily integrated with other AWS services

🔒 **Security Callout:** Never accept file uploads directly to your server and then upload to storage. Use presigned URLs to let clients upload directly to S3/R2. This prevents your server from being a bottleneck and reduces attack surface.

## Secrets Management

Hardcoding secrets is obviously bad. But how do you actually manage them?

**For Fly.io:**
```bash
fly secrets set DATABASE_URL="postgres://..." API_KEY="sk-..."
```

These are injected as environment variables. Simple and sufficient for most cases.

**For AWS:**
Use AWS Secrets Manager or SSM Parameter Store.

```typescript
// src/lib/secrets.ts
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm'

const ssm = new SSMClient({ region: process.env.AWS_REGION })

const secretsCache = new Map<string, string>()

export async function getSecret(name: string): Promise<string> {
  if (secretsCache.has(name)) {
    return secretsCache.get(name)!
  }

  const response = await ssm.send(new GetParameterCommand({
    Name: `/myapi/${process.env.NODE_ENV}/${name}`,
    WithDecryption: true,
  }))

  const value = response.Parameter?.Value
  if (!value) throw new Error(`Secret ${name} not found`)

  secretsCache.set(name, value)
  return value
}
```

```hcl
# Terraform for SSM parameters
resource "aws_ssm_parameter" "db_password" {
  name  = "/myapi/production/db_password"
  type  = "SecureString"
  value = var.db_password

  tags = {
    Environment = "production"
  }
}
```

**Don't:**
- Store secrets in git (even encrypted, it's a footgun)
- Use .env files in production
- Share secrets across environments (production/staging)

## Cost Management

Surprise cloud bills are a startup killer. Set up alerts before you need them.

### Budget Alerts

**AWS:**
```hcl
resource "aws_budgets_budget" "monthly" {
  name         = "monthly-budget"
  budget_type  = "COST"
  limit_amount = "500"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_email_addresses = ["ops@yourcompany.com"]
  }
}
```

**Fly.io:**
Set a spending limit in the dashboard under Billing → Spending Limits.

### Common Cost Traps

1. **Forgotten resources** — That test cluster you spun up and forgot. Use `aws-nuke` or similar tools periodically in non-production accounts.

2. **NAT Gateway charges** — AWS charges $0.045/hour (~$32/month) plus data transfer. If your private subnets need internet access, this adds up fast.

3. **Data transfer** — Egress fees are the hidden tax of cloud computing. Keep traffic within a region when possible.

4. **Overprovisioned databases** — Start with the smallest instance. You can resize in minutes.

5. **Load balancer costs** — Each ALB is ~$20/month. Don't create one per service.

💸 **Startup Cost Callout:** Run `aws ce get-cost-and-usage` monthly and actually look at the breakdown. Most teams have 20-30% waste they don't know about.

## DNS and SSL

### DNS

Use Cloudflare for DNS. It's free, fast, and has good DX.

```
# Cloudflare DNS records (via dashboard or Terraform)
api.yourapp.com    A      123.45.67.89     # Your server IP
api.yourapp.com    AAAA   2001:db8::1      # IPv6 if available
*.yourapp.com      CNAME  api.yourapp.com  # Wildcard for subdomains
```

For Fly.io, point your domain with:
```bash
fly certs create api.yourapp.com
# Then add CNAME: api.yourapp.com -> your-app.fly.dev
```

### SSL/TLS

If you're using Fly.io, Render, or similar platforms, SSL is automatic. Don't think about it.

For AWS with ALB:
```hcl
resource "aws_acm_certificate" "main" {
  domain_name       = "api.yourapp.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Use certificate in ALB listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
```

🔒 **Security Callout:** Always use TLS 1.2 or higher. The `ELBSecurityPolicy-TLS13-1-2-2021-06` policy is a good default — it supports modern clients without legacy baggage.

## When to Move to AWS/GCP

Stay on platforms like Fly.io until:

1. **Specific service needs** — You need SQS, Lambda, SageMaker, BigQuery, or other cloud-specific services that don't have good alternatives.

2. **Compliance requirements** — SOC2, HIPAA, or FedRAMP may require specific cloud providers with specific configurations.

3. **Cost threshold** — When you're spending >$1K/month on infrastructure AND have engineering bandwidth to optimize, moving to IaaS can cut costs 30-50%.

4. **Control requirements** — You need VPCs, specific network topologies, or custom security configurations that PaaS doesn't support.

### The Migration Path

When you do migrate:

1. **Keep your database managed** — Use RDS, not self-managed EC2. Database ops is a full-time job.

2. **Use Terraform from day one** — Don't click around in the console. Infrastructure as code is mandatory.

3. **Start with ECS Fargate, not Kubernetes** — EKS is complex. Fargate runs your containers without cluster management. Graduate to EKS only if Fargate's limitations hit you.

```hcl
# ECS Fargate service - simpler than it looks
resource "aws_ecs_service" "api" {
  name            = "api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.api.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 3000
  }
}
```

## The Taste Test

**Scenario 1:** A startup with 50 users is debating whether to set up Kubernetes "to be ready for scale."

*Skip it.* Kubernetes is operational overhead you don't need. Fly.io or ECS Fargate will handle 10,000x more traffic than you have. Revisit when you have a dedicated platform team.

**Scenario 2:** Your AWS bill shows $200/month for a NAT Gateway with minimal traffic.

*Investigate alternatives.* If your workloads can run in public subnets, do that. If you need private subnets, consider NAT instances ($5/month) or VPC endpoints for AWS services.

**Scenario 3:** A team is storing API keys in environment variables defined in their Dockerfile.

*Fix immediately.* That's secrets in version control. Use the platform's secrets management (Fly secrets, AWS Secrets Manager) and inject at runtime.

**Scenario 4:** Someone suggests using three availability zones "for high availability" when you have 20 customers.

*Not yet.* Multi-AZ adds cost and complexity. Start with single-AZ, add redundancy when downtime actually costs you money.

## Practical Exercise

Deploy your TaskFlow API to production:

**Requirements:**
1. Deploy to Fly.io (or your platform of choice)
2. Set up managed Postgres with automated backups
3. Configure environment-specific secrets (not in code)
4. Set up a custom domain with HTTPS
5. Configure budget alerts at $50/month

**Acceptance criteria:**
- Application accessible via HTTPS on your domain
- Database connection uses pooling
- Secrets not visible in any config files
- You receive an email when forecasted spend exceeds 80% of budget

**⚡ AI Shortcut:**

Have Claude generate your Terraform configuration:

```
Generate Terraform for:
- ECS Fargate service running a Node.js API
- RDS Postgres (db.t4g.micro) with 7-day backups
- Application Load Balancer with HTTPS
- Secrets in SSM Parameter Store
- Budget alert at $100/month

Use modules where appropriate. Include security groups that follow least-privilege.
```

Review the output carefully — AI-generated Terraform often has overly permissive security groups or missing encryption settings. Check every `0.0.0.0/0` CIDR block.

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can deploy a backend application to Fly.io or similar platform
- [ ] I understand when managed databases are worth the cost premium
- [ ] I know how to manage secrets without putting them in code
- [ ] I can set up budget alerts to avoid surprise bills
- [ ] I understand when to stay on PaaS vs. move to AWS/GCP

Infrastructure should enable shipping, not block it. Start simple, add complexity only when you have specific needs that justify it.
