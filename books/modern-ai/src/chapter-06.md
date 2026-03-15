# Chapter 6: Agents & Agentic Systems

## Why This Matters

Agents are the most hyped word in AI right now. Every product announcement in 2025 and 2026 includes "agentic" somewhere in the press release, usually without defining what it means. Investors want agent plays. Product managers want agent features. And engineers are building things they call agents that range from fully autonomous systems to slightly fancier if/else chains with an LLM in the middle. The word has been stretched to the point of near-meaninglessness, and that's a problem. Real agentic systems have real architectural patterns, real failure modes, and real engineering constraints that matter once you're building for production.

This chapter is deliberately skeptical, not contrarian. There are genuine, valuable uses for agentic architectures, and you'll learn to build them. But the practitioner who can explain why an agent fails is more valuable than one who can only make it work in a demo. Understanding failure modes, designing for human oversight, and knowing when a simpler architecture would serve you better. These skills separate production engineers from demo engineers. By the end of this chapter, you'll be able to design, build, and critically evaluate agentic systems with the rigor they deserve.

If you've worked through Chapters 4 and 5, you already understand RAG and tool use, the building blocks that agents are composed of. Now we're asking a harder question: what happens when you give an LLM the ability to decide what to do next, repeatedly, with real consequences?

## What an Agent Actually Is

Strip away the marketing and an agent is a system built on a single loop: **perceive**, **reason**, **act**. The system perceives its environment (the user's request, tool outputs, error messages, the current state of whatever it's working on). It reasons about what to do next: which tool to call, what information to gather, whether it's done. Then it acts by calling a tool, generating output, or asking for clarification. The loop repeats until the agent decides it has completed its task, or until something stops it.

That's it. The **perception-reasoning-action loop** is the core of every agent, from a simple ReAct chatbot to a sophisticated multi-agent coding system. What varies is the complexity of each step, the quality of the reasoning, the set of available actions, and how the system handles memory across iterations of the loop.

The most important distinction in this space is between **agents** and **pipelines**. A pipeline has predetermined steps: retrieve documents, generate a summary, format the output, done. The order and logic are fixed at design time. An agent dynamically decides what to do next based on what it observes. It might call one tool or five. It might loop back and retry. It might decide the task requires a different approach entirely. Agents have a branching, runtime-determined execution path; pipelines have a fixed, design-time-determined one.

Most agent tutorials skip this: the majority of production "agents" are closer to pipelines than to truly autonomous systems. They have a constrained set of tools, a narrow task scope, and heavily guided reasoning. And that's fine. In fact, that's usually the right design. A tightly scoped agent with guardrails is far more reliable than a general-purpose autonomous agent, and reliability is what matters in production. The word "agent" has been applied so broadly that you need to ask, every time you see it: is this system actually making dynamic decisions, or is it following a script with an LLM handling the messy bits?

**Statefulness** is the other defining characteristic. An agent maintains state across steps: what it's tried, what's worked, what's failed, what it still needs to do. This state is what enables multi-step reasoning. But state management is also where agents start to degrade. As context fills up with previous steps, tool outputs, and accumulated reasoning, the model's attention becomes diluted. Important details from early steps get lost. The agent's "memory" of what it's doing and why becomes fuzzy. This degradation is predictable, measurable, and one of the hardest problems in agentic system design.

## Planning Approaches

An agent without a planning strategy is just an LLM calling tools at random. Planning is how the model decides what to do next, in what order, and when to stop. The quality of an agent's planning directly determines whether it can handle tasks that require more than one or two steps.

### ReAct: Reason + Act

The most influential planning pattern for agents is **ReAct**, introduced by Yao et al. in 2022. Before each action, the model explicitly reasons about what it's observed and what it should do next. The loop is think, act, observe, repeat. The "thinking" step is written out as text, a scratchpad where the model articulates its plan, and this explicit reasoning improves the quality of the subsequent action considerably.

ReAct works because it forces the model to commit to a line of reasoning before acting on it. Without the thinking step, models tend to pattern-match to the most obvious next action, which is fine for simple tasks and catastrophic for complex ones. The explicit reasoning step creates a record of the agent's decision-making that's invaluable for debugging. When something goes wrong, you can read the agent's reasoning and identify exactly where the logic broke down.

A basic ReAct agent loop with tool calling in TypeScript. Intentionally minimal (no framework, no abstractions) so you can see the actual structure:

```typescript
// src/react-agent.ts
import Anthropic from "@anthropic-ai/sdk";

interface Tool {
  name: string;
  description: string;
  input_schema: Record<string, unknown>;
  execute: (input: Record<string, unknown>) => Promise<string>;
}

interface AgentStep {
  reasoning: string;
  toolName: string | null;
  toolInput: Record<string, unknown> | null;
  observation: string | null;
}

async function runReActAgent(
  client: Anthropic,
  userQuery: string,
  tools: Tool[],
  maxSteps: number = 10
): Promise<{ answer: string; steps: AgentStep[] }> {
  const steps: AgentStep[] = [];

  const systemPrompt = `You are a helpful assistant that solves problems step by step.
