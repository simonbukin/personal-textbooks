# Chapter 13: Coding Agents & AI Engineering Workflows

## Why This Matters

Coding agents are the fastest-growing category of AI application, not because they're the most technically sophisticated (agentic systems in other domains are arguably more complex), but because their users are the same people who build them. Software engineers adopt tools that make them faster, iterate on those tools relentlessly, and share what works. The result is an acceleration loop that reshaped professional software development between 2024 and 2026 more than any tooling change since the IDE.

You're probably already using one of these tools. The question is whether you're using it well and whether you understand how it works beneath the interface. The gap between "I use Cursor" and "I understand how Cursor's context engine selects what to put in the prompt" is the gap between a consumer and a practitioner. Practitioners get far more value because they can work with the tool's architecture rather than against it. They know when to break a task into smaller pieces, when to provide explicit context, and when to just let the agent run.

This chapter is about moving from consumer to practitioner, and then to builder. By the end, you'll understand the shared architecture beneath all coding agents, the discipline of context engineering that makes them effective, and how to build custom tooling that extends them for your specific workflows.

## The Coding Agent Landscape (March 2026)

The landscape has consolidated around a handful of serious tools, each with a distinct philosophy about how AI integrates into the development workflow.

**Claude Code** is Anthropic's CLI-native coding agent. It runs in your terminal, uses your existing shell tools, and operates agentically: it plans, executes multi-step tasks, and self-corrects. It treats the file system, terminal, and development tools as first-class capabilities rather than afterthoughts. Its extension model is built on MCP (Model Context Protocol), which means you can give it access to databases, APIs, deployment systems, and anything else you can wrap in an MCP server. The design philosophy is "agentic by default": you give it a task, and it figures out how to accomplish it using whatever tools are available.

**Cursor** is the AI-native code editor, a fork of VS Code with AI woven into every interaction. Its strength is deep editor integration: inline completion (Tab), chat with codebase context (Cmd+K), and an agentic composer mode that can make multi-file changes. Cursor's context engine is its key differentiator — it indexes your entire codebase and automatically retrieves relevant files, symbols, and documentation to include in prompts. The philosophy is "AI as pair programmer in your editor."

**Windsurf** (by Codeium) takes a similar approach to Cursor but emphasizes "flows," multi-step actions where the AI plans and executes across files while showing you what it's doing. Its autocomplete model is purpose-built (not just an API wrapper), which gives it lower latency on completions.

**GitHub Copilot** was the first mainstream coding AI and remains the most widely deployed. It's evolved from pure inline completion to include chat, workspace agents, and multi-file editing. Its advantage is GitHub integration: pull request reviews, issue understanding, and repository-level context. Its disadvantage is that it's often a step behind the purpose-built tools in capability and UX.

**Aider** is the open-source CLI coding agent. It supports multiple model backends and emphasizes transparency: you can see exactly what prompts are being sent and what context is included. It's the tool of choice for developers who want control over the AI interaction rather than a polished UX.

**Cline** (formerly Claude Dev) is an open-source VS Code extension that gives you an autonomous agent inside your editor. It uses tool calls to read files, write files, run commands, and browse the web. Cline's approach is maximally agentic — it will plan and execute multi-step tasks with minimal human intervention if you let it.

The shared architecture across all of these tools is strikingly similar: they take your input (a description of what you want), augment it with relevant context (codebase files, documentation, conversation history), send it to a language model, parse the model's response into actions (file edits, terminal commands, questions), execute those actions, and iterate. Where they differ is how they select context, how they present changes, and how much autonomy they give the model.

## How Coding Agents Actually Work

Strip away the UI differences and every coding agent is fundamentally the same system: a loop that reads context, calls a model, parses tool calls, executes them, and feeds the results back to the model for the next iteration. Understanding this loop is how you move from "it sometimes works" to "I can predict when it will work and why."

**Context engineering**, what goes into the context window and why, is the most important architectural decision in any coding agent. The context window is finite (typically 128K-200K tokens for frontier models), and every token you include displaces something else. The agent must decide: which files are relevant to the current task? How much of each file should be included, the whole thing or just the function signatures? Should previous conversation turns be included, or compressed into a summary? What about project-level instructions, documentation, or test files?

