# Chapter 0: What Are We Actually Optimizing?

Before any technique, any tool, any flame chart — you need a sharp answer to one question: when someone says "the site is slow," what do they actually mean?

"Slow" is not a measurement. It's a feeling. Our job is to decompose that feeling into metrics we can observe, and to observe them in ways that reflect what real users on real devices on real networks actually experience. This chapter is about building that shared vocabulary.

## The performance pyramid

User-experienced performance decomposes into four layers, roughly in the order a user encounters them:

1. **Loading** — How fast does meaningful content appear on screen?
2. **Interactivity** — When the user taps, scrolls, or types, how fast does the UI respond?
3. **Visual stability** — Does content jump around while loading or after the user starts interacting?
4. **Runtime responsiveness** — Once the app is loaded, does it stay smooth during scrolling, animations, and ongoing use?

These are not independent. Heavy JavaScript to load a page (1) also causes long tasks that block interactions (2 and 4). A late-loading image without explicit dimensions causes layout shift (3). But decomposing them lets you talk precisely about which one you're fixing.

## Core Web Vitals

Google's Core Web Vitals are the industry-standard metrics for the first three layers. As of early 2026, the three are:

### LCP — Largest Contentful Paint

The time from when navigation starts to when the largest visible content element finishes rendering. "Largest" means the biggest image or text block in the viewport. LCP is a loading metric — it proxies "when does the user see the main thing they came for?"

**Threshold:** Good ≤ 2.5s, Needs Improvement ≤ 4.0s, Poor > 4.0s (at the 75th percentile of page loads).

### INP — Interaction to Next Paint

The latency of user interactions — clicks, taps, and key presses (but not scrolling). Specifically, for a given interaction, it measures the time from the input event until the next frame is painted reflecting the result. A page's INP is roughly the worst interaction a user had during their visit (technically the 98th percentile for long visits, the max for short ones).

INP replaced FID (First Input Delay) as a stable Core Web Vital in March 2024. FID only measured input *delay* — the time until the handler started running. INP measures the whole interaction: delay + processing + presentation. This is a much more honest metric, and much harder to game.

**Threshold:** Good ≤ 200ms, Needs Improvement ≤ 500ms, Poor > 500ms.

### CLS — Cumulative Layout Shift

The sum of unexpected layout shifts during the lifetime of the page, scored by how much content moved and how far. An image loading without reserved space, a late-mounting banner pushing content down, a font swap changing line heights — all CLS.