For each step, you MUST:
1. Think about what you've learned so far and what you need to do next.
2. Decide whether to use a tool or provide a final answer.

When you have enough information to answer, respond without using any tools.
Be precise and avoid unnecessary tool calls.`;

  const messages: Anthropic.MessageParam[] = [
    { role: "user", content: userQuery },
  ];

  const toolDefinitions: Anthropic.Tool[] = tools.map((t) => ({
    name: t.name,
    description: t.description,
    input_schema: t.input_schema as Anthropic.Tool["input_schema"],
  }));

  for (let step = 0; step < maxSteps; step++) {
    const response = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024,
      system: systemPrompt,
      tools: toolDefinitions,
      messages,
    });

    // Extract reasoning from text blocks
    const textBlocks = response.content.filter(
      (block) => block.type === "text"
    );
    const reasoning = textBlocks.map((b) => {
      if (b.type === "text") return b.text;
      return "";
    }).join("\n");

    // Check if the model wants to use a tool
    const toolUseBlock = response.content.find(
      (block) => block.type === "tool_use"
    );

    if (!toolUseBlock || toolUseBlock.type !== "tool_use") {
      // No tool call — the agent is done
      steps.push({
        reasoning,
        toolName: null,
        toolInput: null,
        observation: null,
      });
      return { answer: reasoning, steps };
    }

    // Execute the tool
    const tool = tools.find((t) => t.name === toolUseBlock.name);
    if (!tool) {
      const errorMsg = `Tool "${toolUseBlock.name}" not found.`;
      steps.push({
        reasoning,
        toolName: toolUseBlock.name,
        toolInput: toolUseBlock.input as Record<string, unknown>,
        observation: errorMsg,
      });

      // Feed the error back so the agent can recover
      messages.push({ role: "assistant", content: response.content });
      messages.push({
        role: "user",
        content: [
          {
            type: "tool_result",
            tool_use_id: toolUseBlock.id,
            content: errorMsg,
            is_error: true,
          },
        ],
      });
      continue;
    }

    const observation = await tool.execute(
      toolUseBlock.input as Record<string, unknown>
    );

    steps.push({
      reasoning,
      toolName: toolUseBlock.name,
      toolInput: toolUseBlock.input as Record<string, unknown>,
      observation,
    });

    // Feed the tool result back into the conversation
    messages.push({ role: "assistant", content: response.content });
    messages.push({
      role: "user",
      content: [
        {
          type: "tool_result",
          tool_use_id: toolUseBlock.id,
          content: observation,
        },
      ],
    });
  }

  // If we hit maxSteps, return whatever we have
  return {
    answer: "Max steps reached without a final answer.",
    steps,
  };
}
```

A few things to notice about this implementation. The `maxSteps` parameter is not optional; it's your circuit breaker against infinite loops, which are a real and common failure mode. The error handling for unknown tool names feeds the error back to the model so it can recover, rather than crashing. And every step is recorded in the `steps` array, giving you a complete trajectory for debugging and evaluation. This is the minimal viable agent: no memory system, no planning beyond one step ahead, no persistence. But the structure is sound, and everything more sophisticated is built on this same loop.

### Chain-of-Thought in Agentic Contexts

**Chain-of-thought (CoT)** prompting (asking the model to think step by step) was valuable for single-turn tasks. In agentic contexts, it takes on a different role: it becomes the agent's scratchpad. Each iteration of the loop produces reasoning that serves as working memory for subsequent iterations. The accumulated chain of thought is how the agent maintains coherence across a multi-step task.

The limitation is that this scratchpad lives in the context window. As the agent takes more steps, the accumulated reasoning, tool outputs, and observations consume tokens. Eventually, you hit the context limit, or — more insidiously — the model's attention to early steps degrades long before you hit the hard limit. We'll address this in the memory architecture section.

### Reasoning Models

A significant development in 2024-2025 was the emergence of **reasoning models**: models like OpenAI's o3 and Claude with extended thinking that perform planning *inside the model* rather than requiring external orchestration. These models allocate additional compute at inference time to "think through" a problem before responding, producing internal chains of reasoning that are longer and more structured than what standard chain-of-thought prompting achieves.

For agentic systems, reasoning models change the calculus. Instead of the orchestration code managing the planning loop (prompting the model to think, parsing the reasoning, deciding when to act), the model itself handles planning as part of its inference. This can produce better plans for complex tasks because the reasoning is happening in the model's latent space, not in the relatively lossy process of writing out thoughts as text and reading them back in.

