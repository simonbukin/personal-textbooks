# Authentication, Authorization, and Security

## Why This Matters

You've built a solid data layer and organized your codebase into clean modules. Now you need to protect it.

Security isn't a feature you bolt on at the end. It's woven into every layer of your application — from how you store passwords (don't) to how you validate that a user can access a specific resource. Get this wrong and you're not just dealing with bugs; you're dealing with lawsuits, regulatory fines, and the kind of headlines that end startups.

The good news: most security vulnerabilities follow predictable patterns. The OWASP Top 10 hasn't changed much in a decade because developers keep making the same mistakes. This chapter teaches you to not make them.

By the end, you'll understand the difference between authentication and authorization (and why conflating them causes problems), how to implement both correctly, and how to avoid the security pitfalls that catch most developers.

## Authentication vs. Authorization: The Distinction That Matters

These terms get used interchangeably, but they're fundamentally different:

**Authentication** answers: "Who are you?"
**Authorization** answers: "What are you allowed to do?"

Authentication verifies identity. When a user logs in with email and password, or clicks "Sign in with Google," that's authentication. The system confirms they are who they claim to be.

Authorization verifies permissions. Once we know who someone is, we check whether they can perform the requested action. Can this user view this document? Can they delete that comment? Can they invite new team members?

> Use auth providers for authentication. Build authorization yourself.

This is the key insight. Authentication is a solved problem with significant security implications if you get it wrong. Password hashing, session management, OAuth flows, magic links, MFA — these are complex, audited systems where one mistake can be catastrophic. Let someone else handle this.

Authorization, on the other hand, is specific to your application. No third-party service knows your business rules: who can access which workspaces, what role hierarchy you have, when a user should lose access to a resource. You have to build this.

## Authentication: Let Someone Else Do It

For authentication, use a dedicated provider. The current best options:

**Clerk** — Best developer experience, generous free tier, built-in UI components. The default choice for most startups.

**Auth0** — Enterprise-grade, more configuration options, higher cost. Good if you need SAML/SSO for enterprise customers.

**Supabase Auth** — Good if you're already using Supabase. Tightly integrated with their Postgres offering.

**Firebase Auth** — Good if you're in the Google ecosystem. Less flexible than the others.

**Roll your own** — Don't. Seriously. Unless authentication is literally your product (you're building Clerk), use a provider.

Here's how authentication with Clerk looks in a Hono application:

```typescript
// src/middleware/auth.ts
import { clerkMiddleware, getAuth } from '@hono/clerk-auth'
import { Context, Next } from 'hono'

export const authMiddleware = clerkMiddleware()

export async function requireAuth(c: Context, next: Next) {
  const auth = getAuth(c)

  if (!auth?.userId) {
    return c.json({ error: 'Unauthorized' }, 401)
  }

  // Attach user ID to context for downstream handlers
  c.set('userId', auth.userId)
  await next()
}
```

```typescript
// src/index.ts
import { Hono } from 'hono'
import { authMiddleware, requireAuth } from './middleware/auth'
import { workspaceRoutes } from './modules/workspace/routes'

const app = new Hono()

// Apply Clerk middleware to all routes
app.use('*', authMiddleware)

// Public routes (no auth required)
app.get('/health', (c) => c.json({ status: 'ok' }))

// Protected routes
app.use('/api/*', requireAuth)
app.route('/api/workspaces', workspaceRoutes)
```

That's it for authentication. Clerk handles login pages, password resets, OAuth flows, session tokens, and token verification. You get a `userId` you can trust.

### Understanding JWT Tokens

Even though your auth provider handles token generation, you need to understand how JWT (JSON Web Token) authentication works because you'll debug it.

A JWT has three parts separated by dots:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

1. **Header** — Algorithm and token type
2. **Payload** — Claims (user ID, expiration, custom data)
3. **Signature** — Verification that the token hasn't been tampered with

The payload isn't encrypted — it's base64 encoded. Anyone can decode and read it. The signature is what matters: it proves the token was issued by your auth provider and hasn't been modified.

```typescript
// Decoding a JWT payload (for debugging, not validation)
function decodeJwtPayload(token: string): Record<string, unknown> {
  const [, payload] = token.split('.')
  const decoded = Buffer.from(payload, 'base64url').toString('utf8')
  return JSON.parse(decoded)
}

// Example payload
{
  "sub": "user_2NNEqL5E4Z9k",  // Subject (user ID)
  "iat": 1699200000,           // Issued at (Unix timestamp)
  "exp": 1699203600,           // Expires at (Unix timestamp)
  "azp": "https://yourapp.com" // Authorized party
}
```

