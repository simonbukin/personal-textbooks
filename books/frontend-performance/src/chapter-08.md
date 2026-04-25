# Chapter 8: Measurement, Monitoring, and RUM

You are not allowed to say "it feels faster." Prove it.

Measurement is the discipline that separates the perf expert from the enthusiast. Everything in previous chapters depends on it — you can't meaningfully optimize what you can't observe, and what you don't observe in production will regress without you noticing.

This chapter covers:

- Synthetic testing: Lighthouse, WebPageTest, Lighthouse CI.
- Real User Monitoring: collecting Core Web Vitals from production, with attribution.
- Vendor tradeoffs.
- Statistical literacy: percentiles, why averages lie.
- Performance budgets and CI enforcement.

## Synthetic vs. real

Covered briefly in Chapter 0; worth internalizing.

**Synthetic** tests: you (or CI) load the page under controlled conditions. Lighthouse, WebPageTest, DebugBear synthetic tests, headless Chrome automation. Repeatable, debuggable, but one scenario.

**Real User Monitoring (RUM):** you collect metrics from actual users loading the page in production. Noisy, but reflects reality and is what business outcomes correlate with.

You need both. Synthetic to iterate fast and gate PRs. RUM to verify impact and catch regressions that synthetic misses.

## Lighthouse

Google's synthetic perf audit. Ships with Chrome DevTools, runs on PageSpeed Insights, available as a CLI (`lighthouse`), and as a Node library.

### What Lighthouse reports

Categories: Performance, Accessibility, Best Practices, SEO, PWA. We care mostly about Performance.

The Performance score (0–100) is a weighted average of:

- **FCP** — 10%
- **LCP** — 25%
- **TBT** (Total Blocking Time) — 30%
- **CLS** — 25%
- **Speed Index** — 10%

The weights change between versions. Look them up for your current version.

### What Lighthouse is good at

- Clear, actionable audits. "Opportunities" section tells you specific things to fix.
- Consistent lab numbers for day-over-day comparisons.
- Cheap to run on every PR via Lighthouse CI.

### What Lighthouse is bad at

- **Single runs are noisy.** Run 5 times and take the median, always.
- **Doesn't reflect real user experience.** Lighthouse uses a simulated 4G connection and a fixed CPU throttle; your users are a distribution.
- **Score changes with Lighthouse version.** Major versions re-weight and re-calibrate.
- **Doesn't measure INP.** Lighthouse measures TBT as a proxy, but TBT is lab-only; the real INP experience requires field data.

Don't obsess over the Lighthouse score in isolation. A 95 Lighthouse with a 4-second p75 LCP in CrUX is a failing site. The reverse — 65 Lighthouse, 2-second p75 LCP — is a good site.

## WebPageTest

