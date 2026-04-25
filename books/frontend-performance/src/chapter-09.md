# Chapter 9: Frontier Topics

Everything in the previous chapters is, roughly, the current best practice. This chapter is the frontier — APIs and techniques that are newer, less universally adopted, and where being early is a competitive advantage.

These are the things that separate the expert from the practitioner: not that you *must* use them all, but that you know they exist, understand the shape of the problem they solve, and can evaluate whether they fit your situation.

Topics:

- Speculation Rules API — prerendering the next page before the user clicks.
- View Transitions, deeper.
- `scheduler.postTask` and `scheduler.yield`, deeper.
- The back-forward cache (bfcache) — free performance you might be breaking.
- 103 Early Hints.
- React Server Components wire format, briefly.
- Islands, resumability, and the partial hydration landscape.
- Compression Dictionary Transport.
- WebAssembly for CPU-bound work.
- Production profiling with `performance.mark` wired to RUM.
- Sustainability and the green web.

## Speculation Rules: prerendering the next page

When a user hovers a link, the browser used to do nothing. Then `rel="prefetch"` let us start fetching the next page. Then `<link rel="prerender">` tried full prerendering but was expensive and broken enough that it was deprecated.

The **Speculation Rules API** is the modern replacement. You tell the browser "here are rules for which links to prefetch or prerender, and when." The browser handles the heuristics — hover, viewport, tap-start.

```html
<script type="speculationrules">
{
  "prerender": [
    {
      "where": { "href_matches": "/product/*" },
      "eagerness": "moderate"
    }
  ],
  "prefetch": [
    {
      "where": { "href_matches": "/*" },
      "eagerness": "conservative"
    }
  ]
}
</script>
```

Rules explained:

- **`prerender`** fully renders the page in the background, including running JavaScript. When the user clicks, the navigation is instant.
- **`prefetch`** fetches the HTML and resources but doesn't run them.
- **`eagerness`** controls trigger heuristics:
  - `conservative` — only on click/tap-start.
  - `moderate` — on hover, or tap-start on mobile.
  - `eager` — proactively, when the link is seen.
  - `immediate` — as soon as the rule matches.

### The tradeoffs

Prerendering is amazing when it works: next-page LCP goes to 0. It's terrible when it doesn't:

- You double-fetch pages the user doesn't visit, wasting bandwidth.
- Analytics may fire for prerendered pages the user never actually sees (you have to guard on `document.prerendering`).
- Some third-party scripts panic when loaded in a prerender context.
- Heavy prerenders pressure the user's memory.

Start with `prefetch` at `moderate` for your top navigation paths. Add `prerender` only for very high-confidence next-page predictions. On content sites where "next article" is obvious, prerender that. On a complex app where nav could go anywhere, just prefetch.

Next.js 15 has built-in integration — `<Link prefetch>` already uses prefetch behavior. The Speculation Rules API is a lower-level primitive you can use beyond the framework's defaults.

### Checking if it worked

DevTools Application → Background Services → Speculative Loads shows you what was prerendered/prefetched and whether it was used.

## View Transitions, deeper

Covered briefly in Chapter 7. Two things worth deepening.

### Customizing the transition

Every element with `view-transition-name` gets its own transition pair. You can animate multiple elements independently:

```css
.hero-image {
  view-transition-name: hero;
}

::view-transition-old(hero),
::view-transition-new(hero) {
  animation-duration: 400ms;
  animation-timing-function: cubic-bezier(0.2, 0, 0.2, 1);
}

::view-transition-old(hero) {
  animation-name: fade-out;
}
::view-transition-new(hero) {
  animation-name: fade-in;
}
```

This enables morph-between-routes effects: the hero image on the index smoothly becomes the hero image on the detail page, without you writing any animation logic.

### Cross-document transitions

Newer API — View Transitions across full navigations, not just SPA state changes. You opt in with:

```css
@view-transition {
  navigation: auto;
}
```

Now any same-origin navigation with matching `view-transition-name` elements gets an automatic morph transition. You get SPA-feeling nav without an SPA.