🔒 **Security Callout:** Never put sensitive data in JWT payloads. They're readable by anyone who intercepts the token. User IDs and roles are fine; email addresses and PII are not. If you need to store sensitive claims, encrypt them or keep them server-side.

### Session vs. Token Authentication

Auth providers typically give you a choice:

**Token-based (stateless):** The JWT contains everything needed to verify the user. No server-side session storage. Tokens can't be individually revoked (they're valid until expiration).

**Session-based (stateful):** A session ID references server-side data. Sessions can be instantly revoked. Requires session storage (database or Redis).

For most applications, use token-based auth with short expiration times (15-60 minutes) and refresh tokens. Here's why:

- Horizontal scaling is easier (no shared session state)
- Fewer database lookups per request
- Refresh token rotation catches token theft

```typescript
// Token refresh flow
async function refreshTokens(refreshToken: string): Promise<TokenPair> {
  // Verify refresh token is valid and not revoked
  const stored = await redis.get(`refresh:${refreshToken}`)
  if (!stored) {
    throw new UnauthorizedError('Invalid refresh token')
  }

  const { userId } = JSON.parse(stored)

  // Revoke old refresh token (rotation)
  await redis.del(`refresh:${refreshToken}`)

  // Issue new token pair
  const newAccessToken = issueAccessToken(userId)
  const newRefreshToken = crypto.randomBytes(32).toString('hex')

  // Store new refresh token
  await redis.setex(
    `refresh:${newRefreshToken}`,
    60 * 60 * 24 * 30,  // 30 days
    JSON.stringify({ userId })
  )

  return { accessToken: newAccessToken, refreshToken: newRefreshToken }
}
```

### API Key Authentication

Not all API clients are humans with login pages. Service-to-service communication, CLI tools, and integrations use API keys.

```typescript
// src/modules/apiKey/schema.ts
import { pgTable, text, timestamp, boolean } from 'drizzle-orm/pg-core'

export const apiKeys = pgTable('api_keys', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  workspaceId: text('workspace_id').notNull().references(() => workspaces.id),
  name: text('name').notNull(),               // "Production webhook"
  keyHash: text('key_hash').notNull(),        // Never store plaintext
  keyPrefix: text('key_prefix').notNull(),    // "sk_live_abc..." for identification
  scopes: text('scopes').array().notNull(),   // ['read:tasks', 'write:tasks']
  lastUsedAt: timestamp('last_used_at'),
  expiresAt: timestamp('expires_at'),
  revokedAt: timestamp('revoked_at'),
  createdAt: timestamp('created_at').defaultNow().notNull()
})
```

API keys need different treatment than user tokens:

```typescript
// src/middleware/apiKeyAuth.ts
import { Context, Next } from 'hono'
import { createHash } from 'crypto'
import { db } from '../db'
import { apiKeys } from '../db/schema'
import { eq, and, isNull, gt } from 'drizzle-orm'

function hashApiKey(key: string): string {
  return createHash('sha256').update(key).digest('hex')
}

export async function apiKeyAuth(c: Context, next: Next) {
  const authHeader = c.req.header('Authorization')

  if (!authHeader?.startsWith('Bearer sk_')) {
    return c.json({ error: 'Invalid API key format' }, 401)
  }

  const key = authHeader.replace('Bearer ', '')
  const keyHash = hashApiKey(key)

  const apiKey = await db.query.apiKeys.findFirst({
    where: and(
      eq(apiKeys.keyHash, keyHash),
      isNull(apiKeys.revokedAt),
      gt(apiKeys.expiresAt, new Date())
    )
  })

  if (!apiKey) {
    return c.json({ error: 'Invalid or expired API key' }, 401)
  }

  // Update last used timestamp (fire and forget)
  db.update(apiKeys)
    .set({ lastUsedAt: new Date() })
    .where(eq(apiKeys.id, apiKey.id))
    .execute()

  c.set('apiKey', apiKey)
  c.set('workspaceId', apiKey.workspaceId)
  await next()
}
```

🤔 **Taste Moment:** API keys should be treated as passwords — hash them before storage, never log them, and make them revocable. The common pattern is to show the full key exactly once at creation, then only display a prefix for identification.

