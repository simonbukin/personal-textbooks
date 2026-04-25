# Chapter 2: The Network

Most "my app is slow" problems are network problems wearing a trench coat. You can optimize JavaScript until your fingers bleed, but if your TTFB is 1.5 seconds and you ship 800KB of render-blocking resources over a 4G connection, nothing in the browser can save you.

This chapter is about what happens between "user types URL" and "bytes arrive in the parser." By the end you should be able to:

- Read an HTTP/2 or HTTP/3 connection view in WebPageTest.
- Explain what each resource hint does and when to use which.
- Know the difference between `no-cache` and `no-store` (it's not what it sounds like).
- Audit your caching headers and defend every one of them.

## The cost of getting a byte to a browser

To open a new HTTPS connection to a server, the browser has to:

1. **DNS lookup.** Usually tens of milliseconds. Can be hundreds on mobile. Cached by the OS, the browser, and intermediate resolvers.
2. **TCP handshake.** One round trip (SYN, SYN-ACK, ACK).
3. **TLS handshake.** TLS 1.3 is one round trip for a new connection. TLS 1.2 is two.
4. **Actual request.** One more round trip before the first byte of response comes back.

On a connection with 50ms latency (typical for decent home internet), that's ~200ms of pure protocol overhead before any HTML arrives. On a 3G mobile connection with 200ms latency, it's closer to a second.

This is why **connection reuse** matters. Once a connection is open, subsequent requests on the same origin skip most of that overhead. And it's why **reducing the number of origins** you talk to (or warming them up in advance) is a fundamental optimization.

## HTTP/1.1, HTTP/2, HTTP/3

### HTTP/1.1

Each request needs its own TCP connection, or waits for a previous request on the same connection to finish (since HTTP/1.1 pipelining never really worked in practice). Browsers open up to ~6 parallel connections per origin. If you have 20 resources on one origin, the 7th through 20th wait in line.

This is why the old wisdom was "domain sharding": split assets across multiple subdomains to parallelize more requests. That wisdom is obsolete and counterproductive on HTTP/2+.

### HTTP/2

Multiplexing: one TCP connection carries many requests/responses in parallel, using interleaved binary frames. Solves the HTTP/1.1 parallelism problem at the application layer. Also adds:

- **Header compression (HPACK)** — significant savings since HTTP requests are header-heavy.
- **Server push** — the server can send resources the client hasn't asked for yet. (This was deprecated in Chrome in 2022 because it turned out to be net-negative in practice. Don't use it. 103 Early Hints is the replacement, covered in Chapter 9.)

But: HTTP/2 still runs on TCP, and TCP has **head-of-line blocking**. If one packet is lost, all streams on the connection stall until it's retransmitted, because TCP guarantees in-order delivery.

### HTTP/3

HTTP/3 runs on QUIC, a UDP-based protocol. It eliminates TCP head-of-line blocking — if a packet is lost, only the specific stream that packet belonged to stalls, not all streams. QUIC also bundles the transport handshake and TLS handshake into a single round trip (or zero, with 0-RTT for returning clients), which saves real time.

The practical upshot: on lossy or high-latency networks (mobile, international), HTTP/3 is often meaningfully faster. On a clean wired connection, the difference is smaller. Vercel, Cloudflare, Fastly, and every major CDN now default to HTTP/3 where the client supports it.