The practical tradeoff is cost and latency. Reasoning models spend more tokens on internal thinking, which means higher inference costs and longer response times. For simple agent tasks ("look up this information and format it"), a reasoning model is overkill. For complex tasks requiring real multi-step planning ("analyze this codebase and propose a refactoring strategy"), the improved planning quality can be worth the cost. This is a judgment call, and it changes as models improve and costs decrease.

> 🤔 **Taste Moment** — The choice between orchestration-managed planning (ReAct loops with standard models) and model-managed planning (reasoning models) isn't binary. Some of the most effective agent architectures use a reasoning model for the planning step and a faster, cheaper model for routine tool calls. Match the model to the cognitive demand of each step, not one model for everything.

### When Planning Fails

Planning fails predictably in several scenarios, and you need to recognize them. **Irreversible actions**: when the agent can delete files, send emails, or charge credit cards, a bad plan has consequences you can't undo. **Ambiguous goals**: "make this better" or "clean up this code" gives the agent too much room for interpretation, and it will optimize for something that may not be what you wanted. **Underspecified tasks**: the agent doesn't have enough information to form a plan but proceeds anyway, inventing assumptions that seem plausible but aren't grounded. **Circular reasoning**: the agent gets stuck in a loop, trying the same approach repeatedly because its reasoning leads it back to the same conclusion each time.

The mitigation for all of these is the same: constrain the agent's action space, require explicit confirmation before irreversible actions, and build detection for circular behavior. We'll cover these patterns in the human-in-the-loop section.

## Memory Architecture

An agent without memory is stateless — it can handle one request but can't maintain context across steps or sessions. Memory is what makes multi-step reasoning possible, and the design of an agent's memory system is one of the most consequential architectural decisions you'll make.

### In-Context Memory

The simplest form of agent memory is **in-context memory**: everything the agent needs to remember is kept in the prompt window. The conversation history, tool outputs, reasoning traces, previous observations. All of it lives in the messages array that gets sent to the model on each turn. This is what the ReAct implementation above uses.

In-context memory is simple, reliable, and requires no additional infrastructure. The model has direct access to everything it's been told, with no retrieval step that could fail or return irrelevant results. For agents with short task horizons (five to ten steps), this is often the right choice.

The downsides are straightforward. It's expensive, because you're paying for all those input tokens on every model call. It has a hard ceiling (the context window) beyond which you simply can't add more memory. And the effective ceiling is lower than the hard ceiling, because model attention to information in long contexts degrades well before you hit the token limit. A 200,000-token context window doesn't mean the model pays equal attention to all 200,000 tokens. Information in the middle of a very long context is systematically less likely to influence the model's output. This is the "lost in the middle" phenomenon we covered in Chapter 2.

> 💸 **Cost Callout** — In-context memory means every agent step re-sends the entire conversation history. A 20-step agent task with an average of 2,000 tokens per step accumulates roughly 40,000 tokens of input by the final step. At $3 per million input tokens, that's $0.12 — trivial for one task, significant at 10,000 tasks per day ($1,200/day). Prompt caching can cut this by up to 90% if the prefix is stable, so design your system prompt and tool definitions to appear first and remain constant.

### External and Vector Memory

**External memory** systems use vector databases to store and retrieve past context semantically. Instead of keeping everything in the prompt, the agent stores observations, reasoning, and outcomes in a vector store and retrieves relevant memories when needed. Same architecture as RAG (Chapter 4), applied to the agent's own history rather than an external document corpus.

The advantage is scalability. An agent can accumulate memories over hundreds of sessions and retrieve only the relevant ones for the current task. This enables long-term learning: an agent that remembers how it solved a similar problem last week and applies that approach again.

The disadvantage is retrieval error. Every retrieval step introduces the possibility that the agent recalls the wrong memory, a partially relevant memory, or misses a critical one entirely. The failure modes of RAG (discussed at length in Chapter 4) apply directly. Semantic similarity doesn't guarantee relevance. A memory about "deleting the test database" and a memory about "deleting the production database" look semantically similar but carry very different implications. An agent that retrieves the wrong one and acts on it creates problems.

### Episodic Memory

**Episodic memory** is a more structured approach: the agent maintains explicit records of past actions and their outcomes, stored in a structured format rather than as raw text. Think of it as a database of episodes ("I tried approach X, the result was Y, the user's feedback was Z") that can be queried precisely.

This is more complex to implement but produces higher-quality recall. Instead of semantic similarity search over raw text, you can query by task type, outcome, tool used, or any other structured field. The tradeoff is that you have to design the schema upfront and instrument the agent to write structured records at each step. Schema design matters. Capture too little and the memories are useless; capture too much and you're back to the context bloat problem, just with extra infrastructure.

### Context Compression

**Context compression** is the set of strategies for fitting more useful information into a fixed context window. The most common approach is summarization: periodically condensing the agent's accumulated context into a shorter summary, then replacing the full history with the summary plus recent steps.