As of early 2026, cross-document transitions are stable in Chrome, behind a flag in Firefox, and preview in Safari. If your site is MPA or mostly-MPA, this is approaching "just turn it on" territory.

## `scheduler.postTask` and `scheduler.yield` in depth

Chapter 4 introduced these. Worth the extra detail.

### `postTask` priorities

```js
scheduler.postTask(fn, { priority: 'user-blocking' });
// Highest. Browser treats like an input handler. Rare; use only when you need it.

scheduler.postTask(fn, { priority: 'user-visible' });
// Default. Higher than setTimeout(0), lower than microtasks.

scheduler.postTask(fn, { priority: 'background' });
// Lowest. Like requestIdleCallback but more deterministic.
```

### `AbortSignal` with postTask

Tasks scheduled via `postTask` can be canceled:

```js
const controller = new TaskController();
scheduler.postTask(heavyWork, {
  priority: 'background',
  signal: controller.signal,
});

// Later, if no longer needed:
controller.abort();
```

Great for "the user navigated away; stop the background prefetch we were doing."

### `scheduler.yield()` specifics

The classic yield pattern with `setTimeout(0)` has an unfortunate side effect: yielding drops your continuation to the back of the task queue, so any other tasks scheduled in the meantime run first. This can cause priority inversion — your high-priority work defers to lower-priority work.

`scheduler.yield()` preserves priority — your continuation stays at whatever priority the original task had. It also yields properly to *render* opportunities, not just other tasks, so the browser can paint between yields.

```js
async function processItems(items) {
  for (let i = 0; i < items.length; i++) {
    process(items[i]);
    if (i % 100 === 0) {
      await scheduler.yield();  // Yield but keep priority
    }
  }
}
```

Where supported, prefer `scheduler.yield()` to `setTimeout(0)`. In browsers that don't support it, fall back to `setTimeout` or use a polyfill.

## The back-forward cache (bfcache)