```typescript
// Creating a new API key
async function createApiKey(workspaceId: string, name: string, scopes: string[]) {
  const key = `sk_live_${crypto.randomBytes(24).toString('hex')}`
  const keyPrefix = key.substring(0, 15)
  const keyHash = hashApiKey(key)

  await db.insert(apiKeys).values({
    workspaceId,
    name,
    keyHash,
    keyPrefix,
    scopes,
    expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)  // 1 year
  })

  // Return the full key only this once
  return { key, keyPrefix }
}
```

🔒 **Security Callout:** Never store passwords yourself. If you're hashing passwords with bcrypt or argon2, you're taking on liability you don't need. Auth providers use battle-tested implementations with proper salting, timing-attack resistance, and automatic rehashing as algorithms improve.

## Authorization: Building It Yourself

Now the hard part. You have a user ID. You need to determine what they can do.

### The Three Levels of Authorization

Authorization decisions happen at three levels:

**1. Route-level:** Can this user access this endpoint at all?
**2. Resource-level:** Can this user access this specific resource?
**3. Field-level:** Can this user see/modify this specific field?

Most applications need all three. Let's build them.

### Route-Level Authorization with Roles

The simplest authorization model: users have roles, roles grant access to routes.

```typescript
// src/modules/user/types.ts
export type UserRole = 'member' | 'admin' | 'owner'

export interface User {
  id: string
  clerkId: string
  email: string
  role: UserRole
  workspaceId: string
  createdAt: Date
}
```

```typescript
// src/middleware/authorize.ts
import { Context, Next } from 'hono'
import { UserRole } from '../modules/user/types'
import { userRepository } from '../modules/user/repository'

export function requireRole(...allowedRoles: UserRole[]) {
  return async (c: Context, next: Next) => {
    const clerkId = c.get('userId')

    const user = await userRepository.findByClerkId(clerkId)
    if (!user) {
      return c.json({ error: 'User not found' }, 404)
    }

    if (!allowedRoles.includes(user.role)) {
      return c.json({ error: 'Forbidden' }, 403)
    }

    c.set('user', user)
    await next()
  }
}
```

```typescript
// src/modules/workspace/routes.ts
import { Hono } from 'hono'
import { requireRole } from '../../middleware/authorize'

const workspaceRoutes = new Hono()

// Any authenticated user can list workspaces
workspaceRoutes.get('/', async (c) => {
  // ...
})

// Only admins and owners can update workspace settings
workspaceRoutes.put(
  '/:id/settings',
  requireRole('admin', 'owner'),
  async (c) => {
    // ...
  }
)

// Only owners can delete workspaces
workspaceRoutes.delete(
  '/:id',
  requireRole('owner'),
  async (c) => {
    // ...
  }
)
```

This is clean but insufficient. A user might be an admin in Workspace A but only a member in Workspace B. Role-based access control (RBAC) at the route level doesn't capture this.

### Resource-Level Authorization

For most applications, authorization depends on the relationship between the user and the specific resource they're accessing.

```typescript
// src/modules/workspace/service.ts
import { db } from '../../db'
import { workspaces, workspaceMembers } from '../../db/schema'
import { eq, and } from 'drizzle-orm'
import { ForbiddenError, NotFoundError } from '../../errors'

interface WorkspaceService {
  getWorkspace(workspaceId: string, userId: string): Promise<Workspace>
  updateWorkspace(
    workspaceId: string,
    userId: string,
    data: UpdateWorkspaceInput
  ): Promise<Workspace>
  deleteWorkspace(workspaceId: string, userId: string): Promise<void>
}

export function createWorkspaceService(): WorkspaceService {
  return {
    async getWorkspace(workspaceId, userId) {
      const membership = await db.query.workspaceMembers.findFirst({
        where: and(
          eq(workspaceMembers.workspaceId, workspaceId),
          eq(workspaceMembers.userId, userId)
        ),
        with: { workspace: true }
      })

      if (!membership) {
        throw new NotFoundError('Workspace not found')
      }

      return membership.workspace
    },

    async updateWorkspace(workspaceId, userId, data) {
      const membership = await db.query.workspaceMembers.findFirst({
        where: and(
          eq(workspaceMembers.workspaceId, workspaceId),
          eq(workspaceMembers.userId, userId)
        )
      })

      if (!membership) {
        throw new NotFoundError('Workspace not found')
      }

      // ✅ Resource-level authorization check
      if (!['admin', 'owner'].includes(membership.role)) {
        throw new ForbiddenError('Only admins can update workspace settings')
      }

      const [updated] = await db
        .update(workspaces)
        .set({ ...data, updatedAt: new Date() })
        .where(eq(workspaces.id, workspaceId))
        .returning()

      return updated
    },

    async deleteWorkspace(workspaceId, userId) {
      const membership = await db.query.workspaceMembers.findFirst({
        where: and(
          eq(workspaceMembers.workspaceId, workspaceId),
          eq(workspaceMembers.userId, userId)
        )
      })

      if (!membership) {
        throw new NotFoundError('Workspace not found')
      }

      // ✅ Resource-level authorization check
      if (membership.role !== 'owner') {
        throw new ForbiddenError('Only owners can delete workspaces')
      }

      await db.delete(workspaces).where(eq(workspaces.id, workspaceId))
    }
  }
}
```

