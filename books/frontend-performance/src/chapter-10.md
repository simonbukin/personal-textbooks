# Chapter 10: Influence and Advocacy

Here is the uncomfortable truth: knowing the material isn't what makes you the perf expert on your team. Shipping perf improvements that your team keeps shipping — after you've moved on, after your attention has shifted — is what makes you the expert.

Perf work is unusual in that it benefits everyone but is rarely anyone's explicit job. The PM isn't asking for a 200ms LCP improvement. The designer isn't asking you to remove web fonts. The engineering manager isn't tracking INP on the roadmap.

So the technical skills from the previous nine chapters are necessary but not sufficient. You also need to:

- Translate perf wins into language non-engineers care about.
- Get ahead of regressions in code review without being the Perf Cop.
- Build systems and processes that make perf the default, not the exception.
- Teach the skills to others so the work isn't bottlenecked on you.
- Make perf work legible to leadership — so it gets prioritized, staffed, and rewarded.

This chapter is about all of that.

## Translating perf wins to business metrics

No one outside engineering is moved by "we shaved 180ms off LCP." They move when you say "we expect this to lift conversions by ~1.5% based on benchmarks."

### The speed × business table

Build (and update) an internal table mapping perf changes to outcomes. Something like:

| Metric change | Business expected impact | Source |
| --- | --- | --- |
| LCP -500ms | +2% conversion on product pages | Walmart case study + our 2024 A/B test |
| INP from 350ms → 180ms | +0.8% engagement, -1% bounce | Google INP launch research |
| TTFB -200ms | +1% retention | Our own analysis, last quarter |
| +100KB JS on homepage | -0.4% conversion | Internal correlation analysis |

Some numbers are from public case studies (cite them). Some are from your own A/B tests (more on that next). Either way, the artifact — a living table — becomes the thing you reference in every business-case conversation.

### A/B testing performance changes

The gold standard for convincing your org that perf matters is an A/B test showing *your* users responding to *your* changes. Setup:

1. Ship a meaningful perf improvement to 50% of traffic.
2. Measure conversion, engagement, revenue on both cohorts.
3. Run for at least 2 weeks (capture weekly cycles).
4. Share the results.

The numbers are usually smaller than the case studies suggest — conversion effects of 0.5–2% are typical. But they're real, they're *yours*, and they compound. "We ran an A/B test; users on the fast version converted 1.2% better. At our revenue, that's $X/year" shuts down "I'm not sure perf matters" instantly.

### Business framing for common wins

Some translations to have ready:

- **Image optimization → faster product browsing → higher cart rate.**
- **Smaller JS bundles → better mobile experience → better performance on 3G and low-end devices (often the markets with highest growth).**
- **Better INP → less user frustration → lower rage-click rates, lower support tickets for "the button doesn't work."**
- **Better CLS → fewer misclicks → less accidental purchases, less support churn.**
- **Better TTFB → better SEO → more organic traffic.**

Pick the framing that matches your org's actual priorities. SEO-focused? Lead with Core Web Vitals as a ranking factor. Conversion-focused? Lead with case studies and A/B tests. Mobile-growth-focused? Lead with device-tier breakdowns.

## Flagging regressions in code review without being The Perf Person

A hard social balance. If you comment "this regresses perf" on every PR, you become the friction people route around. If you comment on nothing, regressions ship.

Principles that work:

### 1. Automate what you can.

Bundle-size checks, Lighthouse CI, and Core Web Vitals dashboards do the flagging so you don't have to. A bot saying "JS bundle +25KB on this PR" is less friction than a person saying it.

### 2. When you do comment, be specific and actionable.

Bad: "this might have perf implications."

Good: "This adds `use client` to ProductDetails, which currently only imports Server Components below it. That moves ~30KB of JS that was server-only to the client. Can we keep the server boundary here and put the interactive bit in a smaller child component?"

Specific, diagnostic, suggests the fix. Easy to act on.

### 3. Pick your battles.

Not every regression is worth a comment. A 2KB increase on a rarely-visited admin page is not worth the conversation. A 50KB increase on your main entry point is. Save your credibility for things that matter.

### 4. Frame as team goals, not personal preferences.

"Per our perf budget, this PR would put us over our 200KB entry bundle target" lands differently than "I think this is too much JS." One references a shared commitment; the other references you.

### 5. Offer alternatives.

"This needs a heavy chart library. What if we dynamically-import it so it only loads when the chart is visible? I can show a pattern from ProductStats.jsx."

## Writing perf RFCs

For any significant perf-related architecture decision — adopting PPR, migrating to Tailwind v4, introducing service workers, splitting the monorepo — a written RFC beats a Slack thread. It:

- Forces you to think through the proposal rigorously.
- Makes dissent structured and recorded, not ambient.
- Gives a decision artifact you can point to later ("we decided this on Aug 3, here's the doc").

### RFC structure

A perf RFC I've found works:

1. **Summary** (1 paragraph). What you're proposing.
2. **Motivation.** Current state, what problem it solves, why now.
3. **Proposal.** The specific technical change.
4. **Expected impact.** Measurable metric changes with estimates. "We expect LCP p75 to drop 300–500ms based on X benchmark."
5. **Alternatives considered.** At least 2 other options, why they were rejected.
6. **Risks.** What could go wrong, how we'd detect it, how we'd roll back.
7. **Rollout plan.** Staged deploy, feature flags, metric gates for promotion.
8. **Success metrics.** What numbers tell us this worked, measured over what timeframe.

Share it for comment for 5–10 days before deciding. Don't skip the waiting period even if you "already know" it's right. The discipline of proposal-comment-decide is what makes the process trustworthy.

## Building a perf review process

Regressions happen when the org has no process to catch them. Here's what a mature perf process looks like — aim for this, incrementally.

### Automated in CI

- **Bundle size checks.** Break the build if any entry chunk grows beyond its budget. Post to the PR as a comment with before/after.
- **Lighthouse CI.** Runs on every deploy preview. Posts a summary to the PR.
- **Budget-violation warnings.** Non-blocking warnings for "this PR brings us within 5% of our bundle budget."

### Automated in production

- **RUM dashboard** with Core Web Vitals, broken down by page type and device class.
- **Alert on regressions.** If p75 LCP on the homepage crosses a threshold for 2+ hours, page the on-call engineer or at least post to a Slack channel.
- **Deploy annotations.** Mark every deploy on your metric graphs. When a regression appears, correlating it with a specific deploy is trivial.

### Cadence-based

- **Weekly perf review.** You (at first) looking at the dashboard once a week and posting one observation. Graduate to a team meeting as it becomes valued.
- **Quarterly perf check-in.** Top 10 pages: current numbers, trend, open concerns. Share with the product and engineering leadership.
- **Perf bug bash once per quarter.** Team spends an afternoon just fixing perf issues. Great for morale and breadth; great for teaching.

### Triggered

- **Pre-launch perf review.** Before any significant new feature lands, a review: what are the perf implications, what did we measure in staging, what are we watching post-launch.

You don't need to build all of this tomorrow. Pick one. Do it well. Add the next one next quarter.

## Teaching: scaling yourself

This is the biggest multiplier of your expertise.

### Lunch-and-learns

A 30-minute session walking your team through one concept. Rotate topics over time:

- "How the browser renders a page."
- "The four Next.js caches."
- "Reading a WebPageTest waterfall."
- "What is INP and why does it matter?"
- "The `use client` boundary: moving it right."

Keep them informal. Record them. Make the recordings available to new hires.

### Annotated traces in Slack

When you debug a perf issue, share the trace. Screenshot + annotations + a paragraph of explanation. "Here's why LCP was slow on this page yesterday" is content — other engineers learn from it, remember it, and apply it.

Over time, your Slack channel becomes a searchable knowledge base.

### Code review as teaching

When you comment on a perf issue in a PR, assume the author doesn't know. Explain *why*, not just *what*. A good perf comment teaches; a bad one just blocks.

### Documentation

Create or contribute to your codebase's README with a perf section. Include:

- What the perf budgets are and where they're enforced.
- How to run the bundle analyzer.
- How to profile an interaction.
- Who to ask (hint: it's you, but document the tools too).

New hires read this before they read you. It pays back forever.

### Pair debugging

When a teammate has a perf problem, pair on it. The hour you spend is worth more than the fix — it transfers the skill. Next time, they'll debug it themselves.

## Running a perf bug bash

Once or twice a year, run a focused perf bash.

Structure that works:

1. **Preparation (1 week before).** Pick 3–5 target pages. Produce a dashboard showing each page's Core Web Vitals and a WebPageTest trace. Pre-identify a set of "known issues" teams can pick from, but leave room for discovery.
2. **Kickoff (30 min).** Present the dashboard. Walk through one trace as an example. Explain what you're looking for. Break into pairs or small groups.
3. **Work session (3–4 hours).** Each group picks an issue or hunts for their own. You float between groups helping.
4. **Wrap (30 min).** Each group reports: what they found, what they shipped (or opened a PR for), what they learned.
5. **Follow-up (1 week after).** Measure the real impact of what landed. Share the results. Credit participants.

A good bash produces 5–15 small improvements, three teaching moments, and a measurable Core Web Vitals shift over the following weeks.

## Making perf work legible to leadership

This is where a lot of perf people fail. Leadership doesn't look at your bundle analyzer. They look at quarterly OKRs, dashboards, and what gets said at all-hands.

### Give them metrics they can track

Pick one or two headline metrics — p75 LCP and p75 INP on the homepage are usually good — and make them visible in whatever dashboards leadership already looks at. If your company does weekly business metrics reviews, get Core Web Vitals on that slide.

### Tie wins to business numbers

Every perf win that results in a business number (A/B test result, correlation observation) belongs in a leadership-visible post. "Shipped new image pipeline; LCP -400ms on product pages; A/B test showed +1.1% conversion; projected $X/year at current revenue."

### Use language they use

OKRs. Roadmap. Quarterly planning. Risk register. Learn the words your leadership uses and frame perf work in them.

- "I'm proposing we include 'maintain p75 LCP ≤ 2.5s on homepage' as an engineering OKR."
- "Performance debt is an item on the technical risk register — here's our top 3 risks."
- "For Q2, I'd like to allocate 1 engineer-week to the JS bundle reduction project. Expected impact..."

### Don't become a one-person function

The worst outcome: leadership treats perf as "that thing Alex does." You go on vacation, things regress. You leave, the practice collapses.

The goal is institutional muscle. Budgets in CI. Dashboards on team TVs. Multiple engineers who can debug INP. The bug bashes. The documentation. Your absence should be a minor inconvenience, not a perf cliff.

When you interview for your next role, "built the perf practice at X" means more than "improved LCP by 40%." The former implies the latter continues. The latter implies it regressed the moment you left.

## When to fight, when to yield

You will sometimes lose. A PM will prioritize a feature launch over a perf fix. A designer will insist on a web font that hurts FCP. A vendor requirement will force you to include a script that trashes INP.

Lose gracefully. Document the tradeoff, note the measured cost, move on. Bring it up in the next quarterly review with data. Don't become the person who dies on every hill — you'll lose credibility and end up winning fewer hills, not more.

Pick your hills:

- **Fight for:** budgets in CI, RUM in prod, monitoring alerts, quarterly time for infrastructure work.
- **Often fight for:** `'use client'` discipline, critical path hygiene, third-party script review.
- **Rarely fight for:** micro-optimizations, framework choice, style debates.
- **Don't fight for:** things that don't show up in RUM. If the user can't feel it, it's not worth the social capital.

## The most important habit

Put one recurring calendar block, weekly, 30 minutes, labeled "perf review." Open your RUM dashboard. Look. Post one observation to your team. Do it every week.

That's it. That's the whole practice. Everything else — the bug bashes, the RFCs, the OKRs, the CI, the teaching — grows out of this weekly act of looking. If you do nothing else from this chapter, do that.

## Deliverable

Pick one:

**Option A: Company lunch-and-learn.**

Give a 30-minute talk to your team on one topic from this book. Reading a WebPageTest waterfall is a great first choice. Prepare slides or a live demo. Record it. Ask for questions. Afterwards, write up a short follow-up doc ("we discussed X, here are the action items").

**Option B: A perf RFC, approved.**

Pick a meaningful perf change requiring team alignment — migrating to Tailwind v4, adopting PPR on a set of routes, introducing Lighthouse CI, setting a bundle budget. Write the RFC using the structure above. Circulate for comment. Address feedback. Drive it to an approval.

**Option C: CI perf regression gates.**

Wire up *at least* a bundle-size check (`size-limit` or equivalent) on your main entry chunks. Set thresholds based on current state. Commit the config. Enforce it on the next PR that breaks it. Share a note with your team about the new guardrail.

Any of these is a meaningful artifact of your perf expertise — something beyond shipping technical improvements. It's proof you're operating at a level where the practice outlives the individual.

## Closing

You've reached the end of this book. By now, if you've done the deliverables, you've:

- Audited your app's critical rendering path, network, and bundle composition.
- Profiled real interactions and fixed at least a few of them.
- Set up RUM with attribution and a weekly review cadence.
- Enforced at least one perf budget in CI.
- Written perf documentation for your team.
- Either shipped a lunch-and-learn, an approved RFC, or automated regression gates.

That's the portfolio of someone who *owns* perf at a team. Not someone who knows about perf — someone who runs it.

Keep going. Perf is a field that rewards sustained attention. The engineers who are good at it have been doing it for years, looked at thousands of traces, made hundreds of small bets. Keep your weekly review. Keep writing things up. Keep teaching.

The frontier keeps moving. Every year there's a new API (Speculation Rules, View Transitions, Compression Dictionary Transport were all "new" in the last 18 months). Every year, frameworks change defaults (Next.js 14 → 15 flipped the fetch-cache default; that could easily happen again). Every year, the baseline user expectations get higher.

You are now equipped to keep up. More than that — you're equipped to set the bar for your team.

Next step: open your RUM dashboard. What's it telling you today?
