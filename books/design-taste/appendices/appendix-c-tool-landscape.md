# Appendix C: Tool Landscape (March 2026)

*An honest assessment of AI design tools, written to be useful for 6-12 months.*

---

This appendix surveys the AI design tool landscape as of early 2026. It's written generically enough to remain useful as specific tools evolve, but honestly enough to be practical now.

The landscape changes fast. Specific tools will improve, merge, or die. But the categories of capability and the gaps between AI and human judgment are more stable. Focus on the categories.

---

## Layout Generation Tools

**What they do:** Given a description or brief, these tools generate page layouts — component arrangements, wireframes, or full-fidelity designs.

**What they do well:**
- Produce conventional layouts quickly (hero, features, testimonials structures)
- Handle common patterns reliably (navigation, cards, forms)
- Generate responsive layouts that technically work
- Provide multiple variations for exploration

**What they do poorly:**
- Make contextually appropriate choices (they default to common, not right)
- Create distinctive compositions (layouts tend toward the average)
- Handle complex information hierarchy (more than three levels gets muddy)
- Break conventions intentionally (they follow patterns, never productively violate them)

**How to use them:** For rapid exploration and scaffolding. Generate many layouts quickly, select promising directions, then refine by hand. Don't ship generated layouts directly.

---

## AI Code Generators (for design)

**What they do:** Translate visual descriptions or mockups into HTML/CSS/JS code. May work from text prompts, images, or Figma designs.

**What they do well:**
- Produce functional component code quickly
- Handle standard patterns (buttons, cards, forms)
- Work with common frameworks (React, Vue, Tailwind)
- Generate responsive code that adapts to viewports

**What they do poorly:**
- Create pixel-perfect implementations (spacing and sizing often drift)
- Maintain design system consistency (each generation is independent)
- Handle complex interaction states (hover, focus, error sequences)
- Produce maintainable code (often verbose and inconsistently structured)

**How to use them:** For scaffolding and first drafts. Generate the structure, then refine the details. Expect to adjust spacing, sizing, and interactions. Don't expect production-ready code.

---

## AI Image Generators

**What they do:** Create images from text descriptions. Used for placeholder imagery, illustrations, backgrounds.

**What they do well:**
- Generate concept imagery quickly
- Produce stylistically consistent sets (when prompted carefully)
- Handle abstract and decorative imagery
- Create placeholder content for prototypes

**What they do poorly:**
- Generate realistic humans without uncanny qualities
- Maintain brand-specific style across generations
- Produce images that feel genuinely authored
- Handle precise compositional requirements

**How to use them:** For exploration and placeholders. Useful during design development. Replace with real photography or commissioned illustration before shipping — AI imagery often has a recognizable "AI" quality that undermines credibility.

---

## AI Copy Tools

**What they do:** Generate headlines, descriptions, microcopy, error messages. May work from prompts or analyze existing content for tone.

**What they do well:**
- Produce grammatically correct copy quickly
- Handle common microcopy patterns (buttons, labels, tooltips)
- Generate variations for A/B testing
- Maintain consistent length constraints

**What they do poorly:**
- Create genuinely distinctive voice
- Write with strategic intent (benefits vs. features)
- Handle nuanced emotional register
- Produce copy that doesn't sound AI-generated (superlatives, buzzwords)

**How to use them:** For first drafts and ideation. Rewrite everything before shipping. AI copy is a starting point, not a deliverable.

---

## AI Prototyping Tools

**What they do:** Generate interactive prototypes from descriptions or mockups. May include animation, state handling, and navigation.

**What they do well:**
- Create basic clickable prototypes quickly
- Handle standard navigation patterns
- Generate common UI interactions (dropdowns, modals, toggles)
- Produce shareable demos for feedback

**What they do poorly:**
- Implement precise timing and easing (defaults only)
- Handle complex state logic
- Create choreographed multi-element animations
- Produce prototypes with refined feel

**How to use them:** For rapid concept validation. Show ideas to stakeholders quickly. But don't use generated prototypes to evaluate motion design — they default to generic timing.

---

## AI Color Tools

**What they do:** Generate color palettes from moods, references, or images. May suggest accessible combinations or dark mode variants.

**What they do well:**
- Produce harmonious palettes quickly
- Check accessibility (contrast ratios)
- Generate variations from a starting color
- Suggest dark mode translations

**What they do poorly:**
- Create palettes with emotional precision
- Handle brand-specific color meaning
- Generate distinctive palettes (most converge toward similar harmonies)
- Understand context-specific appropriateness

**How to use them:** For exploration and starting points. Generate many palettes, evaluate against your context, refine by hand. Don't expect AI to understand what colors mean for your product.

---

## AI Design Review Tools

**What they do:** Analyze designs for usability issues, accessibility problems, or consistency violations. May compare against guidelines or heuristics.

**What they do well:**
- Catch accessibility violations (contrast, missing labels)
- Identify obvious usability issues (unclear CTAs, missing feedback)
- Check consistency against defined patterns
- Flag potential problems for human review

**What they do poorly:**
- Evaluate emotional register
- Judge contextual appropriateness
- Identify subtle hierarchy issues
- Assess brand alignment

**How to use them:** As first-pass reviewers for functional issues. Trust AI for accessibility checks and obvious usability problems. Reserve judgment on feel, brand, and nuance for human review.

---

## What's Stable vs. Changing

**Stable (expect these to persist):**
- AI is good at common patterns
- AI defaults to the average of training data
- AI cannot evaluate context-specific appropriateness
- AI output needs human refinement for quality
- The gap between "competent" and "excellent" requires human taste

**Changing (expect improvements):**
- Specific tool capabilities increase
- Integration between tools improves
- Generation quality increases
- Edge cases are handled better

**The implication:** What AI can do will expand. What AI cannot do (contextual judgment, emotional precision, brand consistency) is more fundamental and changes slower. Invest in the capabilities AI lacks.

---

## Workflow Integration

The productive AI design workflow uses these tools strategically:

1. **Ideation:** Use layout and image generators to explore directions quickly
2. **Structure:** Use code generators to scaffold components
3. **Refinement:** Human work — adjusting spacing, typography, color, motion
4. **Copy:** Use copy tools for drafts, then rewrite
5. **Review:** Use review tools to catch functional issues
6. **Polish:** Human work — the details that create feel

AI accelerates the mechanical parts. Humans provide the taste that makes the output worth shipping.
