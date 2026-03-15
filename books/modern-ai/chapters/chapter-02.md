# Chapter 2: Working With Models Directly

## Why This Matters

Every serious AI engineering skill in this book rests on one foundation: direct experience with models. Not through LangChain. Not through a wrapper library that hides the request format. Not through a UI that makes choices for you. You need to sit with the raw API, send messages, read responses, and develop an intuition for how these systems behave. Framework knowledge is perishable: LangChain's API has broken backward compatibility multiple times since 2023, and the abstraction you learn today may not exist in eighteen months. Direct model intuition is durable.

This chapter is about building that intuition. You'll learn prompt engineering as a communication design discipline, not a bag of tricks. You'll understand what context windows, sampling parameters, and multimodal inputs actually are, mechanically, not just conceptually. You'll also build your first eval suite. If you take one thing from this chapter, it should be this: measuring what a model does matters more than any clever prompt you'll ever write.

By the end of this chapter, you'll be able to design prompts that reliably produce structured output, explain what temperature actually controls at the distribution level, identify when multimodal capabilities are production-ready versus demo bait, and build a rubric-based eval for any task you give a model. These are the skills that compound. Everything else in this book builds on them.

## Prompt Engineering as Communication Design

The phrase "prompt engineering" has accumulated a lot of baggage. On one end, you'll find people selling courses on "magic prompts" that unlock hidden capabilities. On the other, you'll find engineers dismissing the entire discipline as soon-to-be-automated fluff. Both are wrong. Prompt engineering is communication design: the discipline of structuring information so that a probabilistic system produces useful output reliably. Not magic, but not trivial either.

### System Prompts: What They Actually Are

A **system prompt** is a message with a privileged position in the conversation context. Architecturally, it occupies the first slot in the messages array and the model treats it as persistent instructions that frame all subsequent interaction. It's not "more powerful" in any mysterious sense. It's simply text that the model sees first and that isn't interleaved with user turns. This positional privilege means the model is less likely to lose track of system prompt instructions compared to instructions buried deep in a conversation.

A direct API call, no framework, no wrapper, just the Anthropic SDK:

```typescript
// src/basic-prompt.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

async function classifySupport(userMessage: string) {
  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    system:
      "You are a support ticket classifier. Classify each message into exactly one category: billing, technical, account, or general. Respond with only the category name in lowercase.",
    messages: [
      {
        role: "user",
        content: userMessage,
      },
    ],
  });

  const text =
    response.content[0].type === "text" ? response.content[0].text : "";
  return text.trim().toLowerCase();
}

// Usage
const category = await classifySupport(
  "I was charged twice for my subscription last month"
);
console.log(category); // "billing"
```

That's it. No chain, no agent framework, no abstraction layer. You send a system prompt, a user message, and you get a response. Every framework you'll ever use is built on top of this interaction. Understanding it directly means you can debug anything built on top of it.

### Positive vs. Negative Instructions

Tell the model what to do, not what to avoid. This reflects how the model processes instructions, not just style advice. When you say "don't include explanations," the model has to represent the concept of explanations, then negate it. When you say "respond with only the category name," the model has a clear target to pattern-match against. Positive instructions give the model a distribution to aim for; negative instructions give it a region to avoid, which is a harder optimization target.

That said, negative instructions aren't useless. They work well as guardrails after you've given the positive instruction. "Respond with only the category name. Do not include reasoning or explanation." The positive instruction does the heavy lifting; the negative instruction catches edge cases. Use negative instructions as reinforcement, not as your primary specification.

### Few-Shot Prompting: Why Examples Outperform Descriptions

A fact that trips up most developers coming from a traditional software background: showing the model what you want works better than describing what you want. This makes sense once you internalize what the model is doing. It's pattern-matching against its training distribution. A description of a format is one kind of pattern. Three concrete examples of that format are a much stronger signal; they give the model a distribution to interpolate from rather than a specification to interpret.

**Few-shot prompting** means providing examples of the desired input-output mapping directly in your prompt. XML tags make these examples parseable and help the model distinguish between the example content and your instructions:

```typescript
// src/few-shot-extraction.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

async function extractEntities(text: string) {
  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 2048,
    system: `You extract structured entity data from text. Follow the exact format shown in the examples.`,
    messages: [
      {
        role: "user",
        content: `Here are examples of the extraction format:

