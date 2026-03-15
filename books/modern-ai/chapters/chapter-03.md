# Chapter 3: The API Layer

## Why This Matters

You've built mental models for how LLMs work. You've learned to craft prompts, run evals, and reason about sampling parameters. Now you're going to cross a line that most AI tutorials never acknowledge exists: the line between "calling an API" and "building a product on one." This chapter is about everything that happens at that boundary.

The messages API isn't just an HTTP endpoint you POST to. It's a contract between your system and a probabilistic engine that charges you per token, responds at variable latency, fails in ways traditional software doesn't, and gives you back different answers to the same question. Understanding this contract (streaming protocols, token economics, retry strategies, model routing) is what separates a working prototype from a system you can ship to users and charge money for.

By the end of this chapter, you'll be able to wire up streaming responses that feel instant, calculate exactly what an AI feature costs at 10x your expected scale, build reliability patterns that don't collapse under load, and make principled decisions about which model to use for which task. Table stakes for anyone building AI into a real product.

## The Messages API in Depth

### Roles and Multi-Turn State

Every request to the Anthropic messages API is structured around three roles — **system**, **user**, and **assistant** — and what each controls matters more than it appears on the surface. The system prompt sets behavioral constraints that persist across the entire conversation: persona, guardrails, output format requirements, domain knowledge. The user role carries the human's input. The assistant role carries the model's previous responses, which the model uses to maintain coherence across turns.

The critical architectural point: the API is stateless. No session, no memory, no server-side conversation object. Every request ships the *entire* conversation history (system prompt plus every user and assistant message) as a single payload. The model doesn't "remember" your last turn; you're re-sending it. The implications for cost, latency, and context window management are substantial, and we'll explore them in the tokens section.

A basic messages API call with a system prompt looks like this:

```typescript
// src/lib/basic-message.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

async function chat(userMessage: string): Promise<string> {
  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    system:
      "You are a senior software architect. Answer concisely. " +
      "When you don't know something, say so directly.",
    messages: [{ role: "user", content: userMessage }],
  });

  const textBlock = response.content.find((block) => block.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("No text content in response");
  }
  return textBlock.text;
}

const answer = await chat("What's the tradeoff between SSE and WebSockets for streaming?");
console.log(answer);
console.log(`Tokens used: ${response.usage.input_tokens} in, ${response.usage.output_tokens} out`);
```

Notice that `response.content` is an array, not a string. Tool use responses can contain multiple content blocks, a pattern we'll see shortly. Always extract by type rather than assuming structure.

### Streaming: Protocol-Level Mechanics

When you call the messages API without streaming, your application waits for the entire response to generate before receiving a single byte. For a response that takes 3 seconds to generate, your user stares at a loading spinner for 3 seconds. With streaming, the first token arrives in a few hundred milliseconds, and subsequent tokens flow in as they're generated. The actual total latency is the same (or slightly higher, due to protocol overhead), but **perceived latency** drops sharply.

Anthropic's streaming implementation uses **Server-Sent Events (SSE)**, a protocol built on standard HTTP that sends a unidirectional stream of events from server to client. Unlike WebSockets, SSE doesn't require a protocol upgrade or bidirectional channel. It's an HTTP response with `Content-Type: text/event-stream` that stays open, sending named events as they occur. Each event has a type (`message_start`, `content_block_start`, `content_block_delta`, `content_block_stop`, `message_stop`) and a JSON payload.

A streaming implementation that handles the event lifecycle properly:

```typescript
// src/lib/streaming-chat.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

async function streamChat(userMessage: string): Promise<string> {
  const stream = client.messages.stream({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    system: "You are a helpful assistant. Be concise.",
    messages: [{ role: "user", content: userMessage }],
  });

  let fullResponse = "";
  const startTime = Date.now();
  let firstTokenTime: number | null = null;

  stream.on("text", (text) => {
    if (!firstTokenTime) {
      firstTokenTime = Date.now();
      console.log(`Time to first token: ${firstTokenTime - startTime}ms`);
    }
    process.stdout.write(text);
    fullResponse += text;
  });

  const finalMessage = await stream.finalMessage();

  const totalTime = Date.now() - startTime;
  console.log(`\n\nTotal time: ${totalTime}ms`);
  console.log(
    `Tokens: ${finalMessage.usage.input_tokens} in, ${finalMessage.usage.output_tokens} out`
  );

  return fullResponse;
}

await streamChat("Explain the CAP theorem in three sentences.");
```

**Time to first token (TTFT)** is the key metric here, typically 200–800ms depending on model, prompt length, and server load. In interactive contexts, TTFT matters more than total generation time. A response that starts flowing in 300ms and takes 4 seconds total *feels* faster than one that arrives all at once after 3 seconds. Let that UX insight inform every interactive AI feature you build.