Notice the pattern: every operation first checks that the user has access to the resource, then checks that they have the right permission level for that specific action.

🤔 **Taste Moment:** Return 404, not 403, when a user doesn't have access to a resource. Returning 403 ("Forbidden") confirms the resource exists. An attacker now knows there's something at that ID worth probing. Return 404 to reveal nothing about whether the resource exists.

### The Policy Pattern

As authorization rules grow complex, scattered `if` checks become hard to maintain. Extract them into policy objects:

```typescript
// src/modules/workspace/policy.ts
import { WorkspaceMembership } from './types'

export const workspacePolicy = {
  canView(membership: WorkspaceMembership | null): boolean {
    return membership !== null
  },

  canUpdate(membership: WorkspaceMembership | null): boolean {
    if (!membership) return false
    return ['admin', 'owner'].includes(membership.role)
  },

  canDelete(membership: WorkspaceMembership | null): boolean {
    if (!membership) return false
    return membership.role === 'owner'
  },

  canInviteMembers(membership: WorkspaceMembership | null): boolean {
    if (!membership) return false
    return ['admin', 'owner'].includes(membership.role)
  },

  canRemoveMember(
    membership: WorkspaceMembership | null,
    targetMembership: WorkspaceMembership
  ): boolean {
    if (!membership) return false

    // Owners can remove anyone
    if (membership.role === 'owner') return true

    // Admins can remove members but not other admins or owners
    if (membership.role === 'admin') {
      return targetMembership.role === 'member'
    }

    return false
  }
}
```

```typescript
// src/modules/workspace/service.ts
import { workspacePolicy } from './policy'

async updateWorkspace(workspaceId, userId, data) {
  const membership = await this.getMembership(workspaceId, userId)

  if (!workspacePolicy.canUpdate(membership)) {
    throw new ForbiddenError('Insufficient permissions')
  }

  // ... update logic
}
```

Policies make authorization testable. You can unit test every permission rule without touching the database:

```typescript
// src/modules/workspace/policy.test.ts
import { describe, it, expect } from 'vitest'
import { workspacePolicy } from './policy'

describe('workspacePolicy', () => {
  describe('canRemoveMember', () => {
    it('allows owners to remove admins', () => {
      const owner = { role: 'owner' } as WorkspaceMembership
      const admin = { role: 'admin' } as WorkspaceMembership

      expect(workspacePolicy.canRemoveMember(owner, admin)).toBe(true)
    })

    it('prevents admins from removing other admins', () => {
      const admin1 = { role: 'admin' } as WorkspaceMembership
      const admin2 = { role: 'admin' } as WorkspaceMembership

      expect(workspacePolicy.canRemoveMember(admin1, admin2)).toBe(false)
    })
  })
})
```

### Field-Level Authorization

Sometimes users can access a resource but shouldn't see all its fields. An admin might see user email addresses; a member might not.

```typescript
// src/modules/user/serializer.ts
import { User, WorkspaceMembership } from './types'

interface SerializedUser {
  id: string
  name: string
  avatarUrl: string | null
  email?: string  // Only visible to admins
  role?: string   // Only visible to admins
}

export function serializeUser(
  user: User,
  viewerMembership: WorkspaceMembership
): SerializedUser {
  const base: SerializedUser = {
    id: user.id,
    name: user.name,
    avatarUrl: user.avatarUrl
  }

  // Admins and owners see additional fields
  if (['admin', 'owner'].includes(viewerMembership.role)) {
    base.email = user.email
    base.role = user.role
  }

  return base
}
```

```typescript
// In your route handler
const members = await workspaceService.getMembers(workspaceId)
const serialized = members.map(m => serializeUser(m, currentUserMembership))
return c.json({ members: serialized })
```

This keeps field-level authorization explicit and testable rather than scattered across template logic.

## The OWASP Top 10: A Practical Checklist

The Open Web Application Security Project maintains a list of the most critical security risks. You don't need to memorize the list, but you need to know how each one applies to your code.