<example>
<input>Sarah Chen joined Anthropic as a research scientist in March 2024. She previously worked at DeepMind in London.</input>
<output>
<entity type="person" name="Sarah Chen">
  <role>Research Scientist</role>
  <organization>Anthropic</organization>
  <date>March 2024</date>
  <previous_organization>DeepMind</previous_organization>
  <location>London</location>
</entity>
</output>
</example>

<example>
<input>Microsoft invested $10B in OpenAI in January 2023, extending their partnership that began in 2019.</input>
<output>
<entity type="organization" name="Microsoft">
  <action>Investment</action>
  <amount>$10B</amount>
  <target>OpenAI</target>
  <date>January 2023</date>
</entity>
<entity type="organization" name="OpenAI">
  <partner>Microsoft</partner>
  <partnership_start>2019</partnership_start>
</entity>
</output>
</example>

Now extract entities from the following text:
<input>${text}</input>`,
      },
    ],
  });

  return response.content[0].type === "text" ? response.content[0].text : "";
}

const result = await extractEntities(
  "Google DeepMind announced Gemini 2.0 in December 2024. " +
    "CEO Demis Hassabis presented the model at their London headquarters."
);
console.log(result);
```

Notice the structure: XML-tagged examples with clear input/output pairs, followed by the actual input in the same format. The model infers the schema from the examples without you explaining it. Two to three examples typically suffice for straightforward extraction tasks. For complex or ambiguous tasks, five to eight examples covering edge cases will improve consistency noticeably.

### Chain-of-Thought: When to Request It

**Chain-of-thought (CoT)** prompting asks the model to show its reasoning steps before producing a final answer. What it actually does is shift the output distribution. By generating intermediate reasoning tokens, the model conditions its final answer on those tokens, which often produces more accurate results for tasks that require multi-step reasoning.

Chain-of-thought helps most on tasks where the answer requires combining multiple pieces of information or applying sequential logic. For simple classification or extraction, it adds latency and token cost without improving accuracy. For multi-step reasoning, it can be the difference between a correct and incorrect answer.

```typescript
// src/chain-of-thought.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

const contractClause =
  "The licensee shall pay a royalty of 5% of net revenue exceeding $1M annually, " +
  "with a minimum guarantee of $50,000 per quarter, subject to a 3% annual escalation " +
  "beginning in year 3 of the agreement.";

// Direct answer — more likely to miss nuances
async function directAnswer() {
  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 512,
    messages: [
      {
        role: "user",
        content: `What is the total minimum payment in year 4 of this contract?\n\n${contractClause}`,
      },
    ],
  });
  return response.content[0].type === "text" ? response.content[0].text : "";
}

// Chain-of-thought — forces step-by-step reasoning
async function chainOfThought() {
  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    messages: [
      {
        role: "user",
        content: `What is the total minimum payment in year 4 of this contract?

${contractClause}

Think through this step by step:
1. What is the base minimum quarterly payment?
2. When does escalation begin?
3. What is the escalation rate?
4. How many years of escalation apply by year 4?
5. What is the adjusted quarterly minimum?
6. What is the annual total?`,
      },
    ],
  });
  return response.content[0].type === "text" ? response.content[0].text : "";
}
```

The chain-of-thought version doesn't just produce a better answer — it produces a *verifiable* answer. You can check each step. This matters enormously when you're building production systems where you need to audit why the model produced a particular output.

### XML Tags and Structured Output

XML tags aren't special to the model — it doesn't have an XML parser built in. But they work well as delimiters because the model's training data contains vast amounts of XML and HTML, so it has strong priors about how tagged content should be structured. This makes XML tags more reliable than ad-hoc delimiters like `###` or `---` for separating sections of your prompt and parsing sections of the output.

Use XML tags for three things: delineating sections of your input (examples, context, instructions), requesting structured output that you'll parse programmatically, and separating "thinking" from "answering" in chain-of-thought prompts. The model will reliably close tags it opens, which makes extraction straightforward.

### Persona Instructions: What They Change

Telling the model to "act as a senior tax attorney" does change the output distribution. It shifts the model toward vocabulary, reasoning patterns, and domain conventions associated with that role in its training data. What it does *not* do is give the model expertise it doesn't have. A persona instruction surfaces knowledge the model already has; it doesn't create new knowledge. The practical implication: persona instructions are useful for tone, format, and domain vocabulary. They're not a substitute for actually providing domain context in the prompt.

## Context Windows as a Resource

