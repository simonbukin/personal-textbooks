# SPEC.md — Irreplaceable: Design Taste in the Age of Machines

## What This Document Is

This is the production spec for a self-contained design textbook. It defines the book's purpose, audience, voice, structure, and rules tightly enough that any chapter can be written independently (e.g., by Claude Code, one chapter at a time) and still feel like it belongs to the same book.

---

## The Book in One Sentence

A textbook that synthesizes the best ideas from the design canon into original, opinionated prose — teaching an experienced frontend engineer to develop world-class design taste, with AI integrated as a tool throughout, aimed at startup contexts.

## Audience

**Primary reader:** Simon Bukin (simonbukin.com) — a frontend engineer with real shipping experience who designs but hasn't systematically trained his eye. Comfortable building anything in code. Has taste instincts but can't always articulate or defend them. Wants to cross the line from "engineer who designs" to "designer who can build."

**Generalized reader:** Any frontend/fullstack engineer at a startup who finds themselves responsible for design decisions and wants to get meaningfully better — not hobbyist-better, but "I could lead design at a Series A company or go independent" better.

**What the reader is NOT:**
- A total beginner (no need to explain what a div is, or what Figma is)
- At a FAANG-scale company (no need for design-at-scale org processes, design ops, etc.)
- Looking for academic theory divorced from practice
- Looking for tool tutorials (this is not "Learn Figma")

## What This Book Replaces

The reader should NOT need to go read these books after finishing this one. The book synthesizes, reframes, and builds on the core ideas from:

| Book | What We Take From It |
|------|---------------------|
| *The Shape of Design* — Frank Chimero | Design as intent and craft, not just problem-solving. The "why" behind making things. |
| *Thinking with Type* — Ellen Lupton | Typography anatomy, classification, hierarchy, and the mechanics of setting type. |
| *The Elements of Typographic Style* — Robert Bringhurst | Typographic refinement, optical spacing, the relationship between type and page. The deep craft. |
| *Refactoring UI* — Schoger & Wathan | Practical, engineer-friendly visual design heuristics. The "just make it look better" toolkit. |
| *Don't Make Me Think* — Steve Krug | Usability as common sense. Lightweight testing. The value of not making users work. |
| *The Design of Everyday Things* — Don Norman | Mental models, affordances, signifiers, feedback loops. How humans actually interact with designed objects. |
| *Interaction of Color* — Josef Albers | Color is relational, not absolute. Perception over theory. |
| *Grid Systems in Graphic Design* — Müller-Brockmann | Grids as compositional infrastructure. Structure as a starting point to break from. |
| *About Face* — Alan Cooper | Goal-directed design, personas as design tools (not marketing artifacts), interaction patterns. |
| *Designing Brand Identity* — Alina Wheeler | Brand as a system of associations across touchpoints. Identity design process. |
| *Expressive Design Systems* — Yesenia Perez-Cruz | Design systems as creative infrastructure, not just component libraries. Encoding opinion into tokens. |
| *Competing Against Luck* — Clayton Christensen | Jobs-to-Be-Done as a lens for understanding what users actually want (not what they say). |
| *Editorial Design* — Cath Caldwell | Visual storytelling through layout, pacing, and sequence. The magazine-design mindset. |
| *Designing Interface Animation* — Val Head | Motion as information, not decoration. Timing, easing, orchestration. |

**Critical rule:** The book never says "go read X." It teaches the ideas directly, in original prose, with attribution where appropriate ("as Bringhurst argued..." or "the principle that Krug called..."). Further reading is collected in an appendix for people who want to go deeper on specific topics.

## Voice and Tone

### The voice is:
- **Direct and uncompromising.** No hedging, no "it depends" without saying what it depends on. Opinions are stated as opinions. Facts are stated as facts.
- **Intellectually honest.** When something is genuinely subjective, say so. When the evidence is mixed, say so. Never false-certainty, never false-humility.
- **Warm but not soft.** The reader is treated as smart and capable. No condescension. No cheerleading. The tone is closer to "trusted mentor who respects you enough to be blunt" than "encouraging teacher" or "academic lecturer."
- **Specific over abstract.** Every principle is illustrated with concrete examples — real products, real typefaces, real interfaces, real decisions. No purely theoretical design discussions.
- **Conversational where appropriate, precise where necessary.** Prose should read like a really good design essay, not like a textbook from a university press. But technical terminology is used correctly and defined on first use.

### The voice is NOT:
- Academic or formal (no "the authors posit that..." or "it should be noted that...")
- Listicle-style ("10 Tips for Better Typography!")
- Breathlessly enthusiastic about AI or anything else
- Preachy about accessibility or inclusion (these matter, and they are discussed, but the tone is practical, not moralizing)
- Self-deprecating or performatively humble

### Stylistic rules:
- Contractions are fine and encouraged ("don't," "it's," "you'll")
- Second person ("you") is the default address
- Em-dashes are preferred over parenthetical asides
- Bold is used for key terms on first definition, then dropped
- Italic is used for emphasis sparingly — no more than 2-3 per page
- Chapter openings have a single-sentence epigraph-style subtitle in italics
- No emoji anywhere
- No bulleted lists in the prose. Information that could be a list is written as flowing sentences. (Exception: the projects at the end of each chapter can use structured formatting.)
- Code examples are used sparingly and only when they illustrate a *design* point (e.g., CSS that demonstrates a spacing system), not for implementation tutorials

## Structure

The book has **four parts** containing **twelve chapters**, plus front matter and appendices.

