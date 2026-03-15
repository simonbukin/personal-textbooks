# Chapter 9: Production Engineering

## Why This Matters

You've built an agent. It works on your machine, with your test inputs, on a good day. Congratulations — you've completed roughly 30% of the engineering work. The remaining 70% is everything this chapter covers: making it fast enough that users don't abandon it, cheap enough that it doesn't bankrupt you, reliable enough that it doesn't fail at 2 AM, safe enough that it doesn't embarrass you, versioned so you can roll back when it breaks, and compliant so you don't get sued. None of this is glamorous. All of it is mandatory.

Production AI engineering comes down to something deceptively simple: the biggest production AI failures are usually software engineering failures, not AI failures. Missing retry logic. No cost caps. No output validation. No version control for prompts. Teams obsess over prompt quality and model selection while shipping code that would get rejected in a first-round code review for any other feature. The model is probabilistic and unpredictable; your infrastructure around it should be deterministic and boring.

This chapter bridges the gap between "it works in a demo" and "it works at scale, under load, with adversarial users, at 3 AM, for months." If you've internalized the capability/reliability gap from Chapter 1, this is where you learn to close it. Better engineering, not better prompts. By the end, you'll have a concrete checklist for hardening any AI feature, and you'll understand why most production incidents trace back to the infrastructure, not the model.

## Latency Optimization

Users don't experience latency as a number. They experience it as a feeling. A 3-second wait with a loading spinner feels interminable. A 3-second wait where tokens stream onto the screen word by word feels responsive and alive. Perceived latency matters more than actual latency, and that's why **streaming** is a UX requirement. The time-to-first-token (TTFT), how long before the user sees any response at all, is your most important latency metric, not total completion time.

Streaming is table stakes for any user-facing AI feature. When a user submits a query and stares at a blank screen for 4 seconds, they start wondering if the system is broken. When they see the first words appear after 400 milliseconds, they settle in and read along as the response builds. The implementation is straightforward with the Anthropic SDK: you switch from `messages.create` to `messages.stream` and handle the event stream. The harder part is designing your frontend to render partial responses gracefully, handle code blocks that haven't closed yet, and manage the UI state between "streaming" and "complete."

> ⚡ **Production Tip:** Measure time-to-first-token (TTFT) separately from total response time. Your P95 TTFT should be under 1 second for interactive features. If it's not, investigate whether your system prompt is too long, your network has unnecessary hops, or you're batching requests that should be individual.

**Prompt caching** is one of the most impactful and underutilized optimizations available today. The concept is simple: if the beginning of your prompt is identical across multiple requests (which it almost always is, since system prompts and context documents don't change per-request) the API can cache the KV computations for that prefix and skip reprocessing it on subsequent calls. With Anthropic's prompt caching, you get approximately 90% cost reduction on cached input tokens and noticeably lower latency. The cache has a 5-minute TTL that refreshes on each hit, so active features with steady traffic maintain their cache naturally.

Maximizing cache hits requires designing your prompts with a **stable prefix**. Everything that doesn't change per-request (your system prompt, few-shot examples, reference documents, tool definitions) goes at the beginning. Everything that varies per-request (the user's message, conversation history) goes at the end. This sounds obvious, but many developers interleave static and dynamic content throughout their prompts, destroying cache efficiency. The cache matches on exact prefix bytes, so even a single character difference in the middle of your prompt invalidates everything after it.

A concrete implementation demonstrating prompt caching with the Anthropic SDK:

```typescript
// src/lib/cached-client.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

// Your stable system prompt — this is the cacheable prefix.
// Mark it with cache_control to tell the API to cache it.
const SYSTEM_PROMPT_BLOCKS: Anthropic.Messages.TextBlockParam[] = [
  {
    type: "text",
    text: `You are a senior customer support agent for Acme Corp.
You have access to our product catalog, return policies, and order
management system. Always verify order numbers before taking action.
Never share internal pricing or margin information.
Respond concisely — most customers want answers, not essays.`,
    cache_control: { type: "ephemeral" },
  },
];

// Reference documents that rarely change — also cacheable.
// In practice, you'd load these from your knowledge base.
const REFERENCE_DOCS: Anthropic.Messages.TextBlockParam[] = [
  {
    type: "text",
    text: `<reference_docs>
    <!-- 50KB of product catalog, return policies, FAQs -->
    <!-- This content changes weekly, not per-request -->
    </reference_docs>`,
    cache_control: { type: "ephemeral" },
  },
];

interface CachedResponse {
  content: string;
  inputTokens: number;
  cachedTokens: number;
  outputTokens: number;
  cacheSavings: number;
}

export async function handleSupportQuery(
  conversationHistory: Anthropic.Messages.MessageParam[],
  userMessage: string
): Promise<CachedResponse> {
  // Conversation history goes after the cached prefix.
  // The system prompt and reference docs stay constant —
  // they'll hit the cache on every call after the first.
  const messages: Anthropic.Messages.MessageParam[] = [
    ...conversationHistory,
    { role: "user", content: userMessage },
  ];

  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    system: [...SYSTEM_PROMPT_BLOCKS, ...REFERENCE_DOCS],
    messages,
  });

  const usage = response.usage;
  const cachedTokens = usage.cache_read_input_tokens ?? 0;
  const uncachedInputTokens = usage.input_tokens;

  // Calculate savings: cached tokens cost ~10% of regular input tokens.
  // Regular input: $3/MTok for Sonnet. Cached: $0.30/MTok.
  const fullCostPerMTok = 3.0;
  const cachedCostPerMTok = 0.3;
  const savingsPerMTok = fullCostPerMTok - cachedCostPerMTok;
  const cacheSavings = (cachedTokens / 1_000_000) * savingsPerMTok;

  const textContent = response.content
    .filter((block): block is Anthropic.Messages.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("");

  return {
    content: textContent,
    inputTokens: uncachedInputTokens,
    cachedTokens,
    outputTokens: usage.output_tokens,
    cacheSavings,
  };
}
```

The critical design decision is the ordering: system prompt first (cached), reference docs second (cached), then conversation history (not cached). Every request after the first in a 5-minute window will read the system prompt and reference docs from cache, paying only 10% of the normal input token cost. For a system processing thousands of support queries per hour with a 50K-token context of reference documents, the savings are substantial. We're talking tens of thousands of dollars per month.

> 💸 **Cost Callout:** A support system processing 10,000 queries/day with a 50K-token system prompt + reference docs costs roughly $1,500/day without caching. With prompt caching and a reasonable hit rate of 95%, that drops to approximately $225/day for the cached portion. That's over $37,000/month in savings from a change that takes an afternoon to implement.