A **context window** is the total number of tokens the model can process in a single request — input and output combined. As of early 2026, Claude 3.5 Sonnet and Claude 4 support 200K token context windows. GPT-4o supports 128K tokens. Google's Gemini models offer up to 1M tokens in some configurations. These numbers will be out of date by the time you read this, but the engineering principles around context management will not.

Think of the context window as working memory. It's the total information the model can attend to when generating a response. Every token of your system prompt, every few-shot example, every piece of retrieved context, and every token of the conversation history consumes this budget. So does every token the model generates in response. **Input tokens** and **output tokens** are priced differently. Output tokens are typically 3-5x more expensive than input tokens because they require sequential generation rather than parallel processing.

### The Lost-in-the-Middle Problem

Liu et al. (2023) demonstrated something that should inform every prompt you build: models perform best on information placed at the beginning and end of the context window, with measurable degradation on information in the middle. They tested this across multiple models and tasks, and the pattern was consistent: a U-shaped performance curve where retrieval accuracy dropped for information positioned in the middle third of the context.

The practical implication is straightforward: put your most important information first (system prompt, critical instructions) and last (the actual query, the most relevant context). If you're stuffing retrieved documents into a prompt, ordering is a performance lever, not an arbitrary choice. Place your highest-relevance documents at the beginning and end of the context block. Prompt construction as memory management. It matters more as your contexts get longer.

### Token Budgets and Cost

A rough cost model as of early 2026. Claude 3.5 Sonnet charges approximately $3 per million input tokens and $15 per million output tokens. GPT-4o is in a similar range. These prices drop roughly 30-50% per year, but the relative economics remain stable: output much more expensive than input, bigger models much more expensive than smaller ones.

A 200K token input context with a 4K token response costs roughly $0.66 per call on Claude Sonnet. That's fine for a single API call. Run it 10,000 times a day and you're looking at $6,600 per day, or roughly $200K per month. Context management isn't a theoretical exercise. Every token you put in the prompt costs real money at scale, and understanding where your tokens go is an engineering discipline. We'll go much deeper on cost optimization in Chapter 3.

## Sampling Parameters: What They Actually Control

### Temperature

**Temperature** is the most misunderstood parameter in LLM APIs. It's not a "creativity dial." It's a scaling factor applied to the logits (raw scores) before the softmax function converts them into a probability distribution. A temperature of 1.0 leaves the distribution unchanged. A temperature below 1.0 sharpens the distribution — the highest-probability tokens get even more probability mass, and the tail gets suppressed. A temperature above 1.0 flattens the distribution — probability mass spreads more evenly across tokens, making lower-probability tokens more likely to be sampled.

At temperature 0, the model (in theory) always picks the highest-probability token — this is called **greedy decoding**. In practice, "temperature 0 = deterministic" is a myth. Floating-point arithmetic on GPUs isn't perfectly deterministic across hardware configurations and batching strategies. Infrastructure-level variance (which GPU handled your request, how the batch was composed, numerical precision differences) means you can get slightly different outputs from the same prompt at temperature 0. The outputs will be *very similar*, but not bitwise identical. If your system requires exact reproducibility, you need to cache outputs, not rely on temperature 0.

Code demonstrating the effect of temperature on output variance:

```typescript
// src/temperature-experiment.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

async function generateWithTemperature(
  prompt: string,
  temperature: number,
  runs: number = 5
): Promise<string[]> {
  const results: string[] = [];

  for (let i = 0; i < runs; i++) {
    const response = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 256,
      temperature,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
    });
    const text =
      response.content[0].type === "text" ? response.content[0].text : "";
    results.push(text.trim());
  }
  return results;
}

async function main() {
  const prompt =
    "Name three potential risks of deploying an LLM in a healthcare setting. Be concise.";

  console.log("=== Temperature 0.0 (near-deterministic) ===");
  const lowTemp = await generateWithTemperature(prompt, 0.0);
  lowTemp.forEach((r, i) => console.log(`Run ${i + 1}: ${r}\n`));

  console.log("=== Temperature 0.7 (moderate variance) ===");
  const midTemp = await generateWithTemperature(prompt, 0.7);
  midTemp.forEach((r, i) => console.log(`Run ${i + 1}: ${r}\n`));

  console.log("=== Temperature 1.0 (full variance) ===");
  const highTemp = await generateWithTemperature(prompt, 1.0);
  highTemp.forEach((r, i) => console.log(`Run ${i + 1}: ${r}\n`));
}

main();
```