This sounds clean in theory. In practice, summarization loses details — and the details it loses are often the ones that matter. A summary might capture "the agent tried three approaches to fix the bug" but lose the specific error message from the second attempt that would have told the agent not to try a similar approach again. The model performing the summarization doesn't know which details will be important later, because neither does the system designer. Every summarization step is a lossy compression, and the losses compound.

> ⚡ **Production Tip** — If you use context compression, keep the raw history available as a fallback. When the agent seems confused or is repeating past mistakes, the issue is often that critical context was lost in summarization. Having the ability to "reload" the full history — or a targeted section of it — can recover from summarization-induced errors without restarting the task.

The practical recommendation: start with in-context memory and move to more complex memory architectures only when you have evidence that context limits are your bottleneck. Premature optimization of memory systems adds complexity without improving outcomes for most agent tasks.

## Single-Agent vs. Multi-Agent

Multi-agent systems are among the most hyped concepts in AI right now. The pitch: break a complex task into subtasks, assign each to a specialized agent, coordinate their work, and get a result that's better than any single agent could produce. It sounds like good engineering: decomposition, specialization, parallelism. And sometimes it is. But multi-agent architectures are justified far less often than they're proposed.

### When Multi-Agent Is Justified

Three scenarios where multi-agent systems earn their complexity. The first is **parallelism**: when you have independent subtasks that can be executed simultaneously. If an agent needs to research three different topics that don't depend on each other, running three agents in parallel is faster than running one sequentially. The key word is "independent" — if the subtasks share dependencies, parallelism introduces coordination overhead that can negate the speed benefit.

The second is **specialization**: when different parts of a task benefit from different models or different system prompts. A code-writing agent and a code-reviewing agent can use different models (a fast model for generation, a reasoning model for review) and different system prompts tuned to their respective tasks. This is a real benefit when the tasks are genuinely different in character.

The third is **verification**: when one agent checks another's work. This is the pattern where a "reviewer" agent evaluates the "worker" agent's output before it's finalized. The reviewer can catch errors, request revisions, and enforce quality standards. This works because the reviewer has a different perspective. It's seeing the output fresh, without the reasoning baggage of having produced it.

### When Multi-Agent Is Overkill

Most tasks. That's the honest answer. The overhead of coordinating multiple agents (defining communication protocols, handling partial failures, merging results, managing conflicting outputs) usually outweighs the benefits for tasks that a single well-prompted agent can handle.

**Failure surface multiplication** is the concept to internalize. A single agent has one set of failure modes. Two agents have their individual failure modes plus every failure mode that emerges from their interaction: miscommunication, conflicting actions, deadlocks, and cascading failures where one agent's error triggers errors in the others. Three agents have even more. The failure surface doesn't grow linearly; it grows combinatorially.

> 🤔 **Taste Moment** — Before proposing a multi-agent architecture, ask yourself: "Could a single agent with better tools or a better prompt handle this?" The answer is yes more often than you'd expect. Multi-agent systems are an architectural choice, not an upgrade. They solve coordination problems at the cost of creating coordination problems.

### The Orchestrator/Subagent Pattern

When multi-agent is justified, the most common production pattern is **orchestrator/subagent**. An orchestrator agent receives the user's task, decomposes it into subtasks, assigns each to a specialized subagent, collects results, and synthesizes a final output. The orchestrator doesn't do domain work — it manages the workflow.

This pattern works because it centralizes coordination. The orchestrator maintains the global plan and makes routing decisions. Subagents are stateless with respect to each other — they receive a task, execute it, and return a result. This simplifies the interaction model compared to having agents communicate with each other directly, where you'd need to solve message routing, conflict resolution, and shared state management.

### Inter-Agent Communication: The Hard Part

The part nobody demos is inter-agent communication. How do agents share context? How does one agent reference what another agent discovered? How do you handle conflicts when two agents produce contradictory outputs? How do you debug a failure that spans three agents?

In practice, most "multi-agent" systems solve this by not having agents communicate directly at all. They use the orchestrator/subagent pattern, where the orchestrator mediates all information flow. This is less architecturally elegant and more operationally reliable. Direct agent-to-agent communication (where agents maintain shared state or send messages to each other) introduces concurrency problems, state management complexity, and debugging nightmares familiar to anyone who's built distributed systems. The only difference is that the components are nondeterministic, which makes everything harder.

## Long-Horizon Task Failure Modes

This is the section that most agent tutorials skip. It's the most important section in this chapter.

Agents that work on short tasks (three to five steps, well-defined goals, constrained tools) are relatively straightforward to build and debug. Agents that work on long-horizon tasks (twenty or more steps, complex goals, broad tool access) fail in ways that are systematic, predictable, and often subtle enough to miss in testing. If you're building agents for production, you need to know these failure modes intimately.

### Compounding Errors