**Parallel calls** are your next latency lever. When your system needs to perform multiple independent operations (checking a knowledge base, classifying user intent, looking up account information) there's no reason to do them sequentially. Fan out, await all results, then proceed. This is basic async programming, but developers building AI features often default to sequential chains because that's how they think about the "reasoning" flow. The model reasons sequentially; your orchestration code doesn't have to.

```typescript
// src/lib/parallel-operations.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

interface TriageResult {
  intent: string;
  sentiment: string;
  relevantDocs: string[];
  accountInfo: Record<string, unknown> | null;
}

async function classifyIntent(message: string): Promise<string> {
  const response = await client.messages.create({
    model: "claude-haiku-4-20250514",
    max_tokens: 50,
    messages: [{ role: "user", content: message }],
    system:
      "Classify the user message into exactly one category: billing, technical, returns, general. Respond with only the category name.",
  });
  const block = response.content[0];
  return block.type === "text" ? block.text.trim() : "general";
}

async function analyzeSentiment(message: string): Promise<string> {
  const response = await client.messages.create({
    model: "claude-haiku-4-20250514",
    max_tokens: 50,
    messages: [{ role: "user", content: message }],
    system:
      "Classify the sentiment: positive, neutral, frustrated, angry. Respond with only the sentiment.",
  });
  const block = response.content[0];
  return block.type === "text" ? block.text.trim() : "neutral";
}

async function retrieveRelevantDocs(message: string): Promise<string[]> {
  // In production, this queries your vector DB.
  // Simulated here for completeness.
  return ["doc_returns_policy_v3", "doc_refund_timeline"];
}

async function lookupAccount(message: string): Promise<Record<string, unknown> | null> {
  // Extract and look up account/order numbers.
  const orderMatch = message.match(/order\s*#?\s*(\d+)/i);
  if (!orderMatch) return null;
  // In production, this queries your order database.
  return { orderId: orderMatch[1], status: "shipped" };
}

export async function triageMessage(message: string): Promise<TriageResult> {
  // All four operations are independent — run them in parallel.
  // Total latency = max(individual latencies), not sum.
  const [intent, sentiment, relevantDocs, accountInfo] = await Promise.all([
    classifyIntent(message),
    analyzeSentiment(message),
    retrieveRelevantDocs(message),
    lookupAccount(message),
  ]);

  return { intent, sentiment, relevantDocs, accountInfo };
}
```

With sequential execution, four operations each taking 500ms would cost you 2 seconds. With `Promise.all`, you pay for the slowest one — roughly 500ms total. For user-facing features, this is the difference between "feels snappy" and "feels sluggish."

**Speculative execution** takes parallelism one step further: you start work before you're certain you'll need the result. If your system usually needs to fetch account details after classifying intent, start the account lookup at the same time as intent classification. If the intent turns out to be "general" and you didn't need the account data, you've wasted one cheap API call. If the intent is "billing" and you do need it, you've saved 500ms. The math usually favors speculative execution when the speculated operation is cheap and the probability of needing it is above 30-40%.

## Cost Optimization

The fastest way to blow your AI budget isn't a single expensive model call. It's an architecture that makes thousands of unnecessary expensive calls. **Model routing** — using the right-sized model for each task — is your single most important cost lever after prompt caching.

Most requests to your AI system don't require frontier-level reasoning. A customer asking "what are your hours?" doesn't need Claude Opus. A request to extract a date from an email doesn't need 200B parameters. But a customer with a complex billing dispute involving multiple orders, partial refunds, and a misapplied promo code — that benefits from a model that can hold the full context and reason through it carefully.

> 🤔 **Taste Moment:** Model routing is about being appropriate, not cheap. Using Opus for everything is like using a chainsaw to cut butter. It works, but you're paying for capability you don't need, and the extra latency actively hurts user experience for simple queries.

A model routing implementation that demonstrates the pattern:

```typescript
// src/lib/model-router.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

type ModelTier = "fast" | "balanced" | "powerful";

interface RoutingDecision {
  tier: ModelTier;
  model: string;
  reason: string;
  estimatedCostPerCall: number;
}

// Cost per million tokens (input/output) as of early 2026.
// Check https://www.anthropic.com/pricing for current rates.
const MODEL_CONFIG: Record<ModelTier, { model: string; inputCostPerMTok: number; outputCostPerMTok: number }> = {
  fast: {
    model: "claude-haiku-4-20250514",
    inputCostPerMTok: 0.80,
    outputCostPerMTok: 4.0,
  },
  balanced: {
    model: "claude-sonnet-4-20250514",
    inputCostPerMTok: 3.0,
    outputCostPerMTok: 15.0,
  },
  powerful: {
    model: "claude-opus-4-20250514",
    inputCostPerMTok: 15.0,
    outputCostPerMTok: 75.0,
  },
};

async function classifyComplexity(userMessage: string): Promise<RoutingDecision> {
  // Use the cheapest model to decide which model handles the real work.
  // This classifier call costs fractions of a cent.
  const response = await client.messages.create({
    model: MODEL_CONFIG.fast.model,
    max_tokens: 100,
    messages: [{ role: "user", content: userMessage }],
    system: `Classify the complexity of this support query.
Respond with exactly one JSON object, no other text:
{"tier": "fast|balanced|powerful", "reason": "one sentence explanation"}

Rules:
- "fast": Simple factual questions, greetings, FAQs, status checks.
- "balanced": Multi-step issues, policy interpretation, account changes.
- "powerful": Complex disputes, multi-order issues, legal/compliance, edge cases requiring nuanced judgment.`,
  });

  const block = response.content[0];
  const text = block.type === "text" ? block.text : '{"tier":"balanced","reason":"fallback"}';

  let parsed: { tier: ModelTier; reason: string };
  try {
    parsed = JSON.parse(text);
    if (!["fast", "balanced", "powerful"].includes(parsed.tier)) {
      parsed = { tier: "balanced", reason: "Invalid tier — defaulting to balanced" };
    }
  } catch {
    parsed = { tier: "balanced", reason: "Parse failure — defaulting to balanced" };
  }

  const config = MODEL_CONFIG[parsed.tier];
  // Estimate based on average token counts for this tier.
  const avgInputTokens = 2000;
  const avgOutputTokens = 500;
  const estimatedCostPerCall =
    (avgInputTokens / 1_000_000) * config.inputCostPerMTok +
    (avgOutputTokens / 1_000_000) * config.outputCostPerMTok;

  return {
    tier: parsed.tier,
    model: config.model,
    reason: parsed.reason,
    estimatedCostPerCall,
  };
}

export async function routedQuery(
  userMessage: string,
  systemPrompt: string,
  conversationHistory: Anthropic.Messages.MessageParam[]
): Promise<{ response: string; routing: RoutingDecision; actualCost: number }> {
  const routing = await classifyComplexity(userMessage);

  const result = await client.messages.create({
    model: routing.model,
    max_tokens: 2048,
    system: systemPrompt,
    messages: [...conversationHistory, { role: "user", content: userMessage }],
  });

  const block = result.content[0];
  const responseText = block.type === "text" ? block.text : "";
  const config = MODEL_CONFIG[routing.tier];
  const actualCost =
    (result.usage.input_tokens / 1_000_000) * config.inputCostPerMTok +
    (result.usage.output_tokens / 1_000_000) * config.outputCostPerMTok;

  return { response: responseText, routing, actualCost };
}
```