You should know what your CDN serves, and your answer should be HTTP/3. Check with `curl -sI --http3 https://yoursite.com` or the Chrome DevTools Network panel (right-click columns → show "Protocol"; you'll see `h2`, `h3`, etc.).

## Resource hints: the family tree

Browsers give you a set of declarative hints to tell them what's coming. They look similar and get confused constantly. Here's the mental model.

### `dns-prefetch`

```html
<link rel="dns-prefetch" href="https://fonts.gstatic.com">
```

"I'm probably going to fetch from this origin soon — do the DNS lookup in advance." Very cheap. Fires the DNS lookup and nothing else. Good for third-party origins that might not be used on every page load.

### `preconnect`

```html
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
```

"I'm going to fetch from this origin very soon — do DNS, TCP, and TLS in advance." More expensive than `dns-prefetch` (holds an idle connection for ~10s). Use for origins you're *certain* you'll need, early. The `crossorigin` attribute is required for origins serving fonts, fetch requests with `credentials: 'omit'`, and similar — because browsers use separate connection pools for credentialed vs. uncredentialed requests. Getting this wrong means your preconnect holds a useless connection.

### `preload`

```html
<link rel="preload" href="/hero.webp" as="image" fetchpriority="high">
<link rel="preload" href="/font.woff2" as="font" type="font/woff2" crossorigin>
```

"Start fetching this specific resource now, I'll definitely need it on this page." The most misused hint. Rules:

- Specify `as=` correctly. It tells the browser what priority to give and what Accept headers to send. Wrong value = duplicate fetch.
- For fonts, always use `crossorigin` (fonts are always fetched with CORS in modern browsers).
- Only preload things you'll use in the current navigation, soon. Preloading things you might not use wastes bandwidth and — worse — competes with things you definitely need.
- A preload is a strong hint: it raises priority. Most over-preloading happens when people add preloads for things already in the critical path; you just shift other things out of their way.

### `modulepreload`

```html
<link rel="modulepreload" href="/app.js">
```

Like `preload`, but for JavaScript modules. It also parses and compiles the module in advance, not just fetches it. Use for ES modules you know you'll import soon.

### `prefetch`

```html
<link rel="prefetch" href="/next-page.js">
```

"I'll probably need this on a *future* navigation." Low priority; fetches when idle. Cached in HTTP cache for the next navigation to pick up. Good for the top 1–3 most likely next pages.

### `fetchpriority`

Not a `<link rel>` but a separate attribute:

```html
<img src="/hero.webp" fetchpriority="high">
<img src="/below-fold.webp" fetchpriority="low">
```

"Treat this resource as high/low priority, overriding the browser's default heuristics." Particularly useful for the LCP image: without `fetchpriority="high"`, the browser often picks low priority for images it doesn't yet know are in the viewport, costing you 100–300ms of LCP.

### When to use which

Mental model:

| Hint | What it does | Cost | Use for |
| --- | --- | --- | --- |
| `dns-prefetch` | DNS lookup | Trivial | Maybe-used third parties |
| `preconnect` | DNS + TCP + TLS | Holds connection ~10s | Soon-used origins |
| `preload` | Fetch specific resource now at high priority | Bandwidth + priority displacement | Critical resources not discoverable by HTML parsing |
| `modulepreload` | Fetch + parse JS module | Same as preload + compile | Critical JS modules |
| `prefetch` | Low-priority fetch | Bandwidth | Likely next page |
| `fetchpriority="high"` | Boost priority of existing resource | Priority displacement | LCP image, critical fetch |

## HTTP caching: the semantics no one fully reads

If you learn one thing from this chapter, make it this. HTTP caching is the most effective performance optimization in existence — literally serving a request with a local cached copy costs zero bytes and zero milliseconds. And most sites get it wrong in expensive ways.

### `Cache-Control`

The header that controls it all. Its directives:

- **`max-age=N`** — the response is fresh for N seconds. The browser may use it from cache without asking the server.
- **`s-maxage=N`** — same as `max-age`, but only applies to shared caches (CDNs, proxies). Overrides `max-age` for them. Lets you cache aggressively at the CDN while keeping browsers conservative.
- **`public`** — explicitly allow shared caches to store it.
- **`private`** — only the user's browser should cache. Never the CDN.
- **`no-cache`** — the cache may store the response, but must revalidate with the server (usually via `ETag` or `Last-Modified`) before serving it. *This is not the same as not caching.*
- **`no-store`** — do not cache this at all, anywhere. The truly no-cache directive.
- **`must-revalidate`** — once stale, must revalidate; don't serve stale on errors or offline.
- **`immutable`** — this response will never change. Don't even revalidate. Pair with content hashing. Massive perf win for fingerprinted assets.
- **`stale-while-revalidate=N`** — serve stale responses for up to N seconds while revalidating in background.
- **`stale-if-error=N`** — serve stale for up to N seconds if the origin errors.

The confusion everyone has at least once: `no-cache` does not mean "don't cache." It means "cache, but always check with the server before using the cache." The directive that means "don't cache" is `no-store`.

### The canonical header for your assets

For content-hashed static assets — JS bundles, CSS files, images named like `main.abc123.js`:

```http
Cache-Control: public, max-age=31536000, immutable
```

One year, immutable. The browser never revalidates. When the content changes, the filename changes, so the URL changes, and the cached version is irrelevant.

### The canonical header for HTML

HTML responses are tricky because:

- You want CDN-level caching so TTFB is fast.
- You want to invalidate easily when deploys happen.
- You can't rely on hashing the URL.

A sensible pattern:

```http
Cache-Control: public, s-maxage=60, stale-while-revalidate=86400
```

CDN caches for 60 seconds fresh, serves stale for another 24h while revalidating. Browser gets no cache on HTML (so user sees the latest on hard reload). Pair with purge-on-deploy from your CDN.

Next.js with the App Router handles most of this for you via the Full Route Cache (covered in Chapter 6). But you should understand what it's emitting, because defaults change between major versions (they did between Next 14 and 15) and misconfigured origins cost real money.

### `ETag` and `Last-Modified`

Weak validators for "has this resource changed?" When a cached response is stale (max-age expired), the browser sends a conditional request:

```http
If-None-Match: "abc123"          # from previous ETag
If-Modified-Since: Thu, ...      # from previous Last-Modified
```

The server responds with `304 Not Modified` and no body if unchanged, saving the payload. Still costs a round trip, but saves bytes.

### `Vary`

```http
Vary: Accept-Encoding, Accept-Language
```

Tells caches "this response varies based on these request headers." Critical correctness issue for CDN caching: if you serve different content based on `Accept-Language` but forget to `Vary` on it, CDNs will serve the wrong language to the wrong users.

Also critical: do not `Vary: User-Agent`. That fractures your cache into millions of variants. If you need to branch on device type, branch on a lower-cardinality signal (`Sec-CH-UA-Mobile` via Client Hints, for instance).

## Compression

Every text resource (HTML, CSS, JS, JSON, SVG, fonts) should be compressed. There are two algorithms you care about:

- **gzip** — universal, cheap to compress and decompress, ~70% reduction on text.
- **brotli** — newer, slightly more expensive to compress, ~15–25% better compression ratio than gzip on text.

### Static vs. dynamic compression

- **Static:** your build pipeline pre-compresses each asset at maximum quality (brotli level 11). The server just reads the `.br` file off disk. Free at runtime, best possible ratios.
- **Dynamic:** the server compresses on the fly, typically at a low-to-medium level (brotli level 4 or so). Cheap per request, decent ratios.

For static assets, brotli-11 is the target. For dynamic HTML, brotli-4 or gzip is usually the right tradeoff — you don't want to spend 50ms CPU compressing every response to save 5KB.

Check your site with `curl -I -H 'Accept-Encoding: br' https://yoursite.com/app.js` and look at the `Content-Encoding` header. If it's `gzip` and not `br`, you have a free 20% payload reduction waiting.

## Service workers and the Cache API

A service worker is a script that runs in the background, intercepts network requests for your site, and can respond from its own cache, the network, or both. It's the foundation of offline-capable web apps.

The browser has two separate cache layers:

- **HTTP cache** — standard, driven by `Cache-Control`. The browser manages it.
- **Cache API** — programmatic, managed by your service worker via JavaScript.

A service worker lets you implement patterns the HTTP cache can't:

- **Cache-first** — serve from cache immediately; optionally update in background.
- **Network-first** — try the network, fall back to cache if offline.
- **Stale-while-revalidate** — serve cached, fetch new in background, update cache for next time. This pattern predates the HTTP header of the same name.

For most sites, the win is offline support and instant subsequent visits. For some, it's over-engineering. If your product has users on flaky networks or returning users who'd benefit from instant loads, a service worker is worth it. Workbox (`npm install workbox-webpack-plugin`) is the well-worn library.

Next.js has a `next-pwa` community plugin that handles service worker registration. Be cautious: service workers can go wrong in spectacular ways (stale caches shipping old code for weeks). Ship with a fast-unregister kill switch.

## The Fetch Priority API

One modern addition worth knowing. Every resource the browser fetches has a priority (Lowest, Low, Medium, High, Highest). The browser picks priorities using heuristics — HTML is Highest, CSS is Highest, early `<script>` is High, images below the fold are Low, etc.

`fetchpriority` lets you override:

```html
<!-- Force the hero image to High priority -->
<img src="/hero.webp" fetchpriority="high" alt="...">

<!-- Deprioritize a heavy but non-critical script -->
<script src="/analytics.js" fetchpriority="low" defer></script>

<!-- Works on fetch() too -->
fetch('/api/critical-data', { priority: 'high' });
```

The common mistake is to set `fetchpriority="high"` on everything. Priority is a scarce resource — if everything is high, nothing is. Pick the one or two most important resources and elevate those. Demote the obvious non-critical ones.

## Reading a network waterfall

Open WebPageTest, run a test, and look at the Waterfall. Each row is a request. Every row has colored segments showing the lifecycle:

- **DNS** (teal)
- **Connect** (orange)
- **SSL** (purple)
- **Wait / TTFB** (green, hollow)
- **Download** (blue, solid)

Things to look for:

1. **The critical path.** Find the LCP element. Trace backwards: the image response depended on what CSS? The CSS depended on what HTML? Is there any waterfall step that could have happened in parallel?
2. **Long Wait segments.** Long green-hollow bars mean the server is taking time to respond. Either a slow origin or a cache miss at the CDN.
3. **Long Connect/SSL segments on the 10th request.** Means the browser opened a new connection instead of reusing. Either a different origin, a connection that died, or the browser's connection pool limits.
4. **Requests that start only after other requests finish.** Classic chain. If `index.html` → `app.js` → `chunk.js` → `data.json` is sequential, that's 4 round trips you might be able to flatten with preloads or inlined data.
5. **Third parties.** A row of requests from an origin that isn't yours, starting halfway through the waterfall, taking a lot of time. Every third party is a tax.

The hardest skill is looking at a waterfall and knowing, at a glance, "this is network-bound" vs "this is main-thread-bound." You build it with reps. After enough traces, you start seeing patterns: a big gap before LCP means network; a dense red-triangle forest before LCP means main thread.

## Deliverable

Audit your app's caching headers on every type of asset. Use `curl -I <url>` or the DevTools Network panel (right-click → Copy → Copy response headers).

Build a table with columns: `Asset Type | Example URL | Cache-Control | CDN Behavior | Browser Behavior | Correct?`. Include:

- HTML (top-level page)
- Next.js static JS bundles (`_next/static/...`)
- Next.js server components payload
- Images served via `next/image`
- Fonts
- API routes (`app/api/...`)
- Anything else substantial

For each, answer: is this header correct for this asset? What should it be?

Then pick **one** misconfigured header, fix it, and measure the TTFB or cache-hit-rate change over a day (via your CDN dashboard or CrUX). Document before and after.

Bonus: check your site's HTTP version. If you're not on HTTP/3, find out why and whether your CDN supports enabling it.

## What's next

Now that you know how bytes arrive, Chapter 3 walks through making the first paint actually fast — the critical rendering path. CSS, fonts, images, the LCP element, and every lever in between.