**Compounding errors** are the fundamental challenge of long-horizon tasks. In a multi-step process, a small mistake in step 3 can propagate and amplify through steps 4 through 20. The agent misidentifies a file in an early step, writes code that references the wrong module, then spends ten steps debugging a problem that wouldn't exist if the initial identification had been correct. Each subsequent step is built on a flawed foundation, and the agent lacks the perspective to recognize that the root cause is far upstream.

This is qualitatively different from single-turn errors. A single wrong answer is easy to identify and fix. A chain of reasoning built on a flawed premise can look locally reasonable at every step while being globally wrong. The agent's reasoning at step 15 might be perfectly sound given the context it has, but the context itself is corrupted by the step 3 error.

The mitigation is checkpointing: periodically validating the agent's state against ground truth or asking a human to confirm that the current trajectory makes sense. This is expensive and slows the agent down, but it's the only reliable way to catch compounding errors before they cascade.

### Context Bloat

**Context bloat** occurs when the agent's accumulated context (reasoning traces, tool outputs, error messages) grows to the point where the model's attention to critical information degrades. The agent doesn't "forget" in the way humans do. The information is still in the context window. But the model's ability to attend to specific details diminishes as the context grows. Critical information from step 2 gets diluted by the verbose output of steps 3 through 15.

This manifests as the agent "losing the plot." It starts repeating actions it's already taken, misses constraints that were established early in the task, or loses track of which subtasks are complete. The agent appears to be working (still reasoning, still calling tools) but its actions become increasingly disconnected from the original goal.

Context compression helps but introduces its own risks, as we discussed. The practical approach is to design agents with shorter task horizons. If a task requires 50 steps, break it into 5 sub-tasks of 10 steps each, with a fresh or heavily pruned context at each boundary.

### Goal Drift

**Goal drift** is when the agent starts optimizing for a proxy that diverges from the actual goal. The user asks the agent to "improve the test suite," and the agent starts adding tests — which superficially looks like progress — but the tests are trivial, repetitive, or test implementation details rather than behavior. The agent is optimizing for "more tests" because that's the most measurable proxy for "improved test suite," even though it doesn't capture what the user actually wanted.

Goal drift is dangerous because the agent appears to be making progress. The output looks reasonable at each step. It's only when you evaluate the final result against the original intent that you realize the agent has been doing the wrong thing productively.

> ⚡ **Production Tip** — Build goal-checking into your agent's loop. Every N steps, add a prompt that asks: "Given the original task [X], are we still making progress toward it? If not, what should change?" This simple check catches goal drift early. It adds latency and cost but prevents far more expensive wasted computation.

### Irreversible Actions

**Irreversible actions** are the most dangerous failure mode because they have consequences outside the agent's runtime. An agent that deletes files, sends emails, posts to social media, modifies database records, or charges credit cards can cause real-world damage that can't be undone by stopping the agent.

Agents often take irreversible actions confidently, compounding the danger. The model doesn't distinguish between "read this file" (reversible, low risk) and "delete this file" (irreversible, high risk) unless you explicitly teach it to. Without human-in-the-loop gates on irreversible actions, a single hallucinated tool call ("the user probably wants me to clean up these old files") can cause real damage.

> 🔒 **Security Callout** — Every tool an agent can access should be classified as read-only or write. Write tools should be further classified as reversible or irreversible. Irreversible write tools (delete, send, publish, charge) must require explicit human approval, no exceptions. This classification should be enforced at the tool layer, not in the agent's prompt. Prompts can be bypassed; code gates cannot.

### Infinite Loops

**Infinite loops** occur when the agent gets stuck in a cycle, trying the same approach repeatedly. The agent encounters an error, attempts a fix, the fix doesn't work, and the agent tries the same fix again — or a cosmetically different fix that fails for the same reason. Without loop detection, the agent will continue indefinitely, consuming tokens and producing nothing useful.

Loop detection isn't hard to implement: track the last N tool calls and check for repeated patterns. The harder problem is loop *breaking*: when you detect a loop, what should the agent do? The options: escalate to a human, try a fundamentally different approach, or give up with an honest explanation of what went wrong. "Try a different approach" sounds obvious but is difficult for models. The reasoning that led to the loop usually looks compelling, and the model needs explicit help breaking out of the local optimum.

The `maxSteps` parameter in the ReAct implementation above is the simplest loop prevention mechanism: a hard ceiling on the number of steps. It's blunt but effective. More sophisticated approaches detect repetition in tool call patterns and trigger escalation after a configurable number of similar attempts.

### Hallucinated Tool Calls

**Hallucinated tool calls** are when the model invents tool parameters that don't exist. The model calls a `search_database` function with a table name that doesn't exist in the schema, or calls a `send_email` function with an email address it fabricated. These hallucinated calls are dangerous because they look syntactically correct (the JSON is valid, the parameter names are right) but the values are invented.