> ⚡ **Production Tip:** Always stream in interactive contexts. The only exception is when you need the complete response before doing anything with it — like parsing structured JSON output for a downstream system call. Even then, consider streaming to a buffer and processing on completion.

### Tool Use and Function Calling

**Tool use** (sometimes called function calling) is the single most important primitive in modern AI engineering. Every agent, every MCP server, every complex AI workflow is built on this mechanism. The model doesn't call your functions; it generates a structured request describing which function to call and with what arguments. Your code executes it.

You define tools in your API request with names, descriptions, and JSON Schema parameters. The model decides whether to use a tool, generates a `tool_use` content block with the tool name and arguments, and stops generating. Your code receives that block, executes the actual function, and sends the result back as a `tool_result` message. The model then incorporates that result and continues generating.

```typescript
// src/lib/tool-use.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

const tools: Anthropic.Tool[] = [
  {
    name: "get_weather",
    description:
      "Get current weather for a city. Returns temperature in Fahrenheit and conditions.",
    input_schema: {
      type: "object" as const,
      properties: {
        city: {
          type: "string",
          description: "City name, e.g. 'San Francisco'",
        },
        state: {
          type: "string",
          description: "Two-letter US state code, e.g. 'CA'",
        },
      },
      required: ["city"],
    },
  },
  {
    name: "get_stock_price",
    description: "Get the current stock price for a given ticker symbol.",
    input_schema: {
      type: "object" as const,
      properties: {
        ticker: {
          type: "string",
          description: "Stock ticker symbol, e.g. 'AAPL'",
        },
      },
      required: ["ticker"],
    },
  },
];

// Simulate tool execution
function executeTool(name: string, input: Record<string, string>): string {
  if (name === "get_weather") {
    return JSON.stringify({
      city: input.city,
      temperature: 62,
      conditions: "Partly cloudy",
      humidity: 68,
    });
  }
  if (name === "get_stock_price") {
    return JSON.stringify({
      ticker: input.ticker,
      price: 187.42,
      change: "+1.23%",
    });
  }
  return JSON.stringify({ error: "Unknown tool" });
}

async function chatWithTools(userMessage: string): Promise<string> {
  const messages: Anthropic.MessageParam[] = [
    { role: "user", content: userMessage },
  ];

  let response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    tools,
    messages,
  });

  // Tool use loop — the model may call multiple tools sequentially
  while (response.stop_reason === "tool_use") {
    const toolUseBlocks = response.content.filter(
      (block): block is Anthropic.ToolUseBlock => block.type === "tool_use"
    );

    const toolResults: Anthropic.ToolResultBlockParam[] = toolUseBlocks.map(
      (block) => ({
        type: "tool_result" as const,
        tool_use_id: block.id,
        content: executeTool(block.name, block.input as Record<string, string>),
      })
    );

    messages.push({ role: "assistant", content: response.content });
    messages.push({ role: "user", content: toolResults });

    response = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024,
      tools,
      messages,
    });
  }

  const textBlock = response.content.find((block) => block.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("No text in final response");
  }
  return textBlock.text;
}

const result = await chatWithTools(
  "What's the weather in San Francisco and the current Apple stock price?"
);
console.log(result);
```

Two things to note. First, the `while` loop: the model might need multiple rounds of tool calls to answer a single question, and your code needs to handle that. Second, the tool results are sent back as a `user` message. The API's convention here matters because the model sees tool results as coming from the external world, not from itself.

> 🔒 **Security Callout:** Tool descriptions are part of the prompt. A user who can influence tool descriptions can influence model behavior. Treat tool definitions as load-bearing code, not metadata. Never populate tool descriptions from untrusted input.

### Structured Outputs and JSON Mode

When you need the model to return data in a specific format (for downstream processing, database insertion, or API responses), you have two options. The first is prompt-based: you describe the JSON schema you want in the system prompt and hope the model complies. This works most of the time with good models, but "most of the time" isn't good enough for production.

Anthropic's approach to structured outputs: you use tool definitions as output schemas. You define a "tool" that represents the structure you want, and the model "calls" it with the data as arguments. Since tool call arguments are constrained to match the JSON Schema you defined, you get **format guarantees**: the output will be valid JSON matching your schema. What you don't get is **content guarantees**. The model might still hallucinate values, misunderstand the task, or fill fields with plausible-sounding nonsense.

