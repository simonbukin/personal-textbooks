# Appendix B: Toolkit

The tools you'll reach for again and again. This is the cheat-sheet: what each does, when to use it, how to set it up fast.

## Chrome DevTools

The daily driver. Every tab has a specific purpose.

### Performance panel

For: profiling interactions and page loads.

Workflow:
1. Open DevTools → Performance.
2. Throttle: CPU 4x or 6x slowdown; Network: Fast 4G.
3. Click record, do the thing, stop.
4. Look at: Interactions track (for INP), Main thread flame chart (for what ran), Timings track (for FCP/LCP markers).

Tips:
- Use the "Screenshots" checkbox to see a filmstrip alongside the timeline.
- Use "Web Vitals" checkbox to surface CWV events.
- Right-click in the main thread track → "Group by tree" vs "Group by top-down" to see different flame chart orientations.

### Network panel

For: seeing every request, its timing, its priority, its cache status.

Tips:
- Right-click column headers to add: Protocol (h2/h3), Priority, Initiator, Type, Cache-Control.
- Filter: `-domain:yoursite.com` to see only third-party requests. `is:from-cache` to see cached ones.
- The waterfall on the right edge of each row shows: Queuing, Stalled, DNS, Connect, SSL, Request Sent, Waiting (TTFB), Content Download.

### Coverage

For: finding unused CSS and JS.

Open with: Cmd/Ctrl-Shift-P → "Show Coverage." Click record, reload, stop.

Shows every CSS and JS file with bytes used/unused. Great for finding dead code and over-broad utility CSS.

### Memory

For: finding leaks.

Workflow:
1. Take heap snapshot ("Profiles" tab → Heap snapshot).
2. Perform an action (open + close a modal 10 times).
3. Force GC (trash icon).
4. Take another snapshot.
5. Use "Comparison" view on the second snapshot.

Look for: detached DOM nodes, unexpectedly-large objects that should have been freed.

### Application

For: inspecting storage, service workers, and (the secret good stuff) bfcache and Speculation Rules.

- Cache Storage → inspect what your service worker has cached.
- Back/forward cache → test whether bfcache works and diagnose why not.
- Background Services → Speculative Loads → see what prerendered.

### Layers

For: seeing what's composited.

Open via More Tools → Layers. Shows all compositor layers, their memory cost, and why each was created. Useful for debugging `will-change` overuse and "why is scrolling janky?"

### Rendering

For: one-off diagnostic overlays.

Open via More Tools → Rendering. Toggles:
- Paint flashing — highlights areas that repaint. Too much green flashing on scroll = paint perf problem.
- Layer borders — shows composited layers.
- Frame rendering stats — FPS, GPU memory.
- Core Web Vitals overlay — realtime FCP/LCP/CLS on the page.

### Lighthouse panel

Built-in Lighthouse. Useful for a one-off check without leaving the browser. Results vary more than a CI run — treat as directional.

## WebPageTest