Run this yourself. At temperature 0, you'll see nearly identical outputs across runs. At 0.7, the core ideas are similar but phrasing varies. At 1.0, you'll see meaningfully different content — different risks mentioned, different framings, occasionally surprising angles. Statistical sampling from a broader portion of the distribution, not "creativity."

### Top-p (Nucleus Sampling)

**Top-p sampling** (also called **nucleus sampling**) is the other main sampling parameter. Instead of scaling the distribution like temperature does, top-p truncates it. A top-p value of 0.9 means: sort all tokens by probability, take the smallest set of tokens whose cumulative probability exceeds 0.9, and sample only from that set. This eliminates the long tail of low-probability tokens while preserving the relative distribution among high-probability ones.

Temperature and top-p interact. Using both at non-default values can produce unpredictable results; pick one to adjust and leave the other at its default. For extraction and classification tasks, use low temperature (0.0-0.3) and leave top-p at 1.0. For generative tasks where you want variety, either raise temperature to 0.7-1.0 or lower top-p to 0.8-0.95. Anthropic's documentation recommends adjusting temperature for most use cases and leaving top-p alone unless you have a specific reason to truncate the distribution.

### When to Use What

Low temperature (0.0-0.3) is appropriate for tasks with a single correct answer or a narrow range of acceptable outputs: classification, extraction, code generation, factual Q&A, and format-constrained generation. The model should be confident and consistent.

Higher temperature (0.7-1.0) is appropriate for tasks where diversity of output is valuable: brainstorming, creative writing, generating multiple candidate solutions, and exploratory analysis. You want the model to explore more of its distribution.

The middle range (0.3-0.7) is where most production applications land. You want some variety so responses don't feel robotic to users, but not so much that outputs become unreliable. Finding the right temperature for your specific task is an empirical question. Your eval suite should measure it.

## Reasoning Models and Extended Thinking

Everything we've covered so far assumes a model that generates its answer in a single forward pass: you send a prompt, the model produces tokens left to right, and what you see is what you get. **Reasoning models** break this assumption. Models like OpenAI's o1 and o3 series, and Claude's extended thinking mode, generate internal chains of reasoning (sometimes called **thinking tokens**) before producing a visible answer. This is **inference-time compute scaling**: instead of making the model bigger or training it longer, you spend more compute at the point of use to improve quality on hard problems.

With a standard model, if you want step-by-step reasoning, you explicitly prompt for it ("think through this step by step") or build a chain-of-thought into your few-shot examples. The reasoning happens in the visible output, and you're orchestrating it. With a reasoning model, the model allocates its own **reasoning budget** internally. It decides how much to think, what subproblems to decompose, and when it has enough confidence to produce a final answer. The planning happens inside the model, not in your orchestration code.

With reasoning models, you often get better results by specifying the problem clearly (what you want, what constraints exist, what a good answer looks like) rather than prescribing how to think about it. You're delegating the reasoning strategy to the model, which has been specifically trained to plan and self-correct. Telling a reasoning model to "think step by step" is like giving a chess engine move-by-move instructions — you're overriding something it's already good at.

### When Reasoning Models Are Worth It

You should reach for reasoning models when you're dealing with complex multi-step reasoning, mathematical proofs or calculations, non-trivial code generation, tasks requiring deep analysis across multiple documents, or problems where the model needs to consider and reject several approaches before finding the right one. These are tasks where a standard model's single-pass generation isn't enough — where the problem requires the kind of deliberation that benefits from internal scratch work.

You should _not_ use reasoning models for classification, entity extraction, simple summarization, reformatting, or anything where speed matters more than depth. A reasoning model classifying sentiment is like hiring a PhD to sort mail. Technically capable, but you're paying for capacity you don't need, and it'll be slower than the alternative.

### The Cost and Latency Tradeoff

Thinking tokens are generated but not always visible to you. They consume compute and add latency — sometimes several seconds of "thinking" before any visible output appears. A real cost you need to account for. You're paying for tokens the user never sees. A problem that triggers 8,000 thinking tokens before producing a 500-token answer means you're paying for 8,500 output tokens total, even though the user only sees 500.

For the right problems — a tricky debugging question, a multi-step math derivation, a code architecture decision — this tradeoff is worth it. The quality difference between a reasoned answer and a single-pass answer can be substantial. But for simple tasks, it's pure waste. Your system design needs to route problems appropriately: simple queries go to fast, cheap models; hard problems go to reasoning models that take their time.