The power tool. [webpagetest.org](https://www.webpagetest.org/) (public instance, free tier) or self-hosted.

What makes WPT different:

- Runs on real devices (Moto G4, iPhone SE, desktop configurations) at various network profiles.
- Multi-location: run from Virginia, São Paulo, Tokyo, Mumbai simultaneously.
- Filmstrip view — frame-by-frame captures of the page loading.
- Detailed waterfall with timing, headers, request priorities, connection reuse.
- Multi-step scripting for flows, not just single pages.

### Reading a WPT waterfall

Every row is a request. Colored segments:

- **Teal** — DNS
- **Orange** — Connect (TCP)
- **Purple** — SSL
- **Green (hollow)** — Time to First Byte (waiting)
- **Blue (solid)** — Download

The request number indicates priority (lower = higher priority). Lines between requests show dependencies where WPT can infer them.

What to look for:

1. **Where does the LCP marker fall?** WPT annotates FCP, LCP, TTI with vertical lines. The LCP line should ideally be right after the LCP image finishes downloading.
2. **Critical path.** Trace backwards from the LCP image. What had to load first? Was anything in series that could be parallel?
3. **Long green bars.** Long TTFB on a request means the server is slow or the CDN is missing cache.
4. **Long blue bars on large files.** Download is bandwidth-bound. Either the file is too big or the connection is too slow.
5. **Priority inversions.** Critical resources starting later than less-critical ones. Smells like a priority hint problem.
6. **Third-party rows.** Everything from a domain you don't own. Tally the time they take.

WPT also has a "Connection View" that groups requests by connection, so you can see HTTP/2 multiplexing at work (or not working).

### The filmstrip

At the top of the waterfall, WPT shows screenshots every 100ms (or faster). You can *see* when content appears. Compare two filmstrips (before/after a change) to judge perceived performance honestly.

A site that "feels slow" to users often has a filmstrip with a long stretch of blank or near-blank frames, then a sudden reveal. A site that "feels fast" has content appearing progressively, even if the total load time is similar. Filmstrip awareness is why LCP and Speed Index exist.

## Lighthouse CI

Runs Lighthouse automatically in CI. Flags regressions on every PR.

```yaml
# .github/workflows/lighthouse.yml
name: Lighthouse CI
on:
  pull_request:
jobs:
  lhci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm run build
      - run: npm install -g @lhci/cli
      - run: lhci autorun
```

```json
// lighthouserc.json
{
  "ci": {
    "collect": {
      "startServerCommand": "npm start",
      "url": ["http://localhost:3000/"],
      "numberOfRuns": 5
    },
    "assert": {
      "assertions": {
        "categories:performance": ["error", {"minScore": 0.9}],
        "largest-contentful-paint": ["error", {"maxNumericValue": 2500}],
        "total-blocking-time": ["error", {"maxNumericValue": 200}],
        "cumulative-layout-shift": ["error", {"maxNumericValue": 0.1}]
      }
    }
  }
}
```

Five runs per URL, assertions against specific metrics. PR fails if any assertion fails.

Where this gets tricky: Lighthouse scores on CI environments are noisy (shared CPUs, network variation). You'll get spurious failures. Mitigations:

- Run multiple URLs, require the median to pass.
- Set conservative thresholds; tighten gradually.
- Use relative thresholds (Lighthouse CI supports "don't drop by more than 5 points from the baseline").
- For accurate results, run against your actual deploy preview (Vercel preview URL), not a local build.

## Real User Monitoring

The `web-vitals` library by Google is the canonical RUM collector:

```jsx
// app/web-vitals.jsx
'use client';
import { useEffect } from 'react';
import { onCLS, onINP, onLCP, onFCP, onTTFB } from 'web-vitals/attribution';

function sendToAnalytics({ name, value, id, attribution, navigationType }) {
  // POST to your endpoint, or call your analytics SDK
  fetch('/api/rum', {
    method: 'POST',
    body: JSON.stringify({ name, value, id, attribution, navigationType }),
    keepalive: true,  // so it completes even during unload
  });
}

export function WebVitals() {
  useEffect(() => {
    onLCP(sendToAnalytics);
    onINP(sendToAnalytics);
    onCLS(sendToAnalytics);
    onFCP(sendToAnalytics);
    onTTFB(sendToAnalytics);
  }, []);
  return null;
}
```

Mount `<WebVitals />` in your root layout. Data flows in.

### The attribution build

The regular `web-vitals` build gives you the metric value. The `web-vitals/attribution` build additionally gives you *why*:

```js
onLCP((metric) => {
  console.log(metric.value);
  console.log(metric.attribution);
  // attribution includes:
  //   element: the CSS selector of the LCP element
  //   url: the URL of the LCP resource (if it's an image)
  //   timeToFirstByte
  //   resourceLoadDelay
  //   resourceLoadDuration
  //   elementRenderDelay
});

onINP((metric) => {
  console.log(metric.attribution);
  // attribution includes:
  //   interactionTarget: the CSS selector of the target
  //   inputDelay
  //   processingDuration
  //   presentationDelay
  //   longAnimationFrameEntries: LoAF data
  //   loadState
});
```

This is the difference between "INP is 300ms on our homepage" (useless) and "INP is 300ms, target is the main-nav-menu button, presentation delay is 220ms, and the LoAF shows it's happening during hydration" (fixable).

### Sampling

Sending every metric from every user can be expensive. Sample:

```js
// Send 10% of sessions
if (Math.random() < 0.1) {
  onLCP(sendToAnalytics);
  // ...
}
```

Adjust based on traffic. A high-traffic site can sample 1% and still have rich data. A low-traffic site should send everything.

Beware: biased sampling skews percentiles. Sample sessions randomly, not users (unless you want user-level aggregation).

## Vendors

You can build your own RUM pipeline with `web-vitals`, but most teams use a vendor for the dashboards, alerting, and attribution UX.

### Vercel Analytics / Speed Insights

- Cheap and integrated if you're on Vercel.
- Good Core Web Vitals dashboards.
- Light on attribution depth.
- Per-route breakdowns work well.

Fine default for most Vercel-hosted Next.js apps.

### Sentry Performance

- If you're already using Sentry for error monitoring, the performance integration is natural.
- Good trace-level visibility (span-level detail).
- Less deep on Core Web Vitals specifically.

### Datadog RUM / New Relic

- Enterprise-grade, expensive.
- Cross-stack correlation (frontend RUM + backend traces in one place).
- Dashboards take setup but are powerful once built.

### SpeedCurve

- Perf-specialist vendor.
- Great dashboards, great synthetic + RUM combined view.
- Pricier than Vercel Analytics, cheaper than Datadog.

### DebugBear

- Both synthetic and RUM.
- Strong on attribution — they lean into LoAF for INP, which many others don't yet.
- Good fit for teams that want synthetic AND RUM from one vendor.

### Calibre

- Synthetic-focused, with RUM available.
- Extensive device coverage, good CI integration.

### What to pick

Default advice:

- **You're on Vercel:** start with Vercel Speed Insights. It's good enough and free/cheap.
- **You're self-hosted with Sentry already:** Sentry Performance.
- **You want the best attribution:** DebugBear or SpeedCurve.
- **You're in an enterprise with existing Datadog/New Relic:** consolidate there.

What matters more than the specific vendor: that you actually look at the dashboard weekly, alert on regressions, and tie metrics to features/releases.

## Statistical literacy

The single most important stat fact for perf work: **averages lie, percentiles tell the truth**.

A page with:

- 90% of users: 1s LCP
- 10% of users: 10s LCP

Has a mean LCP of 1.9s (not bad!) but a p75 of 1s (great, for 75% of users) and a p95 of 10s (disaster for the slow tail).

Google's Core Web Vitals use **p75** — the 75th percentile. This means: if your p75 LCP is 2.5s, 75% of your users had LCP ≤ 2.5s, and 25% had it worse.

Why p75?

- It excludes the extreme tail (broken networks, ancient devices) that you can't meaningfully optimize.
- It's still conservative enough to reflect real user pain.
- It's robust to outliers in a way the mean isn't.

For alerting, p75 is a good starting point. For understanding your worst users, look at p95 or p99.

### Why averages don't work

Imagine your perf fix improves a slow case significantly — the slowest 5% of users go from 8s to 4s. The mean LCP drops slightly. The p75 is unchanged. The p95 drops from 8s to 4s.

If you were tracking the mean, the fix looks like a minor win. If you were tracking p95, it's a huge win. Correct framing matters for shipping perf work.

### CrUX uses p75 over 28 days

The CrUX Report (Google's public field data) reports the 75th percentile over a rolling 28-day window. Your CrUX numbers on any given day reflect the last 4 weeks.

Implications:

- A fix won't show up in CrUX for days. Give it a week before you conclude anything.
- Spikes smooth out. Week-long regressions show up.
- Seasonality matters. Holiday traffic patterns affect CrUX.

## Performance budgets

A perf budget is a commitment: "our JS won't exceed 200KB on the home page; our LCP won't exceed 2.5s p75; etc." Budgets make perf a shared constraint rather than one person's obsession.

### Budget dimensions

- **Byte budgets:** per-page JS, per-page CSS, per-page total transferred bytes, image sizes.
- **Metric budgets:** Core Web Vitals thresholds.
- **Count budgets:** number of third-party scripts, number of fonts.

### Enforcing in CI

Byte budgets are easiest to enforce at build time:

```bash
# Using `bundlesize`
npm install --save-dev bundlesize
```

```json
// package.json
{
  "bundlesize": [
    { "path": ".next/static/chunks/main-*.js", "maxSize": "150kB" },
    { "path": ".next/static/chunks/pages/_app-*.js", "maxSize": "100kB" }
  ]
}
```

Or use the newer `size-limit`:

```bash
npm install --save-dev @size-limit/preset-big-lib size-limit
```

```json
{
  "size-limit": [
    { "path": ".next/static/chunks/*.js", "limit": "300 kB" }
  ]
}
```

Metric budgets via Lighthouse CI (above).

### Setting initial budgets

Start from where you are, not where you wish you were. If your current p75 LCP is 4s, setting a 2.5s budget immediately is setting yourself up to fail CI every day.

Process:

1. Measure current state (p75 over a week).
2. Set the budget at current state + 10% headroom. This catches regressions.
3. Separately, set improvement targets (get p75 from 4s to 2.5s by end of quarter).
4. Tighten the budget as you meet targets.

This is how you build the practice without being the person who just blocks everything.

## Reading a RUM dashboard

What to look at, in order:

1. **Trend lines for each Core Web Vital** over the last 30 days. Watch for step changes aligned with deploys.
2. **Breakdown by page template.** Homepage vs. product page vs. checkout almost always differ. Regressions hide in specific pages.
3. **Breakdown by device class.** Mobile vs. desktop. If you only look at the aggregate, a mobile regression hides behind desktop wins.
4. **Breakdown by country/network.** Users in different regions have wildly different experiences. Your US numbers can look great while your users in Indonesia are suffering.
5. **Attribution breakdowns.** Which element is LCP? Which interaction is INP? Which page has CLS?

### The weekly review

Put a recurring 30-minute slot on your calendar. Review these numbers weekly. Ship a note in Slack/your team channel: "INP on /checkout is up 80ms this week — investigating." This is how you become the performance person in more than technical skill; you become it in practice.

## The Performance.mark / measure API

The browser's built-in way to instrument your own code:

```js
performance.mark('ui-init-start');
// ... work ...
performance.mark('ui-init-end');
performance.measure('ui-init', 'ui-init-start', 'ui-init-end');

// Later, collect
performance.getEntriesByType('measure').forEach(entry => {
  console.log(entry.name, entry.duration);
});
```

These marks show up in the DevTools Performance panel's Timings track. They also work with the `PerformanceObserver` so you can collect them to RUM.

Use them to instrument:

- App init milestones ("store hydrated", "router ready", "first fetch complete").
- Expensive operations ("dashboard data loaded", "virtualized list rendered").
- Business flows ("checkout form visible", "payment complete").

Richer than the generic metrics, visible alongside them in the Performance panel, collectable in RUM. If you have any meaningful business moments, mark them.

## Deliverable

This is a bigger deliverable but it's the foundation for everything going forward.

**1. Set up RUM.**

Pick a stack — Vercel Speed Insights, `web-vitals` + your analytics backend, or a full vendor. Mount it in your root layout. Verify data is flowing by loading your production site and checking the dashboard.

If already set up: verify attribution is included. If not, add it.

**2. Build a dashboard.**

With your RUM data, create (or configure) a dashboard showing:

- p75 LCP, INP, CLS — trending over time.
- Same three metrics, broken down by:
  - Top 5 page templates.
  - Mobile vs. desktop.
  - Country (if cross-regional).

Make it shareable. Put the URL in your team's wiki.

**3. Set a budget.**

Pick one critical page. Set a perf budget:

- An LCP target (current + 10% as a regression threshold).
- An INP target.
- A bundle-size limit for client JS on this page.

Wire one of them — bundle size is easiest — into CI with `size-limit` or equivalent. Land the PR that adds it. When it fires on someone's PR, you've instrumented the team.

**4. Weekly perf review.**

Schedule a recurring 30-minute block. Every week, open the dashboard, note trends, share one observation with your team channel. Keep doing this for a month minimum. You'll start noticing patterns — e.g., "INP always spikes on Mondays" (deploy day) or "mobile CLS is drifting up" (someone's adding below-the-fold content without reserving space).

## What's next

You're now measuring. Chapter 9 takes the gloves off and covers the frontier — the newest APIs, the things that separate the expert from the practitioner. Speculation Rules, View Transitions, Early Hints, shared dictionary compression, WebAssembly. Less "you should do this tomorrow" and more "you should know this exists and understand the shape of it."