```typescript
// src/lib/structured-output.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

const extractionTool: Anthropic.Tool = {
  name: "extract_contact_info",
  description:
    "Extract structured contact information from unstructured text. " +
    "Call this tool with the extracted data.",
  input_schema: {
    type: "object" as const,
    properties: {
      name: { type: "string", description: "Full name of the person" },
      email: { type: "string", description: "Email address, if found" },
      phone: { type: "string", description: "Phone number, if found" },
      company: { type: "string", description: "Company name, if found" },
      role: { type: "string", description: "Job title or role, if found" },
    },
    required: ["name"],
  },
};

async function extractContact(text: string) {
  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    tools: [extractionTool],
    tool_choice: { type: "tool", name: "extract_contact_info" },
    messages: [
      {
        role: "user",
        content: `Extract contact information from this text:\n\n${text}`,
      },
    ],
  });

  const toolBlock = response.content.find(
    (block): block is Anthropic.ToolUseBlock => block.type === "tool_use"
  );

  if (!toolBlock) {
    throw new Error("Model did not return structured output");
  }

  return toolBlock.input;
}

const contact = await extractContact(
  "Hey, this is Jamie Chen from Acme Corp. " +
    "I'm the VP of Engineering. Reach me at jamie@acme.co or 415-555-0192."
);
console.log(contact);
// { name: "Jamie Chen", email: "jamie@acme.co", phone: "415-555-0192",
//   company: "Acme Corp", role: "VP of Engineering" }
```

The `tool_choice: { type: "tool", name: "extract_contact_info" }` parameter forces the model to use this specific tool, which guarantees you get structured output rather than a prose response. This pattern — tool-as-schema — is the most reliable way to get structured data from the API today.

An important distinction to internalize: tool-as-schema guarantees **format** but not **content correctness**. The model will always return valid JSON matching your schema, but it might fill fields with plausible-sounding garbage rather than admitting it can't find the answer. A contact extraction might return `{ name: "Unknown", email: "not provided" }` instead of returning null fields or declining the extraction. You need **schema validation** on every structured output call. Not just checking that the JSON parses, but validating that the values make semantic sense. Does the email field actually contain an email? Is the phone number a real phone number format? You should treat structured output the same way you'd treat user input: never trust it without validation.

**Partial output handling** is another failure mode that surprises teams in production. If the model hits your `max_tokens` limit mid-generation, you'll get truncated JSON, a response that cuts off partway through, leaving you with something like `{ "name": "Jamie Chen", "email": "ja` that won't parse at all. Especially dangerous with structured output because your code expects to deserialize the response, and a parse failure might not be handled gracefully. The fix is straightforward: set `max_tokens` generously for structured output calls, well above what you'd expect the response to require. If you're extracting a contact card that should be ~200 tokens, set the limit to 1,000. The model won't generate more than it needs, but you won't risk truncation. If you detect truncation (most SDKs expose a `stop_reason` field that distinguishes between natural stops and token-limit stops), retry the call with a higher budget.

**Keep schemas flat where possible.** Deeply nested schemas (objects within arrays within objects) increase error rates noticeably. The model has to maintain structural coherence across many levels of nesting, and each level is another opportunity for a malformed response. If you need complex structures, consider breaking the extraction into multiple calls: first extract the top-level entities, then make follow-up calls to fill in the nested details. Two simple extractions are more reliable than one complex one, and the total token cost is often comparable.

**JSON mode** offers an alternative. Some providers offer a JSON mode that constrains the model's output to valid JSON without requiring tool definitions. Simpler to set up (ask for JSON in your prompt and flip a flag), but less reliable for schema adherence than tool-as-schema. JSON mode guarantees you'll get valid JSON, but it doesn't guarantee the JSON will have the fields you expect or the types you need. It's best suited for freeform structured data where you're flexible about the shape, like asking the model to "return your analysis as JSON" without a rigid schema in mind. For anything where you need predictable field names and types, stick with tool-as-schema.

> ⚡ **Production Tip:** Always validate structured output with a schema validator — like Zod in TypeScript or Pydantic in Python — before trusting it. Don't just check that the JSON parses; validate every field against your expected types and constraints. A `z.object({ name: z.string().min(1), email: z.string().email() })` schema catches the `"Unknown"` name and `"not provided"` email that raw JSON parsing would silently accept.

### The Batch API

Anthropic's **Batch API** lets you submit up to 10,000 requests in a single batch, with results delivered within 24 hours. You get a 50% cost discount in exchange for giving up real-time responses. The tradeoff is obvious for offline workloads (bulk classification, dataset labeling, content moderation backlogs, nightly report generation), but many features you think of as "real-time" actually have components that could be batched.

Consider a product that generates personalized onboarding content for new users. The user signs up and expects their content within an hour, not within seconds. That's a batch job, not a synchronous API call, and running it through the Batch API cuts your cost in half. Decompose your features into latency tiers: what must be synchronous, what can be async, and what can be batched.

> 💸 **Cost Callout:** The Batch API's 50% discount applies to both input and output tokens. If you have any workload where latency tolerance exceeds a few minutes, batch it. At scale, this single decision can cut your inference bill by 30-40% overall.

## Tokens, Costs, Latency — The Engineering Tradeoffs

### How Token Pricing Actually Works

Every API call has a cost, measured in tokens — roughly four characters of English text per token, though the exact tokenization varies by model. The pricing splits between **input tokens** (everything you send: system prompt, conversation history, tool definitions, user message) and **output tokens** (everything the model generates). Output tokens are 3-5x more expensive than input tokens, and understanding why gives you a lever for optimization.