[webpagetest.org](https://www.webpagetest.org) (public) or a self-hosted WPT instance.

Default test settings I use:
- Location: somewhere matching your user base (Virginia for US, Frankfurt for Europe, etc.).
- Device: Moto G4 or mid-tier Android for realistic mobile. Desktop if you're testing desktop specifically.
- Connection: 4G for mobile, Cable for desktop.
- Runs: 3+ (WPT takes the median).
- First view + Repeat view (to see cached behavior).

Tabs on the results page:
- **Summary** — headline metrics.
- **Performance** — Core Web Vitals breakdown.
- **Details** — the waterfall and filmstrip.
- **Content** — breakdown by resource type.
- **Request Map** — visualize connections between requests. Great for seeing third-party sprawl.

## Lighthouse CI

Perf regression gating.

```bash
npm install -g @lhci/cli
```

`lighthouserc.json`:
```json
{
  "ci": {
    "collect": {
      "startServerCommand": "npm start",
      "url": ["http://localhost:3000/", "http://localhost:3000/product"],
      "numberOfRuns": 5
    },
    "assert": {
      "assertions": {
        "categories:performance": ["warn", {"minScore": 0.9}],
        "largest-contentful-paint": ["error", {"maxNumericValue": 2500}],
        "total-blocking-time": ["error", {"maxNumericValue": 200}],
        "cumulative-layout-shift": ["error", {"maxNumericValue": 0.1}]
      }
    },
    "upload": { "target": "temporary-public-storage" }
  }
}
```

Then in CI: `lhci autorun`. Post the report URL to the PR.

## web-vitals library

For RUM.

```bash
npm install web-vitals
```

The attribution build adds ~2KB for a huge debugging win:

```jsx
'use client';
import { useEffect } from 'react';
import { onLCP, onINP, onCLS, onTTFB, onFCP } from 'web-vitals/attribution';

function send(metric) {
  const body = JSON.stringify(metric);
  // Use navigator.sendBeacon when possible, it works during unload
  (navigator.sendBeacon && navigator.sendBeacon('/api/rum', body)) ||
    fetch('/api/rum', { body, method: 'POST', keepalive: true });
}

export function WebVitals() {
  useEffect(() => {
    onLCP(send);
    onINP(send);
    onCLS(send);
    onTTFB(send);
    onFCP(send);
  }, []);
  return null;
}
```

Mount in root layout. Done.

## Bundle analyzers

### `@next/bundle-analyzer`

```bash
npm install --save-dev @next/bundle-analyzer
```

```js
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});
module.exports = withBundleAnalyzer({ /* config */ });
```

```bash
ANALYZE=true npm run build
```

Opens an interactive treemap.

### `source-map-explorer`

Simpler alternative if you're not on Next.js, or if you want to inspect a specific chunk:

```bash
npx source-map-explorer build/static/js/main.*.js
```

## Size budgets

### `size-limit`

```bash
npm install --save-dev size-limit @size-limit/preset-app
```

```json
// package.json
{
  "scripts": {
    "size": "size-limit"
  },
  "size-limit": [
    {
      "name": "main bundle",
      "path": ".next/static/chunks/main-*.js",
      "limit": "100 kB"
    },
    {
      "name": "homepage",
      "path": ".next/static/chunks/app/page-*.js",
      "limit": "80 kB"
    }
  ]
}
```

In CI: `npm run size`. Fails the build if limits are exceeded.

## Chrome flags worth knowing

Navigate to `chrome://flags` and search for:

- **Experimental Web Platform features** — enable to try upcoming APIs.
- **Enable strict mixed content checking** — helps catch insecure subresources.

For perf-specific testing:
- **`--enable-experimental-web-platform-features`** command-line flag for Chrome instances used in automated testing.
- **`--enable-features=CompressionDictionaryTransportBackend`** for testing shared dictionary compression.

## Useful `curl` snippets

Check HTTP version:
```bash
curl -sI --http3 https://yoursite.com | head -1
```

See all response headers:
```bash
curl -sI https://yoursite.com/path
```

Check compression:
```bash
curl -sI -H 'Accept-Encoding: br, gzip' https://yoursite.com/app.js | grep -i content-encoding
```

Time each phase of a request:
```bash
curl -w "\nDNS: %{time_namelookup}\nConnect: %{time_connect}\nSSL: %{time_appconnect}\nTTFB: %{time_starttransfer}\nTotal: %{time_total}\n" \
  -o /dev/null -s https://yoursite.com
```

## Checklist: "the site is slow" triage

When someone reports slowness, work through this list in order:

1. **Reproduce it.** What page? What device class? What network? Get specifics.
2. **Is it lab or field?** Run Lighthouse + check CrUX + check your RUM. Agreement across all three = widespread regression. Disagreement = edge case.
3. **When did it start?** Deploy annotations on your RUM dashboard. Look for step changes.
4. **What broke?**
   - LCP regression → check network waterfall for the LCP resource. Something new in the critical path?
   - INP regression → check LoAF attribution in RUM. What scripts are in the offending frame?
   - CLS regression → check which element is shifting (layout-shift entries, or PageSpeed's CLS breakdown).
   - TTFB regression → check your CDN hit rate and origin response times.
5. **Bisect.** If you can't see it, `git bisect` the deploys on a staging URL with Lighthouse.
6. **Fix. Measure. Verify in RUM (give it a day minimum).**

## Checklist: pre-launch perf review

Before any substantial feature ships:

- Bundle size change for this feature's entry point?
- Any new third-party scripts added?
- Any new `use client` boundaries? Are they as deep as possible?
- Any new web fonts added? Self-hosted, size-adjusted?
- Any new images above-the-fold? Dimensions specified? `priority` on the LCP image?
- Lighthouse score on the deploy preview — better or worse than the baseline?
- Any new long tasks introduced? Profile the primary interaction.
- Any new data fetches? Are they in parallel where possible? Cached correctly?

Run through it. It takes ten minutes. It catches 80% of preventable regressions.

## Checklist: monthly audit

Once a month, go through:

- Bundle analyzer — anything unexpectedly large?
- Coverage — any surprising unused JS/CSS?
- RUM dashboard — any regressions hiding in specific page or device segments?
- CrUX changes — p75 trends over last 28 days vs previous 28?
- Third-party scripts — anything new added by marketing/sales you didn't know about?
- Budgets — any budgets creeping toward their limits? Tighten or raise with context.

Put it on your calendar. Thirty minutes. The habit compounds.
