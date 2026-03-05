# LLM Integration Patterns

## Why This Matters

Calling an LLM API looks simple — send a prompt, get a response. The complexity hides in the details: handling streaming, managing costs, dealing with failures, and getting consistent outputs.

This chapter teaches the patterns for integrating LLMs into production systems. Not a tour of every provider, but the fundamental techniques that work regardless of which model you use.

## Connecting to LLMs

### Basic API Call

```typescript
// src/lib/ai.ts
import Anthropic from '@anthropic-ai/sdk'

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
})

// Model names change frequently — check provider docs for current options
// As of early 2026: Haiku 4.5, Sonnet 4.5/4.6, Opus 4.5/4.6
const DEFAULT_MODEL = 'claude-sonnet-4-5-20250514'

export async function complete(prompt: string): Promise<string> {
  const response = await anthropic.messages.create({
    model: DEFAULT_MODEL,
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  })

  return response.content[0].type === 'text'
    ? response.content[0].text
    : ''
}
```

```typescript
// Usage
const summary = await complete(`
  Summarize this article in 2-3 sentences:

  ${articleText}
`)
```

### Streaming Responses

For user-facing features, stream responses so users see output immediately:

```typescript
export async function* completeStream(
  prompt: string
): AsyncGenerator<string> {
  const stream = await anthropic.messages.stream({
    model: 'claude-sonnet-4-5-20250514',
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  })

  for await (const event of stream) {
    if (event.type === 'content_block_delta' &&
        event.delta.type === 'text_delta') {
      yield event.delta.text
    }
  }
}
```

```typescript
// Stream to HTTP response (Server-Sent Events)
app.get('/api/summarize', async (c) => {
  const text = c.req.query('text')

  return c.stream(async (stream) => {
    const generator = completeStream(`Summarize: ${text}`)

    for await (const chunk of generator) {
      await stream.write(`data: ${JSON.stringify({ text: chunk })}\n\n`)
    }
    await stream.write('data: [DONE]\n\n')
  }, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
    }
  })
})
```

### Handling Errors

LLM APIs fail in specific ways. Handle them:

```typescript
import { APIError, RateLimitError, APIConnectionError } from '@anthropic-ai/sdk'

export async function completeWithRetry(
  prompt: string,
  maxRetries = 3
): Promise<string> {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await complete(prompt)
    } catch (error) {
      if (error instanceof RateLimitError) {
        // Wait and retry (respect Retry-After header if present)
        const waitTime = Math.min(Math.pow(2, attempt) * 1000, 30000)
        await new Promise(r => setTimeout(r, waitTime))
        continue
      }

      if (error instanceof APIConnectionError) {
        // Network issue, retry with backoff
        await new Promise(r => setTimeout(r, 1000 * attempt))
        continue
      }

      // Other errors (invalid request, auth) — don't retry
      throw error
    }
  }

  throw new Error('Max retries exceeded')
}
```

## Structured Output

LLMs return text. You usually want structured data.

### JSON Mode

Ask the model to return JSON:

```typescript
interface TaskExtraction {
  title: string
  dueDate: string | null
  priority: 'low' | 'medium' | 'high'
  assignee: string | null
}

export async function extractTask(text: string): Promise<TaskExtraction> {
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-5-20250514',
    max_tokens: 512,
    messages: [{
      role: 'user',
      content: `Extract task details from this text. Return JSON only, no other text.

Text: "${text}"

Return this exact JSON structure:
{
  "title": "string - the task title",
  "dueDate": "string (YYYY-MM-DD) or null",
  "priority": "low" | "medium" | "high",
  "assignee": "string (name) or null"
}`
    }],
  })

  const content = response.content[0]
  if (content.type !== 'text') {
    throw new Error('Unexpected response type')
  }

  // Parse and validate
  try {
    const parsed = JSON.parse(content.text)
    return TaskExtractionSchema.parse(parsed)  // Zod validation
  } catch (error) {
    throw new Error(`Failed to parse task extraction: ${content.text}`)
  }
}
```