Different tools answer these questions differently. Cursor uses a combination of embedding-based retrieval (find files semantically similar to the query), symbol analysis (find the definitions and usages of symbols mentioned in the query), and recency (recently edited files are more likely to be relevant). Claude Code uses explicit tool calls — the agent decides what to read by calling `Read`, `Grep`, and `Glob` tools, building up its understanding of the codebase incrementally rather than pre-loading everything. A fundamental architectural choice: pre-computed index vs. dynamic exploration. Pre-computed indexes are faster but can miss things; dynamic exploration is slower but adapts to what the task actually needs.

**Tool use patterns** in coding agents typically include: file reading (get contents of specific files), file writing (create or modify files), terminal execution (run tests, build commands, git operations), search (find files by name or content), and increasingly, LSP integration (go-to-definition, find-references, type checking). The agent doesn't "write code." It calls tools that modify files, and the model's output is parsed into tool calls. That's why coding agents can do things like run tests and fix failures. The loop is: write code, run test, read error, fix code, run test again.

**Planning and self-correction** distinguish agents from simple code completion. When you give a coding agent a complex task ("refactor this module to use the repository pattern"), it doesn't generate one big diff. It plans: identify the current structure, design the target structure, identify the files that need to change, make changes one at a time, run tests after each change, fix any issues. This planning capability is what makes agents useful for tasks beyond what inline completion can handle. Self-correction, where the agent detects that something went wrong (a test failed, a type error appeared) and fixes it without human intervention, is where agentic coding pulls well ahead of chat-based coding.

**Memory across sessions** is an evolving capability. Claude Code uses CLAUDE.md files, project-level instructions that persist across sessions and communicate conventions, architecture decisions, and project-specific rules. Cursor uses `.cursorrules` files for similar purposes. These are forms of persistent context that tell the agent how to behave in your specific project, and writing good project-level instructions is one of the highest-leverage things you can do to improve agent performance.

## Context Engineering as a Discipline

**Context engineering**, the systematic design of what goes into a model's context window, emerged as a named discipline around 2025. Andrej Karpathy and others crystallized the idea when they recognized that the shift from prompt engineering to context engineering reflected a real change in how AI systems were being built. The difference is scope: prompt engineering optimizes the text you write; context engineering optimizes the entire information environment the model operates in, including prompts, retrieved documents, tool results, conversation history, project configuration, and memory.

The context window is a scarce resource, and context engineering is the discipline of allocating it effectively. Every token you include has an opportunity cost; it displaces something else that might have been more useful. Including an entire 2,000-line file when the model only needs a 30-line function wastes context on irrelevant code and can actively harm performance (recall the "lost in the middle" problem from Chapter 2). Including too little leaves the model guessing about types, interfaces, and conventions it needs to know.

The components of a well-engineered context, in a coding agent specifically, include:

**System-level instructions** tell the model how to behave — what tools are available, what conventions to follow, what output format to use. In Claude Code, this includes the system prompt that defines the agent's capabilities and behavioral rules. This is the most stable component — it changes only when the tool itself is updated.

**Project-level context** communicates project-specific conventions, architecture, and rules. CLAUDE.md files serve this purpose for Claude Code; `.cursorrules` for Cursor. A good project context file tells the agent things like: "this project uses TypeScript strict mode," "API routes follow the pattern /api/v2/{resource}/{id}," "tests go in __tests__ directories next to the source files," and "never modify files in the generated/ directory." These instructions prevent entire categories of errors and cut the number of iterations needed for each task.

**Retrieved content** is the code, documentation, and data the agent retrieves dynamically based on the current task. Most context engineering effort goes here: designing retrieval strategies that surface the right files, the right functions, and the right documentation for the task at hand. The quality of retrieval directly determines the quality of the agent's output.

**Tool results** are the outputs of tools the agent has already called in the current session — file contents it's read, terminal output from commands it's run, search results it's received. These accumulate as the session progresses and form the agent's "working memory" for the current task.

**Conversation history** provides continuity across turns in a multi-turn interaction. As conversations grow long, context management becomes critical — older turns may need to be summarized or dropped to make room for more relevant recent context.

In practice, improving your AI-assisted development workflow is less about crafting better prompts and more about designing better information environments. Write good CLAUDE.md files. Structure your project so that files are self-contained and well-named (the agent finds relevant files by searching, and clear naming helps). Keep functions focused and files reasonably sized. A 3,000-line file is as hard for an AI to navigate as it is for a human. Maintain good documentation, especially for interfaces and conventions that aren't obvious from the code itself.