### Using Extended Thinking in Practice

Claude's extended thinking mode gives you explicit control over the reasoning budget. You set a `budget_tokens` parameter that caps how many tokens the model can spend on internal reasoning. The model may use fewer if the problem is straightforward, but it won't exceed your budget.

```typescript
// src/extended-thinking.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

async function solveWithThinking(problem: string) {
  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 16000,
    temperature: 1, // Extended thinking requires temperature 1
    thinking: {
      type: "enabled",
      budget_tokens: 10000, // Max tokens for internal reasoning
    },
    messages: [{ role: "user", content: problem }],
  });

  for (const block of response.content) {
    if (block.type === "thinking") {
      console.log("Model reasoning:", block.thinking);
    }
    if (block.type === "text") {
      console.log("Answer:", block.text);
    }
  }
}
```

Notice the `temperature: 1` requirement — extended thinking mode fixes temperature at 1 because the model needs the full probability distribution to explore its reasoning space effectively. The response comes back with separate content blocks for thinking and text, so you can inspect the model's reasoning process or hide it from end users as appropriate.

The `budget_tokens` parameter is your primary cost control lever. A budget of 2,000 tokens is enough for moderately complex questions. For genuinely hard problems — multi-file code analysis, complex mathematical reasoning, or tasks requiring the model to consider and reject multiple approaches — you might set budgets of 10,000 or higher. Start low and increase the budget only when you see the model's answers improving with more thinking room.

> 💸 **Cost Callout**: Thinking tokens are billed at output token rates. A 10,000-token thinking budget on a complex problem can easily cost 10–50x more than a simple direct answer to the same question without extended thinking. Monitor your thinking token usage in production — it's the fastest way to accidentally blow through your API budget.

## Multimodal Inputs

Modern frontier models accept images, PDFs, and other non-text inputs alongside text. This is useful — but the gap between demo capabilities and production reliability is wider in multimodal than in almost any other area of LLM application.

### Vision: What Works and What Doesn't

Current models can reliably describe the contents of photographs, read text in images (OCR), interpret charts and graphs at a high level, classify images into categories, and answer questions about image content. These capabilities are real and production-ready for many use cases.

Where demos mislead: current models struggle with spatial reasoning (where exactly is object A relative to object B), counting (how many items are in this image), fine detail extraction (reading small text, identifying subtle differences), and precise measurement (how big is this, what angle is that). If your product depends on any of these capabilities, test extensively before committing. The model will confidently produce answers for spatial and counting tasks; those answers will be wrong often enough to be dangerous in production.

### Document Understanding

Processing PDFs, invoices, forms, and structured documents is one of the genuinely high-value multimodal use cases. Models can extract data from semi-structured documents (invoices, receipts, contracts) with accuracy that approaches or matches specialized OCR pipelines, while being far more flexible. They handle layout variation, handwriting (with caveats), and multi-language documents better than most traditional document processing systems.

The caveat: accuracy on handwriting varies by language and writing quality. Accuracy on complex table structures (nested headers, merged cells, spanning rows) degrades noticeably. Always validate extraction results against ground truth for your specific document types before putting this in production.

### When Multimodal Adds Real Value

Multimodal is valuable when it replaces a brittle, multi-step pipeline. If you're currently doing OCR, then layout analysis, then entity extraction, then validation — a single multimodal model call might replace that entire chain with better accuracy and far less maintenance. It's also valuable when your users naturally communicate with images: support tickets with screenshots, inspection photos, medical imaging triage.

Multimodal is demo bait when the image is incidental to the task (you could have just sent text), when the accuracy requirements exceed what the model can reliably deliver (counting, spatial reasoning), or when a simpler tool solves the problem (if you just need OCR, use an OCR service). The question to ask: does the model need to *understand* the image, or does it just need to *read* the image? If the latter, dedicated OCR is cheaper and more reliable.

## Evals From Day One

This is the most important section of this chapter. Everything else (prompt design, sampling parameters, multimodal) is input. Evals are how you know whether any of it works.

### Why "It Looks Good" Is Not an Eval

You've written a prompt. You run it. The output looks reasonable. You tweak the prompt. The output looks better. You ship it. Three weeks later, a user reports garbage output. You can't reproduce it. You don't know if the model changed, or the input distribution shifted, or your prompt just doesn't handle this edge case.