Input tokens are processed in parallel. The model reads your entire prompt at once using the self-attention mechanism. Output tokens are generated **autoregressively** — one at a time, each conditioned on all previous tokens. Every output token requires a full forward pass through the model. Generating 1,000 tokens takes much longer and costs more than reading 1,000 tokens because of this sequential dependency. `max_tokens` is a cost control mechanism, not just a length preference.

Calculating the actual cost of an AI feature. As of early 2026, Claude Sonnet pricing is approximately $3 per million input tokens and $15 per million output tokens. Let's model a customer support summarization feature:

```typescript
// src/lib/cost-calculator.ts
interface CostEstimate {
  costPerCall: number;
  dailyCost: number;
  monthlyCost: number;
  monthlyCostAt10x: number;
}

function estimateFeatureCost(params: {
  systemPromptTokens: number;
  avgUserInputTokens: number;
  avgOutputTokens: number;
  callsPerDay: number;
  inputPricePerMillion: number;
  outputPricePerMillion: number;
}): CostEstimate {
  const totalInputTokens = params.systemPromptTokens + params.avgUserInputTokens;
  const inputCost = (totalInputTokens / 1_000_000) * params.inputPricePerMillion;
  const outputCost = (params.avgOutputTokens / 1_000_000) * params.outputPricePerMillion;
  const costPerCall = inputCost + outputCost;

  return {
    costPerCall,
    dailyCost: costPerCall * params.callsPerDay,
    monthlyCost: costPerCall * params.callsPerDay * 30,
    monthlyCostAt10x: costPerCall * params.callsPerDay * 30 * 10,
  };
}

// Customer support summarization feature
const estimate = estimateFeatureCost({
  systemPromptTokens: 500,        // System prompt with instructions
  avgUserInputTokens: 2000,       // Average support ticket
  avgOutputTokens: 300,           // Summary output
  callsPerDay: 5000,              // Tickets per day
  inputPricePerMillion: 3,        // Claude Sonnet input price
  outputPricePerMillion: 15,      // Claude Sonnet output price
});

console.log(`Cost per call: $${estimate.costPerCall.toFixed(4)}`);
console.log(`Daily cost: $${estimate.dailyCost.toFixed(2)}`);
console.log(`Monthly cost: $${estimate.monthlyCost.toFixed(2)}`);
console.log(`Monthly cost at 10x: $${estimate.monthlyCostAt10x.toFixed(2)}`);

// Output:
// Cost per call: $0.0120
// Daily cost: $60.00
// Monthly cost: $1,800.00
// Monthly cost at 10x: $18,000.00
```

That $0.012 per call looks harmless. At 5,000 calls per day, it's $1,800/month — manageable. At 10x scale, it's $18,000/month. Now add a multi-turn chat feature, a document analysis pipeline, and an agent that makes 5-10 tool calls per interaction, and you're looking at an inference bill that dominates your cloud spend. Model your costs at 10x *before* you commit to an architecture.

### Prompt Caching

**Prompt caching** is one of the most underutilized cost levers in production AI systems. When you send a request with a large static prefix (a detailed system prompt, few-shot examples, a long document), Anthropic caches the computed representation of that prefix. Subsequent requests that share the same prefix get approximately a 90% discount on those cached input tokens and a lower time-to-first-token.

Cache hit conditions are specific: the prefix must be identical, byte-for-byte, and at least 1,024 tokens long. Your prompt architecture directly affects your caching efficiency. A system prompt that starts with a stable 2,000-token instruction set and ends with dynamic content gets excellent cache hits. A system prompt that interleaves static and dynamic content gets none.

Design for caching by structuring your prompts in layers: the outermost layer is completely static (persona, core instructions, few-shot examples), the middle layer changes infrequently (daily context, reference documents), and the innermost layer is per-request dynamic content. This layered approach maximizes cache hit rates and can reduce your effective input token cost by 70-80%.

> 💸 **Cost Callout:** On a system processing 100,000 requests/day with a 2,000-token system prompt, prompt caching saves approximately $540/day — over $16,000/month. The implementation cost is restructuring your prompt to put static content first. The ROI on this optimization is almost always immediate.

### Latency Profiles

Latency varies widely across models, and the profile of each helps you make routing decisions. Smaller, faster models like Claude Haiku deliver time-to-first-token in 100-300ms and generate tokens at 100+ tokens per second. Sonnet sits in the middle — 200-600ms TTFT, roughly 50-80 tokens per second. Opus is the most capable but slowest — 500ms-1.5s TTFT, 30-50 tokens per second. Reasoning models that use extended thinking add another dimension: they may "think" for several seconds before generating any visible output.