```markdown
# Example CLAUDE.md for a production project

## Project Overview
This is a FastAPI backend for a document processing pipeline.
Python 3.12, Poetry for dependency management.

## Architecture
- `src/api/` — FastAPI route handlers. One file per resource.
- `src/services/` — Business logic. No direct DB access here.
- `src/repositories/` — Database access layer. SQLAlchemy models and queries.
- `src/models/` — Pydantic models for request/response validation.
- `src/workers/` — Celery tasks for async processing.

## Conventions
- All API routes return Pydantic models, never raw dicts.
- Database queries go through repository classes, never called directly
  from route handlers or services.
- Tests mirror src structure: `tests/api/`, `tests/services/`, etc.
- Use `pytest` with `pytest-asyncio` for async tests.
- Environment variables are loaded via `src/config.py` — never use
  `os.environ` directly.

## Common Commands
- `poetry run pytest` — run all tests
- `poetry run pytest -x -k "test_name"` — run specific test, stop on failure
- `poetry run uvicorn src.main:app --reload` — start dev server
- `poetry run alembic upgrade head` — apply migrations

## Things to Watch Out For
- The `documents` table has a composite unique constraint on
  (org_id, document_hash). Violations return 409, not 500.
- Celery tasks must be idempotent — they may be retried.
- Never import from `src.workers` in `src.api` — use message queue only.
```

## Effective AI-Assisted Development Workflows

Not every task benefits from the same level of AI assistance. Knowing when to use inline completion vs. chat vs. full agentic mode is a skill that compounds over time. The developers who are most productive with AI tools are the ones who pattern-match each task to the right interaction mode.

**Inline completion** (Tab autocomplete) is best for: boilerplate code, patterns you've already established in the file, filling in function bodies when the signature and docstring are clear, and repetitive edits across similar code blocks. It's the lowest-friction mode; you barely think about it, and it fills in what you were going to type anyway. Good completions depend on clear context within the file: good function names, type annotations, and comments that describe intent.

**Chat mode** is best for: understanding existing code ("explain what this function does"), generating implementations from specifications ("write a function that takes X and returns Y with these constraints"), exploring approaches ("what are three ways to implement rate limiting here?"), and debugging ("this test is failing with this error — what's wrong?"). Chat mode gives you a conversation where you can iterate, refine, and ask follow-up questions. Effective chat depends on specificity. "Write a function" produces worse results than "write a function called `validate_invoice` that takes an `Invoice` Pydantic model and returns a `ValidationResult` with a list of errors."

**Agentic mode** is best for: multi-file refactoring, implementing features that span several files, running tests and fixing failures iteratively, and tasks where the agent needs to explore the codebase to understand context before making changes. Agentic mode is the highest-leverage but also the highest-risk; the agent might make changes you don't expect or go down a wrong path. Effective agentic use requires clear specifications and good checkpointing (commit before letting the agent run so you can easily revert).

**Prompt design for code generation** follows a principle: specification outperforms description. "Make a user authentication system" is a description; it's ambiguous about what you want. A specification looks like this:

```
Build a JWT authentication system with:
- POST /auth/register — accepts {email, password}, returns {user_id, token}
- POST /auth/login — accepts {email, password}, returns {token, refresh_token}
- POST /auth/refresh — accepts {refresh_token}, returns {token}
- Middleware that validates JWT on protected routes
- Passwords hashed with bcrypt, minimum 12 characters
- Tokens expire in 1 hour, refresh tokens in 7 days
- Store users in PostgreSQL via SQLAlchemy
- Full test coverage with pytest
```

The specification leaves less room for interpretation and produces more predictable results. It's also easier to evaluate: you can check each requirement against the output.

**Reviewing AI-generated code** is becoming a primary engineering skill. When reviewing AI output, focus on: correctness (does it actually do what was asked?), edge cases (what happens with empty inputs, null values, boundary conditions?), security (injection vulnerabilities, improper auth checks, secrets in code), performance (O(n²) where O(n) would work, unnecessary database queries), and maintainability (will a human reading this code in six months understand it?). AI-generated code tends to be syntactically correct and functionally plausible but can miss subtle issues in all these categories.

**Decomposing work for AI** is the meta-skill that makes everything else more effective. Large, vague tasks produce large, vague outputs. Break work into pieces where each piece has a clear specification and a verifiable outcome. Instead of "build the user management module," try: "create the User SQLAlchemy model with these fields," then "write the UserRepository with CRUD operations," then "write the API routes that use the repository," then "write tests for the API routes." Each piece is small enough for the agent to handle well and concrete enough for you to verify.

## Building Your Own Coding Tools

The most productive AI engineering teams build custom tooling that extends off-the-shelf tools for their specific workflows. MCP (Model Context Protocol) makes this practical by providing a standard way to give coding agents access to new capabilities.

