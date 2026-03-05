# Designing for Startups

*Startup design is not "worse enterprise design." It's a different discipline with different constraints and different rewards.*

---

## Opening

Everything in this book applies to startup contexts, but startup contexts have characteristics that shape how the craft is applied.

You don't have a design team. You might be the only person who thinks about design at all. Decisions need to happen in hours, not weeks. The product changes so fast that the interface you perfect this month might be deprecated next month. Half the features haven't been built yet, and the roadmap changes constantly.

This isn't a constraint to complain about. It's a context to design *for*. The best startup designers are fast, opinionated, and comfortable with imperfection. They know the difference between craft that matters and craft that doesn't — and they allocate accordingly.

This chapter is about developing that judgment: when to spend time refining, when to ship "good enough," how to communicate design decisions to non-designers, and how to build for a product that's constantly changing.

---

## The Startup Design Constraint

At a large company, design decisions go through process. Research, exploration, review, iteration, more review, polish, handoff, implementation, QA. The process takes time but produces considered results.

At a startup, you don't have time for process. You have *this week* to ship a feature. You have *this afternoon* to decide how the new page should look. You have *this conversation* to align with the founder on the direction.

This changes everything:

**Speed is a design value.** Getting something out the door that lets you learn is more valuable than perfecting something in isolation. A design that's 80% right and ships today beats a design that's 100% right and ships next quarter.

**Opinions are more valuable than options.** A designer who presents five directions and asks "which do you prefer?" is adding process. A designer who presents one direction with clear rationale and asks "should we proceed?" is accelerating.

**Scope flexibility is essential.** The ideal solution might take two weeks. The practical solution might take two days. Knowing how to find the practical solution — what to cut, what to simplify — is survival.

This doesn't mean low quality. It means *calibrated* quality — knowing where craft matters and where shipping matters.

---

## The "Good Enough" Threshold

There's a point where additional design refinement stops generating user value and starts generating designer satisfaction. At a startup, finding that point is a survival skill.

**The heuristic:** Does this design decision affect whether someone understands the product, trusts it, and can accomplish their goal?

If yes → refine it. The typography on your landing page headline affects conversion. The hierarchy of your pricing table affects purchase decisions. The clarity of your error messages affects user trust. These deserve craft time.

If no → ship it. The border-radius on your settings page cards doesn't affect understanding or trust. The precise spacing in your admin panel doesn't drive conversion. The animation on a tooltip that appears once per session doesn't matter. Ship and move on.

### High-Leverage Decisions

Some decisions have outsized impact:

**First impressions:** The landing page, the first screen after signup, the hero section. These shape whether users continue or leave. Craft matters here.

**Trust signals:** Checkout flows, error handling, anything involving money or sensitive data. Users need to trust the interface. Professionalism (good design) builds trust. Amateurishness (bad design) destroys it.

**Core loops:** The primary interaction your product is built around. If your product is a note-taking app, the note editor deserves extreme care. If it's a dashboard, the data visualization deserves care. The core loop is where users spend time. It should feel right.

**Differentiation moments:** The features or interactions that make your product different from alternatives. These are where brand personality lives. They deserve to be more than generic.

### Low-Leverage Decisions

Some decisions have minimal impact:

**Admin and settings:** Pages users visit rarely and where task completion matters more than experience. Don't spend days refining your account settings page.

**Internal tools:** If the only users are employees, functional is good enough. Save craft for external users.

**Features used once:** A one-time setup wizard, a migration tool, a rarely-triggered flow. Spend time proportional to usage.

**Temporary states:** If the product is pivoting soon, don't over-invest in interfaces that might not exist next quarter.

The discipline is treating these differently. The perfectionist instinct is to make everything beautiful. The startup instinct is to make high-leverage things beautiful and low-leverage things *functional*.

---

## Landing Pages That Convert

The landing page is the highest-leverage design asset. It's the first thing potential users see, and it determines whether they become users or leave.

### Headline Hierarchy

The headline is the most important element on the page. If someone reads nothing else, they should understand what the product does.

**Common mistakes:**
- Headlines that describe features instead of outcomes: "Real-time collaboration platform" vs. "Your team, working together, right now."
- Headlines that require knowledge to understand: "The #1 enterprise integration solution" — for what? Who cares about #1?
- Headlines that are too clever: Puns and wordplay might be memorable but are often confusing at first read.

The headline should be instantly understandable. Read it aloud to someone who knows nothing about your product. Do they understand what you do? If not, rewrite.

### Benefit > Feature

Features are what the product does. Benefits are what the user gets. Benefits sell.

- Feature: "End-to-end encryption"
- Benefit: "Your data stays private. No one — not even us — can read your files."

- Feature: "Real-time sync"
- Benefit: "Every change, everywhere, instantly."

