# Chapter 6: Next.js Performance, Inside and Out

Next.js is the framework. This chapter is about making it work for you — knowing every lever, what each does, and when to reach for it.

We'll cover:

- Rendering strategies (SSR, SSG, ISR, CSR, PPR) and when each fits.
- The App Router vs. Pages Router, Server Components vs. Client Components.
- The four Next.js caches and how to invalidate each.
- Data fetching, parallelism, and the waterfall trap.
- Bundling, code splitting, and the image/font/script primitives.
- Edge Runtime vs. Node Runtime.

This is the longest chapter in the book. That's intentional — the framework is where most of your daily perf decisions happen.

## Rendering strategies

Next.js supports multiple ways to produce HTML. Each has different tradeoffs for TTFB, cacheability, freshness, and personalization.

### SSG — Static Site Generation

HTML is generated at build time. The same HTML is served to every user until the next build.

- **TTFB:** Extremely fast (it's a file on a CDN).
- **Freshness:** Bad. Data is as stale as your last build.
- **Personalization:** None by default.
- **When to use:** Marketing pages, blog posts, documentation, anything that doesn't change often.

In the App Router, this is the default for any route with no dynamic functions (`headers()`, `cookies()`, dynamic `fetch` options, etc.).

### SSR — Server-Side Rendering

HTML is generated on every request.

- **TTFB:** Depends on the origin. Typically 200–500ms for a well-built app, but can balloon.
- **Freshness:** Perfect. Always current.
- **Personalization:** Full. Read cookies, headers, user session.
- **When to use:** Logged-in views, personalized dashboards, search results pages.

### ISR — Incremental Static Regeneration

Like SSG, but regenerated in the background on a schedule or on-demand. Users always get a cached HTML response (fast TTFB); revalidation happens asynchronously.

- **TTFB:** Fast (cached).
- **Freshness:** Configurable. You say "revalidate every N seconds" or "revalidate on this event."
- **Personalization:** None (same caveat as SSG).
- **When to use:** Content that changes occasionally but doesn't need to be perfectly fresh — product pages, article lists, category pages.

In the App Router:

```js
// Regenerate every 60 seconds in the background
export const revalidate = 60;

// Or per-fetch
const data = await fetch('/api/items', { next: { revalidate: 60 } });
```

### CSR — Client-Side Rendering

The HTML is a shell; data is fetched and rendered entirely in the browser after hydration.

- **TTFB:** Fast (shell).
- **Freshness:** Perfect (fetched live).
- **Personalization:** Full.
- **When to use:** Rarely, on its own. Usually one small piece of a page that's intentionally client-rendered inside an SSR/SSG shell.

### PPR — Partial Prerendering

The new hotness. A page is mostly static (prerendered HTML shell), with dynamic holes that stream in. You get SSG's fast TTFB plus SSR's personalization for specific parts.

- **TTFB:** Fast. The shell is cached.
- **Freshness:** Dynamic parts are fresh on every request.
- **Personalization:** The dynamic holes can read cookies, session, etc.
- **When to use:** Most product and marketing pages with small personalized sections (logged-in user name in nav, personalized recommendations, a cart badge).

PPR is in the App Router, shipped as stable in Next.js 15+. Enable per-route:

```jsx
// app/product/[id]/page.jsx
export const experimental_ppr = true;  // or: `ppr: true` depending on your version

export default async function Page({ params }) {
  return (
    <>
      <StaticProductInfo id={params.id} />
      <Suspense fallback={<CartBadgeSkeleton />}>
        <CartBadge />  {/* Reads cookies, renders dynamically */}
      </Suspense>
    </>
  );
}
```

The shell (everything outside the Suspense) is prerendered. `CartBadge` streams in on request.

PPR is the right default for most logged-in apps that also have a lot of static content.

## App Router vs. Pages Router

Both exist. New code should use the App Router. Here's why, for perf:

- **Server Components by default** — less JS ships to the client.
- **Streaming SSR** — the server flushes HTML as it's ready, so the browser can start rendering (and the preload scanner can start fetching) before the whole page is computed.
- **Nested layouts** — common UI (header, sidebar) is shared across routes without re-rendering on navigation.
- **Granular caching** — the framework caches at multiple levels, fetch-by-fetch.
- **PPR support** — not available in the Pages Router.

If you're on the Pages Router in an active project, plan the migration. The perf headroom is significant.

## Server Components vs. Client Components

The defining concept of the App Router. Getting this right is the highest-leverage optimization available in Next.js.

### Server Components

- Run only on the server.
- Render to HTML (and a serialized tree for the client).
- **Never ship their JavaScript to the browser.**
- Can be async, can directly `await fetch`, can access the filesystem, etc.
- Cannot use React hooks (`useState`, `useEffect`, etc.).
- Cannot use browser APIs.

### Client Components

- Marked with `'use client'` at the top of the file.
- Run on the server (for initial HTML) AND in the browser (for hydration and subsequent renders).
- Their JavaScript is bundled and sent to the client.
- Can use hooks, event handlers, browser APIs.
- Can import other Client Components freely; can import Server Components only by receiving them as `children` or props.

### The "use client" boundary

`'use client'` marks a *boundary*. Everything imported by that file, and imported by those imports, and so on, is part of the client bundle.

This means **where you place `'use client'` determines how much JS ships**.

The wrong approach: put `'use client'` at the top of your root layout or your page component. Everything becomes a Client Component, nothing benefits from Server Components, you ship all the JS.

The right approach: put `'use client'` as deep in the tree as possible — on the smallest leaf that actually needs client interactivity.

```jsx
// Wrong: whole page becomes client-rendered
'use client';
export default function ProductPage() {
  return (
    <div>
      <ProductInfo />      {/* could have been a server component */}
      <BuyButton />        {/* needs to be client */}
      <Reviews />          {/* could have been a server component */}
    </div>
  );
}

// Right: only the button is client
export default function ProductPage() {
  return (
    <div>
      <ProductInfo />      {/* server component */}
      <BuyButton />        {/* this file has 'use client' */}
      <Reviews />          {/* server component */}
    </div>
  );
}
```

The mental move: design your pages as mostly-server-rendered, with small islands of interactivity. This is closer to the "islands architecture" pattern (Astro popularized the term, but the idea is older).

### The Client Component that doesn't need to be

Sometimes you'll find a component marked `'use client'` that doesn't actually need it. Maybe it was copied from a tutorial. Maybe a library dependency pulled it that way. Audit your `use client` directives periodically. Each one is a potential bundle reduction.

### Passing server components as children

One pattern worth knowing: a Client Component can render Server Component children, as long as they come in via props.

```jsx
// ClientWrapper.jsx
'use client';
export default function ClientWrapper({ children }) {
  const [open, setOpen] = useState(true);
  return open ? <div>{children}</div> : null;
}

// page.jsx — a server component
export default function Page() {
  return (
    <ClientWrapper>
      <ServerOnlyDetail />  {/* stays a server component */}
    </ClientWrapper>
  );
}
```

The `ServerOnlyDetail` rendered output is sent as part of the RSC payload; its code doesn't ship. Huge for wrapping server-only content in a client-side animation or interactivity shell.

## Streaming and Suspense

The App Router streams HTML. Here's what that means.

For an SSR or SSG page without Suspense, the server has to render the entire page before sending any bytes. TTFB is "how long does the slowest data fetch take?"

With Suspense boundaries:

```jsx
export default function Page() {
  return (
    <>
      <Header />                          {/* fast */}
      <Suspense fallback={<ListSkeleton />}>
        <SlowProductList />               {/* waits on API */}
      </Suspense>
      <Footer />                          {/* fast */}
    </>
  );
}
```

The server:

1. Immediately flushes the HTML for everything outside the Suspense.
2. Shows the fallback in place of `<SlowProductList>`.
3. When the slow part resolves, streams the additional HTML to the browser via chunked transfer encoding.
4. The browser swaps the skeleton for the resolved content, inline, no JavaScript required (the swap is driven by a tiny piece of framework JS but the content itself is streamed HTML).

Consequences:

- **TTFB is bounded by the shell**, not the slowest fetch. Massive improvement.
- **LCP is bounded by whatever is above your Suspense boundary**. Move expensive async work below Suspense.
- **Preload hints, critical CSS, and fonts are all in the shell** — they're discoverable immediately.

This is why *where you place Suspense boundaries* is a perf decision, not just a UX one. Put them around slow things. Keep the shell fast.

## Data fetching in the App Router

### `fetch` with caching controls

The App Router extends `fetch` with caching semantics:

```js
// Cached indefinitely (default in Next 14; opt-in in Next 15 — verify!)
const data = await fetch('/api/items');

// Revalidate every 60 seconds
const data = await fetch('/api/items', { next: { revalidate: 60 } });

// Tag-based invalidation
const data = await fetch('/api/items', { next: { tags: ['items'] } });
// Then, later, from a server action or route handler:
revalidateTag('items');

// Never cache (fully dynamic)
const data = await fetch('/api/items', { cache: 'no-store' });
```

**Important version note:** the default cache behavior for `fetch()` changed between Next.js 14 and 15. In 14, `fetch` was cached by default (you had to opt out with `no-store`). In 15, `fetch` is not cached by default (you opt in). Route handlers (`app/api/...`) similarly flipped defaults. Check your version. Many "my deploy suddenly has a 3x cost increase" stories come from missing this.

### Automatic request deduplication

Within a single render pass, multiple calls to `fetch` with the same URL + options are deduplicated. You can call a function that calls `fetch('/api/user')` from multiple Server Components on the same page, and only one request hits the origin.

This is why "pass props down" vs. "call the fetch again in a child" is not a perf tradeoff in Server Components. Both behave identically, bandwidth-wise. Use whichever is cleaner.

### Parallel vs. sequential: the waterfall trap

The single most common Server Component perf mistake: accidental waterfalls.

```jsx
// BAD: sequential
export default async function Page() {
  const user = await fetchUser();           // 200ms
  const orders = await fetchOrders(user.id); // 300ms (needs user)
  const recs = await fetchRecs(user.id);     // 400ms (needs user, doesn't need orders)
  // Total: 900ms
  return <UI user={user} orders={orders} recs={recs} />;
}

// GOOD: parallelize what can be
export default async function Page() {
  const user = await fetchUser();  // 200ms

  // These two don't depend on each other. Fire in parallel.
  const [orders, recs] = await Promise.all([
    fetchOrders(user.id),
    fetchRecs(user.id),
  ]);  // max(300, 400) = 400ms
  // Total: 600ms
  return <UI user={user} orders={orders} recs={recs} />;
}
```

Harder to spot: waterfalls across component boundaries.

```jsx
// Page component fetches user
export default async function Page() {
  const user = await fetchUser();
  return (
    <>
      <Sidebar userId={user.id} />
      <Main userId={user.id} />
    </>
  );
}

// Sidebar fetches its own data (starts AFTER Page finishes its await)
async function Sidebar({ userId }) {
  const data = await fetchSidebarData(userId);
  return <nav>{/* ... */}</nav>;
}

// Main does the same
async function Main({ userId }) {
  const data = await fetchMainData(userId);
  return <div>{/* ... */}</div>;
}
```

Sidebar and Main's fetches happen in parallel with each other (they're siblings), but they don't start until after Page's `await fetchUser()` finishes. Often this is fine. Sometimes it's wasteful.