A custom MCP server is just a program that exposes tools and resources through the MCP protocol. The server declares what tools it offers (with descriptions and parameter schemas), and the coding agent calls those tools when they're relevant to the current task. You can build MCP servers for: querying your company's internal APIs, searching your documentation system, interacting with your deployment pipeline, looking up customer data (with appropriate access controls), running domain-specific analysis tools, or anything else that would be useful to have in the agent's toolkit.

```python
"""
A minimal MCP server that provides access to a team's
internal tools — Jira ticket lookup and deployment status.
"""
from mcp.server.fastmcp import FastMCP
import httpx

mcp = FastMCP("team-tools")

JIRA_BASE = "https://your-org.atlassian.net/rest/api/3"
JIRA_TOKEN = "your-api-token"  # In practice, load from env/secrets

@mcp.tool()
async def lookup_jira_ticket(ticket_id: str) -> str:
    """Look up a Jira ticket by ID (e.g., PROJ-1234).
    Returns the ticket's summary, status, description, and assignee."""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{JIRA_BASE}/issue/{ticket_id}",
            headers={"Authorization": f"Bearer {JIRA_TOKEN}"},
        )
        if response.status_code != 200:
            return f"Error: Could not fetch ticket {ticket_id}"

        data = response.json()
        fields = data["fields"]
        return (
            f"Ticket: {ticket_id}\n"
            f"Summary: {fields.get('summary', 'N/A')}\n"
            f"Status: {fields.get('status', {}).get('name', 'N/A')}\n"
            f"Assignee: {fields.get('assignee', {}).get('displayName', 'Unassigned')}\n"
            f"Description: {fields.get('description', 'No description')}\n"
        )

@mcp.tool()
async def check_deployment_status(service_name: str, environment: str = "production") -> str:
    """Check the current deployment status of a service.
    Returns the deployed version, last deploy time, and health status."""
    # Replace with your actual deployment API
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"https://deploy.internal/api/v1/services/{service_name}/environments/{environment}"
        )
        if response.status_code != 200:
            return f"Error: Could not fetch status for {service_name} in {environment}"

        data = response.json()
        return (
            f"Service: {service_name}\n"
            f"Environment: {environment}\n"
            f"Version: {data.get('version', 'unknown')}\n"
            f"Last deployed: {data.get('deployed_at', 'unknown')}\n"
            f"Health: {data.get('health_status', 'unknown')}\n"
            f"Instances: {data.get('instance_count', 'unknown')}\n"
        )

@mcp.tool()
async def search_internal_docs(query: str, max_results: int = 5) -> str:
    """Search the team's internal documentation (Confluence, Notion, etc.).
    Returns matching document titles and snippets."""
    # Replace with your actual docs search API
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://docs.internal/api/search",
            params={"q": query, "limit": max_results},
        )
        if response.status_code != 200:
            return f"Error: Search failed for '{query}'"

        results = response.json().get("results", [])
        if not results:
            return f"No results found for '{query}'"

        output = []
        for r in results:
            output.append(
                f"- [{r['title']}]({r['url']})\n  {r.get('snippet', '')}"
            )
        return "\n".join(output)

if __name__ == "__main__":
    mcp.run()
```

To use this with Claude Code, add it to your MCP configuration:

```json
{
  "mcpServers": {
    "team-tools": {
      "command": "python",
      "args": ["path/to/team_tools_server.py"],
      "env": {
        "JIRA_TOKEN": "your-token"
      }
    }
  }
}
```

### AI-Assisted Code Review and Development Pipelines

**Automated PR review** is the highest-value, lowest-risk AI application for most engineering teams. The pattern is straightforward: build a pipeline that triggers on every pull request, extracts the diff, sends it to a model alongside your team's code review checklist, and posts findings as PR comments. The critical word there is *specific*. "Check for unparameterized SQL queries" is actionable; it tells the model exactly what to look for and gives it a concrete pass/fail criterion. "Check for bugs" is useless; it's so vague that the model will either hallucinate problems or produce generic advice nobody reads. Teams that invest the time to encode their actual review standards (the things that show up in every retrospective, the patterns that cause production incidents) get a review system that catches issues generic linters miss entirely.

A practical PR review pipeline looks like this:

```typescript
// src/tools/pr-reviewer.ts
async function reviewPullRequest(diff: string, checklist: string[]): Promise<string> {
  const client = new Anthropic();

  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 4096,
    system: `You are a code reviewer. Review this diff against the team's checklist.