### Validation with Zod

Always validate LLM output — it will occasionally return malformed data:

```typescript
import { z } from 'zod'

const TaskExtractionSchema = z.object({
  title: z.string().min(1),
  dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(),
  priority: z.enum(['low', 'medium', 'high']),
  assignee: z.string().nullable(),
})

type TaskExtraction = z.infer<typeof TaskExtractionSchema>

// Retry on validation failure (model sometimes needs another attempt)
export async function extractTaskWithRetry(text: string): Promise<TaskExtraction> {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      return await extractTask(text)
    } catch (error) {
      if (error instanceof z.ZodError && attempt < 2) {
        continue  // Retry, model might produce valid output
      }
      throw error
    }
  }
  throw new Error('Failed to extract task after retries')
}
```

## Cost Management

LLM calls are expensive. A single API call can cost $0.01-0.10. At scale, this adds up fast.

### Tracking Usage

```typescript
interface UsageMetrics {
  inputTokens: number
  outputTokens: number
  model: string
  costCents: number
}

// Pricing changes frequently — check provider docs for current rates
const PRICING: Record<string, { inputPer1k: number; outputPer1k: number }> = {
  'claude-sonnet-4-5-20250514': {
    inputPer1k: 0.003,  // $3 per 1M input tokens
    outputPer1k: 0.015, // $15 per 1M output tokens
  },
  'claude-haiku-4-5-20251015': {
    inputPer1k: 0.001,  // $1 per 1M input tokens
    outputPer1k: 0.005, // $5 per 1M output tokens
  },
}

export async function completeWithMetrics(
  prompt: string
): Promise<{ text: string; usage: UsageMetrics }> {
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-5-20250514',
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  })

  const pricing = PRICING['claude-sonnet-4-5-20250514']
  const usage: UsageMetrics = {
    inputTokens: response.usage.input_tokens,
    outputTokens: response.usage.output_tokens,
    model: 'claude-sonnet-4-5-20250514',
    costCents: (
      (response.usage.input_tokens / 1000) * pricing.inputPer1k +
      (response.usage.output_tokens / 1000) * pricing.outputPer1k
    ) * 100,
  }

  // Log for monitoring
  console.log({ event: 'llm_call', ...usage })

  return {
    text: response.content[0].type === 'text' ? response.content[0].text : '',
    usage,
  }
}
```

### Caching Responses

Cache identical prompts to avoid redundant calls:

```typescript
import { createHash } from 'crypto'

function hashPrompt(prompt: string, model: string): string {
  return createHash('sha256')
    .update(`${model}:${prompt}`)
    .digest('hex')
    .slice(0, 32)
}

export async function completeWithCache(
  prompt: string,
  options: { ttl?: number; bypassCache?: boolean } = {}
): Promise<string> {
  const { ttl = 3600, bypassCache = false } = options
  const cacheKey = `llm:${hashPrompt(prompt, 'claude-sonnet-4-5-20250514')}`

  if (!bypassCache) {
    const cached = await redis.get(cacheKey)
    if (cached) {
      console.log({ event: 'llm_cache_hit', key: cacheKey })
      return cached
    }
  }

  const result = await complete(prompt)
  await redis.setex(cacheKey, ttl, result)

  return result
}
```

### Model Selection

Use cheaper models when quality requirements are lower:

```typescript
type ModelTier = 'fast' | 'balanced' | 'quality'

// Model names follow the pattern: claude-{tier}-{version}-{date}
// Check docs.anthropic.com for current model IDs
const MODEL_CONFIG = {
  fast: 'claude-haiku-4-5-20251015',     // Cheapest, fastest
  balanced: 'claude-sonnet-4-5-20250514', // Good balance
  quality: 'claude-opus-4-5-20251101',    // Best quality, expensive
}

export async function complete(
  prompt: string,
  tier: ModelTier = 'balanced'
): Promise<string> {
  const response = await anthropic.messages.create({
    model: MODEL_CONFIG[tier],
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  })

  return response.content[0].type === 'text' ? response.content[0].text : ''
}
```