Let's do the cost math. Suppose your support system handles 100,000 queries per day. Without routing, using Sonnet for everything at an average of 2,000 input and 500 output tokens per query: that's ($3.00 × 2,000 + $15.00 × 500) / 1,000,000 × 100,000 = $1,350/day. With routing, assume 60% are "fast" (Haiku), 30% are "balanced" (Sonnet), and 10% are "powerful" (Opus). The blended cost drops to roughly $550/day — a 60% reduction. Add prompt caching on top of that, and you're looking at $200-300/day for the same workload.

**Semantic caching** goes beyond exact-match caching by recognizing that "What's your return policy?" and "How do I return something?" should return the same answer. The implementation typically embeds incoming queries, checks cosine similarity against cached query embeddings, and returns the cached response if similarity exceeds a threshold (usually 0.92-0.95). This works well for support, FAQ, and search use cases where the same questions recur in slightly different phrasings. The tradeoff: you're adding embedding latency and risking stale or incorrect cache hits when queries are similar but semantically distinct. Start with a high similarity threshold and tune down carefully.

**Output length control** is a surprisingly effective cost lever. Models, left to their own devices, tend toward verbosity. They'll produce 500 tokens when 100 would suffice. Since output tokens are 3-5x more expensive than input tokens across most providers, explicit length instructions in your system prompt ("respond in 2-3 sentences," "be concise," "answer in under 100 words") directly reduce cost. Setting `max_tokens` is a hard cutoff that truncates mid-sentence. Instructing the model to generate appropriate-length responses in the first place is the better approach.

> 💸 **Cost Callout:** The **Batch API** offers 50% cost reduction for workloads that can tolerate up to 24 hours of latency. Nightly report generation, bulk classification, eval suite runs, content moderation backlogs: any task where you don't need results immediately is a candidate. At scale, running your eval suite through the Batch API instead of synchronous calls can save thousands per month.

## Reliability Engineering

Your AI feature will go down. The model API will return 500 errors. Rate limits will be hit. Timeouts will expire. The question isn't whether these failures happen; it's whether your system handles them gracefully or falls over spectacularly. This is the same reliability work you'd do for any external API dependency. The tragedy is how many teams skip it for AI features specifically.

**Retry with exponential backoff and jitter** is the foundation, and most implementations get it wrong. Plain exponential backoff (wait 1s, then 2s, then 4s, then 8s) creates a thundering herd problem. When a service recovers from an outage, every client retries at the same intervals, creating synchronized waves of traffic that can push the service right back down. **Jitter** adds randomness to each retry delay, spreading the load across time.

The correct implementation uses "full jitter": the delay for each retry is a random value between 0 and the exponential cap. This is more aggressive than "equal jitter" (which uses half-exponential plus random) but distributes load most evenly. Here's the right way:

```typescript
// src/lib/retry.ts
import Anthropic from "@anthropic-ai/sdk";

interface RetryConfig {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
}

const DEFAULT_RETRY_CONFIG: RetryConfig = {
  maxRetries: 3,
  baseDelayMs: 1000,
  maxDelayMs: 30000,
};

function calculateDelay(attempt: number, config: RetryConfig): number {
  // Full jitter: random value between 0 and min(cap, base * 2^attempt).
  // This distributes retry load most evenly across time.
  const exponentialDelay = config.baseDelayMs * Math.pow(2, attempt);
  const cappedDelay = Math.min(exponentialDelay, config.maxDelayMs);
  return Math.random() * cappedDelay;
}

function isRetryable(error: unknown): boolean {
  if (error instanceof Anthropic.APIError) {
    // 429: rate limited. 500, 502, 503: server errors. 529: overloaded.
    // 400, 401, 403, 404: client errors — don't retry these.
    return [429, 500, 502, 503, 529].includes(error.status);
  }
  // Network errors (ECONNRESET, ETIMEDOUT) are retryable.
  if (error instanceof Error && "code" in error) {
    const code = (error as NodeJS.ErrnoException).code;
    return ["ECONNRESET", "ETIMEDOUT", "ECONNREFUSED"].includes(code ?? "");
  }
  return false;
}

export async function withRetry<T>(
  operation: () => Promise<T>,
  config: RetryConfig = DEFAULT_RETRY_CONFIG
): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      if (!isRetryable(error) || attempt === config.maxRetries) {
        throw error;
      }

      const delay = calculateDelay(attempt, config);
      console.warn(
        `Attempt ${attempt + 1} failed, retrying in ${Math.round(delay)}ms`,
        error instanceof Error ? error.message : error
      );
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}
```

Note what this implementation gets right: it distinguishes between retryable and non-retryable errors. A 401 (unauthorized) won't get better on retry. Your API key is wrong. A 429 (rate limited) or 503 (service unavailable) almost certainly will improve. Retrying non-retryable errors wastes time and can mask real configuration problems.

A **circuit breaker** builds on retry logic by recognizing when a service is down and stopping retries entirely. It has three states: **closed** (normal operation, requests pass through), **open** (service is down, requests fail immediately without trying), and **half-open** (testing whether the service has recovered). Without a circuit breaker, your retry logic will keep hammering a downed service, wasting latency budget and potentially delaying recovery.

