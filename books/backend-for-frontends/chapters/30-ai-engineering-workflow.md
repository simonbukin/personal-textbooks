# AI in Your Engineering Workflow

## Why This Matters

You've learned to build AI features. Now learn to use AI as an engineering tool.

AI changes how you write code, debug problems, learn technologies, and make decisions. Used well, it's a multiplier. Used poorly, it's a crutch that degrades your skills.

This chapter teaches practical AI workflows for engineering work — what AI is good at, what it's bad at, and how to use it effectively without losing the ability to think for yourself.

## Where AI Helps Most

### Code Generation

AI excels at generating boilerplate, translating between formats, and implementing well-defined patterns.

**Good prompts:**
```
Write a Zod schema for this TypeScript interface:
interface User {
  id: string
  email: string
  createdAt: Date
  settings: {
    theme: 'light' | 'dark'
    notifications: boolean
  }
}
```

```
Convert this curl command to a fetch request in TypeScript:
curl -X POST https://api.example.com/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "John", "email": "john@example.com"}'
```

**Tips for code generation:**
- Be specific about language, framework, and style
- Include example input/output when possible
- Review output carefully — AI makes subtle mistakes
- Don't accept code you don't understand

### Debugging

AI can analyze error messages and suggest causes.

**Good prompt:**
```
I'm getting this error in my Node.js application:

Error: ECONNREFUSED 127.0.0.1:5432
    at TCPConnectWrap.afterConnect [as oncomplete] (net.js:1141:16)

Context:
- Running in Docker container
- PostgreSQL is in a separate container
- Connection string: postgres://localhost:5432/mydb
- Both containers are in the same docker-compose network

What's causing this and how do I fix it?
```

AI will correctly identify that `localhost` inside a container refers to the container itself, not the host or other containers. The fix is to use the service name from docker-compose.

### Learning New Technologies

AI is an excellent tutor for unfamiliar tools.

**Good prompt:**
```
I'm familiar with Express.js and need to learn Hono.
Give me a comparison showing:
1. Basic route handler
2. Middleware
3. Request/response handling
4. Error handling

Show Express code and equivalent Hono code side by side.
```

**For deep dives:**
```
Explain how PostgreSQL's MVCC works.
I understand transactions at a high level.
Explain:
1. How concurrent reads/writes are handled
2. What vacuum does and why it's needed
3. How this affects query performance
4. When I might see problems from MVCC
```

### Code Review

AI can catch issues you might miss.

**Good prompt:**
```
Review this function for security issues:

async function getUser(userId: string) {
  const result = await db.query(
    `SELECT * FROM users WHERE id = '${userId}'`
  )
  return result.rows[0]
}
```

AI will immediately flag the SQL injection vulnerability.

**For broader review:**
```
Review this pull request diff for:
1. Security issues
2. Performance problems
3. Code style inconsistencies
4. Missing error handling
5. Edge cases not handled

[paste diff]
```

### Writing Documentation

AI can draft docs you then refine.

**Good prompt:**
```
Write API documentation for this endpoint:

POST /api/tasks
Body: { title: string, dueDate?: string, projectId: string }
Response: { id: string, title: string, status: "pending", createdAt: string }
Errors: 400 (validation), 404 (project not found), 401 (unauthorized)

Include:
- Description
- Request/response examples
- Error cases
- Authentication requirements
```

## Where AI Falls Short

### Architecture Decisions

AI doesn't know your constraints, team, timeline, or business context.

**Don't ask:**
```
Should I use microservices or a monolith?
```

**Instead, ask:**
```
I'm deciding between microservices and a monolith for a new project.
Team: 4 engineers, shipping MVP in 3 months
Scale: Expecting 10K users first year
Current skills: Strong in Node.js, minimal DevOps experience

What are the trade-offs I should consider given these constraints?
```

AI can inform your thinking, but the decision is yours.

### Security-Critical Code

AI makes subtle security mistakes. Never trust AI for:
- Authentication/authorization logic
- Cryptography
- Input validation for security-critical paths
- Access control decisions

Always have a human security review for critical code.

### Understanding Your Codebase

AI doesn't know your codebase's history, why decisions were made, or what's tried before.

**Don't ask:**
```
Why is our authentication slow?
```

AI can't answer this. Instead, investigate yourself, then use AI to interpret what you find:

```
I profiled our authentication endpoint and found:
- 200ms in password hashing (bcrypt, cost factor 12)
- 150ms in database query (SELECT with JOIN on sessions table)
- 50ms in JWT generation

Which of these is most worth optimizing? What are the trade-offs?
```

### Novel Problems

AI is great at pattern matching. It's mediocre at novel problems where there's no established pattern.

If your problem is unique, AI suggestions may be subtly wrong in ways that are hard to spot.

## Effective Prompting

### Be Specific

```
# ❌ Vague
Write a function to process data

# ✅ Specific
Write a TypeScript function that:
- Takes an array of User objects
- Filters to users who signed up in the last 30 days
- Groups them by signup source (organic, referral, paid)
- Returns counts per source
```

### Provide Context