### 1. Broken Access Control

We just covered this extensively. The mitigations:

- Check authorization on every request, not just in the UI
- Use resource-level checks, not just role-level
- Return 404 instead of 403 for unauthorized access to specific resources
- Deny by default; require explicit grants

### 2. Cryptographic Failures

Don't roll your own crypto. Use established libraries. Specific rules:

```typescript
// ❌ Don't do this
const token = crypto.randomBytes(16).toString('hex')  // Too short

// ✅ Do this instead
const token = crypto.randomBytes(32).toString('hex')  // 256 bits
```

```typescript
// ❌ Don't do this
const hash = crypto.createHash('md5').update(password).digest('hex')

// ✅ Do this instead - but actually, don't hash passwords yourself at all
// Use your auth provider
```

For any sensitive data at rest, use encryption:

```typescript
// src/utils/encryption.ts
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto'

const ALGORITHM = 'aes-256-gcm'
const KEY = Buffer.from(process.env.ENCRYPTION_KEY!, 'hex')  // 32 bytes

export function encrypt(plaintext: string): string {
  const iv = randomBytes(16)
  const cipher = createCipheriv(ALGORITHM, KEY, iv)

  let encrypted = cipher.update(plaintext, 'utf8', 'hex')
  encrypted += cipher.final('hex')

  const authTag = cipher.getAuthTag()

  // Format: iv:authTag:ciphertext
  return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`
}

export function decrypt(encrypted: string): string {
  const [ivHex, authTagHex, ciphertext] = encrypted.split(':')

  const iv = Buffer.from(ivHex, 'hex')
  const authTag = Buffer.from(authTagHex, 'hex')

  const decipher = createDecipheriv(ALGORITHM, KEY, iv)
  decipher.setAuthTag(authTag)

  let decrypted = decipher.update(ciphertext, 'hex', 'utf8')
  decrypted += decipher.final('utf8')

  return decrypted
}
```

Use this for API keys, tokens, and other sensitive data you need to store and retrieve.

🔒 **Security Callout:** Never commit encryption keys. Generate them with `openssl rand -hex 32` and store in environment variables or a secrets manager.

### 3. Injection

SQL injection is the classic, but injection vulnerabilities exist wherever user input is interpreted as code.

```typescript
// ❌ SQL injection vulnerability
const users = await db.execute(
  `SELECT * FROM users WHERE email = '${email}'`
)

// ✅ Parameterized query
const users = await db.query.users.findMany({
  where: eq(users.email, email)
})
```

Drizzle and other modern ORMs prevent SQL injection by default. The risk comes when you write raw SQL:

```typescript
// ❌ Still vulnerable with raw SQL
const result = await db.execute(sql`
  SELECT * FROM users WHERE email = '${email}'
`)

// ✅ Use the sql template tag correctly
const result = await db.execute(sql`
  SELECT * FROM users WHERE email = ${email}
`)
```

The difference is subtle but critical. String interpolation (`'${email}'` with quotes) embeds the value directly. The `sql` template tag (`${email}` without quotes) creates a parameterized query.

Other injection vectors to watch:

```typescript
// ❌ Command injection
exec(`convert ${userProvidedFilename} output.png`)

// ✅ Use arrays to prevent injection
execFile('convert', [userProvidedFilename, 'output.png'])
```

```typescript
// ❌ NoSQL injection (if using MongoDB)
const user = await collection.findOne({
  username: req.body.username,
  password: req.body.password  // Could be { $gt: '' }
})

// ✅ Explicitly cast to string
const user = await collection.findOne({
  username: String(req.body.username),
  password: String(req.body.password)
})
```

### 4. Insecure Design

This is about missing security controls at the design level. Examples:

- No rate limiting on login endpoints (allows brute force)
- No account lockout after failed attempts
- Password reset tokens that don't expire
- Predictable resource IDs

```typescript
// ❌ Predictable IDs
const workspaceId = autoincrement()  // 1, 2, 3, 4...

// ✅ Unpredictable IDs
const workspaceId = crypto.randomUUID()  // or nanoid, cuid2
```

```typescript
// src/middleware/rateLimit.ts
import { RateLimiterRedis } from 'rate-limiter-flexible'
import { redis } from '../redis'

const loginLimiter = new RateLimiterRedis({
  storeClient: redis,
  keyPrefix: 'login_limit',
  points: 5,           // 5 attempts
  duration: 60 * 15,   // per 15 minutes
  blockDuration: 60 * 60  // block for 1 hour after exhausting points
})

