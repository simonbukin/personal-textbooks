# Chapter 8: Orchestration Frameworks

## Why This Matters

You've spent the last several chapters building AI systems from scratch: calling APIs directly, managing tool loops by hand, wiring up retrieval pipelines with code you wrote and understood. That wasn't busywork. It was the single best preparation for what comes next, because orchestration frameworks are only useful to people who understand what they're abstracting over. If you've never hand-rolled a tool-calling loop, you can't diagnose why your LangGraph agent is silently dropping tool results. If you've never managed conversation state manually, you won't understand why your framework's state management is adding 200ms of latency per step.

Frameworks exist to solve real problems: managing complex state machines, providing checkpointing for long-running workflows, standardizing patterns that every team reinvents. But they also hide things. Error handling, retry logic, the exact shape of messages hitting the API. When everything works, that hiding is a feature. When something breaks at 3 AM in production, that hiding is the reason you can't figure out why. This chapter gives you a clear-eyed understanding of what each major framework adds, what it costs, and how to make the choice deliberately rather than by default.

Framework churn is the other elephant in the room. LangChain's API changed substantially multiple times between 2023 and 2025, and teams that built tightly coupled systems against early LangChain spent months migrating. LlamaIndex went through similar evolution. The underlying primitives — the messages API, tool calling conventions, embedding interfaces — are far more stable than any framework built on top of them. This isn't an argument against frameworks. It's an argument for understanding what's underneath, so that when your framework changes (and it will), you can adapt quickly rather than panic.

## What Frameworks Actually Do, and What They Hide

At their core, orchestration frameworks provide abstractions over two things: the **messages API** and the **tool call loop**. You've implemented both. The messages API is the stateless interface where you send a list of messages and get a completion back. The tool call loop is the pattern where the model requests a tool call, you execute it, feed the result back, and let the model continue. Every framework wraps these primitives in higher-level constructs ("chains," "graphs," "agents," "query engines") that handle the plumbing so you can focus on the logic.

The real value of frameworks lies in **state management for multi-step pipelines**, not the API wrapper. When you're building a system that needs to route between multiple paths based on intermediate results, checkpoint its progress so it can resume after failure, and maintain a structured representation of what's happened so far, doing all of that from scratch is tedious and error-prone. Frameworks like LangGraph give you a state machine model where you define nodes (steps), edges (transitions), and conditions (routing logic), and the framework handles execution, state persistence, and error recovery. That's useful. It's the kind of infrastructure you'd otherwise build yourself, badly, under deadline pressure.

What frameworks hide is equally important to understand. Most frameworks intercept the raw API response before you see it. They parse tool calls, manage message history, handle retries, and sometimes modify the messages being sent (adding system prompts, reformatting tool results, truncating context). When something goes wrong, you're debugging through layers of abstraction. A tool call silently fails, a message gets truncated, the model's response is misinterpreted. You can't just print the raw request and response; you have to understand the framework's internal pipeline to figure out where things went sideways.

> **⚡ Production Tip:** Before adopting any framework, write a test that captures the raw HTTP request and response being sent to the model API. If you can't easily do this within the framework, that's a red flag. You will need this capability when debugging production issues.

There's also a subtler cost: **cognitive lock-in**. Once your team thinks in terms of a framework's abstractions (LangGraph nodes, LlamaIndex query engines, LangChain chains) it becomes harder to see solutions that don't fit those abstractions. Sometimes the right answer is a plain function that calls the API. Frameworks make you forget that's an option. Developers who built without frameworks first (as you did in Chapters 5 and 6) have a permanent advantage here: they know what the framework is doing because they've done it themselves, and they can always drop down to the primitives when the framework gets in the way.

## LangChain / LangGraph

**LangChain** started as the dominant orchestration framework in the Python AI ecosystem, providing abstractions for prompt templates, model interfaces, chains, and agents. Its early popularity was well-earned — it gave developers a fast path to building AI applications when the ecosystem was young and patterns hadn't solidified. But LangChain's rapid evolution came with real costs: breaking API changes, heavy abstraction layers that obscured what was happening, and a tendency to wrap things that didn't need wrapping. By 2025, the LangChain team had acknowledged much of this feedback and refocused their energy on **LangGraph**, a more principled framework built around explicit state machines.