### Parts:
1. **Foundations of Seeing** (Chapters 1–3): Training the eye. Perception, type, color.
2. **The Grammar of Interfaces** (Chapters 4–6): Layout, interaction, motion. The structural skills.
3. **Designing With Intent** (Chapters 7–9): UX thinking, systems, brand. The strategic skills.
4. **Thriving in the Machine Age** (Chapters 10–12): AI workflows, startup contexts, building a public practice.

### Chapter anatomy:

Every chapter follows this structure:

```
# Chapter N: Title
*Italicized subtitle / epigraph-style line*

## Opening
A 2-4 paragraph hook that frames why this topic matters — specifically
for taste, not just for competence. Connects to the book's thesis.

## Core Content
The teaching. 3-6 major sections per chapter, each building on the last.
Written as prose, not as a reference manual. Uses concrete examples from
real products and real design work. Introduces vocabulary and principles
in context, not as glossary entries.

## Taste Interlude
A short section (1-2 pages) that goes deeper on a specific taste
distinction within the chapter's topic. These are the "connoisseur"
sections — the nuances that separate good from great. Examples:
- Typography chapter: "The difference between harmonious and alive"
- Color chapter: "Why most dark modes feel wrong"
- Motion chapter: "The 50ms that separates snappy from jarring"

## AI Integration
How AI tools interact with this chapter's topic. What AI does well here,
what it does badly, and how to use it as a training partner, generator,
or stress-tester. This is NOT a separate "AI section" tacked on — it's
woven into the chapter's narrative. But each chapter also has a focused
1-2 page section on the specific AI angle.

## Projects
2-3 substantial projects that require the reader to produce real work.
Each project has:
- A clear brief (what to make)
- Constraints (what to limit — constraints drive creativity)
- A "taste check" (specific questions to evaluate your own output)
- An AI integration angle (how to use AI in the project, and what
  to watch for when you do)

Projects escalate: first project is focused/contained, last project
is larger and integrates previous chapters.
```

## Key Concepts That Recur Across Chapters

These ideas should be threaded throughout, not isolated to single chapters:

- **"The gap"** — The difference between AI-generated output and human-refined output. This gap is the reader's professional value. Every chapter should help the reader see, name, and widen this gap.
- **Intentionality over convention** — The recurring argument that every design decision should be *chosen*, not defaulted to. AI defaults. Designers choose.
- **Contextual appropriateness** — The same visual treatment can be perfect in one context and wrong in another. Taste is knowing which.
- **The constraint/creativity relationship** — Constraints produce better design. Every project uses constraints deliberately.
- **Articulation as skill** — Being able to name and explain your decisions is as important as making them. The book models this throughout.

## On Examples and References

- **Use real products** as examples wherever possible: Linear, Notion, Stripe, Vercel, Arc, Figma, Raycast, Apple, and non-tech brands like Aesop, Acne Studios, Monocle, Bloomberg Businessweek.
- **Use real typefaces** by name: don't say "a serif font" when you mean Freight Text or Tiempos.
- **Use real designers' work and thinking** with attribution: Dieter Rams, Massimo Vignelli, Paula Scher, Mike Matas, Bethany Heck, Tobias Frere-Jones, etc.
- **Dated examples are fine** as long as they're identified as such ("In 2019, Stripe's marketing site demonstrated..."). The design world has a canon; reference it.
- **AI tool references** should be generic enough to survive 6–12 months ("AI code generation tools" or "image generation tools" rather than specific product versions), except where specificity is needed.

## On Projects

Projects are the most important part of the book. They should be:

- **Shippable.** The output should be something the reader can put on the internet or in a portfolio.
- **Constrained.** Open-ended projects ("design a website") teach nothing. Specific constraints ("redesign only the typography of an existing site, changing no other property") force the reader to engage deeply with the chapter's topic.
- **Progressive.** Later projects in each chapter integrate skills from earlier chapters.
- **AI-integrated.** Every project has a specific angle on how AI tools should (and shouldn't) be used.
- **Evaluated by taste, not by correctness.** Each project includes "taste check" questions that ask the reader to evaluate their own work against the chapter's principles — not pass/fail, but "did I make deliberate choices, and can I articulate why?"

## What This Book Does NOT Cover

To stay focused, these topics are explicitly out of scope:

- Figma tutorials or tool-specific workflows
- Design ops, design team management, design at scale
- User research methodology beyond lightweight testing
- Accessibility as a standalone topic (it's woven in as a quality consideration, but this is not an accessibility textbook)
- Native mobile design patterns (the focus is web, though principles transfer)
- Print design beyond what informs screen typography and layout
- Design history as a standalone subject (history is used to explain *why* things look the way they do, not as an end in itself)
- Backend/API design, data modeling, or engineering topics

## Production Notes for Claude Code

- Each chapter should be written as a standalone markdown file: `chapter-01.md`, `chapter-02.md`, etc.
- Target length per chapter: **4,000–7,000 words**. Dense enough to be substantive, short enough to be readable. (For reference: a typical book chapter is 5,000–8,000 words.)
- The front matter (preface) should be ~2,000 words.
- Each appendix should be ~1,000–2,000 words.
- Total book target: **~65,000–85,000 words** (roughly 250–350 pages in print).
- Write in standard Markdown. Use `#` for chapter title, `##` for major sections, `###` for subsections. No deeper nesting.
- When referencing other chapters, use the format: "as we explored in Chapter 3" or "we'll return to this in Chapter 8." Don't use hyperlinks.
- Keep paragraphs to 3–6 sentences. This is not academic writing; let the text breathe.
- When introducing a technical term for the first time, bold it and define it in the same sentence or the next.