export async function loginRateLimit(c: Context, next: Next) {
  const ip = c.req.header('x-forwarded-for') || 'unknown'

  try {
    await loginLimiter.consume(ip)
    await next()
  } catch {
    return c.json({ error: 'Too many login attempts' }, 429)
  }
}
```

### 5. Security Misconfiguration

Defaults are often insecure. Check these:

```typescript
// src/index.ts
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { secureHeaders } from 'hono/secure-headers'

const app = new Hono()

// ❌ Don't do this in production
app.use('*', cors())  // Allows any origin

// ✅ Configure CORS explicitly
app.use('*', cors({
  origin: ['https://yourapp.com', 'https://app.yourapp.com'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}))

// Add security headers
app.use('*', secureHeaders())
```

Other configuration checks:
- Remove default credentials from databases
- Disable directory listing
- Set secure cookie flags (`httpOnly`, `secure`, `sameSite`)
- Don't expose stack traces in production errors

### 6. Vulnerable Components

Keep dependencies updated. Use tools to find vulnerabilities:

```bash
# Check for known vulnerabilities
npm audit

# Auto-fix what's safe to fix
npm audit fix

# For more aggressive updates (review changes carefully)
npm audit fix --force
```

Set up automated security scanning in CI:

```yaml
# .github/workflows/security.yml
name: Security Scan
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 0 * * *'  # Daily

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm audit --audit-level=high
```

💸 **Startup Cost Callout:** Snyk and GitHub's Dependabot are free for open source and have generous free tiers for private repos. No excuse not to use them.

### 7. Authentication Failures

We covered this — use an auth provider. Additional points:

- Require MFA for admin accounts (most auth providers support this)
- Implement proper session invalidation on logout
- Use short-lived tokens with refresh token rotation

### 8. Data Integrity Failures

Verify data integrity, especially for anything that affects billing, permissions, or security:

```typescript
// ❌ Trust client-provided data
const order = {
  items: req.body.items,
  total: req.body.total  // User could send $0
}

// ✅ Calculate server-side
const items = await validateAndFetchItems(req.body.itemIds)
const total = items.reduce((sum, item) => sum + item.price, 0)
const order = { items, total }
```

### 9. Logging and Monitoring Failures

We'll cover observability in detail in Phase 3. For security specifically:

```typescript
// Log security-relevant events
logger.info('user_login', {
  userId: user.id,
  ip: req.ip,
  userAgent: req.headers['user-agent']
})

logger.warn('failed_login_attempt', {
  email: req.body.email,  // OK to log
  ip: req.ip
  // Never log the attempted password
})

logger.warn('authorization_denied', {
  userId: user.id,
  resource: 'workspace',
  resourceId: workspaceId,
  action: 'delete'
})
```

### 10. Server-Side Request Forgery (SSRF)

When your server makes HTTP requests based on user input:

```typescript
// ❌ SSRF vulnerability
const response = await fetch(req.body.webhookUrl)

// ✅ Validate the URL
import { URL } from 'url'

function isAllowedUrl(urlString: string): boolean {
  try {
    const url = new URL(urlString)

    // Block internal IPs
    const blockedHosts = ['localhost', '127.0.0.1', '0.0.0.0', '169.254.169.254']
    if (blockedHosts.includes(url.hostname)) return false

    // Block private IP ranges
    if (url.hostname.startsWith('10.') ||
        url.hostname.startsWith('192.168.') ||
        url.hostname.match(/^172\.(1[6-9]|2[0-9]|3[01])\./)) {
      return false
    }

    // Require HTTPS
    if (url.protocol !== 'https:') return false

    return true
  } catch {
    return false
  }
}

if (!isAllowedUrl(req.body.webhookUrl)) {
  return c.json({ error: 'Invalid webhook URL' }, 400)
}
const response = await fetch(req.body.webhookUrl)
```

## Input Validation and Sanitization

Every piece of data from outside your system is suspect. This includes:

- Request bodies
- Query parameters
- Path parameters
- Headers
- File uploads
- Webhook payloads

### Schema Validation with Zod

Don't manually check each field. Use a schema validation library:

```typescript
// src/modules/task/schema.ts
import { z } from 'zod'

export const createTaskSchema = z.object({
  title: z.string()
    .min(1, 'Title is required')
    .max(200, 'Title too long')
    .trim(),
  description: z.string()
    .max(10000, 'Description too long')
    .optional(),
  projectId: z.string().uuid('Invalid project ID'),
  assigneeId: z.string().uuid('Invalid assignee ID').optional(),
  priority: z.enum(['low', 'medium', 'high', 'urgent']).default('medium'),
  dueDate: z.string()
    .datetime()
    .optional()
    .transform(val => val ? new Date(val) : undefined)
})

export type CreateTaskInput = z.infer<typeof createTaskSchema>
```

```typescript
// src/modules/task/routes.ts
import { Hono } from 'hono'
import { createTaskSchema } from './schema'

const taskRoutes = new Hono()

taskRoutes.post('/', async (c) => {
  const body = await c.req.json()

  const result = createTaskSchema.safeParse(body)
  if (!result.success) {
    return c.json({
      error: 'Validation failed',
      details: result.error.flatten().fieldErrors
    }, 400)
  }

  const input = result.data  // Fully typed and validated
  // ... create task
})
```

Create a validation middleware for cleaner routes:

```typescript
// src/middleware/validate.ts
import { Context, Next } from 'hono'
import { ZodSchema } from 'zod'

export function validate<T>(schema: ZodSchema<T>) {
  return async (c: Context, next: Next) => {
    const body = await c.req.json()
    const result = schema.safeParse(body)

    if (!result.success) {
      return c.json({
        error: 'Validation failed',
        details: result.error.flatten().fieldErrors
      }, 400)
    }

    c.set('validatedBody', result.data)
    await next()
  }
}

// Usage
taskRoutes.post('/', validate(createTaskSchema), async (c) => {
  const input = c.get('validatedBody') as CreateTaskInput
  // ...
})
```

### Preventing XSS

Cross-site scripting (XSS) happens when user input is rendered as HTML without escaping. This is primarily a frontend concern, but the backend plays a role:

1. **Output encoding:** If you render HTML server-side, always escape user content
2. **Content Security Policy:** Set CSP headers to prevent inline script execution
3. **Input sanitization:** For rich text fields, use an allowlist-based sanitizer

```typescript
// If you accept HTML content (like a rich text editor)
import DOMPurify from 'isomorphic-dompurify'

const sanitizedHtml = DOMPurify.sanitize(userProvidedHtml, {
  ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'ul', 'ol', 'li', 'a'],
  ALLOWED_ATTR: ['href'],
  ALLOW_DATA_ATTR: false
})
```

```typescript
// CSP headers via Hono
import { secureHeaders } from 'hono/secure-headers'