**LangGraph** models agents as state machines. You define a **StateGraph**: a directed graph where nodes are functions that transform state, edges define the flow between nodes, and conditional edges enable dynamic routing based on the current state. This is a real conceptual improvement over the "chain of prompts" model. Instead of hoping your agent follows the right path through a linear pipeline, you explicitly define what paths exist, what conditions trigger each path, and what state is carried between steps.

The core abstraction is the **StateGraph** with a typed state object. A complete example implementing a research agent follows. It takes a question, decides whether to search or answer directly, and routes accordingly:

```python
from typing import TypedDict, Literal, Annotated
from langgraph.graph import StateGraph, END
from langgraph.graph.message import add_messages
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage, SystemMessage
import operator
import json


class AgentState(TypedDict):
    """Explicit state — every field is visible and typed."""
    messages: Annotated[list, add_messages]
    question: str
    search_results: list[str]
    answer: str
    needs_search: bool


model = ChatAnthropic(model="claude-sonnet-4-20250514", temperature=0)


def classify_question(state: AgentState) -> dict:
    """Decide whether the question needs external search."""
    response = model.invoke([
        SystemMessage(content=(
            "You are a router. Given a question, respond with ONLY "
            "'search' if it requires current or specific factual data, "
            "or 'direct' if you can answer from general knowledge. "
            "One word only."
        )),
        HumanMessage(content=state["question"]),
    ])
    needs_search = "search" in response.content.lower()
    return {"needs_search": needs_search}


def search_node(state: AgentState) -> dict:
    """Execute search — replace with your actual search implementation."""
    # In production, this calls your search API or RAG pipeline
    query = state["question"]
    # Placeholder: your Chapter 4 retrieval system goes here
    results = [f"Search result for: {query}"]
    return {"search_results": results}


def generate_answer(state: AgentState) -> dict:
    """Generate final answer, optionally using search results."""
    context = ""
    if state.get("search_results"):
        context = (
            "\n\nRelevant search results:\n"
            + "\n".join(state["search_results"])
        )

    response = model.invoke([
        SystemMessage(content=(
            "Answer the user's question accurately and concisely."
            + context
        )),
        HumanMessage(content=state["question"]),
    ])
    return {"answer": response.content}


def route_after_classification(
    state: AgentState,
) -> Literal["search_node", "generate_answer"]:
    """Conditional edge: route based on classification result."""
    if state["needs_search"]:
        return "search_node"
    return "generate_answer"


# Build the graph
workflow = StateGraph(AgentState)

# Add nodes
workflow.add_node("classify", classify_question)
workflow.add_node("search_node", search_node)
workflow.add_node("generate_answer", generate_answer)

# Add edges
workflow.set_entry_point("classify")
workflow.add_conditional_edges(
    "classify",
    route_after_classification,
)
workflow.add_edge("search_node", "generate_answer")
workflow.add_edge("generate_answer", END)

# Compile and run
app = workflow.compile()

result = app.invoke({
    "question": "What were Anthropic's latest model releases?",
    "messages": [],
    "search_results": [],
    "answer": "",
    "needs_search": False,
})

print(result["answer"])
```

Notice what's happening here. The `AgentState` TypedDict makes the agent's state explicit. You can inspect it at any point, serialize it, and reason about what the agent "knows." The conditional edge (`route_after_classification`) replaces the implicit routing you'd get from letting the model decide what to do next. Both the strength and the constraint of the state machine model show up here: you get predictability and debuggability at the cost of flexibility. The agent can only take paths you've defined.

> **🤔 Taste Moment:** Some teams define a single massive state object with every possible field. Others create minimal state and add fields only when needed. The right answer depends on your debugging needs — larger state objects are easier to inspect but harder to serialize and more expensive to checkpoint. Start minimal and expand when debugging tells you that you need more visibility.

**Checkpointing and resumability** are where LangGraph provides the most value over hand-rolled solutions. When you add a checkpointer (LangGraph supports SQLite, PostgreSQL, and custom backends) the framework automatically saves the agent's state after every node execution. If the process crashes mid-workflow, you can resume from the last completed node rather than starting over. For long-running agents that might make dozens of API calls, this separates a recoverable failure from a total loss of work and cost.