This is the failure mode of "vibes-based evaluation," and it's how most AI features are developed. Your judgment isn't bad. It's just a sample size of one, and LLM outputs are stochastic. A prompt that produces great output on your five test cases might fail 15% of the time on real user inputs. Without an eval suite, you have no way to know.

### Building a Rubric-Based Eval

A **rubric** is a scoring framework that defines what "good" means for a specific task. It forces you to articulate your quality criteria before you look at outputs, which prevents the common failure of retroactively justifying whatever the model happened to produce. Building the rubric is often harder and more valuable than building the prompt.

A concrete eval framework. Simple on purpose — the value is in the practice, not the infrastructure:

```typescript
// src/eval-framework.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

// Define your rubric as structured criteria
interface RubricCriterion {
  name: string;
  description: string;
  weight: number; // 0-1, should sum to 1
  scoringGuide: {
    1: string;
    2: string;
    3: string;
    4: string;
    5: string;
  };
}

interface EvalResult {
  input: string;
  output: string;
  scores: Record<string, number>;
  weightedTotal: number;
  notes: string;
}

// Example rubric for a "summarize support ticket" task
const supportSummaryRubric: RubricCriterion[] = [
  {
    name: "accuracy",
    description: "Does the summary accurately reflect the ticket content?",
    weight: 0.4,
    scoringGuide: {
      1: "Major factual errors or fabricated information",
      2: "Some inaccuracies that would mislead a support agent",
      3: "Mostly accurate with minor omissions",
      4: "Accurate with all key details preserved",
      5: "Perfectly accurate, no information lost or added",
    },
  },
  {
    name: "actionability",
    description: "Can a support agent act on this summary without reading the original?",
    weight: 0.3,
    scoringGuide: {
      1: "No actionable information",
      2: "Vague — agent would need to read original",
      3: "Partially actionable, some ambiguity",
      4: "Clear next steps evident from summary",
      5: "Immediately actionable with specific details",
    },
  },
  {
    name: "conciseness",
    description: "Is the summary appropriately brief?",
    weight: 0.2,
    scoringGuide: {
      1: "Longer than the original or extremely verbose",
      2: "Contains significant unnecessary detail",
      3: "Reasonable length with some padding",
      4: "Concise with minimal excess",
      5: "Optimal length — nothing to cut, nothing missing",
    },
  },
  {
    name: "format",
    description: "Does it follow the requested output format?",
    weight: 0.1,
    scoringGuide: {
      1: "Completely wrong format",
      2: "Partially follows format",
      3: "Follows format with minor deviations",
      4: "Correct format throughout",
      5: "Perfect format compliance",
    },
  },
];

// The prompt under test
async function summarizeTicket(ticket: string): Promise<string> {
  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 512,
    temperature: 0.3,
    system: `You summarize support tickets for agents. Output format:
<summary>
<category>[billing|technical|account|general]</category>
<severity>[low|medium|high|critical]</severity>
<issue>[One sentence describing the core problem]</issue>
<action>[Recommended next step for the agent]</action>
</summary>`,
    messages: [{ role: "user", content: ticket }],
  });
  return response.content[0].type === "text" ? response.content[0].text : "";
}

// Score a single output against the rubric (human scoring)
function scoreOutput(
  input: string,
  output: string,
  scores: Record<string, number>,
  notes: string,
  rubric: RubricCriterion[]
): EvalResult {
  const weightedTotal = rubric.reduce((sum, criterion) => {
    const score = scores[criterion.name] || 0;
    return sum + score * criterion.weight;
  }, 0);

  return { input, output, scores, weightedTotal, notes };
}

// Run the eval: generate outputs, then score them
async function runEval(
  testCases: string[],
  runs: number = 3
): Promise<{ results: EvalResult[][]; variance: Record<string, number> }> {
  const allOutputs: string[][] = [];

  // Generate multiple outputs per test case to measure variance
  for (const testCase of testCases) {
    const outputs: string[] = [];
    for (let i = 0; i < runs; i++) {
      const output = await summarizeTicket(testCase);
      outputs.push(output);
    }
    allOutputs.push(outputs);
  }

  // Print outputs for manual scoring
  for (let i = 0; i < testCases.length; i++) {
    console.log(`\n=== Test Case ${i + 1} ===`);
    console.log(`Input: ${testCases[i].substring(0, 100)}...`);
    for (let j = 0; j < allOutputs[i].length; j++) {
      console.log(`\n--- Run ${j + 1} ---`);
      console.log(allOutputs[i][j]);
    }
  }

  // Return structure for scoring
  // In practice, you'd score these and compute variance
  return { results: [], variance: {} };
}

// Example test cases
const testCases = [
  "Hi, I've been charged $49.99 three times this month for my Pro subscription. I only have one account. My card ending in 4242 shows three charges on March 1, March 3, and March 7. I need a refund for the duplicate charges. Order numbers: ORD-2024-8891, ORD-2024-8923, ORD-2024-8967.",
  "The API keeps returning 503 errors since yesterday around 3pm EST. I'm on the Enterprise plan and this is affecting our production system. We've tried from multiple regions. Our account ID is ENT-4455.",
  "I need to change the email address on my account from john@oldcompany.com to john@newcompany.com. I still have access to both email addresses. Username: jsmith_enterprise.",
];

runEval(testCases, 3);
```