This is the tool-use version of the hallucination problem we've discussed throughout this book. The model generates plausible-looking output that isn't grounded in reality. The mitigation is the same: validate inputs before executing. Every tool should validate its parameters against actual system state. Does this file exist? Is this a valid email address in our directory? Does this database table have this column? Validation at the tool layer catches hallucinated parameters before they cause problems.

## Human-in-the-Loop Design

The most reliable production agents aren't the most autonomous ones. They're the ones with well-designed human oversight. **Human-in-the-loop (HITL)** design is the practice of identifying where an agent should stop and ask a human before proceeding. Done well, HITL creates a system that's fast on routine tasks and safe on risky ones. Done poorly, you get agents that move fast in the wrong direction.

### Interrupt Design

The core question is: when should an agent pause and ask for human input? The answer involves three categories.

First, **before any irreversible action**. This is non-negotiable. Before deleting, sending, publishing, paying, or modifying anything that can't be undone, the agent should present its intended action and wait for approval. The presentation should include what it plans to do, why, and what the consequences will be. "I'm about to send this email to 500 customers — here's the content. Approve?" is good design. Silently sending it is not.

Second, **before spending above a cost threshold**. If an agent is making API calls that cost money, set a budget. When the agent's accumulated cost approaches the budget, it pauses and reports: "I've spent $X so far on this task. Here's what I've accomplished and what's remaining. Should I continue?" This prevents runaway costs from agents that get stuck in loops or take unnecessarily expensive paths.

Third, **before acting on ambiguous instructions**. When the user's request is unclear ("fix the performance issue" without specifying which issue, or "update the documentation" without specifying what changed), the agent should ask for clarification rather than guessing. Models have a tendency to fill in ambiguity with plausible-seeming assumptions, which is helpful in a chat context and dangerous in an agentic one where those assumptions drive real actions.

### Approval Gates

An **approval gate** is a point in the agent's workflow where execution pauses until a human explicitly approves the next step. Approval gates can be implemented at the tool level (certain tools require approval before execution), at the plan level (the agent presents its full plan before starting), or at the outcome level (the agent completes its work and presents it for review before committing).

The architectural decision is where to place the gates. Too few gates and you lose oversight. Too many gates and you lose the automation benefit — if the human has to approve every step, they might as well do the work themselves. The sweet spot depends on the risk profile of the task. Internal-facing agents working on low-stakes tasks might need approval only for irreversible actions. Customer-facing agents handling financial transactions might need approval at every step.

### Progressive Autonomy

**Progressive autonomy** is the pattern where an agent earns increasing independence over time. A new agent starts with heavy human oversight: approval gates at every step, narrow tool access, short task horizons. As the agent demonstrates reliability on a specific class of tasks, the oversight is gradually relaxed. Fewer approval gates, broader tool access, longer task horizons.

This is the production equivalent of building trust. It's how responsible organizations deploy agents: start constrained, measure performance, expand scope. The alternative, deploying a fully autonomous agent and hoping for the best, is how incidents happen.

> 💸 **Cost Callout** — Human-in-the-loop isn't free. Every approval gate adds latency (minutes to hours, depending on human availability) and human cost (someone has to review and decide). Design approval gates to batch when possible. Instead of five separate approvals for five file changes, present all five changes as a single review. This preserves safety while minimizing the interrupt burden.

## Evaluating Agents

Evaluating agents is harder than evaluating single-turn model outputs because agents produce trajectories, not just answers. An agent might arrive at the right answer via an unreasonable path, or arrive at a reasonable answer via the right approach but with a small final error. Both the destination and the journey matter.

### Task Completion vs. Quality

**Task completion rate** (did the agent finish the task?) is the most basic metric and also the most misleading on its own. An agent that completes 90% of tasks but produces mediocre quality on all of them is less useful than one that completes 80% of tasks at high quality and honestly reports "I can't do this" for the other 20%.

You need both completion rate and quality metrics. For coding agents, quality might be "code passes tests and follows style guidelines." For research agents, quality might be "answer is factually accurate and cites sources." For workflow agents, quality might be "all steps completed correctly and in the right order." Define quality specific to your use case and measure it separately from completion.

### Trajectory Evaluation

**Trajectory evaluation** assesses the path the agent took, not just the outcome. Was the approach reasonable? Did the agent take unnecessary steps? Did it recover gracefully from errors? Did it get stuck and waste tokens before finding the right approach?

Trajectory evaluation matters because it predicts reliability. An agent that reaches the right answer but takes 30 steps of confused wandering to get there is fragile — on a slightly different input, that wandering might not converge. An agent that takes a direct, logical path to the answer is more likely to succeed consistently.

The practical approach is to log complete trajectories — every reasoning step, every tool call, every observation — and review them for a sample of tasks. Automated trajectory evaluation is possible but harder: you can measure step count, detect loops, and flag unnecessary tool calls, but evaluating whether the reasoning was "good" still requires human judgment or a very capable evaluator model.