```typescript
// src/lib/circuit-breaker.ts

type CircuitState = "closed" | "open" | "half-open";

interface CircuitBreakerConfig {
  failureThreshold: number;    // Failures before opening the circuit.
  resetTimeoutMs: number;      // How long to wait before trying half-open.
  halfOpenMaxAttempts: number;  // Successful calls needed to close again.
}

export class CircuitBreaker {
  private state: CircuitState = "closed";
  private failureCount = 0;
  private successCount = 0;
  private lastFailureTime = 0;
  private config: CircuitBreakerConfig;

  constructor(config: Partial<CircuitBreakerConfig> = {}) {
    this.config = {
      failureThreshold: config.failureThreshold ?? 5,
      resetTimeoutMs: config.resetTimeoutMs ?? 60_000,
      halfOpenMaxAttempts: config.halfOpenMaxAttempts ?? 2,
    };
  }

  async execute<T>(operation: () => Promise<T>, fallback: () => Promise<T>): Promise<T> {
    if (this.state === "open") {
      // Check if enough time has passed to try half-open.
      if (Date.now() - this.lastFailureTime >= this.config.resetTimeoutMs) {
        this.state = "half-open";
        this.successCount = 0;
        console.info("Circuit breaker: transitioning to half-open");
      } else {
        console.warn("Circuit breaker: open — using fallback");
        return fallback();
      }
    }

    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      console.warn(
        `Circuit breaker: failure #${this.failureCount} (state: ${this.state})`,
        error instanceof Error ? error.message : error
      );

      if (this.state === "open") {
        return fallback();
      }
      throw error;
    }
  }

  private onSuccess(): void {
    if (this.state === "half-open") {
      this.successCount++;
      if (this.successCount >= this.config.halfOpenMaxAttempts) {
        this.state = "closed";
        this.failureCount = 0;
        console.info("Circuit breaker: closed (service recovered)");
      }
    } else {
      this.failureCount = 0;
    }
  }

  private onFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();

    if (
      this.failureCount >= this.config.failureThreshold ||
      this.state === "half-open"
    ) {
      this.state = "open";
      console.warn("Circuit breaker: opened (service appears down)");
    }
  }

  getState(): CircuitState {
    return this.state;
  }
}
```

In production, you'd use the circuit breaker alongside your retry logic and a **fallback hierarchy**: try the primary model with retries. If the circuit opens, try a smaller/cheaper model (it may be on different infrastructure). If that fails, return a cached response for semantically similar queries. If no cache hit, fall back to rule-based responses ("I'm having trouble right now, let me connect you with a human agent"). If nothing else works, escalate to a human. Each fallback level is a degradation, but a degraded response is infinitely better than an error page.

> ⚡ **Production Tip:** Set your AI API timeouts based on user expectations, not API maximums. The Anthropic API allows requests that run for minutes. Your user will abandon the page after 10-15 seconds. Set a timeout of 30 seconds maximum for interactive features, with streaming making the wait feel shorter. For background processing, timeout limits can be more generous.

Timeouts deserve special attention because they're the most common source of reliability issues in AI features. Unlike traditional APIs that respond in milliseconds, LLM calls routinely take 2-10 seconds, and complex reasoning calls can take 30 seconds or more. Your timeout strategy needs two layers: a hard timeout at the HTTP level (abort the request after N seconds) and a soft timeout at the UX level (show a fallback or "still working..." message after a shorter interval). The hard timeout prevents hung connections from consuming resources indefinitely; the soft timeout manages user expectations.

## Safety and Guardrails

Your AI feature is a public-facing system that generates natural language. It will receive adversarial inputs. It will occasionally produce outputs that shouldn't reach users. If you're not filtering both sides — inputs and outputs — you're running an unguarded system in production, and it's a matter of when, not if, something goes wrong.

**Input filtering** is your first line of defense. Before a user's message ever reaches the model, you should check for prompt injection attempts (as we covered in Chapter 5), PII that shouldn't be processed (credit card numbers, Social Security numbers in contexts where you don't handle them), and content that violates your acceptable use policy. Implementations range from regex patterns for known PII formats to a classifier model that scores inputs for attack patterns.

The tradeoff between filtering approaches is cost and latency versus coverage. Regex-based rules are free and instant but miss anything that doesn't match a pattern. Dedicated moderation APIs (like OpenAI's Moderation endpoint or Anthropic's safety classifiers) add 50-200ms of latency and a small per-call cost but catch a wider range of problematic inputs. A full classifier model gives you the most control but adds the most latency and cost. In practice, most production systems use a layered approach: fast regex checks first, then a moderation API for inputs that pass the initial screen.

**Output filtering** is equally important and more often neglected. Even with a well-tuned system prompt and safety-trained model, outputs can contain content that shouldn't reach users: hallucinated URLs that lead to unrelated or harmful sites, generated phone numbers that belong to real people, confidential information the model inferred from context clues, or responses that technically answer the question but in a tone inappropriate for your brand. Output filtering should validate format (did the model return valid JSON when you asked for it?), check for safety (does this response contain anything your content policy prohibits?), and where possible, verify factual claims against your retrieved context.

```typescript
// src/lib/guardrails.ts

interface GuardrailResult {
  passed: boolean;
  flagged: string[];
  sanitizedContent: string;
}

// Input guardrails — run BEFORE the model call.
export function filterInput(userMessage: string): GuardrailResult {
  const flags: string[] = [];
  let sanitized = userMessage;

  // Check for common PII patterns.
  const ssnPattern = /\b\d{3}-?\d{2}-?\d{4}\b/g;
  const ccPattern = /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g;

  if (ssnPattern.test(sanitized)) {
    flags.push("potential_ssn_detected");
    sanitized = sanitized.replace(ssnPattern, "[SSN_REDACTED]");
  }

  if (ccPattern.test(sanitized)) {
    flags.push("potential_credit_card_detected");
    sanitized = sanitized.replace(ccPattern, "[CC_REDACTED]");
  }

  // Check for injection patterns — basic examples.
  // In production, use a more sophisticated classifier.
  const injectionPatterns = [
    /ignore\s+(previous|prior|all|above)\s+(instructions|prompts)/i,
    /you\s+are\s+now\s+a/i,
    /system\s*prompt/i,
    /reveal\s+your\s+(instructions|system|prompt)/i,
  ];

  for (const pattern of injectionPatterns) {
    if (pattern.test(userMessage)) {
      flags.push("potential_prompt_injection");
      break;
    }
  }

  return {
    passed: flags.length === 0,
    flagged: flags,
    sanitizedContent: sanitized,
  };
}