app.use('*', secureHeaders({
  contentSecurityPolicy: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],  // No 'unsafe-inline'
    styleSrc: ["'self'", "'unsafe-inline'"],  // CSS often needs inline
    imgSrc: ["'self'", 'data:', 'https:'],
    connectSrc: ["'self'", 'https://api.yourapp.com']
  }
}))
```

💸 **Startup Cost Callout:** DOMPurify is free and lightweight. Don't skip sanitization to save bytes — the cost of an XSS vulnerability is measured in reputation, not server resources.

## Secrets Management

Secrets — API keys, database passwords, encryption keys — need special handling.

### Development

Use `.env` files locally, but never commit them:

```bash
# .env (never commit)
DATABASE_URL=postgres://localhost/myapp
CLERK_SECRET_KEY=sk_test_...
ENCRYPTION_KEY=...

# .env.example (commit this)
DATABASE_URL=postgres://localhost/myapp
CLERK_SECRET_KEY=sk_test_your_key_here
ENCRYPTION_KEY=generate_with_openssl_rand_hex_32
```

```gitignore
# .gitignore
.env
.env.local
.env.*.local
```

### Production

Never put secrets in environment variables set through your hosting provider's UI — they often end up in logs or can be accessed by other services.

Use a secrets manager:

- **AWS Secrets Manager** — Native AWS, automatic rotation support
- **Doppler** — Great DX, works with any cloud
- **HashiCorp Vault** — Self-hosted option, more complex

```typescript
// src/config/secrets.ts
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager'

const client = new SecretsManagerClient({ region: 'us-east-1' })

export async function getSecret(secretName: string): Promise<string> {
  const command = new GetSecretValueCommand({ SecretId: secretName })
  const response = await client.send(command)

  if (!response.SecretString) {
    throw new Error(`Secret ${secretName} not found`)
  }

  return response.SecretString
}

// Usage at startup
const dbUrl = await getSecret('myapp/database-url')
```

⚡ **AI Shortcut:** Prompt Claude to review your codebase for hardcoded secrets:

```
Review this codebase for hardcoded secrets, API keys, or credentials.
Look for:
1. Strings that look like API keys (long alphanumeric, prefixed with sk_, pk_, etc.)
2. Database connection strings with passwords
3. JWT secrets or encryption keys
4. OAuth client secrets
5. Any values that should be environment variables but aren't