For each checklist item, state PASS or ISSUE with a brief explanation.
Only flag real issues — do not invent problems. If the diff is clean, say so.`,
    messages: [{
      role: "user",
      content: `## Review Checklist\n${checklist.map(c => `- ${c}`).join("\n")}\n\n## Diff\n\`\`\`\n${diff}\n\`\`\``
    }],
  });

  return response.content[0].type === "text" ? response.content[0].text : "";
}

// Example checklist (make this specific to YOUR team)
const teamChecklist = [
  "SQL queries use parameterized inputs (no string concatenation)",
  "Error responses don't leak internal implementation details",
  "New API endpoints have input validation",
  "Async operations have timeout handling",
  "New dependencies are from trusted sources with active maintenance",
];
```

Notice how the checklist items are concrete and falsifiable. Each one corresponds to a real class of issue your team has dealt with before. You're not asking the model to be a general-purpose code reviewer — you're giving it a focused inspection rubric that reflects your team's hard-won experience.

**Security scanning with LLMs** complements traditional SAST tools in ways that matter. Traditional static analysis checks for known vulnerability patterns — it's pattern matching, and it's good at what it does. LLMs, however, can identify novel security issues by understanding code *semantics*. They can detect when user input flows through a transformation that looks safe but isn't, spot race conditions in authentication logic, and identify information leakage through overly detailed error messages. You shouldn't replace your existing security scanning; those tools have decades of battle-tested rules. But an LLM-based security pass catches a different class of issue, the kind that requires understanding what the code *means* rather than what it *looks like*.

**Automated documentation generation** solves the oldest problem in software engineering: documentation that's perpetually out of date. The approach that actually works is making documentation generation part of your CI pipeline so it stays in sync with code automatically. The model reads the diff from each merged PR and either generates new API documentation and function docstrings or flags existing docs that may need updating based on the changes. The point isn't generating documentation from scratch. It's maintaining a living relationship between your code and its documentation, where every code change triggers a documentation check.

**Code review as a skill multiplier** ties all of this together. When AI writes first drafts of code, the ability to *review* code becomes the bottleneck, and AI-assisted review creates a force multiplier on both sides of that equation. The AI catches mechanical issues (naming convention violations, missing error handling patterns, test coverage gaps, inconsistent API signatures) while human reviewers focus their attention on architecture, design decisions, and business logic correctness. You're not automating review away. You're restructuring it so that humans spend their review time on the things only humans can evaluate well.

> **Taste Moment:** The best AI code review pipelines are opinionated. A generic "review this code" prompt produces generic feedback nobody reads. A checklist that encodes your team's specific standards (the things that show up in every retrospective, the patterns that cause incidents) produces actionable, team-specific feedback.

## The Evolving Role of the Engineer

When AI writes first drafts of code, the engineer's role shifts. This is already happening. The shift doesn't diminish the engineer's importance; it changes what matters most.

**Code review becomes a primary skill.** When AI generates the initial implementation, evaluating that implementation for correctness, security, performance, and maintainability becomes the bottleneck. Engineers who are excellent code reviewers become more valuable, not less. The skill goes beyond "can you spot bugs" to "can you evaluate whether this architecture will scale, whether these abstractions are right, whether this code will be maintainable by the team?"

**System design remains human territory.** AI can implement features; it can't (yet) make good high-level architectural decisions about system boundaries, data flow, failure modes, and operational concerns. The decisions that matter most (should this be a microservice or a module? should we use event-driven architecture or request-response? how do we handle this failure mode?) require understanding the organizational context, the team's capabilities, the business constraints, and the operational environment in ways that current AI can't.

**"Taste" is the hardest thing to automate.** Knowing what's good (what's simple without being simplistic, what's flexible without being over-engineered, what's fast enough without being prematurely optimized) is a form of judgment that comes from experience. AI can generate ten solutions; the engineer's value is knowing which one to pick and why. This taste extends beyond code to product decisions, API design, error messages, and documentation. It's the skill that distinguishes senior engineers from junior ones, and it's the skill that AI amplifies rather than replaces.

Engineers who thrive in an AI-augmented world share a pattern: they have deep fundamentals (data structures, algorithms, systems thinking, security), they're excellent communicators (specifications, code reviews, documentation), and they're willing to learn how these tools work rather than treating them as magic. AI doesn't replace expertise. It makes expertise more leveraged.

> ## Reality Check
>
> Coding agents are transformative. This isn't hype. Developers who use them effectively are measurably more productive on most tasks. But the developers who get the most value are the ones who understand software deeply. An agent can write a function, but it can't tell you whether that function should exist. It can implement a design pattern, but it can't tell you whether the design pattern is appropriate for your context. AI amplifies expertise. If you have deep knowledge of software engineering, AI makes you faster and more effective. If you don't, AI gives you the ability to produce more code of uncertain quality, which is worse than producing less code of known quality.

## Case Study: Claude Code's Architecture

Claude Code illustrates the architectural principles of coding agents through concrete design choices that differ meaningfully from editor-based tools like Cursor.

**Agentic tool use** is Claude Code's core architectural pattern. Rather than pre-indexing a codebase and selecting context heuristically, Claude Code gives the model tools (`Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`) and lets the model decide what to read, when. This means the model builds its understanding of the codebase dynamically, reading files as it determines they're relevant. The advantage is adaptability: the model explores exactly what the current task requires. The disadvantage is latency: each tool call is a round trip, and a complex task might require dozens of file reads before the model has enough context to act.

**MCP extension** is how Claude Code gains capabilities beyond its built-in tools. Any MCP server (connecting to a database, a deployment system, a documentation platform, or a custom internal tool) extends Claude Code's capability surface without modifying Claude Code itself. This is architecturally significant: it means the tool ecosystem is open and composable. Your team can build MCP servers for your specific infrastructure, and Claude Code can use them alongside its built-in tools in the same agentic loop.

**CLAUDE.md convention** is Claude Code's approach to persistent project context. Rather than a structured configuration format, it uses a markdown file that the model reads as natural language instructions. That's both a strength (anyone can write it, no schema to learn) and a weakness (natural language is ambiguous, and the model may interpret instructions differently than you intended). The best CLAUDE.md files are specific, declarative, and tested. You verify that the agent actually follows the instructions by trying tasks that would violate them.

The contrast with Cursor is instructive. Cursor pre-indexes your codebase at the editor level, building a searchable representation that it uses to select relevant context before sending anything to the model. This is faster for individual interactions (the context is already prepared) but less adaptable to unusual tasks. Cursor's composer mode approaches agentic behavior but is still more constrained than Claude Code's fully agentic loop. Neither approach is strictly better; they optimize for different workflows. Cursor excels at rapid, editor-integrated interactions during active coding. Claude Code excels at larger, self-contained tasks where the agent needs to explore, plan, and execute independently.

## Practical Exercise

**Build a custom MCP server for your team's specific tooling.**

**Specification:**

1. Identify 3-5 tools that would be useful for a coding agent working in your codebase. These should be things the agent can't currently do — query your internal API, look up documentation in your wiki, check CI/CD status, search your error tracking system, etc.

2. Implement an MCP server that exposes these tools. Use the `mcp` Python package (or TypeScript equivalent). Each tool should have:
   - A clear description that helps the model understand when to use it
   - Well-defined parameters with types and descriptions
   - Error handling that returns useful messages, not stack traces
   - Appropriate access controls (don't expose sensitive operations without authentication)

3. Configure Claude Code (or another MCP-compatible agent) to use your server.

4. Test the server by giving the agent tasks that require your custom tools. Document:
   - What worked well — which tools did the agent use appropriately?
   - What didn't — which tools were misused or ignored?
   - What you'd change — how would you redesign the tool descriptions or parameters?

**Acceptance criteria:**
- MCP server runs and exposes at least 3 tools
- Tool descriptions are specific enough that the model uses them appropriately
- Error handling produces useful error messages
- You've tested with at least 5 different tasks and documented the results
- Documentation includes at least one case where the tool was misused and your analysis of why

**Evaluation:** Does the agent use your tools correctly more than 80% of the time? If not, the tool descriptions likely need refinement — this is the context engineering lesson in practice.

**Time estimate:** ~6 hours

## Checkpoint

After completing this chapter, you should be able to say:

- I can explain how coding agents use context engineering to select relevant information for each task — and how this differs from simple prompt engineering
- I can describe the shared architecture beneath different coding agents (context selection, model call, tool parsing, execution, iteration) and where specific tools diverge
- I can design effective prompts for code generation, using specifications rather than descriptions
- I can build custom MCP tooling that extends a coding agent's capabilities for my team's specific infrastructure
- I can choose the right interaction mode (completion, chat, agentic) for different development tasks
- I can write effective project-level context files (CLAUDE.md, .cursorrules) that improve agent performance
- I understand how the engineer's role is evolving (toward review, system design, and taste) and what that means for skill development