This framework does three things: it generates multiple outputs per test case (measuring variance), it structures scoring around a predefined rubric (preventing post-hoc rationalization), and it separates the generation step from the evaluation step (so you can swap prompts without rebuilding the eval).

### Measuring Variance

Run the same prompt 20 times on the same input. Look at the distribution of outputs. You learn how stable the model's behavior is on this specific task. High variance means your prompt is under-specified; the model has multiple plausible interpretations and is exploring them. Low variance means the model has a strong, consistent interpretation of your instructions.

Variance measurement matters most for classification tasks where you need high consistency. If the model classifies the same input as "billing" 17 out of 20 times and "account" 3 out of 20 times, that's a 15% error rate that you'd never catch by looking at single outputs. Your eval suite should flag any test case where classification disagrees across runs.

### LLM-as-Judge

Using one LLM to evaluate another LLM's output (**LLM-as-judge**) is increasingly common because human evaluation is expensive and slow. It works surprisingly well for many tasks, but it has systematic biases you need to understand.

**Length preference**: LLM judges consistently rate longer outputs higher, even when the additional length adds no value. If you're using LLM-as-judge, normalize for length or explicitly instruct the judge to penalize unnecessary verbosity.

**Position bias**: When comparing two outputs, LLM judges tend to prefer whichever output they see first. Mitigate this by running each comparison twice with the order swapped and checking for consistency.

**Self-preference**: Models tend to rate outputs from their own model family higher. If you're using Claude to judge Claude's outputs, the scores will be systematically inflated. Use a different model family for judging, or calibrate against a set of human-scored examples.

**Rubric adherence**: LLM judges are more reliable when given a specific rubric than when asked for open-ended quality assessment. Always provide scoring criteria. The same rubric you use for human evaluation works for LLM-as-judge — and using the same rubric for both lets you measure human-LLM agreement.

We'll return to evaluation frameworks, particularly RAGAS for retrieval evaluation, in much more depth in Chapter 4. For now, the core principle: you cannot improve what you cannot measure, and you cannot measure without a rubric.

## Reality Check

> Prompt engineering is not a long-term moat. Most of the tricks filling blog posts and Twitter threads (specific phrasings, role-playing techniques, chain-of-thought invocations) are compensation for not having better data, better evals, or a better model. They work today and may not work tomorrow. Anthropic's own prompt engineering documentation has changed significantly across Claude versions: techniques that were critical for Claude 2 became unnecessary with Claude 3, and new techniques emerged for Claude 3.5 that didn't exist before.
>
> Prompt engineering matters right now, for shipping products today. But prompt knowledge has a shelf life. Evals don't. A well-built eval suite will tell you when your prompts stop working, regardless of why. It will catch model updates that break your carefully tuned prompts. It will detect input distribution shifts that expose edge cases. It will measure whether your "improvement" actually improved anything. Invest in evals over clever prompts. The prompts will change; the discipline of measurement is permanent.

## Case Study: The Evolution of Anthropic's Prompt Engineering Documentation

Anthropic has published and updated their prompt engineering documentation across every major Claude release. Tracking what changed, and what survived, illustrates exactly why eval infrastructure outlasts prompt knowledge.

With Claude 2 (2023), the documentation emphasized explicit XML formatting for all structured interactions, recommended detailed persona instructions to shape output quality, and suggested specific phrasings to avoid hallucination ("only use information provided in the context"). Many recommended techniques were compensating for the model's weaker instruction-following capabilities. Prompts needed to be verbose and explicit because the model required more scaffolding.