```
# ❌ No context
Fix this error: Cannot read property 'map' of undefined

# ✅ With context
Fix this error: Cannot read property 'map' of undefined

Code:
function UserList({ users }) {
  return users.map(u => <div>{u.name}</div>)
}

The component is called with users fetched from an API.
The error happens on initial render.
```

### Request Explanations

```
# Instead of just asking for code:
Write a debounce function and explain:
1. Why each line is necessary
2. How the closure preserves state
3. When I'd use this vs throttle
```

### Iterate

AI rarely gets it right the first time. Refine:

```
# Initial response has issues
That approach has a race condition when multiple users submit simultaneously.
Revise to handle concurrent submissions safely.
```

## AI Assistants in Your Editor

Claude Code (this tool), GitHub Copilot, Cursor, and similar tools integrate AI into your editor.

### When to Use Completion

- Boilerplate you've written before
- Test cases following established patterns
- Data transformations with clear input/output
- Documentation strings

### When to Disable/Ignore Completion

- Complex logic where you need to think
- Security-sensitive code
- Novel algorithms
- When you're learning (let your brain work)

### Code-with-AI Workflow

1. **Write the signature yourself** — you define the interface
2. **Let AI suggest the implementation**
3. **Review critically** — does it handle edge cases? Is it efficient?
4. **Test thoroughly** — AI-generated code needs tests like any code
5. **Understand everything** — if you can't explain it, don't ship it

## Building AI Skills Responsibly

AI assistance is addictive. The quick wins feel great. But over-reliance degrades your skills.

### Stay Sharp

- **Write without AI regularly.** Pick a day each week to code without assistance.
- **Understand before accepting.** If AI generates something, make sure you could have written it.
- **Do hard things yourself first.** Struggle, then use AI to verify or improve.

### Know When to Disconnect

- **Learning new concepts.** Let your brain build the mental models.
- **Debugging complex issues.** Develop your debugging intuition.
- **Architecture work.** Your judgment, not AI's, should drive decisions.

### The 10x Pitfall

AI makes some tasks 10x faster. This doesn't make you a 10x engineer — it makes you faster at those specific tasks.

The most valuable engineering skills — judgment, system design, debugging intuition, team collaboration — aren't improved by AI. Don't neglect them.

## AI-Assisted Testing

AI is excellent at generating test cases:

```
Write unit tests for this function:

function parseDate(input: string): Date | null {
  // Accepts: "2026-01-15", "Jan 15, 2026", "01/15/2026"
  // Returns null for invalid input
  ...
}

Include:
- Valid inputs in each format
- Invalid inputs (wrong format, impossible dates)
- Edge cases (leap years, month boundaries)
```

**But:** AI often misses subtle edge cases. Use AI-generated tests as a starting point, then add cases your domain knowledge suggests.

## AI-Assisted Code Review

Use AI to supplement (not replace) human review:

```
Review this diff for common issues.
Focus on: security, performance, and maintainability.
Flag anything that looks suspicious but don't change style preferences.

[diff]
```

AI catches:
- Obvious security issues (SQL injection, XSS)
- Performance antipatterns (N+1 queries, missing indexes)
- Logic errors (off-by-one, null handling)

AI misses:
- Business logic correctness
- Whether the approach fits the codebase
- Long-term maintainability concerns
- Team conventions and preferences

## The Taste Test

**Scenario 1:** An engineer accepts every AI code suggestion without review "because AI is smart."

*Dangerous.* AI makes mistakes constantly. Every suggestion needs human review. Blindly accepting AI code ships bugs.

**Scenario 2:** An engineer refuses to use AI tools "because I want to do it myself."

*Wasteful.* AI accelerates routine work. Refusing to use it for boilerplate and translation is like refusing to use Google. Use AI for what it's good at, save your brain for what matters.

**Scenario 3:** A team relies on AI to review all pull requests and skips human review.

*Insufficient.* AI catches surface issues but misses context, business logic, and architectural fit. Human review remains essential.

**Scenario 4:** An engineer uses AI to learn a new framework by having it write all the code while they watch.

*Not learning.* Watching AI write code doesn't build skills. Struggle first, use AI to fill gaps, then review and understand what it produced.

## Practical Exercise

Use AI to accelerate your work on a real task:

**Requirements:**
1. Pick a feature or bug in a project you're working on
2. Use AI at each stage (planning, implementation, testing, documentation)
3. Track where AI helped and where it fell short
4. Note any AI mistakes you caught

**Reflection questions:**
- Where did AI save the most time?
- Where did AI suggestions need significant revision?
- Did you trust AI appropriately, or did you over/under-rely on it?
- What would you do differently next time?

**Deliverable:** A short writeup (1 page) on your AI-assisted workflow and lessons learned.

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I know where AI helps most in engineering work
- [ ] I understand AI's limitations and where human judgment is essential
- [ ] I can write effective prompts for code generation and debugging
- [ ] I use AI tools to accelerate routine work without becoming dependent
- [ ] I maintain my core engineering skills while leveraging AI assistance

AI is a tool, not a replacement for engineering judgment. The best engineers use AI to move faster on routine work while applying their own thinking to hard problems. That's the balance to strike.