💸 **Startup Cost Callout:** Haiku is 20x cheaper than Opus. Use Haiku for classification, extraction, and simple tasks. Reserve expensive models for generation and complex reasoning.

## Prompt Management

Prompts are code. Treat them that way.

### Prompt Templates

```typescript
// src/prompts/summarize.ts
export const summarizePrompt = {
  system: `You are a helpful assistant that summarizes text.
Your summaries are concise, accurate, and capture the key points.
Respond only with the summary, no preamble.`,

  user: (text: string, maxSentences: number) => `
Summarize the following text in ${maxSentences} sentences or fewer:

<text>
${text}
</text>`,
}

// Usage
const response = await anthropic.messages.create({
  model: 'claude-sonnet-4-5-20250514',
  system: summarizePrompt.system,
  messages: [{
    role: 'user',
    content: summarizePrompt.user(articleText, 3)
  }],
  max_tokens: 256,
})
```

### Few-Shot Examples

Give the model examples of desired output:

```typescript
export const classifyPrompt = {
  system: `Classify customer support tickets into categories.
Return only the category name, nothing else.`,

  examples: [
    { input: "I can't log in to my account", output: "account-access" },
    { input: "The checkout page is broken", output: "bug-report" },
    { input: "Can you add dark mode?", output: "feature-request" },
    { input: "I want a refund", output: "billing" },
  ],

  buildMessages(ticket: string): Message[] {
    const messages: Message[] = []

    for (const ex of this.examples) {
      messages.push({ role: 'user', content: ex.input })
      messages.push({ role: 'assistant', content: ex.output })
    }

    messages.push({ role: 'user', content: ticket })
    return messages
  },
}
```

### Prompt Versioning

Version prompts like code:

```typescript
// src/prompts/v2/classify.ts
export const PROMPT_VERSION = 'classify-v2'

export const classifyPrompt = {
  version: PROMPT_VERSION,
  // ... prompt definition
}

// Log version with every call for debugging
const response = await complete(prompt)
logger.info({
  promptVersion: classifyPrompt.version,
  inputTokens: response.usage.inputTokens,
})
```

## Common Patterns

### Pattern 1: Extraction

Pull structured data from unstructured text:

```typescript
// Extract meeting details from a message
const meetingSchema = z.object({
  title: z.string(),
  attendees: z.array(z.string()),
  dateTime: z.string().nullable(),
  location: z.string().nullable(),
  agenda: z.array(z.string()),
})

async function extractMeeting(message: string) {
  const response = await complete(`
Extract meeting details from this message.
Return JSON matching this schema:
${JSON.stringify(meetingSchema.shape, null, 2)}

Message: "${message}"
`)

  return meetingSchema.parse(JSON.parse(response))
}
```

### Pattern 2: Summarization

Condense long content:

```typescript
async function summarizeDocument(
  document: string,
  targetLength: 'brief' | 'detailed' = 'brief'
) {
  const lengthGuide = targetLength === 'brief'
    ? '2-3 sentences'
    : '1-2 paragraphs'

  return complete(`
Summarize this document in ${lengthGuide}.
Focus on the main points and conclusions.

Document:
${document}
`)
}
```

### Pattern 3: Classification

Categorize inputs into predefined buckets:

```typescript
const CATEGORIES = ['bug', 'feature', 'question', 'complaint', 'praise'] as const

async function classifyFeedback(feedback: string): Promise<typeof CATEGORIES[number]> {
  const response = await complete(`
Classify this customer feedback into exactly one category.
Categories: ${CATEGORIES.join(', ')}

Respond with only the category name, nothing else.

Feedback: "${feedback}"
`)

  const category = response.trim().toLowerCase()
  if (CATEGORIES.includes(category as any)) {
    return category as typeof CATEGORIES[number]
  }

  throw new Error(`Invalid category: ${category}`)
}
```

### Pattern 4: Generation with Constraints

Generate content following specific rules:

```typescript
async function generateEmailReply(
  originalEmail: string,
  tone: 'formal' | 'friendly' | 'apologetic',
  maxWords: number
) {
  return complete(`
Write a reply to this email.

Tone: ${tone}
Maximum length: ${maxWords} words
Do not include a subject line.
Do not use placeholder brackets like [Name].

Original email:
${originalEmail}
`)
}
```

## Testing LLM Features

LLM outputs are non-deterministic. Testing requires different approaches.

### Property-Based Testing

Test properties that should always hold:

```typescript
describe('extractTask', () => {
  it('always returns required fields', async () => {
    const inputs = [
      'Finish the report by Friday',
      'Call John about the project',
      'urgent: fix the bug in checkout',
    ]

    for (const input of inputs) {
      const result = await extractTask(input)

      // Structure is always valid
      expect(result.title).toBeDefined()
      expect(result.title.length).toBeGreaterThan(0)
      expect(['low', 'medium', 'high']).toContain(result.priority)
    }
  })
})
```

### Golden Tests

Compare against known-good outputs:

```typescript
describe('classifyFeedback', () => {
  const goldenCases = [
    { input: "The app crashes when I click save", expected: 'bug' },
    { input: "I love the new dark mode!", expected: 'praise' },
    { input: "Can you add calendar integration?", expected: 'feature' },
  ]

  for (const { input, expected } of goldenCases) {
    it(`classifies "${input.slice(0, 30)}..." as ${expected}`, async () => {
      const result = await classifyFeedback(input)
      expect(result).toBe(expected)
    })
  }
})
```

### Evaluation Metrics

For more rigorous testing, evaluate on a held-out dataset:

```typescript
async function evaluateClassifier(testCases: { input: string; label: string }[]) {
  let correct = 0

  for (const { input, label } of testCases) {
    const predicted = await classifyFeedback(input)
    if (predicted === label) correct++
  }

  return {
    accuracy: correct / testCases.length,
    total: testCases.length,
  }
}
```

## The Taste Test

**Scenario 1:** Every API endpoint calls an LLM to "enhance" its response.

*Overuse.* LLM calls are slow and expensive. Only use AI where it provides clear value. A CRUD endpoint doesn't need LLM enhancement.

**Scenario 2:** An LLM is used to validate email addresses.

*Wrong tool.* Regex or a validation library is faster, cheaper, and more reliable. LLMs are for fuzzy, language-based tasks.

**Scenario 3:** A prompt says "Return valid JSON" but there's no validation or retry logic.

*Fragile.* LLMs occasionally return malformed JSON. Always validate with Zod/JSON Schema and retry on failure.

**Scenario 4:** A team uses Opus or GPT-5 for a simple classification task with 5 categories.

*Expensive.* Simpler models (Haiku, GPT-5-mini) handle classification well. Save expensive models for complex generation. Model tiers exist for a reason — match the model to the task complexity.

## Practical Exercise

Add an AI-powered feature to your TaskFlow API:

**Feature: Smart Task Creation**

Accept natural language input and create a properly structured task:

Input: "Remind me to call Sarah next Tuesday about the quarterly review, high priority"

Output:
```json
{
  "title": "Call Sarah about quarterly review",
  "dueDate": "2026-03-11",
  "priority": "high",
  "tags": ["call", "quarterly-review"]
}
```

**Requirements:**
1. Endpoint that accepts natural language and returns structured task
2. Validation with Zod schema
3. Retry logic for parsing failures
4. Cost tracking (log token usage)
5. Caching for identical inputs

**Acceptance criteria:**
- Invalid LLM output triggers retry (up to 3 times)
- Token usage is logged with every request
- Duplicate inputs return cached results

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can connect to LLM APIs and handle streaming responses
- [ ] I know how to get structured output from LLMs with validation
- [ ] I understand cost management strategies (caching, model selection)
- [ ] I can write maintainable prompts with versioning
- [ ] I know when to use AI vs. traditional code

LLM integration is about treating AI as an API with unique characteristics — embrace its capabilities while managing its costs and unreliability.