These numbers directly constrain what you can build. An autocomplete feature that takes 800ms to start showing suggestions feels broken. A document analysis pipeline that processes reports overnight doesn't care about TTFT at all. Match your model choice to your latency requirement, and if no single model fits all your features, that's a signal to implement model routing, which we'll cover in the last section.

## Building Reliable Systems on Probabilistic Primitives

### The Reliability Problem

Traditional software either works or throws an error. You call a database, and you get your data or an exception. AI APIs introduce a third state: the call succeeds, but the output is wrong, incomplete, or unusable. Reliability engineering for AI systems is a different discipline than traditional backend work.

On top of content unreliability, you're dealing with infrastructure unreliability: rate limits, transient server errors, network timeouts, and capacity constraints that vary by time of day. You need defense in depth: retry logic for transient failures, validation for content quality, fallbacks for when the primary model is unavailable, and timeout management for user-facing features.

### Retry Logic with Exponential Backoff and Jitter

The naive approach to retries ("if it fails, try again immediately") makes things worse. When a server is overloaded and returning 429 (rate limit) or 529 (overloaded) errors, immediate retries from thousands of clients create a **thundering herd** that prevents recovery. The correct pattern is **exponential backoff** with **jitter**: wait an increasing amount of time between retries, and add randomness to prevent synchronized retry storms.

```typescript
// src/lib/retry.ts
import Anthropic from "@anthropic-ai/sdk";

interface RetryConfig {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
}

const DEFAULT_RETRY_CONFIG: RetryConfig = {
  maxRetries: 5,
  baseDelayMs: 1000,
  maxDelayMs: 60000,
};

function calculateBackoff(attempt: number, config: RetryConfig): number {
  // Exponential backoff: 1s, 2s, 4s, 8s, 16s...
  const exponentialDelay = config.baseDelayMs * Math.pow(2, attempt);
  // Cap at maxDelay
  const cappedDelay = Math.min(exponentialDelay, config.maxDelayMs);
  // Full jitter: random value between 0 and the capped delay
  // This prevents synchronized retries across clients
  return Math.random() * cappedDelay;
}

function isRetryableError(error: unknown): boolean {
  if (error instanceof Anthropic.RateLimitError) return true;
  if (error instanceof Anthropic.InternalServerError) return true;
  if (error instanceof Anthropic.APIConnectionError) return true;
  // Overloaded errors (529)
  if (
    error instanceof Anthropic.APIError &&
    error.status === 529
  ) {
    return true;
  }
  return false;
}

async function callWithRetry<T>(
  fn: () => Promise<T>,
  config: RetryConfig = DEFAULT_RETRY_CONFIG
): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      if (!isRetryableError(error)) {
        throw error; // Non-retryable — fail immediately
      }

      if (attempt === config.maxRetries) {
        break; // Exhausted retries
      }

      const delay = calculateBackoff(attempt, config);
      console.warn(
        `Attempt ${attempt + 1} failed. Retrying in ${Math.round(delay)}ms...`
      );
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}

// Usage
const client = new Anthropic();

const response = await callWithRetry(() =>
  client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    messages: [{ role: "user", content: "Hello" }],
  })
);
```

Jitter is the detail most implementations get wrong. Without it, all clients that failed at the same time will retry at the same time, fail again, and retry at the same time again — an oscillating failure pattern that can persist for minutes. Full jitter (random value between 0 and the calculated delay) breaks this synchronization.

> ⚡ **Production Tip:** The Anthropic SDK includes built-in retry logic with sensible defaults. Before writing your own, check if the SDK's behavior meets your needs. Write custom retry logic when you need fallback chains, custom error classification, or circuit-breaking. You will in production.

### Fallback Strategies

Retries handle transient failures. Fallbacks handle sustained failures: the primary model is down, rate-limited for an extended period, or responding too slowly. A well-designed fallback chain degrades gracefully through multiple levels:

```typescript
// src/lib/fallback-chain.ts
import Anthropic from "@anthropic-ai/sdk";

interface FallbackResult {
  response: string;
  model: string;
  tier: "primary" | "fallback" | "cached" | "degraded";
  latencyMs: number;
}

// Simple in-memory cache for demonstration
const responseCache = new Map<string, { response: string; timestamp: number }>();
const CACHE_TTL_MS = 3600000; // 1 hour

async function chatWithFallback(
  client: Anthropic,
  userMessage: string,
  timeoutMs: number = 10000
): Promise<FallbackResult> {
  const startTime = Date.now();

  // Tier 1: Primary model (Sonnet) with timeout
  try {
    const response = await Promise.race([
      client.messages.create({
        model: "claude-sonnet-4-20250514",
        max_tokens: 1024,
        messages: [{ role: "user", content: userMessage }],
      }),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error("Timeout")), timeoutMs)
      ),
    ]);

    const text = response.content.find((b) => b.type === "text");
    const result = text && text.type === "text" ? text.text : "";

    // Cache successful responses
    responseCache.set(userMessage, {
      response: result,
      timestamp: Date.now(),
    });

    return {
      response: result,
      model: "claude-sonnet-4-20250514",
      tier: "primary",
      latencyMs: Date.now() - startTime,
    };
  } catch (primaryError) {
    console.warn(`Primary model failed: ${primaryError}`);
  }

  // Tier 2: Smaller, faster model (Haiku)
  try {
    const response = await Promise.race([
      client.messages.create({
        model: "claude-haiku-4-20250514",
        max_tokens: 1024,
        messages: [{ role: "user", content: userMessage }],
      }),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error("Timeout")), 5000)
      ),
    ]);

    const text = response.content.find((b) => b.type === "text");
    const result = text && text.type === "text" ? text.text : "";

    return {
      response: result,
      model: "claude-haiku-4-20250514",
      tier: "fallback",
      latencyMs: Date.now() - startTime,
    };
  } catch (fallbackError) {
    console.warn(`Fallback model failed: ${fallbackError}`);
  }

  // Tier 3: Cached response
  const cached = responseCache.get(userMessage);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
    return {
      response: cached.response,
      model: "cache",
      tier: "cached",
      latencyMs: Date.now() - startTime,
    };
  }

  // Tier 4: Graceful degradation — honest failure message
  return {
    response:
      "I'm temporarily unable to process your request. " +
      "Please try again in a moment, or contact support if this persists.",
    model: "none",
    tier: "degraded",
    latencyMs: Date.now() - startTime,
  };
}
```

This pattern — primary model, fallback model, cached response, graceful degradation — is the minimum viable reliability architecture for any user-facing AI feature. In practice, you'd add a fifth tier: human fallback, routing the request to a support queue when all automated options fail. Each tier sacrifices quality for availability, and that tradeoff is almost always worth making. A mediocre automated response is better than a loading spinner, and a loading spinner is better than an error page.

### Timeout Design

Timeout values are UX decisions disguised as engineering constants. Research on perceived responsiveness is clear: under 1 second feels instant, 1-3 seconds feels fast, 3-10 seconds requires a progress indicator, and anything over 10 seconds requires explicit explanation of what's happening and why.

For interactive chat features, set your initial timeout at 5-10 seconds and use streaming to mask the total generation time. For background processing, timeouts can be much longer, but you still need them — a request that hangs indefinitely holds open connections and threads. For tool-calling agents that make multiple round trips, budget your timeout across the total interaction, not per-call, because three 5-second calls feel very different from one 15-second wait.

> 🤔 **Taste Moment:** There's a temptation to set generous timeouts "just in case." Resist it. A 30-second timeout on an interactive feature means your worst-case user experience is staring at a spinner for 30 seconds before seeing an error. It's almost always better to fail fast and fall back than to let the user wonder if the app is frozen.

### Multi-Turn Conversation Design

A fact about the chat completions API that catches many engineers off guard: it's **stateless**. Every single turn of a conversation re-sends the entire message history. The API doesn't remember what you said two messages ago; you have to tell it again. The cost and performance implications compound as conversations grow longer.

The math is straightforward and unforgiving. Each new message in a conversation pays for all previous messages again as input tokens. If your first message costs X tokens, your second costs roughly 2X, your third roughly 3X, and so on. Input tokens grow linearly with conversation length, but total cost across all turns grows **quadratically**: the sum of 1 + 2 + 3 + ... + N. A 20-turn conversation doesn't cost 20x what a single turn costs; it costs closer to 210x when you add up every turn's input bill.

**Context window pressure** compounds the problem. A 20-turn conversation can consume 80% or more of your available context window with history alone, leaving little room for your system prompt, tool definitions, and tool results. When you're building agentic features that rely on tools returning large payloads (database results, file contents, API responses), you'll hit context limits long before you hit any natural end to the conversation.

You have three **session management patterns** to choose from, and the right one depends on your use case. The **sliding window** approach keeps only the last N turns and drops everything older. Simple, predictable, and cheap, but the model loses all context about what happened early in the conversation. **Summarization** compresses older turns into a condensed summary that you prepend to the conversation. Preserves more context but adds an extra model call and introduces a lossy compression step; the summary might drop a critical detail the user mentioned in turn three. The **hybrid approach** combines both: keep the most recent turns verbatim for fidelity, and summarize everything older for context. This is the pattern most production systems converge on.

```typescript
// src/lib/conversation-manager.ts
interface Message {
  role: "user" | "assistant";
  content: string;
}

function manageConversationContext(
  messages: Message[],
  maxRecentTurns: number = 10,
  maxTokenBudget: number = 50000
): { recentMessages: Message[]; summary: string | null } {
  if (messages.length <= maxRecentTurns) {
    return { recentMessages: messages, summary: null };
  }

  const recentMessages = messages.slice(-maxRecentTurns);
  const olderMessages = messages.slice(0, -maxRecentTurns);

  // In production, call a fast model to summarize older messages
  const summary = `[Summary of ${olderMessages.length} earlier messages: ` +
    `The user discussed ${olderMessages.length} topics. ` +
    `Key context preserved here via summarization.]`;

  return { recentMessages, summary };
}
```