// Output guardrails — run AFTER the model call, BEFORE returning to user.
export function filterOutput(
  modelResponse: string,
  retrievedContext?: string
): GuardrailResult {
  const flags: string[] = [];
  let sanitized = modelResponse;

  // Check for hallucinated URLs — if the URL wasn't in the retrieved
  // context, the model may have generated it from training data.
  const urlPattern = /https?:\/\/[^\s)]+/g;
  const urls = modelResponse.match(urlPattern) || [];
  for (const url of urls) {
    if (retrievedContext && !retrievedContext.includes(url)) {
      flags.push(`potentially_hallucinated_url: ${url}`);
      sanitized = sanitized.replace(url, "[URL removed — could not verify]");
    }
  }

  // Check for generated phone numbers (often hallucinated).
  const phonePattern = /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/g;
  if (phonePattern.test(modelResponse)) {
    if (!retrievedContext || !phonePattern.test(retrievedContext)) {
      flags.push("potentially_hallucinated_phone_number");
    }
  }

  // Check for internal information leakage patterns.
  const internalPatterns = [
    /internal\s+use\s+only/i,
    /confidential/i,
    /margin|markup\s+is\s+\d+%/i,
  ];

  for (const pattern of internalPatterns) {
    if (pattern.test(modelResponse)) {
      flags.push("potential_internal_info_leakage");
    }
  }

  return {
    passed: flags.length === 0,
    flagged: flags,
    sanitizedContent: sanitized,
  };
}
```

> 🔒 **Security Callout:** Output filtering is about liability as much as safety. A hallucinated URL in a support response can send your customers to a phishing site. A generated phone number can belong to a real person who gets flooded with calls. Every unverified piece of information in a model's output is a potential liability if it reaches a user.

Every guardrail adds latency. A regex check takes microseconds. A moderation API call takes 50-200ms. A secondary model call for safety classification takes 500ms+. You need to measure this overhead and decide what's acceptable for your use case. For a real-time chat feature, you might use fast regex for inputs and a moderation API call running in parallel with the main model call for outputs. For a batch processing pipeline, you can afford more thorough checks. Make the tradeoff consciously rather than defaulting to either "no guardrails" or "every guardrail we can think of."

## Prompt Versioning and Change Management

A sentence that will save you from at least one production incident: **prompts are load-bearing code**. They determine your system's behavior as directly as any function in your codebase. And yet, most teams treat prompts as configuration, edited in dashboards, stored in environment variables, deployed without testing. Imagine deploying a new version of your authentication logic without running your test suite. That's what you're doing every time you change a prompt without running your evals.

A **prompt versioning system** gives you the same capabilities you already have for code: history, diff, review, test, deploy, rollback. The implementation doesn't need to be complex. At minimum, you need versioned storage (prompts identified by name and version number), an eval suite that runs automatically when a prompt changes, and the ability to roll back to the previous version if something breaks.

```typescript
// src/lib/prompt-manager.ts

interface PromptVersion {
  id: string;
  name: string;
  version: number;
  content: string;
  createdAt: Date;
  metadata: {
    author: string;
    changeDescription: string;
    evalResults?: EvalResult[];
  };
}

interface EvalResult {
  testCase: string;
  passed: boolean;
  score: number;
  details: string;
}

interface PromptConfig {
  activeVersion: number;
  rolloutPercentage: number;  // 0-100: for gradual rollouts.
  previousVersion: number;    // For instant rollback.
}

// In production, back this with a database.
// This in-memory version shows the API design.
class PromptManager {
  private prompts: Map<string, PromptVersion[]> = new Map();
  private configs: Map<string, PromptConfig> = new Map();

  registerPrompt(
    name: string,
    content: string,
    author: string,
    changeDescription: string
  ): PromptVersion {
    const versions = this.prompts.get(name) || [];
    const newVersion: PromptVersion = {
      id: `${name}-v${versions.length + 1}`,
      name,
      version: versions.length + 1,
      content,
      createdAt: new Date(),
      metadata: { author, changeDescription },
    };

    versions.push(newVersion);
    this.prompts.set(name, versions);

    // First version becomes active automatically.
    if (versions.length === 1) {
      this.configs.set(name, {
        activeVersion: 1,
        rolloutPercentage: 100,
        previousVersion: 1,
      });
    }

    return newVersion;
  }

  getActivePrompt(name: string, userId?: string): PromptVersion | null {
    const config = this.configs.get(name);
    const versions = this.prompts.get(name);
    if (!config || !versions) return null;

    // Feature flag: gradual rollout based on user ID hash.
    if (config.rolloutPercentage < 100 && userId) {
      const hash = this.hashUserId(userId);
      const useNewVersion = hash % 100 < config.rolloutPercentage;
      const targetVersion = useNewVersion
        ? config.activeVersion
        : config.previousVersion;
      return versions[targetVersion - 1] || null;
    }

    return versions[config.activeVersion - 1] || null;
  }

  async deployVersion(
    name: string,
    version: number,
    rolloutPercentage: number,
    evalSuite: (prompt: PromptVersion) => Promise<EvalResult[]>
  ): Promise<{ success: boolean; evalResults: EvalResult[] }> {
    const versions = this.prompts.get(name);
    const config = this.configs.get(name);
    if (!versions || !config || !versions[version - 1]) {
      throw new Error(`Prompt ${name} v${version} not found`);
    }

    const targetPrompt = versions[version - 1];

    // Run eval suite BEFORE deploying. This is non-negotiable.
    const evalResults = await evalSuite(targetPrompt);
    targetPrompt.metadata.evalResults = evalResults;

    const allPassed = evalResults.every((r) => r.passed);
    const avgScore = evalResults.reduce((sum, r) => sum + r.score, 0) / evalResults.length;

    if (!allPassed || avgScore < 0.85) {
      console.error(
        `Eval failed for ${name} v${version}: ` +
        `${evalResults.filter((r) => !r.passed).length} failures, ` +
        `avg score ${avgScore.toFixed(2)}`
      );
      return { success: false, evalResults };
    }

    // Deploy with gradual rollout.
    this.configs.set(name, {
      activeVersion: version,
      rolloutPercentage,
      previousVersion: config.activeVersion,
    });

    console.info(
      `Deployed ${name} v${version} at ${rolloutPercentage}% rollout`
    );
    return { success: true, evalResults };
  }

  rollback(name: string): void {
    const config = this.configs.get(name);
    if (!config) throw new Error(`No config for prompt ${name}`);

    console.warn(
      `Rolling back ${name} from v${config.activeVersion} to v${config.previousVersion}`
    );
    this.configs.set(name, {
      activeVersion: config.previousVersion,
      rolloutPercentage: 100,
      previousVersion: config.previousVersion,
    });
  }