Techniques to flatten:

1. **Fetch in the parent and pass data down.** Trivial.
2. **Start fetches early; await late.**

   ```jsx
   export default async function Page() {
     // Kick off fetches before awaiting
     const userPromise = fetchUser();
     const otherPromise = fetchOther();  // doesn't depend on user

     // Await when the values are actually needed
     const user = await userPromise;
     // ...
   }
   ```

3. **Suspense with streaming.** If the slow fetch is in a leaf, wrap that leaf in a Suspense boundary. The rest of the page streams immediately; the slow part fills in later.

### Server Actions

Server Actions are functions marked `'use server'` that can be called from client components. They run on the server.

```jsx
// actions.js
'use server';
export async function addToCart(formData) {
  // runs on server
  await db.insert(...);
  revalidatePath('/cart');
}

// ClientComponent.jsx
'use client';
import { addToCart } from './actions';
export function AddButton() {
  return <button onClick={() => addToCart(...)}>Add</button>;
}
```

Perf considerations:

- **Less JS shipped** for the data mutation path (you don't need a client-side fetch function).
- **Sequential by default within a single action.** Multiple actions called in the same interaction don't run in parallel — they queue.
- **Can cause waterfalls** if overused (call an action, await its result, call another action, etc.).

Use for data mutations (form submits, like/unlike, add-to-cart). Don't use as a general RPC mechanism for reads — for reads, prefer Server Components with `fetch`.

## The four caches

This is the deep-cut Next.js material every expert needs cold. The App Router has four separate caching layers:

```text
  [ Request Memoization ]   In-memory, per-request, server-side.
         ↓                    Dedupes fetches within a single render.
  [ Data Cache ]             Persistent, server-side.
         ↓                    Caches fetch responses across requests.
                              Invalidated by revalidateTag, revalidatePath, revalidate time.
  [ Full Route Cache ]       Persistent, server-side.
         ↓                    Caches the rendered RSC payload + HTML for static routes.
                              Invalidated on deploy, by revalidatePath.
  [ Router Cache ]           In-memory, per-session, client-side.
                              Caches RSC payloads on the client so back/forward navigation is instant.
                              Invalidated by router.refresh() or revalidatePath (with the right setup).
```

Let's unpack each.

### 1. Request Memoization

Scope: server-side, during a single render. When two Server Components in the same request both call `fetch('/api/user')`, only one network request is made. This is automatic and always on for `fetch`.

For non-`fetch` data sources (your own DB calls), wrap with React's `cache()`:

```js
import { cache } from 'react';
export const getUser = cache(async (id) => {
  return db.users.findById(id);
});
```

Now multiple `getUser(1)` calls in the same render share one DB query.

### 2. Data Cache

Scope: persistent on the server (disk on self-hosted, managed on Vercel). Caches `fetch` responses across requests.

Controlled by the `next` option on fetch:

```js
fetch(url, { next: { revalidate: 3600 } });  // time-based
fetch(url, { next: { tags: ['products'] } }); // tag-based
fetch(url, { cache: 'no-store' });            // no cache
```

Invalidation:

- Time-based: expires after `revalidate` seconds.
- Tag-based: `revalidateTag('products')` from a Server Action or route handler.
- Path-based: `revalidatePath('/products')` invalidates all data for that path.

### 3. Full Route Cache

Scope: persistent on the server. Caches the entire rendered route (RSC payload + HTML) for statically-rendered routes. This is what makes SSG fast — the server doesn't re-render at all, it just serves the cached output.

Dynamic routes (any route using `headers()`, `cookies()`, dynamic fetches, etc.) skip this cache.

Invalidation:

- On deploy (new build replaces it).
- `revalidatePath('/x')` invalidates the cached render for path `/x`.

### 4. Router Cache

Scope: in the browser, per session. When the user navigates between routes, the client stores the RSC payload for recently-visited routes in memory. Going back is instant.

Invalidation:

- `router.refresh()` — invalidates all.
- `revalidateTag` and `revalidatePath` invalidate the relevant entries.
- Router Cache entries have TTLs (defaults are short for dynamic, longer for static).

### Why this matters

Next.js caching is powerful but also the single most common source of "it works locally, breaks in prod" and "I can't see my changes" complaints. You need to be able to answer, for any piece of data on your site:

- Which cache is it in?
- How do I invalidate it?
- Is this cached per-user or globally?

Teach this diagram to your team. Print it out. You'll reference it forever.

## Bundling and code splitting

### Bundle analyzer

Every perf engineer runs this first:

```bash
npm install --save-dev @next/bundle-analyzer
```

```js
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});
module.exports = withBundleAnalyzer({ /* your config */ });
```

```bash
ANALYZE=true npm run build
```

You get an interactive treemap of every client bundle. Look for:

- **Unusually large chunks** — one huge file usually means a barrel import dragging in too much.
- **Duplicates** — the same library included twice because different parts of your tree pulled different versions.
- **Obvious bloat** — Moment.js (use date-fns or day.js), Lodash whole-package imports (use `lodash-es` or direct paths), huge icon libraries (tree-shake or use SVGs).

### `next/dynamic`

Code-splits a component into its own chunk, loaded on demand.

```jsx
import dynamic from 'next/dynamic';

const HeavyChart = dynamic(() => import('./HeavyChart'), {
  loading: () => <ChartSkeleton />,
  ssr: false,  // if the component can't SSR
});

function Page() {
  return <HeavyChart data={...} />;
}
```

Use for:

- Components that are below the fold.
- Components that only render on interaction (modal contents, heavy editors).
- Libraries that are large and used rarely.

Don't use for:

- Components in the initial viewport (you just add a round trip).
- Components used on every page (shared chunks already handle this).

### Barrel files and `optimizePackageImports`

A "barrel file" is an `index.js` that re-exports everything from a directory:

```js
// components/index.js
export * from './Button';
export * from './Input';
export * from './Modal';
// ...50 more
```

Import a single component, and depending on how your bundler tree-shakes, you may drag in the whole package.

Next.js's `optimizePackageImports` targets this:

```js
// next.config.js
module.exports = {
  experimental: {
    optimizePackageImports: [
      'lucide-react',
      '@radix-ui/react-icons',
      'date-fns',
      '@your/component-library',
    ],
  },
};
```

This tells Next.js to treat imports from these packages as if they were imported individually. The effect on client bundle size can be massive for icon and UI libraries.

### Tree shaking and side effects

For tree shaking to work, your code and your libraries need to cooperate:

- Use ES modules (`import`, `export`), not CommonJS.
- Avoid side effects in module initialization (or mark your package with `"sideEffects": false` in `package.json`).
- Avoid dynamic imports of unknown strings (`import(pathVariable)` doesn't tree-shake).

If a library ships CommonJS only, it can't tree-shake. Look for ESM alternatives.

## `next/image`

The image optimization primitive. It:

- Generates responsive `srcset` from a single source.
- Serves AVIF/WebP when supported.
- Lazy-loads by default.
- Requires width/height (preventing CLS).
- Caches optimized variants at the edge.

```jsx
import Image from 'next/image';

<Image
  src="/hero.jpg"
  alt="..."
  width={1200}
  height={600}
  priority         // for LCP; disables lazy loading, adds fetchpriority=high
  placeholder="blur"  // works with local imports
  sizes="(max-width: 768px) 100vw, 50vw"
/>
```

Configuration in `next.config.js`:

```js
module.exports = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'cdn.example.com' },
    ],
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
  },
};
```

`deviceSizes` and `imageSizes` determine the variants generated. Fewer variants means smaller Vercel image-optimization bill; more variants means better sizing per device. The defaults are fine for most.

If self-hosting, you may want to front `next/image` with an image CDN (Cloudinary, Imgix) for better caching — Vercel's default image optimizer is great but expensive at scale.

## `next/font`

Automatic font self-hosting and optimization:

```js
// app/layout.jsx
import { Inter } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
});

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="font-sans">{children}</body>
    </html>
  );
}
```

Under the hood, `next/font`:

- Downloads the font files at build time (so no request to Google Fonts at runtime).
- Self-hosts them with long cache headers.
- Generates preload hints for routes that use them.
- Computes size-adjust metrics for a matched fallback font (dramatically reducing CLS from font swap).

For local fonts, use `next/font/local`:

```js
import localFont from 'next/font/local';
const myFont = localFont({
  src: './my-font.woff2',
  display: 'swap',
});
```

Use one of these two APIs. Hand-rolled font loading almost always loses on metric-matching.

## `next/script`

Third-party script loading:

```jsx
import Script from 'next/script';

// Loads after page is interactive
<Script src="https://example.com/analytics.js" strategy="afterInteractive" />

// Loads during idle time
<Script src="https://example.com/chat.js" strategy="lazyOnload" />

// Loads before hydration — use rarely
<Script src="https://example.com/critical.js" strategy="beforeInteractive" />

// Runs in a web worker via Partytown (experimental)
<Script src="https://example.com/analytics.js" strategy="worker" />
```

Default to `lazyOnload` for everything that isn't business-critical. Most analytics vendors tell you to put their tag in `<head>` — they're optimizing for event fidelity, not your LCP.

## Edge Runtime vs. Node Runtime

Next.js supports two runtimes for server-side code:

### Edge Runtime

- Runs on Vercel Edge, Cloudflare Workers, etc. — close to the user, globally distributed.
- Subset of Node APIs — no filesystem, no native Node modules.
- Small dependencies only (the bundled code has to fit within platform limits).
- Fast cold starts.

```jsx
// app/api/edge-route/route.js
export const runtime = 'edge';
export async function GET() { /* ... */ }
```

Good for:

- Simple API routes that are latency-sensitive (authentication checks, A/B test assignments).
- Middleware (it's always edge).
- Streaming responses that benefit from low TTFB.

Bad for:

- Anything needing heavy native deps (image processing, PDF generation).
- Anything needing a database driver that doesn't support HTTP/edge fetching.

### Node Runtime

- Full Node.js — filesystem, native modules, any npm package.
- Slower cold starts on serverless platforms.
- Higher per-invocation cost on Vercel.

Default for App Router routes.

### When edge is worth it

Edge is genuinely lower-latency for simple, stateless logic. For a route that reads a cookie and returns a 200 or a redirect, moving it to the edge can save 50–200ms of TTFB for users far from your primary region.

It stops being worth it when:

- The route needs to talk to a database in a specific region (now you've added a round trip to the origin DB region).
- The dependencies don't fit.
- Cold starts on your primary region are already fast.

Measure both in your situation. Don't assume edge is always better.

## Middleware

Middleware runs at the edge on every request. It's powerful — A/B tests, auth checks, i18n routing — and expensive in the sense that it adds to every request's TTFB.

Perf rules for middleware:

- Keep the bundle small. It loads on every request, and bundle size directly affects cold start.
- Avoid heavy deps. Don't import a full analytics SDK just to log a request.
- Use `matcher` in the config to skip routes that don't need middleware (static assets, specific paths).
- Every `await` in middleware adds to TTFB.

```js
// middleware.js
export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};

export async function middleware(request) {
  // Fast logic only.
}
```

## Turbopack and SWC

Turbopack (the new bundler, Rust-based, replacing Webpack for dev and increasingly for prod) and SWC (the Rust-based compiler replacing Babel) are build-time concerns. They don't affect runtime perf directly, but:

- Faster dev builds mean faster iteration means more time spent on actual optimization.
- Turbopack's incremental rebuilds mean HMR stays fast even in large codebases.

If you're on a large project still using Babel config overrides for specific transforms, look at whether SWC plugins cover your use case. The cold-start improvement can be dramatic.

## Deliverable

This chapter's deliverable is the largest, but it's also the most likely to give you a big visible win.

**Part 1: Bundle analysis.**

1. Run `@next/bundle-analyzer` on your production build.
2. Identify your three biggest client-side chunks.
3. For each, list what's inside and whether it needs to be there. For each, choose one action:
   - Remove (unused import).
   - Replace (smaller alternative library).
   - Dynamically import (`next/dynamic`).
   - Move server-side (remove `'use client'` and fetch on the server).
4. Apply at least one of these and measure the change.

**Part 2: Rendering strategy audit.**

Pick your three most-trafficked page types (home, category/listing, detail). For each:

1. What rendering strategy is it currently using (SSG, SSR, ISR, PPR)? How do you know?
2. Is that the right choice? Consider:
   - How often does the content change?
   - Is there personalization? How much?
   - What's the current p75 TTFB?
3. If a different strategy would help (e.g., "PPR would give us SSG TTFB with the personalized nav badge"), write a short spec.

**Part 3: Caching audit.**

For one of those pages, trace every `fetch` call and answer:

- Is it cached in the Data Cache? For how long?
- How is it invalidated?
- Is the route in the Full Route Cache? If not, why not?

Build a diagram of the request path. This is what you'll refer to when your team debugs "why is prod stale."

## What's next

We've covered the framework. Chapter 7 goes into CSS and Tailwind specifically — the styling layer, and its outsized impact on rendering performance.
