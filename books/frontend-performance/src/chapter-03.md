# Chapter 3: Critical Rendering Path Optimization

You know how the browser renders (Chapter 1). You know how bytes arrive (Chapter 2). Now we make the first paint fast.

This chapter is about the handful of resources between the HTML response and the LCP paint — the *critical rendering path* — and how to remove every byte, every round trip, every blocking step that isn't strictly required.

The three big categories:

1. **CSS and fonts** — because they block the first paint.
2. **Images** — because the LCP is usually an image.
3. **Third-party scripts** — because they always take more than you think.

## Render-blocking CSS, and making it not

By default, every `<link rel="stylesheet">` blocks rendering until it's downloaded, parsed, and the CSSOM is built. There is no FCP until the CSSOM is ready. This is sensible — we don't want unstyled content flashing — but it means CSS size and delivery matter a lot for first paint.

### Inline critical CSS

The technique: extract the styles needed to render above-the-fold content, inline them in a `<style>` tag in the HTML `<head>`, and load the rest of your CSS asynchronously.

```html
<head>
  <style>
    /* Critical styles for the first viewport, inlined */
    body { font-family: system-ui; margin: 0; }
    .hero { /* ... */ }
    /* etc. */
  </style>

  <!-- Rest of the CSS, loaded async -->
  <link rel="preload" href="/styles.css" as="style"
        onload="this.onload=null;this.rel='stylesheet'">
  <noscript><link rel="stylesheet" href="/styles.css"></noscript>
</head>
```

The gymnastics in the `<link>` tag is a standard pattern: preload the stylesheet, then flip it to a stylesheet once loaded. This way it doesn't block the first paint.