Claude 3 (early 2024) brought substantially better instruction following. The documentation shifted. Persona instructions became less critical because the model's default behavior was more capable. XML tags remained recommended but the model could handle less rigidly structured inputs, and the emphasis moved toward clear task specification rather than elaborate prompting scaffolding. Several techniques that were "essential" for Claude 2 were reclassified as optional or dropped entirely.

With Claude 3.5 Sonnet and Claude 4 (2024-2025), the documentation evolved again. Extended thinking capabilities meant that explicit chain-of-thought instructions became less necessary for reasoning tasks; the model could reason internally. Focus shifted further toward system prompt design and structured output specification, and away from prompt-level tricks. Now the documentation emphasizes prompt engineering as communication clarity rather than as a set of techniques to unlock capabilities.

What survived across all versions? Clear task specification, providing relevant context, using examples (few-shot), and structured output formatting. What was abandoned? Specific "magic" phrasings, elaborate jailbreak-prevention instructions (replaced by better model-level safety), verbose persona setups, and many workaround techniques for limitations that newer models simply don't have.

Techniques that compensate for model limitations expire when the model improves. Techniques that represent clear communication survive because clear communication is always useful. The only way to know which of your current techniques are in which category is to measure — which brings us back to evals.

You can read the current documentation at https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview and compare it to archived versions. The differences teach you something.

## Practical Exercise

**Build a prompt eval suite for a real task.** Estimated time: ~5 hours.

Choose one of the following tasks, or bring your own:

- **Extraction**: Pull structured data from unstructured text (entities, dates, relationships from news articles or support tickets)
- **Classification**: Categorize inputs into predefined classes (support ticket routing, sentiment analysis, content moderation)
- **Generation**: Produce a specific kind of text output (summaries, email drafts, code documentation)

### Specification

1. **Define your rubric first** — before writing any prompts. Identify 3-5 scoring criteria, each with a 1-5 scale and specific descriptions for each score level. The rubric is the most important artifact you'll produce.

2. **Collect or create 10+ test cases** that cover the realistic distribution of inputs your task would encounter. Include easy cases, hard cases, and edge cases. At least 2 test cases should be adversarial — inputs designed to trip up the model.

3. **Write your prompt** — system prompt, few-shot examples if appropriate, structured output format.

4. **Run each test case at least 3 times** at each of three temperature settings (0.0, 0.5, 1.0). That's a minimum of 90 outputs to evaluate.

5. **Score every output** against your rubric. You can use human scoring, LLM-as-judge, or both. If using LLM-as-judge, also human-score at least 20 outputs to calibrate.

6. **Analyze the results**: What's the mean score per criterion? What's the variance across runs? How does temperature affect quality? Which test cases are most prone to failure?

### Acceptance Criteria

- A rubric document with 3-5 criteria, each with clear scoring guides
- At least 90 scored outputs (10 test cases x 3 temperatures x 3 runs)
- A variance analysis: for each test case, how consistent are the outputs?
- A written summary (1 page) of findings: what worked, what failed, what surprised you
- At least one concrete prompt improvement based on eval findings, with before/after scores

The rubric is as important as the code. If your rubric is vague ("output quality: 1-5"), your eval is worthless. If your rubric is specific ("accuracy: all entities extracted with correct types and no hallucinated entities"), your eval will teach you something about both the model and your prompt.

## Checkpoint

After completing this chapter, you should be able to affirm the following:

- I can design prompts using system prompts, few-shot examples, chain-of-thought, and structured output formatting — and I can explain when each technique is appropriate.
- I can build a rubric-based eval for any prompt, and I understand why the rubric matters more than the prompt.
- I understand what temperature and top-p actually control at the distribution level, and I know why "temperature 0 = deterministic" is a simplification.
- I can explain the lost-in-the-middle problem and how to mitigate it through prompt construction.
- I know when multimodal is genuinely useful versus demo bait, and I can list the specific capabilities where current models are unreliable.
- I can explain why evals matter more than prompt tricks, and I can point to concrete examples of prompt knowledge becoming obsolete.

If any of these feel uncertain, revisit the relevant section. Chapter 3 builds directly on this foundation. We'll move from prompt construction to the full API layer, where tokens, costs, latency, and reliability become engineering constraints you manage directly.