```python
from langgraph.checkpoint.sqlite import SqliteSaver

# Add checkpointing — state saved after every node
memory = SqliteSaver.from_conn_string(":memory:")  # use a file path in prod
app = workflow.compile(checkpointer=memory)

# Run with a thread_id for resumability
config = {"configurable": {"thread_id": "research-task-42"}}
result = app.invoke(
    {
        "question": "Summarize recent advances in reasoning models",
        "messages": [],
        "search_results": [],
        "answer": "",
        "needs_search": False,
    },
    config=config,
)

# If the process crashes, re-invoke with the same thread_id
# and it resumes from the last completed node
```

> **💸 Cost:** Checkpointing to a database adds I/O latency — typically 5-20ms per node on SQLite, more on networked databases. For fast, simple agents, this overhead may exceed the cost of just re-running from scratch on failure. Measure before you commit.

**When LangGraph is the right choice:** complex multi-step workflows with branching logic, agents that need to survive process restarts, systems where you need a visual representation of the agent's decision tree (LangGraph can render its graphs), and teams that want to standardize how agents are built across a codebase. **When it's overkill:** single-step API calls, simple linear pipelines (just use functions), one-off scripts, and prototypes where iteration speed matters more than structural rigor. If your agent is three function calls in sequence, a `for` loop is the right framework.

## LlamaIndex

**LlamaIndex** occupies a different niche from LangGraph, and understanding that difference saves you from false comparisons. LangGraph is a general-purpose agent orchestration framework. LlamaIndex is a **document-centric framework**, built around the problem of ingesting, indexing, querying, and reasoning over documents. If your primary challenge is RAG-heavy systems with complex document pipelines, LlamaIndex is purpose-built for that. If your primary challenge is agent orchestration with tools, LangGraph is a better fit. They're not really competing; they solve different problems.

LlamaIndex's architecture centers on three core abstractions. **Data connectors** (also called "readers") handle ingesting data from various sources: PDFs, databases, Notion, Slack, web pages, and dozens of others. **Indices** organize that data for retrieval: vector indices for semantic search, keyword indices for exact matching, tree indices for hierarchical summarization, and knowledge graph indices for relationship-aware retrieval. **Query engines** tie retrieval and generation together, handling the full pipeline from user question to grounded answer.

LlamaIndex shines in **multi-document reasoning**: the scenario where answering a question requires synthesizing information across multiple documents, tracking which documents contributed to the answer, and providing citations. If you built a basic RAG pipeline in Chapter 4, you know how to embed chunks, retrieve top-k results, and stuff them into a prompt. LlamaIndex extends that pattern by routing queries to different indices based on the question type, composing responses across sub-indices, and maintaining citation metadata throughout the pipeline.

```python
from llama_index.core import (
    VectorStoreIndex,
    SimpleDirectoryReader,
    Settings,
)
from llama_index.llms.anthropic import Anthropic
from llama_index.embeddings.openai import OpenAIEmbedding

# Configure LLM and embedding model
Settings.llm = Anthropic(model="claude-sonnet-4-20250514")
Settings.embed_model = OpenAIEmbedding(model="text-embedding-3-small")

# Load and index documents — LlamaIndex handles chunking
documents = SimpleDirectoryReader("./data/company_docs").load_data()
index = VectorStoreIndex.from_documents(documents)

# Query with citation tracking
query_engine = index.as_query_engine(
    response_mode="tree_summarize",  # synthesize across chunks
    similarity_top_k=5,
)

response = query_engine.query(
    "What is our company's policy on remote work exceptions?"
)

print(response.response)

# Access source nodes for citations
for node in response.source_nodes:
    print(f"Source: {node.node.metadata.get('file_name', 'unknown')}")
    print(f"Score: {node.score:.3f}")
    print(f"Text: {node.node.text[:200]}...")
    print()
```

**When to choose LlamaIndex over custom retrieval:** when you need to ingest documents from many source types and don't want to write a connector for each one; when you need citation tracking that follows metadata through the entire pipeline; when you're building multi-index systems where different document collections need different retrieval strategies; and when the document pipeline complexity exceeds what you want to maintain by hand. For a single-source, single-index RAG system, your Chapter 4 implementation is probably simpler and easier to debug.