  private hashUserId(userId: string): number {
    let hash = 0;
    for (let i = 0; i < userId.length; i++) {
      const char = userId.charCodeAt(i);
      hash = (hash << 5) - hash + char;
      hash = hash & hash; // Convert to 32-bit integer.
    }
    return Math.abs(hash);
  }
}

export const promptManager = new PromptManager();
```

The most important line in that code is the eval gate in `deployVersion`: the system refuses to deploy a prompt that fails its eval suite. CI blocking a merge when tests fail is the same principle. It sounds obvious, but the number of production AI systems where prompts are edited directly in a config file and deployed without any automated testing is staggering.

**Feature flags for prompt rollouts** let you deploy a new prompt to 5% of traffic, monitor quality metrics, and gradually increase the rollout or roll back instantly if metrics degrade. The pattern is identical to feature flagging in traditional software development, and it exists for the same reason: gradual rollouts catch problems that test suites miss. The user ID hash in the implementation above ensures consistent experience for individual users. The same user always gets the same prompt version during a rollout, which matters for multi-turn conversations.

**A/B testing AI features** requires special care because AI has higher output variance than traditional software. When you A/B test a button color, users in each cohort see exactly the same experience. When you A/B test a prompt, users in each cohort see different model outputs even within the same cohort because the model is stochastic. You need larger sample sizes to reach statistical significance. Where a button-color A/B test might need 1,000 users per variant, a prompt A/B test might need 5,000-10,000 to detect a meaningful difference in quality. Measure output quality directly (user satisfaction, task completion, escalation rate) not just engagement metrics like time-on-page.

> 🤔 **Taste Moment:** Model update drift is a subtle but real risk. When your provider updates the model behind a stable API endpoint (same model name, different weights) your carefully tuned prompts can start behaving differently. The fix: run your eval suite against production traffic regularly, not just at deploy time. If your eval scores drop without any changes on your side, the model may have changed under you.

## Compliance and Data Governance

When you call an AI model API, you're sending data to a third-party service. For many applications, this is fine. For applications that handle personal data, health information, financial records, or data subject to industry-specific regulations, it's a legal minefield you need to navigate deliberately.

**GDPR** — the EU's General Data Protection Regulation — applies whenever you process personal data of EU residents, regardless of where your company is based. Sending a user's message to an AI model API constitutes data processing. You need a **Data Processing Agreement** (DPA) with your model provider that specifies how they handle the data, how long they retain it, and whether they use it for training. As of 2026, Anthropic and OpenAI both offer DPAs and both commit to not training on API data by default. But you need to verify this for your specific agreement tier and understand the distinction between zero-day retention and short-term processing retention.

Data residency matters too. If your GDPR compliance strategy requires data to stay within the EU, you need to verify that your model provider offers EU-hosted endpoints. Anthropic offers EU data residency through AWS EU regions; OpenAI offers it through Azure. If your provider doesn't offer in-region hosting, you may need to self-host an open-source model — which is one of the strongest practical arguments for open-weight models like Llama in enterprise contexts.

> 🔒 **Security Callout:** Don't send data you don't need. If a user's support query includes their Social Security number but you only need their order number, strip the SSN before it hits the model API. The principle of data minimization isn't just good security practice — it's a legal requirement under GDPR.

**HIPAA** — the Health Insurance Portability and Accountability Act — governs Protected Health Information (PHI) in the United States and is more restrictive than GDPR for health data. If your application processes PHI (patient names, diagnoses, treatment plans, medical record numbers) you need a **Business Associate Agreement** (BAA) with your model provider, and the provider's infrastructure must meet HIPAA's technical safeguards. As of early 2026, Anthropic offers HIPAA-eligible services through specific enterprise tiers with BAAs. OpenAI offers similar arrangements through Azure OpenAI Service. But "HIPAA-eligible" and "HIPAA-compliant" are different things. Eligibility means the provider will sign a BAA and claims to meet the technical requirements; compliance depends on your entire system architecture, not just the model API.

For the most sensitive health data scenarios (psychiatric notes, substance abuse records, HIV status) many organizations conclude that third-party API calls are unacceptable regardless of BAAs. Self-hosted models become a compliance requirement in these cases, not just a cost optimization. Running a fine-tuned open-source model on your own HIPAA-compliant infrastructure gives you full control over data flows, but you take on the full burden of model quality, monitoring, and maintenance.

The **EU AI Act**, which entered phased enforcement starting in 2024 with most provisions active by August 2026, introduces a risk-based classification system for AI systems. High-risk AI systems (those used in employment, education, credit scoring, law enforcement, and several other domains) must meet specific requirements: risk management systems, data governance, technical documentation, transparency, human oversight, accuracy and robustness guarantees, and post-market monitoring. If you're building an AI-powered hiring tool, credit decisioning system, or educational assessment platform for EU users, the AI Act's requirements are substantial and non-optional.

The Act also imposes obligations on providers of **general-purpose AI models** (which includes the foundation model providers you're building on top of). These providers must publish technical documentation, comply with EU copyright law, and, for models with "systemic risk" (currently defined by a compute threshold), conduct model evaluations, adversarial testing, and incident reporting. As a developer building on these models, your primary obligations relate to the high-risk use case requirements, but you should understand what your model provider is obligated to provide in terms of documentation and transparency.

**Audit logging** is a requirement in virtually every regulated industry and a best practice everywhere else. For AI features, your audit log should capture: what input was sent to the model, what output was returned, which model and version were used, which prompt version was active, what guardrails were applied, and the timestamp and user identity. This serves regulatory compliance, incident investigation, quality monitoring, and training data collection. The implementation is straightforward database logging, but the key decision is retention: how long do you keep model inputs and outputs? GDPR's data minimization principle says "no longer than necessary," while regulatory audit requirements in finance or healthcare may mandate years of retention. These tensions need explicit resolution in your data governance policy.

```typescript
// src/lib/audit-logger.ts

interface AuditEntry {
  id: string;
  timestamp: Date;
  userId: string;
  sessionId: string;
  modelId: string;
  promptVersion: string;
  input: {
    userMessage: string;
    systemPrompt: string;
    // Store hashes, not raw content, if PII is a concern.
    inputHash: string;
  };
  output: {
    response: string;
    outputHash: string;
  };
  guardrails: {
    inputFlags: string[];
    outputFlags: string[];
    inputPassed: boolean;
    outputPassed: boolean;
  };
  usage: {
    inputTokens: number;
    outputTokens: number;
    cachedTokens: number;
    cost: number;
    latencyMs: number;
  };
  routing: {
    tier: string;
    reason: string;
  };
}