Lead with benefits. Features are proof that the benefits are real.

### Social Proof Placement

Social proof — testimonials, logos, case studies — answers the unspoken question: "But does it actually work?"

Placement matters. Social proof is most effective:
- After the value proposition has been made (users need to understand what you do before caring who else uses it)
- Before the CTA (social proof reduces friction right before the ask)

The classic structure: Hero (what we do) → Features (how we do it) → Social proof (proof it works) → CTA (get started).

### CTA Strategy

**One primary action per viewport.** Users should never be confused about what you want them to do. If there are three equally-prominent buttons, none is the CTA.

**Clear visual hierarchy.** The CTA should be the most visually prominent element in its section. Larger, brighter, more contrast than secondary actions.

**Specific language.** "Start your free trial" is better than "Get started." "Book a demo" is better than "Learn more." Specific CTAs set expectations and reduce uncertainty.

### Page Structure

The proven structure for startup landing pages:

1. **Hero:** What you do, who it's for, primary CTA
2. **Problem:** The pain point you solve (optional but powerful)
3. **Solution/Features:** How you solve it
4. **Social proof:** Evidence it works
5. **Secondary features:** Additional capabilities
6. **Final CTA:** Reiterate the ask
7. **FAQ:** Address common objections
8. **Footer:** Navigation, legal, contact

Not every page needs every section. But this flow — establish value, prove it, ask for action — works.

---

## Figma vs. Code-First: Choose Your Starting Point

This book doesn't teach Figma because the focus is taste, not tools. But the question of *when* to use a design tool versus code matters for startup speed.

**Start in code when:**
- You're iterating on existing components (the design system is established)
- The design is structural, not visual exploration (forms, data tables, settings)
- You're prototyping interactions that need real data or state
- You'll be the one implementing it anyway
- Speed matters more than pixel-perfect exploration

**Start in Figma (or similar) when:**
- You're exploring visual directions without constraints
- You need stakeholder feedback before committing to code
- You're establishing new visual patterns (brand work, landing pages)
- Multiple people need to collaborate on visual design
- You need quick mockups for multiple options

The design-engineer advantage: you can choose. Designers who can't code are locked into Figma-first. Engineers who don't design are locked into code-first. You can pick the tool that serves the situation.

For most startup product work, code-first makes sense — you're iterating within an established system, and the fastest path from idea to feedback is shipping. For marketing pages, brand exploration, and major redesigns, starting in a visual tool lets you explore without engineering overhead.

The anti-pattern: religious commitment to one approach. "I always start in code" or "I always design in Figma first" ignores context. Match the tool to the task.

---

## Designing for Iteration

At a startup, everything changes. The feature set changes. The user base changes. The brand might change. The design you ship today will need to change tomorrow.

This has implications for how you design:

### Component-Based Design

Not for architectural purity — for changeability. When you need to update the card design (you will, multiple times this quarter), you change one component, not fifty instances.

This isn't about engineering elegance. It's about your future self, who will need to move fast.

### Semantic Tokens

Not because they're theoretically elegant — because you'll rebrand. When the primary color changes (and it probably will within 18 months), semantic tokens let you change it once. Hardcoded hex values require find-and-replace across the codebase.

### Relative Spacing

Not because it's best practice — because content changes. The marketing copy will get longer or shorter. The feature list will grow. Absolute spacing breaks when content changes. Relative spacing adapts.

### Design for Change

The meta-principle: **make things easy to change, not just easy to look at.**

When you're making design decisions, ask: if this needs to change in three months, how painful will it be? If the answer is "very painful" (embedded everywhere, no system, hardcoded values), consider whether the approach is right for a startup context.

---

## Communicating Design to Non-Designers

Founders and engineers evaluate design differently than designers do. They ask "does it work?" before "does it feel right?" — which is reasonable. The product needs to function.

Your job is to connect *feel* to *outcomes*.

**Not:** "I made the button bigger because it looked better."
**Instead:** "I made the CTA more prominent because analytics show 60% of users never scroll past the fold. The previous button wasn't visible enough to draw attention in the 3 seconds we have."

**Not:** "The spacing was too tight."
**Instead:** "Cramped spacing makes users feel rushed and reduces trust. Especially on pricing pages, breathing room signals confidence — 'we're not trying to overwhelm you.'"

**Not:** "This doesn't feel right."
**Instead:** "The hierarchy is unclear — there are three elements competing for attention. Users won't know where to look first, which increases cognitive load and reduces conversion."

The shift is from aesthetic judgment to *user behavior and business outcomes*. You're not arguing about taste; you're arguing about what will work.

### The Language of Design Communication

**Talk about users, not preferences.** "Users will be confused" is better than "I don't like it."

**Talk about business goals.** "This will hurt conversion" is better than "This isn't designed well."