### Key Benchmarks

Several benchmarks attempt to measure agent capabilities. Understanding what they test — and their current state — helps you calibrate expectations.

**GAIA** (General AI Assistants) tests agents on real-world tasks requiring web browsing, file handling, and multi-step reasoning. As of early 2026, top systems score approximately 90%, which means the benchmark is approaching saturation — the ceiling on what current architectures can achieve on this particular task distribution. GAIA is useful for comparing systems but less useful for predicting performance on your specific tasks.

**SWE-bench Verified** tests agents on real GitHub issues: given a bug report, can the agent produce a correct patch? Top scores are approximately 74.4% as of early 2026. This is a genuinely hard benchmark because it requires understanding codebases, localizing bugs, and producing working fixes. The gap between 74% and 100% represents the hardest cases — complex bugs, multi-file changes, ambiguous specifications — and closing it is an active area of work.

**BFCL** (Berkeley Function Calling Leaderboard) evaluates tool use accuracy — can the model correctly call functions with the right parameters? Top scores hover around 77.5%. This matters for agent builders because every tool call that's wrong is a step that fails, and in a multi-step agent, one wrong tool call can cascade.

**OSWorld** tests agents on computer use tasks — operating GUIs, navigating applications, completing workflows. Even top agents struggle here, scoring roughly 34.5% on 50-step tasks. This benchmark is a sobering reminder of how far we are from reliable long-horizon autonomous systems.

### Cost-Normalized Metrics

Raw accuracy numbers are less meaningful than **cost-normalized metrics**. An agent that achieves 80% task completion at $0.05 per task is often more valuable than one that achieves 85% at $2.00 per task. The marginal 5% improvement costs 40x more per task. Is that worth it?

Cost-normalized metrics force you to think about deployment economics, not just capability. In production, you're optimizing for value delivered per dollar spent, not for benchmark scores. An agent that's 10% less accurate but 90% cheaper might be the right choice if the remaining errors can be caught by a human reviewer.

> 🤔 **Taste Moment** — When evaluating agent systems, always ask: "What does this cost per task, and what would a human cost for the same task?" If the agent costs $0.50 per task and a human costs $5.00, the agent needs to be only 10% as good as the human to break even on cost alone — and it runs 24/7. The economics of "good enough" automation are often more compelling than the pursuit of perfect automation.

## Reality Check

> A 2025 survey of 306 AI agent practitioners (conducted by LangChain) found that reliability issues are the single biggest barrier to enterprise agent adoption. Not capability. Not cost. Reliability. The agents can do impressive things in demos, but they break in ways that are hard to predict, hard to debug, and hard to explain to stakeholders.
>
> Practitioners are responding by limiting autonomy. The most common production deployments use shorter task horizons, internal-facing agents with human review rather than customer-facing autonomous systems, and tightly constrained tool access. Multi-agent hype outpaces multi-agent reliability by a wide margin. The survey found that while interest in multi-agent systems is high, actual production deployments are overwhelmingly single-agent or structured pipelines.
>
> This matches what we see across the industry in 2025-2026. Most production AI applications are not autonomous agents roaming free. They're tightly scoped systems with human oversight, narrow tool access, and well-defined task boundaries. The companies succeeding with agents are the ones that treat them like junior employees: give them clear instructions, check their work, and expand their responsibilities gradually as they prove reliable.
>
> Default to the simplest architecture that could work. A pipeline with an LLM handling the ambiguous parts is simpler, cheaper, and more reliable than a full agent for most tasks. An agent with human-in-the-loop is simpler, cheaper, and more reliable than an autonomous agent. A single agent is simpler, cheaper, and more reliable than a multi-agent system. Move to more complex architectures only when you have evidence — not intuition — that the simpler approach is insufficient.

## Case Studies

### Cognition/Devin: The Gap Between Demo and Production

Cognition's Devin was introduced in March 2024 with a demo that captivated the AI engineering world: an autonomous software agent that could take a GitHub issue and produce a working pull request. The initial demo showed Devin navigating codebases, writing code, running tests, and debugging errors — all without human intervention. It felt like a glimpse of the future.

The subsequent reality was more instructive than the demo. Independent evaluations found that Devin's actual success rate on real-world tasks was well below what the demo suggested. The tasks it handled well were well-specified, contained, and similar to patterns in its training data. The tasks it struggled with — ambiguous requirements, large codebases, complex multi-file changes — were exactly the tasks that human engineers find hard too, plus the additional challenge of maintaining coherent planning across dozens of steps.

Cognition's response was telling and, to their credit, honest. They evolved Devin from an autonomous system toward a human-in-the-loop collaborative tool. Rather than presenting it as a replacement for engineers, they repositioned it as an assistant that handles routine work — fixing simple bugs, writing boilerplate, running through straightforward tasks — while escalating complex decisions to human engineers. This evolution mirrors the broader pattern in the industry: the gap between autonomous agent capability and production reliability pushes builders toward human oversight, not away from it.