[paste your code]
```

## The Taste Test

**Scenario 1:** You see a login endpoint that returns different error messages for "user not found" vs "wrong password."

*What's the issue?* This is user enumeration. An attacker can discover valid email addresses by observing which error they get. Return the same generic message for both: "Invalid email or password."

**Scenario 2:** A PR adds a `isAdmin` field to the user object that gets sent to the frontend. The frontend uses it to show/hide admin UI elements.

*What do you think?* The UI visibility is fine, but there better be server-side authorization checks too. Sending `isAdmin` to the client is acceptable for UI purposes, but the client can't be trusted — all admin endpoints must verify permissions server-side.

**Scenario 3:** An endpoint accepts a `userId` parameter and returns that user's data. There's no authorization check because "users can only see their own data from the frontend."

*What's wrong?* The frontend isn't a security boundary. An attacker can call the API directly with any userId. Every endpoint that takes a resource ID must verify the requesting user has access.

**Scenario 4:** You're reviewing code that stores OAuth refresh tokens in the database as plaintext.

*Is this a problem?* It depends on the threat model, but generally yes — refresh tokens should be encrypted at rest. If the database is compromised, plaintext tokens let attackers impersonate users indefinitely. Encrypt them.

**Scenario 5:** A colleague argues against rate limiting because "legitimate users won't hit the limits."

*Your response?* Rate limits aren't primarily for legitimate users — they protect against abuse: brute force attacks, credential stuffing, scraping, denial of service. The limits should be high enough that normal usage never hits them, but low enough to slow down attacks.

## Practical Exercise

Build a complete authentication and authorization system for a multi-tenant project management application:

**Requirements:**

1. **Authentication setup:**
   - Integrate Clerk (or another auth provider)
   - Create a users table that links Clerk IDs to your internal user records
   - Implement a sync webhook that creates local user records when users sign up in Clerk

2. **Multi-tenant authorization:**
   - Users belong to workspaces
   - Each membership has a role: `owner`, `admin`, `member`
   - Implement the workspace policy pattern from this chapter
   - All workspace endpoints must verify membership

3. **Project and task permissions:**
   - Projects belong to workspaces
   - Tasks belong to projects
   - Any workspace member can view projects and tasks
   - Only project members (or workspace admins) can modify tasks
   - Implement cascading permissions checks

4. **Security hardening:**
   - Add rate limiting to authentication endpoints
   - Implement CORS properly for your frontend domain
   - Add security headers
   - Set up npm audit in your build process

**Acceptance criteria:**
- No authorization check relies solely on frontend behavior
- All resource access checks happen at the service layer
- Rate limiting blocks excessive login attempts
- Running `npm audit` produces no high-severity vulnerabilities
- All secrets are in environment variables, not code

**AI Integration:**

Have Claude review your authorization implementation:

```
Here is my authorization system for a multi-tenant project management app.

[paste your policy files and service layer]

Analyze for:
1. Authorization bypass vulnerabilities - can any check be skipped?
2. Inconsistent permission checks across different code paths
3. Missing checks - what operations should have auth but don't?
4. Information leakage through error messages
5. Race conditions that could allow unauthorized access
```

Document what Claude finds and how you address each issue.

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I understand the difference between authentication (identity) and authorization (permissions) and why to handle them differently
- [ ] I can explain why you should use auth providers instead of building authentication yourself
- [ ] I can implement resource-level authorization checks in service layers
- [ ] I know when to return 404 vs 403 and why it matters for security
- [ ] I can implement the policy pattern to centralize and test authorization rules
- [ ] I understand the OWASP Top 10 and can identify these vulnerabilities in code
- [ ] I know how to manage secrets in development and production environments
- [ ] I can implement rate limiting to protect against brute force attacks

Security isn't a feature — it's a practice. The patterns in this chapter should become automatic. Every time you write an endpoint, you should instinctively ask: "Who should be able to call this, and how am I verifying that?"

The patterns here compound. Good input validation prevents injection attacks. Proper authorization prevents data leaks. Rate limiting prevents brute force. Secrets management prevents credential exposure. None of these is sufficient alone, but together they form defense in depth — multiple layers that an attacker must bypass.

Start with the authentication provider. Then implement authorization at the service layer. Add input validation. Configure security headers. Set up dependency scanning. Each layer reduces your attack surface. The goal isn't perfect security — it's making attacks expensive enough that attackers move on to easier targets.