When a user navigates away and then back (via the browser's back button), the browser can — if conditions are met — restore the entire page from an in-memory snapshot. No re-fetch, no re-render, no re-hydrate. The page appears instantly, with its scroll position and JavaScript state intact.

bfcache is one of the single largest perf wins available, and most sites unintentionally break it.

### What breaks bfcache

- `Cache-Control: no-store` on the HTML response. This is the big one. Many sites set it out of superstition.
- `unload` event listeners. The spec says `unload` is incompatible with bfcache.
- Open connections (WebSockets, server-sent events) that aren't cleanly closed on pagehide.
- `window.opener` references.
- Certain cross-origin iframes.
- Pages using HTTP Basic Auth.

### Checking your bfcache status

DevTools → Application → Back/Forward Cache. Click "Test back/forward cache". It tells you whether the page is eligible and, if not, why.

### Fixing the common issues

1. **Drop `Cache-Control: no-store`.** Use `Cache-Control: private, no-cache` if you want to prevent CDN caching while still allowing bfcache. (Remember: `no-cache` ≠ `no-store`.)
2. **Replace `unload` with `pagehide`.** The `pagehide` event is bfcache-compatible and fires in similar situations.
3. **Close websockets on `pagehide`.** Reopen on `pageshow`.

Fixing bfcache on a common page flow (checkout → product page back → instant) can lift perceived performance dramatically. Often the single-highest-leverage fix I've seen.

## 103 Early Hints

An HTTP status code that sends "while you're waiting on my real response, here are some resources you should start fetching." It's a pre-response response.

```http
HTTP/1.1 103 Early Hints
Link: </styles.css>; rel=preload; as=style
Link: </hero.webp>; rel=preload; as=image; fetchpriority=high

HTTP/1.1 200 OK
Content-Type: text/html
... actual response ...
```

The browser starts fetching the preload targets as soon as it sees the 103, even though the real response hasn't arrived yet. Classic use case: a backend that takes 300ms to generate HTML but knows in advance which CSS and hero image will be needed. Early Hints lets those fetches parallelize with the HTML generation, saving 100–200ms LCP.

Supported by Chrome, Fastly, Cloudflare, Vercel (on specific plans). Usually configured at the CDN layer — you tell the CDN "for requests to /page, send these Early Hints."

If you're on Vercel, check their docs for Early Hints support on your plan. If you're on Cloudflare, they offer automatic Early Hints generation from previous responses. Either way, worth investigating for the big static resources on your LCP path.

## React Server Components: what's actually on the wire

For mental-model completeness.

When a Server Component renders, React produces a serialized tree — not HTML, not JSON, but a custom format called the "RSC payload." It looks something like:

```text
0:["$","div",null,{"children":[["$","h1",null,{"children":"Hello"}],["$","$L1",null,{"data":{...}}]]}]
1:"ClientComponent"
```

Each line is either:

- A component reference (with its props).
- A client component placeholder (with chunks to load for it).
- A module reference (links to the JS file containing the client component).

The browser receives HTML (for fast first paint) AND the RSC payload (for hydration, subsequent renders, router transitions). When you navigate, the client doesn't fetch new HTML — it fetches an RSC payload for the new route and re-renders in-place, feeding into the React tree.

Implications for performance:

- The RSC payload is smaller than equivalent HTML for content-heavy pages.
- The payload is streamed, so the client can start processing before it's complete.
- Prefetching a route (via `<Link prefetch>`) fetches the RSC payload, not the full HTML — efficient.
- Only the client component code is shipped as JS. Server-only components never ship.

The format is undocumented by React (intentionally — it's an implementation detail). But knowing it exists, and roughly what it contains, demystifies a lot of "why is this request happening?" questions in DevTools.

## Islands, resumability, partial hydration

Competing paradigms to React's "everything hydrates" model. Worth knowing conceptually even if you're all-in on Next.js.

### Islands (Astro popularized)

Most of the page is static HTML. Interactive widgets are isolated "islands" that hydrate independently. Each island has its own JS bundle. The rest of the page ships zero JS.

React's Server Components are Next.js's answer to this — the "use client" boundary is an island boundary.

### Resumability (Qwik)

Instead of hydrating (re-executing component code on the client to attach event listeners), Qwik *serializes the application state* into HTML attributes and *lazily loads only the specific handler code needed* when the user interacts.

The result: effectively no hydration work at load time. JS is fetched on-demand on first interaction. Initial TTI approaches zero.

Tradeoffs: first interaction triggers a network request; the mental model is different; the ecosystem is smaller.

### Partial hydration (React's evolving answer)

React 19 + Server Components + Suspense boundaries give you something partial-hydration-like: hydration is interleaved with server streaming; Suspense boundaries hydrate independently; the shell can be interactive before the whole page is done.

As of 2026 this is good but not as aggressive as Qwik's resumability. The gap is narrowing with each React release.

You don't have to switch frameworks, but understanding that alternatives exist, and that the React team is pulling ideas from them, helps you anticipate where Next.js and React are headed.

## Compression Dictionary Transport

This is the 2025 big deal. Short version: shared dictionaries for compression.

Normally, gzip/brotli compress each response independently. But a user's second visit to your site often re-fetches files similar to the first visit — same JS frameworks, similar component code. If the browser could use the *previous* version of a file as a "dictionary" for compressing the new one, the diff would be tiny.

Compression Dictionary Transport does exactly that. Chrome 117+ supports it. When a browser has a previous version cached, it sends an `Available-Dictionary` header indicating which dictionary it can use. The server compresses the new response *against* that dictionary, and the browser decompresses using the same dictionary.

Reported results: ~80% reduction in JS bytes for repeat visits, because most updates change only a small fraction of the bundle.

### What it takes

- CDN/server support — Cloudflare, Akamai, Fastly, and a growing set support it.
- `Use-As-Dictionary` header on the original resource, saying "this file can be used as a dictionary for future responses matching this pattern."
- Content-hashed URLs (which you already have for JS bundles).

If you're on a supporting CDN, enabling this is a config toggle. The win is largest for sites where users return often.

## WebAssembly for CPU-bound work

Wasm isn't primarily a perf play — it's a "run languages other than JS in the browser" play. But for CPU-heavy tasks where the JS equivalent is slow, Wasm can be 2–10x faster.

Real use cases I've seen pay off:

- **Image processing** (cropping, filters, format conversion). Libraries like `@squoosh/lib`.
- **PDF rendering** (`pdf.js` uses some Wasm).
- **Compression** (brotli, zstd, custom formats).
- **Crypto** (though WebCrypto is usually the right answer).
- **Game/simulation math** (physics, pathfinding).

Wasm has startup cost (fetch + compile the module) and communication cost (data in/out of Wasm memory). It's not a free speedup. But for CPU-pure, data-loop work, it reliably wins.

Consider Wasm when:

- The work is CPU-bound, not IO-bound.
- There's an existing Wasm library or a good Rust/C++/Go implementation to compile.
- The work runs long enough (> 100ms) for Wasm's overhead to pay off.
- The data marshalling is manageable.

Don't consider it for light work. A 10ms function in JS doesn't need Wasm.

## Production profiling with `performance.mark` + RUM

Chapter 8 covered `performance.mark` as an instrumentation tool. Here's the deeper use: forwarding marks to RUM so you can correlate custom business moments with Core Web Vitals.

```js
// Instrument a meaningful business moment
performance.mark('feed-first-item-visible');

// Observe and forward to RUM
new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    sendToAnalytics({
      name: 'custom-mark',
      markName: entry.name,
      time: entry.startTime,
    });
  }
}).observe({ type: 'mark', buffered: true });
```

Now you can answer questions like:

- "What's our p75 time-to-first-feed-item?"
- "Did the latest deploy slow down feed rendering?"
- "Do users with bad LCP also have bad time-to-feed?"

Core Web Vitals are the industry metrics. Custom marks are *your* metrics. Track both.

## Sustainability: the green web

A legitimate frontier topic. Every byte transferred consumes energy — in your servers, in the network, in users' devices. Globally, web traffic is a non-trivial carbon footprint.

Tools:

- [Website Carbon Calculator](https://www.websitecarbon.com/) — estimates CO2 per page load.
- The `ecograder` tool for basic assessments.
- The Sustainable Web Design community's [Web Sustainability Guidelines](https://w3c.github.io/sustyweb/).

Practical overlap with performance:

- Shipping less JS = less energy to transfer and execute.
- Better caching = fewer redundant fetches.
- Smaller images = less bandwidth and processing.
- Efficient animations (composited) = less CPU/GPU.

The point isn't that you should refactor for a half-gram of CO2 savings. It's that performance optimization and sustainability usually pull in the same direction. The frame of "this is also about energy and carbon" is worth adding to your internal advocacy, particularly in organizations that care about ESG metrics.

## Deliverable

Pick **one** frontier feature and prototype it behind a flag on a specific page or flow.

Candidates, by effort:

- **Low effort:** Speculation Rules prefetch on your top nav. Add a `<script type="speculationrules">` block to your layout. Measure next-page LCP in RUM.
- **Low-medium:** Fix bfcache. Audit what's breaking it. Fix the top issue. Measure return-navigation speed in RUM.
- **Medium:** View Transitions for a specific route change (product list → product detail). Measure user feedback and commit timings.
- **Medium:** Add `performance.mark` for 5 business-meaningful moments and forward to RUM. Build a dashboard.
- **High:** Enable Compression Dictionary Transport if your CDN supports it. Measure repeat-visit byte reduction.
- **High:** Move a CPU-heavy task (image processing, CSV parsing) to Wasm or a web worker. Measure INP impact.

The goal is to build experience shipping something beyond the standard playbook. Document what you did, what you measured, what surprised you. Write it up as a short internal post — this is material for Chapter 10's deliverable too.

## What's next

You now know more about frontend performance than 95% of frontend engineers. The final chapter is about the skill that actually separates perf experts in the long run: getting others to care. Influence, advocacy, and the meta-skill of making performance a team practice rather than a solo crusade.