// In production, this writes to your database with appropriate
// encryption, access controls, and retention policies.
export function createAuditEntry(
  fields: Omit<AuditEntry, "id" | "timestamp">
): AuditEntry {
  return {
    id: crypto.randomUUID(),
    timestamp: new Date(),
    ...fields,
  };
}
```

> ⚡ **Production Tip:** Design your audit logging from day one, not as an afterthought. Retrofitting audit logging into an AI feature that's already in production is painful. You have to instrument every code path, handle migration of existing data, and explain the gap in your audit trail to regulators. Start with the log schema and work backward to the feature.

## Testing AI Systems in CI/CD

Traditional software has decades of established testing practice: unit tests, integration tests, end-to-end tests, coverage thresholds, CI gates. You wouldn't dream of deploying a backend service without running your test suite. But most teams building AI features test their prompts manually and ship. They try a few inputs in a playground, eyeball the results, and push to production. This is the equivalent of deploying code without running tests, and it's the norm rather than the exception.

The gap exists because AI outputs are **stochastic**. You can't write `assertEqual(output, "exact expected string")` when the model might phrase the same correct answer differently every time. But this difficulty has become an excuse to skip testing entirely, and that's a mistake. You can't assert exact output, but you can assert properties of output and track quality scores over time. The tools are less mature than pytest or Jest, but the discipline is the same.

**Eval suites are your test suites.** The eval framework you built in Chapter 2 shouldn't live in a notebook you run occasionally. It should run in CI. Every prompt change, every dependency update, every model migration should trigger your eval suite automatically. Treat eval failures the same way you treat test failures: they block deployment. If your eval score drops below your threshold, the PR doesn't merge. This sounds obvious, but the number of production AI systems running without automated evals is staggering. If you take one thing from this section, make it this — wire your evals into CI and make them a gate.

**Regression testing for prompts** requires a shift in how you think about prompt changes. When you modify a prompt, you need to run it against your full test set and compare scores to the previous version, not just check whether the new version "seems better." A prompt that improves accuracy on one category but degrades another is a regression, not an improvement. Diff the eval results category by category, not just the average. A prompt with 85% average accuracy that's consistent across categories is often better in production than one with 90% average that scores 98% on easy cases and 60% on hard ones. The average lies to you.

**Property-based testing** is where AI testing gets practical even without perfect evals. You can assert deterministic properties of stochastic outputs. "Output is valid JSON." "Output contains no PII." "Output length is under 500 tokens." "Output doesn't reference competitors by name." "Classification output is one of the five allowed categories." "Response language matches input language." These checks are cheap, fast, and catch real production bugs. A model that starts hallucinating malformed JSON will fail your property checks immediately; you don't need a sophisticated eval to catch that. Layer these property checks underneath your quality evals and you get two tiers of protection: hard constraints that must never be violated, and soft quality scores that track overall performance.

A practical pattern for integrating eval runs into a CI pipeline:

```typescript
// src/lib/ci-eval-runner.ts
interface EvalConfig {
  promptVersion: string;
  testCases: Array<{ input: string; expectedProperties: string[] }>;
  minimumScore: number;
  maximumRegressionPercent: number;
}

