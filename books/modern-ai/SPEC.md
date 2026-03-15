# SPEC.md — Modern AI: From Vibe Coder to Practical SME

## What This Document Is

This is the production spec for a self-contained AI engineering textbook. It defines the book's purpose, audience, voice, structure, and rules tightly enough that any chapter can be written independently and still feel like it belongs to the same book.

---

## The Book in One Sentence

A textbook that takes a technically competent developer from "I can call an API" to "I can build, audit, and advise on production AI systems with credibility" — covering the full stack from mental models through agents, MCP, production engineering, and business strategy, with calibrated skepticism throughout.

## Audience

**Primary reader:** Simon Bukin — a frontend engineer with real shipping experience who uses AI tools daily but wants to cross the line from consumer to practitioner. Comfortable building in TypeScript, has strong design instincts, and is heading toward (or already at) a startup where AI features are table stakes.

**Generalized reader:** Any developer who uses AI tools but doesn't deeply understand what's happening under the hood. They can prompt Claude effectively and build with AI-assisted workflows, but they can't architect a RAG pipeline, evaluate a model for a specific use case, audit an agent for security issues, or advise a non-technical stakeholder on AI strategy with credibility.

**What the reader is NOT:**
- A total beginner (no need to explain what an API is, what JSON is, or how HTTP works)
- An ML researcher (no need for mathematical derivations of attention mechanisms or loss functions)
- At a FAANG-scale company (no need for training infrastructure at Google scale)
- Looking for a framework tutorial (this is not "Learn LangChain")
- Looking for hype validation (this book is deliberately skeptical where warranted)

## What This Book Replaces

The reader should NOT need to go read these separately after finishing this book. The book synthesizes, reframes, and builds on:

| Source | What We Take From It |
|--------|---------------------|
| Anthropic's prompt engineering docs | Prompt design as communication, not tricks. How to work with models effectively. |
| "Attention Is All You Need" (Vaswani et al.) | The transformer architecture — explained for practitioners, not researchers. |
| The RAG literature (Lewis et al., RAGAS) | Retrieval-augmented generation done right — chunking, embedding, hybrid search, evals. |
| Simon Willison's prompt injection writing | Security as a first-class concern. Real attack patterns, real defenses. |
| Anthropic's agent-building guides | Agent architecture patterns that actually work in production. |
| MCP documentation and ecosystem | The protocol layer — building servers, clients, and understanding the ecosystem. |
| The fine-tuning literature (QLoRA, DPO) | When to fine-tune, when not to, and how to do it practically. |
| RLHF/Constitutional AI papers | How models are shaped — for practitioners who deploy them, not researchers who train them. |

**Critical rule:** The book never says "go read X." It teaches the ideas directly, in original prose, with attribution where appropriate. Further reading is collected in an appendix for people who want to go deeper.

## Voice and Tone

### The voice is:
- **Direct and uncompromising.** No hedging, no "it depends" without saying what it depends on. Opinions are stated as opinions. Facts are stated as facts.
- **Intellectually honest.** When something is genuinely contested, say so. When the evidence is mixed, say so. Never false-certainty, never false-humility.
- **Warm but not soft.** The reader is treated as smart and capable. No condescension. No cheerleading. The tone is closer to "trusted senior engineer who respects you enough to be blunt" than "encouraging teacher" or "academic lecturer."
- **Calibrated in its skepticism.** The book pushes back on hype — but it also acknowledges when something genuinely works. The goal is accuracy, not contrarianism.
- **Specific over abstract.** Every principle is illustrated with concrete examples — real products, real companies, real code, real failure modes. No purely theoretical discussions.