The lesson isn't that Devin failed. The failure modes were exactly the ones described in this chapter: compounding errors, context degradation over long horizons, goal drift on ambiguous tasks, and hallucinated actions on underspecified inputs. Cognition didn't encounter novel problems. They encountered the known, predictable problems of long-horizon agentic systems, and they responded by limiting autonomy and adding human checkpoints. That's the mature engineering response.

### Cursor 2.0: Multi-Agent as a Product Decision

In October 2025, Cursor shipped its 2.0 release with a multi-agent interface that represented one of the first widely deployed multi-agent coding systems. The architecture allowed up to eight agents working in parallel, each operating in an isolated worktree — a separate copy of the codebase — with a shared plan visible to all agents and the user.

This is multi-agent done with engineering discipline. Each agent has an isolated workspace, so agents can't step on each other's changes. The shared plan provides coordination without requiring agents to communicate directly. The orchestrator manages the plan, and each agent works on its assigned subtask independently. The user can see all agents' progress, intervene when something goes wrong, and approve or reject changes before they're merged.

The architecture works because it satisfies the three conditions for justified multi-agent systems: parallelism (independent subtasks on isolated worktrees), specialization (different agents can use different strategies), and verification (changes are reviewed before merging). It avoids the coordination nightmare of direct agent-to-agent communication by routing everything through the shared plan and user oversight.

By Q1 2026, Cursor had reached approximately $2B in annual recurring revenue, a testament to the product-market fit of AI-assisted coding tools and the viability of well-designed multi-agent systems. But it's worth noting what made this work: isolated workspaces, a visible shared plan, human oversight at the merge point, and a task domain (code editing) where each agent's work can be objectively verified by running tests. Remove any of those properties and the multi-agent architecture becomes significantly harder to operate reliably.

## Practical Exercise

**Build a single-agent system for a multi-step real-world task.**

Choose one of the following tasks, or design your own with comparable complexity:

1. **Research and synthesis**: Build an agent that takes a technical topic, searches multiple sources, evaluates source quality, synthesizes findings, and produces a structured report with citations. The report should cover what's established, what's contested, and what's unknown.

2. **Code generation against a spec**: Build an agent that takes a natural-language specification for a small program (a CLI tool, a data transformer, a simple web server), writes the code, writes tests, runs the tests, and iterates until the tests pass.

3. **Workflow planning**: Build an agent that takes a high-level goal (e.g., "migrate this Express app to use a new database schema"), breaks it into steps, identifies dependencies between steps, creates a plan, and executes the first few steps with human approval gates.

**Requirements:**

- Use the ReAct pattern with explicit reasoning at each step.
- Implement at least three tools the agent can use.
- Include a `maxSteps` circuit breaker.
- Log every step: reasoning, tool calls, observations, and timing.
- Implement at least one human-in-the-loop approval gate for a high-risk action.

**Then — and this is the most important part — document every failure mode:**

- Run the agent on at least five different inputs, including edge cases.
- Record every failure: what broke, at which step, and why.
- Note which failures are compounding errors, context bloat, goal drift, or hallucinated tool calls.
- Write a post-mortem: what broke, what compounded, and what you'd redesign if you were building version 2.

The post-mortem is worth more than the agent. Any engineer can build an agent that works in a demo. The engineer who can explain why it fails, classify the failure modes, and propose architectural mitigations is the one you want on your team.

Estimated time: ~8 hours (3-4 hours building, 4-5 hours testing and documenting failures).

## Checkpoint

- I can explain the difference between an agent and a pipeline, and I know that most production "agents" are closer to pipelines.
- I can implement a basic ReAct agent loop with tool calling and understand why the explicit reasoning step matters.
- I can list at least five failure modes for long-horizon agent tasks: compounding errors, context bloat, goal drift, irreversible actions, infinite loops, and hallucinated tool calls.
- I can design human-in-the-loop interrupt points: before irreversible actions, above cost thresholds, and on ambiguous instructions.
- I understand when multi-agent is justified — parallelism, specialization, verification — and when it's overkill, which is most of the time.
- I can evaluate agent performance beyond "it works in the demo" — using task completion rate, quality metrics, trajectory evaluation, and cost-normalized metrics.
- I can explain why the simplest architecture that could work is usually the right starting point.

---

*Key Sources: Yao et al., "ReAct: Synergizing Reasoning and Acting in Language Models" (2022). Anthropic, "Building Effective Agents" (https://docs.anthropic.com/en/docs/build-with-claude/agents). GAIA Benchmark (https://huggingface.co/spaces/gaia-benchmark/leaderboard). SWE-bench (https://www.swebench.com).*