> **🤔 Taste Moment:** LlamaIndex and LangChain/LangGraph can be used together: LlamaIndex as the retrieval layer, LangGraph as the orchestration layer. Whether this is a good idea depends on your tolerance for dependency complexity. Two frameworks means two sets of breaking changes to track, two mental models to maintain, and two debugging surfaces. Sometimes the right answer is to use LlamaIndex's retrieval with your own orchestration, or LangGraph's orchestration with your own retrieval.

## Observability: The Non-Negotiable

Everything you've built so far (agents, RAG pipelines, tool-calling systems) shares a common failure mode: when something goes wrong, you don't know where or why. The model returned a bad answer. Was it the retrieval step that pulled irrelevant documents? The prompt that didn't constrain the output well enough? A tool that returned unexpected data? The model hallucinating despite good context? Without **observability** — structured, comprehensive logging of every step in your AI pipeline — you're guessing. In production, guessing is not a strategy.

Observability isn't optional or a nice-to-have you add later. It's infrastructure you build into your system from the start, because retrofitting it is painful and the first production incident without it will cost you more time than setting it up would have. Every serious AI team learns this lesson; the only variable is whether they learn it before or after their first outage.

### What to Log

Before choosing tools, understand what you're logging. Every AI system in production should capture: **inputs** (the full prompt or message history sent to the model), **outputs** (the complete response, including any tool calls), **every tool call** (function name, arguments, return value, duration), **latency per step** (how long each node, retrieval, or model call took), **token counts** (input tokens, output tokens, by step), and **cost per run** (calculated from token counts and model pricing). This serves debugging, cost management, performance optimization, and detecting when model updates change your system's behavior.

**Detecting model update drift** deserves special attention. Model providers update their models, sometimes with notice and sometimes without. A model update can change your system's behavior in subtle ways: slightly different tool call formatting, shifted probability distributions for edge cases, changed handling of ambiguous instructions. Without observability that tracks output distributions over time, you won't notice until users complain. With it, you can detect drift within hours and respond before it becomes an incident.

### LangSmith

**LangSmith** is the native observability platform for LangChain and LangGraph. If you're already in the LangChain ecosystem, LangSmith is the path of least resistance. It integrates with a single environment variable and automatically captures traces for every chain, agent, and tool call. Every step in your LangGraph state machine gets logged with inputs, outputs, latency, and token counts. You can inspect individual runs, compare runs side by side, and set up automated evaluation on logged traces.

The primary limitation is ecosystem lock-in. LangSmith works best with LangChain and LangGraph. If you're using custom orchestration, the integration is possible but less seamless. Consider whether you want your observability platform tied to your orchestration framework. If you switch frameworks, do you also want to switch observability?

### Weights & Biases (Weave)

**Weights & Biases** extended their experiment tracking platform into LLM observability with **Weave**. The strength is prompt variant comparison: running the same inputs through different prompt versions and comparing outputs systematically. If your primary optimization loop involves iterating on prompts and measuring the impact, W&B Weave provides tooling specifically for that workflow. It's also framework-agnostic, so you can use it regardless of whether you're using LangGraph, LlamaIndex, or raw API calls.

### Arize Phoenix and Honeycomb

**Arize Phoenix** is an open-source LLM observability platform that works with any stack. It provides trace visualization, embedding drift detection, and retrieval evaluation. The retrieval evaluation piece is particularly useful for RAG systems where you need to measure whether your retrieval step is actually pulling relevant documents. **Honeycomb** approaches LLM observability from the distributed systems tradition, treating LLM calls as spans in a distributed trace. If your team already uses Honeycomb for backend observability, extending it to cover AI components means one fewer tool to maintain.

### Structured Traces in Practice

The difference between "something broke" and "step 4 failed because the tool returned X" is **structured tracing**. A practical implementation that works with any framework or no framework at all:

```python
import time
import json
import uuid
import logging
from dataclasses import dataclass, field, asdict
from typing import Any
from contextlib import contextmanager

logger = logging.getLogger("ai_traces")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter("%(message)s"))
logger.addHandler(handler)


@dataclass
class Span:
    """A single step in an AI pipeline."""
    span_id: str
    trace_id: str
    name: str
    start_time: float
    end_time: float | None = None
    input_data: dict = field(default_factory=dict)
    output_data: dict = field(default_factory=dict)
    metadata: dict = field(default_factory=dict)
    error: str | None = None
    token_count: dict = field(default_factory=dict)

    @property
    def duration_ms(self) -> float | None:
        if self.end_time is None:
            return None
        return (self.end_time - self.start_time) * 1000


class Tracer:
    """Lightweight structured tracer for AI pipelines."""

    def __init__(self, trace_id: str | None = None):
        self.trace_id = trace_id or str(uuid.uuid4())
        self.spans: list[Span] = []

    @contextmanager
    def span(self, name: str, input_data: dict | None = None):
        """Context manager that records a span."""
        s = Span(
            span_id=str(uuid.uuid4()),
            trace_id=self.trace_id,
            name=name,
            start_time=time.time(),
            input_data=input_data or {},
        )
        try:
            yield s
            s.end_time = time.time()
        except Exception as e:
            s.end_time = time.time()
            s.error = str(e)
            raise
        finally:
            self.spans.append(s)
            logger.info(json.dumps(asdict(s), default=str))

    def summary(self) -> dict:
        """Return a summary of all spans in this trace."""
        total_tokens = {"input": 0, "output": 0}
        for s in self.spans:
            total_tokens["input"] += s.token_count.get("input", 0)
            total_tokens["output"] += s.token_count.get("output", 0)
        return {
            "trace_id": self.trace_id,
            "total_spans": len(self.spans),
            "total_duration_ms": sum(
                s.duration_ms for s in self.spans if s.duration_ms
            ),
            "total_tokens": total_tokens,
            "errors": [
                {"span": s.name, "error": s.error}
                for s in self.spans
                if s.error
            ],
        }


# --- Usage with any AI pipeline ---

import anthropic

client = anthropic.Anthropic()


def traced_research_pipeline(question: str) -> str:
    tracer = Tracer()

    # Step 1: Classify the question
    with tracer.span("classify", {"question": question}) as s:
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=10,
            messages=[
                {
                    "role": "user",
                    "content": (
                        f"Does this question require search? "
                        f"Answer 'yes' or 'no': {question}"
                    ),
                }
            ],
        )
        needs_search = "yes" in response.content[0].text.lower()
        s.output_data = {"needs_search": needs_search}
        s.token_count = {
            "input": response.usage.input_tokens,
            "output": response.usage.output_tokens,
        }

    # Step 2: Search (conditional)
    search_context = ""
    if needs_search:
        with tracer.span("search", {"query": question}) as s:
            # Your search implementation here
            search_context = "Retrieved: [search results would go here]"
            s.output_data = {"result_count": 1, "context": search_context}

    # Step 3: Generate answer
    with tracer.span("generate", {"question": question}) as s:
        prompt = question
        if search_context:
            prompt = f"Context: {search_context}\n\nQuestion: {question}"
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}],
        )
        answer = response.content[0].text
        s.output_data = {"answer_length": len(answer)}
        s.token_count = {
            "input": response.usage.input_tokens,
            "output": response.usage.output_tokens,
        }

    # Log trace summary
    summary = tracer.summary()
    logger.info(f"Trace summary: {json.dumps(summary, indent=2)}")

    return answer


# Run it
answer = traced_research_pipeline(
    "What is the current state of reasoning models?"
)
```

This tracer is deliberately simple, about 60 lines of core code. It captures everything you need: what happened, what went in, what came out, how long it took, how many tokens it used, and whether it failed. You can send these structured logs to any backend: a file, a database, Datadog, Honeycomb, or a custom dashboard. The point is the discipline of structured tracing, not the specific implementation. Every step gets a span. Every span has inputs, outputs, and metadata. When something breaks, you look at the trace and immediately see which step failed and why.

> **⚡ Production Tip:** Set up alerting on trace summaries from day one. Alert on: total cost per trace exceeding a threshold, any span with an error, total latency exceeding your SLA, and token counts that spike unexpectedly (which often indicates prompt injection or runaway context).