async function runCIEval(config: EvalConfig): Promise<{
  passed: boolean;
  score: number;
  regressions: string[];
  propertyViolations: string[];
}> {
  const results = [];

  for (const testCase of config.testCases) {
    const output = await callModel(testCase.input, config.promptVersion);

    // Property-based checks (deterministic)
    const violations = checkProperties(output, testCase.expectedProperties);

    // Quality scoring (may use LLM-as-judge)
    const score = await scoreOutput(output, testCase);

    results.push({ output, violations, score });
  }

  const avgScore = results.reduce((s, r) => s + r.score, 0) / results.length;
  const allViolations = results.flatMap(r => r.violations);

  return {
    passed: avgScore >= config.minimumScore && allViolations.length === 0,
    score: avgScore,
    regressions: detectRegressions(results, config.maximumRegressionPercent),
    propertyViolations: allViolations,
  };
}
```

The `EvalConfig` captures your quality contract: the minimum acceptable score and the maximum regression you'll tolerate. Property violations are hard failures; a single violation fails the entire run. Score regressions are softer but still block deployment if they exceed your threshold. The `detectRegressions` function compares per-category scores against the previous run's baseline and flags any category that dropped by more than `maximumRegressionPercent`. This catches the prompt change that helps one use case while silently breaking another.

**Model migration testing** deserves special attention. When your provider releases a new model version, you need to run your full eval suite against the new model BEFORE switching. Models can regress on specific tasks even when their overall benchmark numbers improve. A model that's better at reasoning might be worse at following your specific output format, or a model that's faster might be less reliable at complex multi-step instructions. Your eval suite is your canary. Run it against the new model, compare results to your current model's baseline, and only migrate when you're confident the new model meets your quality bar across every category that matters to your users. Don't trust the provider's benchmarks as a substitute for your own evals. Their benchmarks measure general capability, not your specific use case.

> ⚡ **Production Tip:** The cheapest way to catch model drift: run your eval suite on a cron job against production — daily for critical features, weekly for others. When scores drop without any changes on your side, the model changed under you.

### Model Deprecation and Migration

Model versions get deprecated. Claude 3 Sonnet gave way to Claude 3.5 Sonnet, which gave way to Claude 4 Sonnet. GPT-4 became GPT-4 Turbo became GPT-4o. Each transition can break prompts that were tuned for specific model behavior — a prompt that produced perfectly structured JSON on one model version might start adding unwanted commentary on the next. You don't control the timeline, and providers typically give you a deprecation window measured in months, not years.

Your **migration checklist** should be systematic: first, run your full eval suite against the new model to establish a baseline. Second, identify regressions, the categories and test cases where the new model underperforms the old one. Third, adjust prompts where needed to restore quality on the new model. Fourth, use the prompt versioning system from earlier in this chapter to do a gradual rollout: send 5% of traffic to the new model, then 25%, then 50%, then 100%, monitoring production metrics at each stage. Fifth, keep the old prompt version available for instant rollback if production metrics degrade. This process is the difference between a smooth migration and a production incident.

**Abstract your model selection behind a config.** Don't hardcode model IDs throughout your codebase. A model identifier scattered across dozens of files turns a simple migration into a codebase-wide search-and-replace exercise. A single config change should switch all calls from one model version to another. Better yet, support per-feature model selection so you can migrate your low-risk features first and your critical features last.

**Budget for migration work.** Every 6–12 months, expect to spend 1–2 weeks validating and adjusting for a model update. This is maintenance cost that most teams don't plan for, and it catches them off guard. Your product roadmap should account for model migration sprints the same way it accounts for dependency updates and security patches. The teams that treat model migration as unplanned interrupt work are the ones that end up rushing it and shipping regressions.

## Reality Check

> The companies that have had painful cost surprises in production AI are numerous and reluctant to publicize it. The stories that do surface (support chatbots that rack up six-figure monthly bills, agent loops that burn through API credits, batch processing jobs that run without cost caps) are the tip of the iceberg. Prompt caching is currently one of the most underutilized cost levers available, partly because it requires upfront prompt design work that demo-driven development skips.
>
> But the deepest truth of this chapter is uncomfortable: the biggest production AI failures are usually plain software engineering failures. They're missing retry logic. They're absent cost caps. They're unvalidated outputs. They're prompts edited in production without testing. Traditional software engineering failures applied to AI features. The model is new and challenging. The infrastructure problems around it are solved problems that teams skip because they're building AI and somehow convince themselves the normal rules don't apply. They do. If anything, the probabilistic nature of AI makes engineering rigor more important, not less.

## Case Study: Klarna and Intercom — AI in Customer Service

Klarna made waves in February 2024 when it announced that its AI assistant — powered by OpenAI — handled two-thirds of all customer service chats in its first month, performing "the equivalent work of 700 full-time agents." The numbers were impressive: a claimed 25% reduction in repeat inquiries, resolution in under 2 minutes compared to 11 minutes for human agents, and projected $40 million in annual cost savings. Intercom, a customer service platform, has made similar claims about its Fin AI agent handling large percentages of support volume.

These claims are real but need careful unpacking, and they illustrate production engineering challenges that every team building AI support systems will face.

**Deflection rate versus resolution rate** is the first critical distinction. Deflection measures how many conversations the AI handled without escalating to a human. Resolution measures how many of those conversations actually solved the customer's problem. These are very different numbers. An AI that responds to every query with a generic "I hope that helps!" has a 100% deflection rate and a near-zero resolution rate. Klarna's public numbers primarily reported deflection-equivalent metrics. The resolution quality — did the customer's actual problem get solved? — is harder to measure and less frequently disclosed. By late 2024, Klarna's CEO acknowledged that AI quality scores were lower than human agent scores, and the company began rehiring human agents.

**Hidden costs of AI errors in support contexts** are the second challenge. When a human agent makes an error, the customer contacts support again. One additional interaction. When an AI makes an error, several things happen: the customer contacts support again (now frustrated), the second interaction is often harder to resolve because the AI's incorrect response set wrong expectations, and the customer's trust in the support system is damaged. In support, a wrong answer is often worse than no answer. The cost of an AI error goes well beyond the API call. It includes the downstream cost of fixing what the AI broke.

The third lesson is about **escalation engineering**. Both Klarna and Intercom invest heavily in detecting when the AI should hand off to a human, and this is real production engineering work. The escalation logic needs to detect frustrated sentiment, recognize when the AI is looping without making progress, identify queries that require account-level actions the AI can't perform, and handle edge cases where the AI is confident but wrong. Klarna's system, by their own reporting, went through multiple iterations of escalation tuning. Getting this wrong in either direction is expensive: too-eager escalation defeats the purpose of AI support; too-reluctant escalation damages customer relationships.

AI in support clearly delivers value when implemented well. The takeaway is that the infrastructure around the AI (routing, escalation, quality measurement, error handling, cost tracking) is where the real engineering challenge lives. The model call itself is the easy part. Measuring resolution quality (not just deflection volume), handling the downstream costs of errors, and building robust escalation: these are the production engineering problems that determine whether AI support is actually saving money or just deferring costs.

## Practical Exercise

**Objective:** Take a "demo-quality" AI feature — your Chapter 6 capstone agent is a good candidate, or any AI feature you've built — and harden it for production.

**Specification:**

Add the following six capabilities, implementing each from scratch rather than using a third-party library:

1. **Streaming responses.** Convert your synchronous API calls to streaming. Measure time-to-first-token. Implement a frontend (or terminal) display that renders tokens as they arrive.

2. **Prompt caching.** Restructure your prompts so that static content (system prompt, reference documents, tool definitions) forms a stable cacheable prefix. Add `cache_control` markers. Log cache hit rates and calculate cost savings over a test run of 50+ queries.

3. **Retry logic with exponential backoff and jitter.** Implement full-jitter exponential backoff. Distinguish between retryable and non-retryable errors. Add a circuit breaker that stops retrying after consecutive failures and falls back to a degraded response.

4. **Cost tracking per request.** Log input tokens, output tokens, cached tokens, model used, and calculated cost for every API call. Build a simple dashboard or summary that shows total cost, average cost per request, and cost breakdown by model tier.

5. **Safety filtering (input + output).** Implement input filtering for PII and basic injection patterns. Implement output filtering for hallucinated URLs and format validation. Log all filtered content for review.

6. **Prompt versioning system.** Implement a prompt manager that stores prompt versions, runs an eval suite before deployment, supports gradual rollout via feature flags, and enables instant rollback.

**Acceptance Criteria:**

- The system handles API failures gracefully — no unhandled promise rejections, no error pages.
- Cost per request is tracked and logged.
- At least one prompt change is deployed through the versioning system with eval results.
- Input and output guardrails catch at least two categories of problematic content in testing.
- The system streams responses to the user.

**Evaluation Component:** After implementation, write a one-page document answering: What would you change with more time? Which guardrails add the most latency? What's your cost projection at 100x current usage? Where are the remaining single points of failure?

**Time Estimate:** ~8 hours (2 hours streaming + caching, 2 hours retry + circuit breaker, 1.5 hours cost tracking, 1.5 hours safety filtering, 1 hour prompt versioning).

## Checkpoint

After completing this chapter and the exercise, you should be able to confirm the following:

- I can implement prompt caching correctly, with stable prefixes and cache_control markers, and calculate the cost savings.
- I can design a model routing strategy with cost projections for different traffic volumes.
- I can version prompts with regression testing and gradual rollout via feature flags.
- I understand the compliance landscape — GDPR, HIPAA, and EU AI Act — well enough to identify which regulations apply to a given AI feature and what they require.
- I can articulate what separates demo quality from production quality, with specific examples of what production requires that demos skip.
- I can implement a circuit breaker for AI API calls with correct state transitions between closed, open, and half-open states.