### The voice is NOT:
- Academic or formal (no "the authors posit that..." or "it should be noted that...")
- Listicle-style ("10 Tips for Better Prompts!")
- Breathlessly enthusiastic about AI or any specific tool
- Preachy about safety or ethics (these matter deeply, and they are discussed, but the tone is practical, not moralizing)
- Self-deprecating or performatively humble
- Marketing copy for any vendor (including Anthropic — use their tools where they're best, criticize where warranted)

### Stylistic rules:
- Contractions are fine and encouraged ("don't," "it's," "you'll")
- Second person ("you") is the default address
- Em-dashes are preferred over parenthetical asides
- Bold is used for key terms on first definition, then dropped
- Italic is used for emphasis sparingly
- No emoji in prose. Emoji are permitted in callout labels only (same convention as the backend book)
- No bulleted lists in the main prose. Information that could be a list is written as flowing sentences. (Exception: exercises, checklists, and structured sections at the end of chapters can use structured formatting.)
- Code examples are complete enough to run. No `// ... rest of the code` for critical logic.

## Structure

The book has **four arcs** containing **fifteen chapters**, plus an introduction, a final capstone, and appendices.

### Arcs:
1. **Foundations** (Chapters 1-3): Mental models, working with models directly, the API layer. Calibration before building.
2. **Knowledge & Tools** (Chapters 4-5): RAG, retrieval, tool use, function calling, security. The building blocks of useful AI systems.
3. **Agents & Infrastructure** (Chapters 6-9): Agents, MCP, orchestration frameworks, production engineering. Building and operating real systems.
4. **Advanced & Strategic** (Chapters 10-14): Fine-tuning, data strategy, business layer, coding agents and workflows, safety and alignment. The senior-level material.

### Chapter anatomy:

Every chapter follows this structure:

```
# Chapter N: Title

## Why This Matters
A 2-4 paragraph opening that frames the problem this chapter solves.
Specifically for the practitioner, not the academic. What you'll be
able to do by the end that you can't do now.

## Core Content
The teaching. 3-6 major sections per chapter, each building on the
last. Written as prose with integrated code examples. Uses real
products, real companies, real failure modes as illustrations.

Each module covers: (1) how it works, (2) how to build it,
(3) how it breaks in production, and (4) what the hype gets wrong.

## Reality Check
A short section (1-2 paragraphs, blockquoted) that gives the honest
assessment. What most curricula skip, what most tutorials get wrong,
what you should actually be worried about. These are calibration
sections — the nuances that separate a credible practitioner from
someone who just completed a tutorial.

## Case Study
1-2 real companies or real systems examined in depth. Not puff pieces —
honest analysis of what worked, what didn't, and what you can learn
from their approach.

## Practical Exercise
One substantial exercise that requires building real things:
- A clear specification (what to build)
- Acceptance criteria (how you know it works)
- An eval component (how to measure quality, not just functionality)
- Estimated time (2-6 hours)

## Checkpoint
5-8 "I can..." or "I understand why..." statements. If the reader
can't agree with all of them, they should revisit the chapter.
```

### Cross-cutting callouts (same convention as backend book):

- **🔒 Security Callout** — Security implications of the current topic. Short, specific, actionable.
- **💸 Cost Callout** — Cost implications at scale. Real numbers where possible.
- **🤔 Taste Moment** — Judgment calls and decision frameworks. The most valuable parts of the book.
- **⚡ Production Tip** — Practical advice for shipping AI features that survive real users.

## Key Concepts That Recur Across Chapters

These ideas should be threaded throughout, not isolated to single chapters:

- **The capability/reliability gap** — Why demos work and products are hard. The 90/10 problem. This is the central tension of AI engineering.
- **Evals over vibes** — "It looks good" is not an eval. Measurement discipline is introduced in Chapter 2 and reinforced in every subsequent chapter.
- **Production instincts** — Knowing how things fail, not just how they work. Every chapter covers failure modes explicitly.
- **The "when not to use AI" reflex** — The most credibility-building thing you can say is "this doesn't need AI." The book models this judgment throughout.
- **Cost consciousness** — Unit economics at 1x, 10x, 100x. Every architectural decision has a cost dimension.

## On Code Examples

### Language & Framework Choices
- **Primary language:** TypeScript (the reader is a frontend engineer)
- **Secondary:** Python where the ecosystem is clearly better (ML tooling, some AI libraries)
- **AI SDK:** Anthropic SDK as primary, with patterns that transfer to other providers
- **Frameworks:** Show without frameworks first, then with. Understanding > syntax.

### Code Style
- All code examples must be complete enough to run
- Realistic variable names, realistic data shapes, realistic error handling
- Every code example over 20 lines has a preceding explanation and a following "why it's written this way" note
- Show the wrong way first when it illustrates a common mistake: `// ❌ Don't do this` and `// ✅ Do this instead`
- Maximum code block length: 60 lines. If longer, split with explanatory text.

### Code Block Formatting
- Triple backticks with language identifier: ```typescript, ```python, ```bash, ```json
- File paths as comments at top: `// src/lib/ai.ts`

## On Case Studies

Case studies are threaded throughout, not bolted on at the end. Key companies to reference:

| Company | What to Study |
|---------|--------------|
| **Cursor** | Multi-model routing economics, AI-native UX, $2B ARR journey, proprietary model investment |
| **Harvey** | Vertical AI in regulated industry, domain expert data flywheel, enterprise selling |
| **Perplexity** | RAG at product scale, citation/faithfulness as user trust, competing with Google |
| **Klarna / Intercom** | AI in customer service — real resolution numbers vs. deflection claims |
| **Cognition (Devin)** | Honest state of autonomous agents, demo vs. production reality |
| **Glean** | Enterprise RAG, permission-aware retrieval, organizational complexity |
| **Cohere** | Enterprise privacy, on-premises deployment, the "never public API" customer |
| **Anthropic** | Claude Code as MCP exemplar, Constitutional AI, model cards as calibration exercises |

## What This Book Does NOT Cover

- Mathematical derivations of transformer architectures or loss functions
- Training large models from scratch (pretraining)
- ML ops at FAANG scale (Kubernetes clusters for model serving, etc.)
- Specific framework tutorials (not "Learn LangChain" — LangChain is discussed but as one option among several)
- Academic research methodology
- Hardware and chip-level optimization (GPU programming, CUDA, etc.)
- Mobile/edge deployment in depth (mentioned in appendix as emerging topic)

## Production Notes

- Each chapter is a standalone markdown file: `chapter-01.md`, `chapter-02.md`, etc.
- Target length per chapter: **4,000–7,000 words**. Dense enough to be substantive, short enough to be readable.
- The introduction should be ~2,500–3,000 words.
- Each appendix should be ~1,500–2,500 words.
- Total book target: **~80,000–100,000 words**.
- Write in standard Markdown. Use `#` for chapter title, `##` for major sections, `###` for subsections. No deeper nesting.
- When referencing other chapters, use: "as we explored in Chapter 3" or "we'll return to this in Chapter 8." No hyperlinks.
- Keep paragraphs to 3-6 sentences.
- When introducing a technical term for the first time, bold it and define it in the same sentence or the next.
- All claims about specific numbers (benchmark scores, revenue figures, ecosystem sizes) must be marked as approximate and dated. The field moves fast.
- All URLs must be valid as of March 2026.