> **🔒 Security:** Trace logs contain your prompts, model outputs, and tool call data. This may include user PII, proprietary business logic, or sensitive data from your tools. Treat trace logs with the same security posture as your database — access controls, encryption at rest, retention policies, and redaction of sensitive fields before shipping to third-party observability platforms.

## Reality Check

> Framework knowledge is perishable. The specific API you learn today — the exact method signatures, the configuration patterns, the import paths — will change. LangChain went through multiple breaking API overhauls between 2023 and 2025. LlamaIndex reorganized its package structure. New frameworks appeared, gained traction, and sometimes faded. This is normal for a fast-moving ecosystem, and it's not going to slow down.
>
> The developers who survived these transitions without losing weeks of productivity were the ones who understood the concepts underneath the framework syntax. They knew what a state machine was before LangGraph, so when the API changed, they could map the new syntax onto the same mental model. They understood retrieval pipelines before LlamaIndex, so when the abstraction shifted, they adapted in hours instead of days.
>
> Build your mental model around **underlying concepts** — tool use, state management, retrieval, evaluation, observability — not framework syntax. Use frameworks to move faster. Understand what they're doing underneath to survive when they change. The primitives are stable: the messages API, tool calling, embeddings, vector search, structured output. Frameworks are convenience layers over these primitives. Convenience layers change. Primitives don't.
>
> This doesn't mean you should avoid frameworks. It means you should adopt them with your eyes open — knowing what they add, what they hide, and what you'll do when they break or change. The best framework users are the ones who could build the same system without the framework. They choose the framework because it saves time, not because they can't imagine an alternative.

## Practical Exercise

Re-implement the agent you built in Chapter 6 using LangGraph. This means taking your hand-rolled tool-calling agent — the one where you managed the message loop, parsed tool calls, executed functions, and fed results back — and rebuilding it as a LangGraph StateGraph with explicit nodes, edges, and conditional routing.

The implementation itself is not the deliverable. The comparison is. After you've built both versions, write a document (one to two pages) that answers these questions:

**What did the framework add?** Be specific. Did checkpointing save you from re-running failed workflows? Did the state machine model make your routing logic clearer? Did the typed state object catch bugs that your hand-rolled version missed? Quantify where you can — lines of code, number of edge cases handled, time to implement.

**What did the framework hide?** Where did you lose visibility into what was happening? Did you find yourself debugging through framework internals? Were there moments where the framework's abstraction didn't match your mental model of what should happen? Did the framework's error messages help or hinder?

**What broke that didn't break before?** Framework-specific failure modes — dependency version conflicts, unexpected default behaviors, implicit state transformations. Document every friction point, even small ones.

**What would you change?** Given what you now know, would you use LangGraph for this specific agent? Would you use it for a more complex version of this agent? Where's the complexity threshold where the framework starts paying for itself?

Estimated time: approximately five hours — about two for the reimplementation, three for the comparison and writeup.

## Checkpoint

After completing this chapter and the exercise, you should be able to confirm the following:

I can explain what LangGraph's state machine model adds over raw tool calling (explicit state management, conditional routing, checkpointing, and resumability) and I can articulate when those additions justify the framework dependency and when they don't.

I can set up structured tracing for an AI system, capturing inputs, outputs, tool calls, latency, token counts, and errors at every step, and I can use that trace data to diagnose failures.

I understand why observability is non-negotiable for production AI systems: without it, you cannot debug failures, detect model drift, manage costs, or meet reliability SLAs.

I can evaluate whether a framework is worth the dependency for a given project by weighing the value it adds (state management, checkpointing, standardization) against its costs (abstraction opacity, API churn, cognitive lock-in, dependency complexity), and I can make that decision based on the specific requirements of the project rather than defaulting to whatever is popular.

---

**Key Sources:**

- LangGraph Documentation: [https://langchain-ai.github.io/langgraph/](https://langchain-ai.github.io/langgraph/)
- LlamaIndex Documentation: [https://docs.llamaindex.ai](https://docs.llamaindex.ai)
- LangSmith: [https://smith.langchain.com](https://smith.langchain.com)