**Truncation vs. summarization** comes down to a speed-cost-fidelity tradeoff. Truncation is instantaneous and free; you're just slicing an array. But you lose everything outside the window, which can break conversations where the user references something they said earlier. Summarization preserves more context but adds latency (another model call), costs tokens, and can itself lose critical details if the summarization prompt isn't well-tuned. For most applications, truncation works fine for casual chat features, while summarization is worth the overhead for complex multi-step workflows where early context matters.

**Conversation branching** adds another layer of complexity. When a user wants to "go back" to an earlier point in the conversation (maybe they don't like the direction a suggestion took and want to try a different approach), you need to maintain a tree of conversation states rather than a linear history. In practice, most teams store the full message history server-side and let the user fork from any point, creating a new branch that shares the prefix of the original conversation. Conceptually simple, but it requires careful state management and clear UX to avoid confusing the user about which branch they're on.

> 💸 **Cost Callout:** A 20-message conversation re-sends ~40,000 tokens of history on the final turn. At $3/million input tokens, that's $0.12 per message — 10x the cost of the first message. Sliding window or summarization can cut this by 60-80%.

## Model Selection as a Continuous Engineering Decision

### When Small Models Win

Not every AI call needs a frontier model. Classification tasks (routing a support ticket, detecting intent, categorizing content) are well within the capabilities of smaller, faster, cheaper models. Extraction tasks where the schema is well-defined and the source text is clean work perfectly on Haiku-class models. Simple summarization, translation, and reformatting tasks rarely benefit from the additional reasoning capability of larger models.

Claude Haiku costs roughly 1/20th of Claude Opus on a per-token basis, responds 3-5x faster, and handles simple tasks with equivalent accuracy. If 60% of your traffic is routing and classification, running all of it through Sonnet is burning money for no quality improvement.

### When You Need the Big Models

Complex reasoning (multi-step analysis, nuanced judgment calls, synthesizing contradictory information) is where frontier models earn their cost. Code generation for non-trivial problems, long-form content that requires maintaining coherence over thousands of tokens, and tasks that require understanding subtle context all benefit measurably from larger models. Extended thinking models add another tier for problems that require step-by-step reasoning: mathematical proofs, complex debugging, multi-constraint optimization.

The mistake is defaulting to the biggest model "just to be safe." Every call to a frontier model that could have been handled by a smaller model is a direct hit to your margins.

### Model Routing

**Model routing** (using a cheap, fast model to decide which expensive model to use) is the pattern that makes multi-model architectures practical. The router model classifies incoming requests by complexity and routes them to the appropriate tier. Simple questions go to Haiku. Complex analysis goes to Sonnet. Problems requiring deep reasoning go to Opus or a reasoning model.

The router itself is a classification task, exactly the kind of thing small models handle well. A well-tuned Haiku router adds 100-200ms of latency and costs fractions of a cent, but it can reduce your overall inference spend by 40-60% by ensuring expensive models only handle requests that need them.

Cursor's entire economic model depends on aggressive model routing. At their scale (over a billion lines of code generated per day as of Q1 2026), the difference between routing 70% of requests to a fast model versus sending everything to a frontier model is the difference between healthy margins and burning cash.

> 💸 **Cost Callout:** A simple model router that sends 60% of traffic to Haiku instead of Sonnet saves roughly $9 per 1,000 requests (at typical token volumes). At 100,000 requests/day, that's $270,000/year in savings from a classification prompt that takes an afternoon to build.

### Staying Model-Agnostic

Vendor lock-in is an architectural risk that's easy to dismiss early and expensive to fix later. If every prompt in your system uses Anthropic-specific features, references Claude by name in system prompts, or relies on model-specific behaviors, switching providers (or even switching models within the same provider) becomes a rewrite.

The defensive architecture is straightforward: abstract your AI calls behind a service interface that takes a prompt and returns a response, keep model-specific configuration (model names, pricing, parameter ranges) in a central config, and build your eval suite to run against multiple models. You don't need to support every provider on day one, but you need the seams in your code that would let you add one without touching every file.

Don't avoid provider-specific features. Prompt caching, tool use schemas, and batch APIs are too valuable to ignore. Isolate those features behind well-defined interfaces so the blast radius of a provider change is a single module, not your entire codebase.

> 🤔 **Taste Moment:** Model-agnosticism is a spectrum, not a binary. Go deep on one provider's SDK (learn the streaming events, the error types, the caching behavior) while keeping your business logic decoupled from that provider. Full abstraction from day one is premature optimization. Zero abstraction is technical debt that compounds fast.

## Reality Check

> Cost surprises are the most common and most painful lesson in production AI engineering. A feature that costs $0.002 per call sounds trivial. Then it runs 50,000 times a day and your monthly inference bill is $3,000. Then your product goes viral and you're looking at $30,000. Always model costs at 10x expected usage before committing to an architecture, and include multi-turn conversations in your model. A 10-message chat thread re-sends the entire conversation history every turn, meaning your effective input token count grows quadratically with conversation length.
>
> Prompt caching remains one of the most underutilized cost levers available. Most teams know it exists; few have restructured their prompts to maximize cache hits. Teams that have report 60-80% reductions in input token costs, numbers that materially change the economics of their AI features. If you're spending more than $1,000/month on inference and you haven't implemented prompt caching, start there before optimizing anything else.

## Case Study: Cursor's Model Economics

Cursor, the AI-native code editor, crossed $2 billion in annualized recurring revenue in Q1 2026, making it one of the fastest-growing software products in history. Understanding how they got there requires understanding their model economics, because at their scale, inference cost is the single largest variable cost and the primary constraint on gross margins.

Cursor processes over a billion lines of code per day across its user base. That volume makes every basis point of inference cost meaningful. A 1% improvement in routing efficiency across a billion daily interactions translates to millions of dollars in annual savings. This is why Cursor invested heavily in multi-model routing from early on — different features use different models based on the complexity of the task.

Tab completions, the single most frequent AI interaction in the editor, use Cursor's own fine-tuned models, purpose-built for code completion. These are small, fast, and cheap to run, optimized for the specific task of predicting the next few tokens of code in a particular file context. They don't need to understand nuanced instructions or generate long-form explanations; they need to predict likely code continuations with sub-200ms latency.

Chat and agentic features (where users ask complex questions, request refactors, or run multi-step coding tasks) route to frontier models from Anthropic and OpenAI. These features generate more tokens, require more reasoning, and cost more per interaction. But they're also where users perceive the most value, so the cost is justified by retention and willingness to pay.

Cursor's margins depend on the *ratio* of cheap-model interactions to expensive-model interactions. Their proprietary model investment handles the high-volume, low-complexity tasks in-house so API costs only apply to interactions that need frontier capability. Model routing as business strategy, not just engineering optimization.

Cursor has also invested in proprietary models to reduce dependency on any single API provider. When you're spending tens of millions of dollars per year on inference (plausible at their scale), every pricing change from your model providers directly affects your gross margin. Owning the models for your most common workloads gives you cost predictability and negotiating leverage that pure API consumers don't have.

Even if you can't train proprietary models, you can implement the same tiered routing strategy. Classify your AI features by complexity, match each tier to an appropriate model, and measure the cost difference. Most teams find that 50-70% of their AI traffic is simple enough for the cheapest available model.

## Practical Exercise

**Build a production-like streaming chat application with reliability engineering.**

You're going to build a small but complete system that demonstrates the core patterns from this chapter. The goal is the engineering underneath, not a pretty UI.

**What to build:**

A command-line chat interface (TypeScript) with these requirements:

1. **Streaming responses** — Tokens appear as they're generated. Measure and display time-to-first-token for every response.

2. **Retry logic** — Implement exponential backoff with jitter for transient failures. Simulate failures by occasionally calling a non-existent model to trigger errors.

3. **Cost tracking** — Track input and output tokens per message and per session. Display running cost totals after each response using current model pricing.

4. **Automatic fallback** — When the primary model (Sonnet) fails or times out after 8 seconds, fall back to Haiku. When Haiku fails, display a graceful degradation message. Log which tier served each response.

5. **Latency measurement** — Record TTFT and total response time for every interaction. After 10+ interactions, display P50 and P95 latency statistics.

**Acceptance criteria:**

Your application should handle a normal 10-message conversation, correctly fall back when the primary model is unavailable, display accurate cost and latency metrics after each message, and recover gracefully from simulated failures without crashing.

**Eval component:**

After building the system, write a brief analysis (500-1,000 words) documenting: Where are the latency bottlenecks? What's the cost difference between primary and fallback tiers? How does conversation length affect per-message cost (hint: re-sent context)? What would break first at 100x scale?

**Estimated time:** ~6 hours.

## Checkpoint

By the end of this chapter, you should be able to affirm each of these:

- I can implement streaming responses using SSE and measure time-to-first-token.
- I can calculate the cost of an AI feature at current scale and at 10x, accounting for input vs. output token pricing.
- I understand when and how to use prompt caching to reduce input token costs by up to 90%.
- I can implement retry logic with exponential backoff and jitter, and I can explain why jitter matters.
- I can design a fallback strategy that degrades gracefully through multiple tiers — smaller model, cached response, human fallback.
- I can explain model routing as both a cost optimization and a quality optimization, and I know when to use which model tier.
- I can make the case for (or against) model-agnostic architecture in a specific system context.