CLS is unitless (it's a score, not a time). Thresholds: Good ≤ 0.1, Needs Improvement ≤ 0.25, Poor > 0.25.

The current CLS definition uses "session windows" — it only adds up shifts within 5-second windows, taking the worst window. This prevents long-lived single-page apps from accumulating an uncapped score.

## Supporting metrics you need to know

Core Web Vitals are the public scorecard. These are the diagnostic metrics you'll use while debugging.

### TTFB — Time to First Byte

When does the first byte of the HTML response reach the browser? Includes DNS, TLS, request queuing, and server processing. If TTFB is 2 seconds, your LCP cannot possibly be better than 2 seconds — you are network-bound before any rendering even starts.

### FCP — First Contentful Paint

When does the browser paint *anything* from the DOM — text, an image, a non-white background? FCP is the "the page started working" moment. LCP is strictly ≥ FCP.

### TBT — Total Blocking Time

The sum of main-thread blocking time between FCP and TTI (Time to Interactive), where any task over 50ms contributes its excess (the part over 50ms) to TBT. TBT is a lab-only metric — you can't measure it in the field — but it correlates strongly with INP. Lighthouse uses it in its score.

### Speed Index

How quickly the visible content of the page is visually populated. It's based on filmstrip analysis — comparing frame-by-frame how much of the final viewport is already painted. Speed Index is lab-only, and mostly appears in WebPageTest and Lighthouse.

## Lab vs. field: the distinction that trips up everyone

This is the single most important conceptual point in measurement:

- **Lab data** comes from a synthetic run — you, or a CI system, loading the page on a controlled machine under controlled conditions. Lighthouse, WebPageTest, and the DevTools Performance panel all produce lab data.
- **Field data** comes from real users on real devices. Your RUM (Real User Monitoring) tool collects it. Google's Chrome User Experience Report (CrUX) aggregates it across Chrome users who have opted in.

**Core Web Vitals, as Google uses them for ranking and reporting, are field data.** Specifically, they're the 75th percentile of CrUX data over a rolling 28-day window. Your Lighthouse score is lab data and can disagree wildly with your CrUX score. When someone at Google says "your LCP is bad," they mean your p75 CrUX LCP. Not your Lighthouse LCP.

This distinction matters for practical reasons:

1. Lab numbers can be cleaner and let you iterate fast, but they reflect one synthetic scenario.
2. Field numbers are noisy (real users have spotty networks, old phones, weird extensions) but are what ranking and business outcomes are tied to.
3. Optimizations that help lab can hurt field (e.g., aggressively prefetching everything makes your Lighthouse run look great but wastes real users' data on mobile). The reverse also happens.

You need both. Lab to iterate, field to verify.

## Checking your own site's field data

The fastest way to see your CrUX numbers:

1. Go to [PageSpeed Insights](https://pagespeed.web.dev/) and enter your URL.
2. The top section ("Discover what your real users are experiencing") is CrUX field data.
3. The bottom section is Lighthouse lab data.

For programmatic access, the [CrUX API](https://developer.chrome.com/docs/crux/api) is free and returns JSON. If your site doesn't get enough traffic to appear in CrUX, you'll need your own RUM (we cover this properly in Chapter 8).

## Why this matters: the business case

Performance isn't an aesthetic concern. The case studies that circulate are from the mid-2010s onward and are remarkably consistent:

- **Amazon** (2006, often cited): every 100ms of latency cost 1% in sales. The figure is old but the study has been repeatedly re-validated with more modern numbers.
- **Walmart**: for every 1 second of improvement in load time, conversions increased by up to 2%.
- **Pinterest** (2017): rebuilding for perf led to a 40% reduction in wait time, a 15% increase in SEO traffic, and a 15% increase in conversion rate to signup.
- **Vodafone** (2021): a 31% improvement in LCP led to an 8% increase in sales.
- **BBC**: they lose an additional 10% of users for every additional second of loading.

These aren't cherry-picked. Every major e-commerce, media, and content site that has published performance case studies has reported similar effects. The magnitude varies, but the sign is always the same: faster = more money.

You will cite these numbers in buy-in conversations. Memorize at least two.

## What you're actually optimizing for

Put the metrics together and the picture is this:

- **TTFB** is bounded by your infrastructure (server, CDN, network).
- **FCP** is bounded by TTFB plus your render-blocking resources (HTML, blocking CSS, blocking JS).
- **LCP** is bounded by FCP plus whatever it takes to load the hero element (often an image or a text block depending on a web font).
- **CLS** is bounded by whether you reserve space for everything that loads async.
- **INP** is bounded by how long your JavaScript handlers and subsequent renders take, plus any main-thread congestion at the moment of interaction.
- **TBT** in the lab is the strongest leading indicator of **INP** in the field.

Every technique in the rest of this book is, ultimately, an intervention on one of these chains.

## Deliverable

Write a one-page internal document titled *"What performance means at \[your company\], and why."* It should include:

1. **The metrics we care about.** Name each Core Web Vital, its definition in one sentence, and its threshold.
2. **Our current numbers.** Pull your p75 CrUX data from PageSpeed Insights for your top 3 pages. Note lab Lighthouse scores alongside so people can see the gap.
3. **The business case.** One paragraph citing 1–2 case studies, framed in terms of your company's metrics (conversion, engagement, retention, whatever matters).
4. **The distinction between lab and field** in plain language, so non-engineers stop conflating them.
5. **What we are not optimizing yet.** Pick two advanced techniques you haven't yet applied (e.g., "we haven't adopted `fetchpriority`" or "we're not on Tailwind v4 yet"). This sets up future work.

This document is your north star. You'll reference it in every perf conversation for the next year. Put it somewhere your team can find — a Notion page, a README in the repo, a wiki. It should exist *before* you write a single line of optimization code.

## What's next

Chapter 1 goes down a level: how the browser actually renders a page, what the rendering pipeline is, and why "a painted pixel" is the end of a long chain of events that you'll eventually know cold.