**Be specific.** "The headline and subhead are too similar in size, so users can't tell which is more important" is better than "the hierarchy doesn't work."

**Offer alternatives.** Don't just critique; propose. "If we make the headline 32px and the subhead 20px, the hierarchy will be clear."

### Picking Battles

Not every design issue is worth fighting for. If you push back on everything, your feedback becomes noise.

Pick battles based on impact. The homepage hero headline is worth arguing about. The icon style in the settings menu is not. Focus your advocacy on decisions that affect users and business outcomes.

---

## Taste Interlude: When to Be Fast and When to Be Right

The tension in startup design is between speed and craft. You can't have both for everything. The skill is knowing when each matters.

**Be fast when:**
- The decision is low-leverage (admin pages, internal tools, rarely-used features)
- The decision is reversible (you can iterate based on feedback)
- Perfect is blocking progress (the team is waiting on this to move forward)
- You're learning (ship something, see how users respond, then improve)

**Be right when:**
- The decision is high-leverage (landing page, onboarding, core product loop)
- The decision is hard to reverse (brand identity, system architecture, public-facing commitments)
- Quality is the differentiator (the whole point is that this is better than alternatives)
- Trust is at stake (payments, security, user data)

The danger for taste-oriented designers is treating everything as high-leverage. You spend a week perfecting a settings page that users visit once a month. The product stalls while you polish.

The danger for speed-oriented engineers is treating nothing as high-leverage. Everything ships fast, nothing is refined, and the product feels amateur. Users don't trust it because it doesn't look trustworthy.

Developing judgment about which is which — which decisions deserve craft and which deserve speed — is the startup designer's most valuable skill.

---

## AI Integration

The 48-hour landing page project (below) is designed to develop AI-assisted speed.

Here's the workflow:

1. **Brief and strategy:** 30 minutes. Define the product, the audience, the positioning. What should the page communicate?

2. **AI-generated first draft:** 2 hours. Use AI to generate copy, layout structure, component code. Don't evaluate quality yet — just get material.

3. **Refinement:** 8+ hours. Now apply taste. Rewrite AI copy that's generic. Adjust layout proportions. Fix typography that's default. Add animation where it serves. Remove what doesn't work.

4. **Polish and ship:** Remaining time. Final tweaks, responsive behavior, deploy.

**Time yourself and document where time went.** The ratio of "time generating with AI" to "time refining by hand" reveals where your taste is strong (fast decisions) and where it's developing (slow decisions).

The goal is to reach a point where AI handles scaffolding and you handle taste — a collaboration where both contributors play to their strengths.

---

## Projects

### Project 1: 48-Hour Landing Page

Create a landing page for a fictional product in 48 hours. Ship it live.

**Requirements:**
- Hero section with headline, subhead, and CTA
- Features or benefits section
- Social proof section (can be fictional testimonials)
- Pricing or secondary CTA
- Footer
- Responsive (works on mobile)

**Constraints:**
- 48 hours from start to live on the internet
- Use AI freely for first drafts and scaffolding
- Document time spent on each phase

**Deliverable:**
- Live URL
- Time log: how long did each phase take?
- Reflection: where did AI help? Where did you have to override AI output?

**Taste check:**
- Does the page look like it was built in 48 hours, or does it look polished?
- Would you send this link to a potential employer or client?
- What would you improve with another 48 hours?

### Project 2: Design as Persuasion

Redesign the landing page of a real open-source tool with a mediocre marketing site.

**Focus:** Conversion. Your job is to make someone more likely to try the tool.

**Process:**
- Audit the current page: what's working, what's failing?
- Identify the jobs-to-be-done: what does a visitor want to know?
- Redesign with persuasion in mind: every element should serve conversion

**Deliverable:**
- Before/after screenshots
- Live redesign (even if it's your hosted version, not official)
- 500-word brief explaining every persuasion decision
- Offer the redesign to the maintainers (optional but good for portfolio and karma)

**Taste check:**
- Would the redesign actually improve conversion? (Not "does it look better" but "would it work better")
- Did you prioritize correctly? (Hero headline matters more than footer link styling)

### Project 3: Design Review Playbook

Write a guide for how a small startup team (2-5 people, no dedicated designer) should run design reviews.

**The guide must include:**
- When to have a design review (not everything needs one)
- What to critique (focus areas)
- How to give feedback (language, specificity, constructive framing)
- When to use AI as first-pass reviewer
- When to trust gut vs. test
- How to resolve disagreements

**Constraints:**
- The guide must be usable by a team with no design background
- Keep it to 1,500 words max — it should be quick to read and apply

**Deliverable:**
- The playbook as a document or page
- Optional: test it with a real team and document what worked/didn't

**Taste check:**
- Would a non-designer team actually follow this guide?
- Does it help them make better decisions, or does it add process without value?