Next.js with the App Router and automatic critical-CSS extraction handles most of this for you. Tools like [Critters](https://github.com/GoogleChromeLabs/critters) (now **Beasties**, the maintained fork) do it at build time: they parse your HTML and your CSS, figure out which selectors match above-the-fold content, inline those, and load the rest async.

If you're on `next start` with the App Router, critical CSS is largely handled. If you're self-rolling or doing SSR manually, Beasties is the tool to reach for.

### The `media` trick

Old but useful pattern: a stylesheet with a `media` attribute that doesn't match the current viewport is non-blocking. Browsers still download it (at low priority) but don't wait for it before rendering.

```html
<link rel="stylesheet" href="/print.css" media="print">
<link rel="stylesheet" href="/tablet.css" media="(min-width: 600px)">
```

Combine with a JavaScript flip:

```html
<link rel="stylesheet" href="/non-critical.css" media="print" onload="this.media='all'">
```

Loads non-blocking (the `media="print"` makes it non-blocking for screen), then flips to `all` once loaded. Cute trick, still works, but modern Next.js projects should be using the framework's CSS handling rather than hand-rolling this.

### Keep your CSS small

On a typical Tailwind project, your production CSS should be 20–50KB gzipped. If yours is larger, you probably have:

- **Dynamic class names** defeating Tailwind's tree-shaking (`bg-${color}-500` — covered more in Chapter 7).
- **Unused components** from a UI library bundled in.
- **An over-broad safelist** in `tailwind.config`.

Run `ls -lh .next/static/css/*` after a build to see your CSS size. If anything is over 100KB, investigate.

## Fonts: the most common CLS and LCP culprit

Web fonts are notorious for:

- **Blocking text rendering** while the font downloads (if using `font-display: block` or, historically, the default).
- **Layout shift** when the fallback font's metrics don't match the web font's metrics (text reflows when the web font arrives).
- **Slowing LCP** if your LCP element is text rendered in a web font.

### `font-display`

The CSS descriptor that controls what happens while a font is loading:

- **`auto`** — browser decides. Usually acts like `block`. Avoid.
- **`block`** — text is invisible for up to 3 seconds, then falls back. Bad for LCP.
- **`swap`** — text is immediately shown in the fallback font; swaps to the web font when ready. Fast FCP, but causes layout shift when the swap happens.
- **`fallback`** — compromise. 100ms invisible, then fallback, then swap if the web font arrives within a few seconds.
- **`optional`** — 100ms invisible, then fallback. If the web font isn't cached locally, it may not be used at all on this page load. Best for perf, but the user might not see your branded font on first visit.

For body text on a content-heavy site: `swap` with good fallback metric matching (next section).
For brand-critical headings where the specific font matters: `fallback` or `optional` with a well-matched fallback.

### Size-adjust: the CLS killer

The biggest font-related CLS comes from swap: fallback renders, web font arrives, letters reflow. Modern CSS lets you neutralize this by matching the fallback font's metrics to the web font's:

```css
@font-face {
  font-family: "Inter Fallback";
  src: local("Arial");
  size-adjust: 107%;
  ascent-override: 90%;
  descent-override: 22%;
  line-gap-override: 0%;
}

body {
  font-family: "Inter", "Inter Fallback", sans-serif;
}
```

When the web font swaps in, the line heights, character widths, and baselines line up, so layout doesn't shift.

Figuring out the right numbers is tedious. Tools like [Fontaine](https://github.com/unjs/fontaine) automate it at build time. Next.js's `next/font` does it automatically: it computes size-adjust metrics for every font you import, generating a fallback that matches. This alone eliminates most font-related CLS for Next.js users.

### Self-host vs. third-party CDN

Hosting fonts on `fonts.googleapis.com` adds a third-party connection, costing at least a preconnect. Self-hosting means:

- One less origin to warm up.
- You control `Cache-Control` (can set `immutable` on hashed filenames).
- You can preload with confidence.

`next/font/google` downloads the font at build time and self-hosts it. `next/font/local` uses fonts you've placed in your repo. Either way, you're self-hosting. Use one of them.

### Preload the critical font

For any font used above the fold:

```html
<link rel="preload" href="/_next/static/media/inter.woff2"
      as="font" type="font/woff2" crossorigin>
```

Without this, the browser discovers the font only while parsing CSS, which happens after the CSSOM is built, which is after the HTML is fully received. A well-placed preload can shave 100–500ms off LCP on text-heavy pages.

`next/font` handles this too: it inserts the preload automatically for fonts you use in the current route.

### Variable fonts

A variable font is a single file that contains many weights and styles. Instead of shipping Regular, Medium, SemiBold, Bold as four files (each ~30KB), you ship one variable font (~50KB) that covers the entire range.

Net savings if you use multiple weights. Plus fluid weight transitions for animations. Most modern font families (Inter, Manrope, Figtree, etc.) have variable versions. Prefer them.

## Images: usually the LCP

On e-commerce, media, and content sites, the LCP element is almost always an image. If you optimize one thing on your site, optimize the hero image.

### Format choice

In order of preference on modern browsers:

1. **AVIF** — best compression ratio, ~30% smaller than WebP on average. Slow to encode but fast to decode. Support is now universal (Chrome, Firefox, Safari 16+).
2. **WebP** — still great, widely supported, good fallback.
3. **JPEG** — the universal fallback. Good for photos.
4. **PNG** — for flat images with sharp edges and alpha channels. SVG is often better for icons and diagrams.

The pattern via `<picture>`:

```html
<picture>
  <source srcset="/hero.avif" type="image/avif">
  <source srcset="/hero.webp" type="image/webp">
  <img src="/hero.jpg" alt="..." width="1200" height="600">
</picture>
```

Or, in Next.js, `next/image` does this for you automatically — it negotiates the best format based on the `Accept` header the browser sends. Just use `next/image` and you get it for free.

### Responsive images

Don't ship a 2000px-wide hero to a 400px-wide phone. The pattern:

```html
<img
  src="/hero-1200.jpg"
  srcset="/hero-400.jpg 400w,
          /hero-800.jpg 800w,
          /hero-1200.jpg 1200w,
          /hero-1600.jpg 1600w"
  sizes="(max-width: 768px) 100vw, 50vw"
  width="1200"
  height="600"
  alt="...">
```

`srcset` lists candidates. `sizes` tells the browser how wide the image will be at different viewport sizes so it can pick the right one.

`next/image` again handles this. You give it a source and a `sizes` prop and it generates the `srcset`, serves from its optimizer, caches the resized variants at the CDN.

### Always specify dimensions

```html
<!-- Good: reserves space, no CLS -->
<img src="/x.jpg" alt="" width="1200" height="600">

<!-- Also good: aspect-ratio in CSS -->
<img src="/x.jpg" alt="" style="aspect-ratio: 2/1; width: 100%">

<!-- Bad: unknown dimensions, will cause layout shift when image loads -->
<img src="/x.jpg" alt="">
```

`next/image` requires `width` and `height` (or `fill` with a sized container). This is one of the best things it forces on you.

### Priority and `fetchpriority`

The LCP image needs high priority and no lazy-loading:

```jsx
// Next.js
<Image src="/hero.jpg" alt="..." priority width={1200} height={600} />
```

`priority` does two things: disables lazy-loading, and adds `fetchpriority="high"`. Without this, the browser often assigns low priority to images it doesn't yet know are above the fold (because it hasn't run layout yet). You see this specifically in the Performance panel: the LCP image starts downloading late because the browser was being conservative.

Every page should have at most one `priority` image — the LCP. Any more and you're fighting with yourself.

### LQIP and blur placeholders

For images below the fold or that take time to load, show something during the wait:

```jsx
<Image
  src="/hero.jpg"
  alt="..."
  width={1200}
  height={600}
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."  // Next.js generates this at build time for local imports
/>
```

The `placeholder="blur"` renders a tiny blurred version inline, then crossfades to the full resolution. Great for perceived performance — the user sees *something* immediately.

For dynamic images (URLs from a CMS), Next.js can't generate the blur data URL at build time. Options:

- Generate it at the source when content is published (and store alongside the URL).
- Use BlurHash or ThumbHash (even tinier encoded representations).
- Use a solid color placeholder: `placeholder="empty"` with a background color.

### Lazy loading

For below-the-fold images, `loading="lazy"` defers the fetch until the image is near the viewport:

```html
<img src="/below-fold.jpg" loading="lazy" alt="...">
```

Browsers handle this well now. `next/image` lazy-loads by default. Do NOT use it on the LCP image — you'll delay the load until it's already visible.

## Third-party scripts

Every third-party script is a tax. Analytics, chat widgets, A/B testing, tag managers, session replay, feature flags, ads. They all compete with your critical path and all tend to be shipped by people whose perf bar is lower than yours.

### The hierarchy of pain

From most painful to least:

1. **Synchronous `<script src>` in `<head>`.** Blocks HTML parsing, blocks all rendering, blocks everything. Should not exist. Ever.
2. **`<script>` without `async` or `defer`.** Same as above, blocks during its execution.
3. **`<script async>`.** Downloads in parallel, executes as soon as it's ready, blocking parsing at that moment. Order not guaranteed.
4. **`<script defer>`.** Downloads in parallel, executes after HTML parsing is done, in order.
5. **Injected late.** Script tag created by JS after some delay or after user interaction.

For third-party scripts you control the loading of, `defer` is almost always the right answer. `async` is fine for standalone scripts that don't depend on anything.

### `next/script`

Next.js's Script component has strategies built in:

```jsx
import Script from 'next/script';

// Loads during hydration, defaults for most things
<Script src="https://example.com/analytics.js" strategy="afterInteractive" />

// Load only when the browser is idle
<Script src="https://example.com/chat.js" strategy="lazyOnload" />

// Load before hydration (use very sparingly — it's blocking)
<Script src="https://example.com/critical.js" strategy="beforeInteractive" />

// Run in a web worker via Partytown
<Script src="https://example.com/analytics.js" strategy="worker" />
```

Default to `lazyOnload` for anything non-critical. Resist the vendor's documentation telling you it must be in `<head>` — they're optimizing for reliability of their analytics events, not for your LCP.

### Partytown

[Partytown](https://partytown.builder.io/) runs third-party scripts in a web worker, off the main thread entirely. Analytics scripts stop contributing to INP. It works by proxying DOM access through the worker, with real caveats (some scripts don't work, debugging is harder).

Worth evaluating for heavy analytics/tag-manager loads. Not a magic bullet.

### Tag managers

If your team has Google Tag Manager or a similar tool, understand: every tag added to GTM runs on your site. A marketing person adds a "helpful" pixel and your INP drops by 100ms. The solution is not "don't use GTM" — it's ownership and review. Make sure someone (you) sees what's being added.

The simplest GTM perf policy: the tag manager loads with `afterInteractive` or `lazyOnload`, never `beforeInteractive`.

## The LCP waterfall

Put it together. For any page, trace every byte required to render the LCP element:

```text
  HTML
    ↓ (critical CSS inlined, so no blocking CSS here)
  Discover <img> in HTML (parse + preload scan)
    ↓
  AVIF image fetch (priority: high thanks to fetchpriority)
    ↓
  Image decodes
    ↓
  First paint / LCP
```

Four serial steps. Anything that adds a fifth — a blocking CSS file before the image is discovered, a font the text layout depends on, a JS-driven image URL — is an LCP regression.

The Next.js App Router version of this flow:

1. Browser requests `/page`.
2. Server streams the HTML shell immediately, with the critical CSS, preload hints for the LCP image, and a preload/preconnect for the font.
3. `<img fetchpriority="high" src="/hero.avif">` is in the HTML from the shell.
4. Preload scanner discovers it, kicks off the request during HTML streaming.
5. Hero image arrives, decodes, paints. LCP fires.

You want that chain as short as possible. Any step you can parallelize or eliminate is a win.

## A word on Interaction to Next Paint for initial load

One thing often missed: if the user taps something during the first second of loading — before hydration — that tap has to wait until the main thread is free. This is a classic cause of bad INP: the interaction happens during the load, processing is delayed, presentation is delayed, and the whole interaction scores terribly.

The mitigations:

- **Ship less JS** for initial render (Server Components, `next/dynamic`, code splitting).
- **Hydrate progressively** (React 19 Server Components, Suspense boundaries).
- **Use native elements** (real `<button>`, real `<a>`) that work before hydration.

Chapter 4 goes deep on INP. The seeds are planted during initial load.

## Deliverable

Pick your three most-trafficked pages. For each:

1. **Identify the LCP element.** Use the Performance panel (Timings track), or the `web-vitals/attribution` library, or PageSpeed Insights' LCP breakdown.

2. **Trace every byte required to render it.** Make a list:
   - What HTML had to load?
   - What CSS had to load (or was it inlined)?
   - What fonts?
   - What JavaScript (hopefully none)?
   - What was the final LCP resource (usually an image)?
   - Were there any preloads, preconnects, or priority hints?

3. **Identify one round trip you can eliminate or parallelize.** Common wins:
   - Preload the LCP image.
   - Add `fetchpriority="high"`.
   - Self-host a third-party font.
   - Inline a small critical stylesheet.
   - Switch a below-fold image off `priority`.

4. **Apply the change. Measure before/after** in lab (Lighthouse on the deployed URL) and, over a week, in field (CrUX or your RUM).

Document the before/after LCP numbers in your internal performance doc from Chapter 0. This is your first shipped win. You'll reference it when someone asks why perf matters.

## What's next

With loading fundamentally understood, Chapter 4 shifts to runtime: JavaScript on the main thread, long tasks, scheduling, and INP — the metric that actually measures whether your app feels responsive.
