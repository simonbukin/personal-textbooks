# Chapter 7: CSS and Tailwind Performance

CSS is usually a small portion of total bytes and rarely the bottleneck — until it is. This chapter covers:

- Why Tailwind is usually a perf win (and the footguns that undo it).
- The cost of CSS: payload, parse, selector matching, and style recalculation.
- Containment, `content-visibility`, and the underused CSS performance APIs.
- Tailwind v3 vs. v4, and the v4 Oxide engine's performance wins.

## Why Tailwind is fast

The short answer: Tailwind ships only the classes you actually use. On a typical Next.js + Tailwind v3 project with a well-configured `content` field, the production CSS is 20–50KB gzipped, regardless of how large your component library grows.

The reason: Tailwind v3's JIT (Just-In-Time) engine scans your source files at build time, collects every class name used, and generates CSS only for those. The utility-first approach — where classes are tiny, single-purpose, and reused across the whole codebase — means even a huge app rarely exceeds a few thousand distinct classes.

Compare to hand-written CSS, where every new feature adds selectors and every refactor risks leaving dead rules behind. Tailwind's output is almost by construction minimal.

Compare to CSS-in-JS libraries where styles are generated at runtime — those add JavaScript cost (the library itself), parse cost (often async `<style>` tag insertion), and sometimes runtime style object churn. Tailwind at build time is free of all that.

### The content-config footgun

Tailwind's JIT works by scanning files listed in the `content` config:

```js
// tailwind.config.js (v3)
module.exports = {
  content: [
    './app/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
  ],
  // ...
};
```

If you miss a directory, classes used there are not generated. More commonly, if you include too much (e.g., `./node_modules/**/*`), the scan is slow and you may drag in thousands of unused classes.

### Dynamic class names: the big trap

Tailwind's scanner uses regex, not a JS parser. It looks for *string literals that match Tailwind class patterns*. This means dynamic composition breaks it.

```jsx
// BAD: Tailwind's scanner cannot see `bg-red-500`, `bg-blue-500`, etc.
<div className={`bg-${color}-500`}>...</div>

// Worse: Tailwind sees literally nothing useful
const colors = { red: 'bg-red-500', blue: 'bg-blue-500' };
<div className={colors[color]}>...</div>

// GOOD: full class names are string-literal-visible
const classForColor = {
  red: 'bg-red-500',
  blue: 'bg-blue-500',
};
<div className={classForColor[color]}>...</div>

// ALSO GOOD: explicit conditionals
<div className={isActive ? 'bg-blue-500' : 'bg-gray-500'}>...</div>
```

Rule: every Tailwind class must appear somewhere in your source as a complete string. Interpolation into class names doesn't work.

### Safelisting

If you have a genuinely dynamic set (class names from a CMS, for instance), you can safelist:

```js
// tailwind.config.js
module.exports = {
  content: [...],
  safelist: [
    'bg-red-500',
    'bg-blue-500',
    // or a pattern:
    { pattern: /bg-(red|blue|green)-(400|500|600)/ },
  ],
};
```

But: every safelisted class is generated whether used or not. Over-safelisting bloats your CSS. Use sparingly and regenerate carefully.

## Tailwind v4: the Oxide engine

Tailwind v4 (released in early 2025) is a major rewrite. Key perf-relevant changes:

- **Oxide engine** — the scanner and CSS generator are rewritten in Rust. Build times drop dramatically (often 5–10x), which means faster dev iteration and faster CI.
- **CSS-first configuration** — instead of `tailwind.config.js`, configuration moves into CSS via `@theme`, `@utility`, etc. Smaller config footprint, simpler build pipeline.
- **Automatic content detection** — no more `content` array. Tailwind v4 detects source files automatically.
- **Native cascade layers** — generated CSS uses `@layer` natively, giving better cascade control.
- **Composable variants** — more expressive variant system without bloat.

The dev-loop improvement alone is worth the upgrade. The production CSS is also slightly smaller and sometimes loads faster due to cleaner layer structure.

Migration from v3 to v4 is non-trivial but mostly mechanical. If you're on v3 and working on a long-lived codebase, plan the migration.

## The cost of CSS

A few facts to calibrate intuition:

- **Parse cost:** CSS parses fast — typically < 10ms for 50KB of CSS on a mid-range phone. Parse is rarely the bottleneck.
- **Payload:** A Tailwind v3 production build is usually 20–50KB gzipped. A Tailwind v4 build is similar or slightly smaller. These are small numbers relative to typical JS payloads.
- **Style recalculation:** When the DOM or class list changes, the browser recomputes styles for affected nodes. On complex pages with many selectors, this can be 10–50ms. Simpler selectors (Tailwind utilities) keep this fast.
- **Render-blocking behavior:** All `<link rel="stylesheet">` blocks the first paint until loaded. This is the main runtime cost of CSS — the wait.

So for most apps, CSS perf work is about:

1. Keeping the payload small (covered above).
2. Getting critical CSS inlined (covered in Chapter 3 — Next.js handles this automatically).
3. Using `content-visibility` and containment to localize style work for long pages (below).

## `content-visibility`: the underused superpower

For long pages with lots of content below the fold, most rendering work is wasted — you paint and lay out content the user can't see yet. `content-visibility: auto` tells the browser "skip rendering this subtree until it's near the viewport."

```css
.card {
  content-visibility: auto;
  contain-intrinsic-size: 0 300px; /* reserve space so CLS doesn't go haywire */
}
```

The browser:

- Skips painting, layout, and style work for elements in this subtree until they're close to scrolling into view.
- Uses `contain-intrinsic-size` as the placeholder size (so the scrollbar is accurate).
- Does the full work when the element approaches the viewport.

For a page with 200 card-like items, this can turn a 2-second initial render into 200ms. It's particularly effective for:

- Long lists that don't warrant full virtualization.
- Documentation pages with many sections.
- Feed-style content.
- Comment threads.

Caveats:

- The subtree isn't in the accessibility tree for "invisible" content (though it's reached via tab navigation and Ctrl-F still works, because browsers handle this).
- `contain-intrinsic-size` is critical — without it, the browser thinks every skipped element is 0×0 and the page scroll is broken.
- Chrome and Edge support it well. Safari added support in 18.

### CSS containment

Related but different:

```css
.widget {
  contain: layout paint style;
}
```

Tells the browser "changes inside this element cannot affect layout, paint, or style of anything outside it." This lets the browser optimize — if something inside changes, it doesn't have to re-lay-out the whole page.

- **`contain: layout`** — layout changes inside don't cascade out.
- **`contain: paint`** — descendants cannot paint outside the bounds.
- **`contain: style`** — certain style properties don't leak (like counters).
- **`contain: size`** — the element's size is independent of its children (unusual; you must specify size).

`contain: content` is a shorthand for `layout paint style`. Good default for components that are visually isolated (cards, tiles, modals). Typically improves style recalc and layout speed on pages with many such components.

`content-visibility: auto` implies containment plus the viewport-skip behavior.

## Container queries

Container queries let you style based on the container's size, not the viewport:

```css
.sidebar {
  container-type: inline-size;
}

@container (min-width: 400px) {
  .widget { /* bigger styles */ }
}
```

Perf implication: container queries are well-optimized now (all major browsers, stable). They add some style recalc cost when the container resizes, but it's proportional to affected elements, not the whole page. Prefer them to JS-driven size detection with ResizeObserver, which is strictly more expensive.

## Animations: composited vs. everything else

Already covered in Chapter 1 but worth reinforcing in a CSS context:

```css
/* Composited — cheap, runs on the compositor thread */
.thing {
  transition: transform 200ms, opacity 200ms;
}

/* Triggers layout — expensive, main thread */
.thing {
  transition: width 200ms, height 200ms, top 200ms;
}
```

Rule of thumb for animations: `transform` (including `translate`, `scale`, `rotate`) and `opacity`. Those are cheap. Everything else — `width`, `height`, `top`, `left`, `margin`, `padding`, `box-shadow`, `filter` (in most cases) — is expensive.

If you need a size animation, prefer scaling with `transform: scale()` or animating `clip-path`. For position changes, `transform: translate()` beats `top`/`left` every time.

### `will-change`

Tells the browser "I'm about to animate this; promote it to its own layer in advance."

```css
.menu {
  will-change: transform;
}
```

Two important rules:

1. Only apply right before the animation starts (toggle via a class).
2. Remove after the animation ends.

Leaving `will-change` on permanently wastes memory (each layer is a bitmap) and can cause the compositor to become a bottleneck on pages with many such elements.

Don't apply it to every card on the page "just in case." Apply it to the one menu that's about to open.

## View Transitions API

Modern CSS API that lets you animate between DOM states declaratively:

```js
// Trigger a view transition for a DOM update
document.startViewTransition(() => {
  updateDOM();  // your synchronous DOM update, or a React flushSync
});
```

```css
/* Customize the transition */
::view-transition-old(root),
::view-transition-new(root) {
  animation-duration: 300ms;
}
```

What it does: captures the "before" state as a bitmap, applies the DOM update, captures the "after" state, and animates between them using CSS. Because it's the compositor doing the animation, it's smooth even for expensive updates.

Two flavors:

- **Same-document** — within a single-page app, animating state changes. Stable in Chrome 111+, Safari 18+, Firefox behind a flag as of late 2025.
- **Cross-document** — animating across full navigations (traditional multi-page app). Newer, less universal support.

Next.js 15 added support via the router. Expect to see this shipping more broadly.

This is both a nice UX win and a nice perf-feel win: expensive state changes that used to feel jarring become smooth.

## Stacking contexts and paint containment

A stacking context is a grouping of elements for z-ordering. Every time you create one (via `position` + `z-index`, `opacity < 1`, `transform`, `filter`, `will-change`, `isolation: isolate`, etc.), the browser has a natural boundary for paint.

Implication: elements inside a stacking context paint together, and the compositor can move them as a group. Ironically, *creating* a stacking context is sometimes a perf optimization because it promotes a subtree to its own layer and isolates paint work.

`isolation: isolate` is the cleanest way to create a stacking context without side effects. Use it on components that overlap others or have complex `position: absolute` children.

## The Chrome DevTools Coverage tab

Open DevTools → "More tools" → "Coverage". Start recording. Load your page. Stop.

You see every JS and CSS file with an "Unused Bytes" column. For CSS, this tells you what percentage of each file's rules didn't match anything on the current page.

Expect Tailwind to show high unused percentages for any given page — that's normal, because most classes are for other pages/components. What you care about: are there classes generated but used *nowhere*? Check by running multiple Coverage recordings across your highest-traffic pages and cross-referencing.

## Style recalculation

When you change a class or a style, the browser recomputes style for affected elements. On a page with tens of thousands of elements and complex selectors, this can be noticeably slow.

Tailwind-generated selectors are simple (`.bg-red-500`, `.px-4`), which keeps style matching fast. Deeply nested selectors (`nav > ul > li > a`) and attribute selectors (`[data-active="true"] > div`) are slower.

The Performance panel's "Recalc Style" events show you where this is happening. If you see one taking > 50ms, something's off — either you're invalidating too many elements at once, or your selectors are unusually expensive.

## Avoiding layout shift from CSS

Layout shifts from CSS (as opposed to late-loading images) usually come from:

- **Font swap.** Fix with size-adjusted fallbacks (Chapter 3, handled by `next/font`).
- **Content that renders conditionally.** If `{isReady && <Thing />}` mounts a Thing at the end of loading, that's a shift unless the space was reserved. Use `min-height` on the parent, or `aspect-ratio`, to reserve space.
- **Images without dimensions.** Covered in Chapter 3.
- **Animations that change layout.** Use `transform`/`opacity` instead (see above).

`aspect-ratio` in particular is a great CSS tool:

```css
.media {
  aspect-ratio: 16 / 9;
  width: 100%;
}
```

Reserves space proportional to the width, so when the image or video loads, nothing shifts.

## Some Tailwind-specific patterns

A few practical tips for Tailwind-heavy codebases:

### Group common compositions with `@apply` or a helper

Repeated long strings of classes hurt readability and can sometimes grow CSS when combined with many variants. For truly common compositions, either:

```css
/* app.css */
.btn-primary {
  @apply rounded-md bg-blue-500 px-4 py-2 text-white hover:bg-blue-600;
}
```

Or with a helper like `cva` (class-variance-authority):

```js
const button = cva('rounded-md px-4 py-2', {
  variants: {
    intent: {
      primary: 'bg-blue-500 text-white hover:bg-blue-600',
      secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300',
    },
  },
});
```

This doesn't reduce CSS size (Tailwind still generates the underlying utilities), but it makes the code maintainable and less error-prone.

### Don't nest `className` concatenation in hot render paths

```jsx
// Fine for static
<div className="text-sm text-gray-500" />

// Also fine, most of the time
<div className={clsx('text-sm', isActive && 'text-blue-500')} />

// Worst case: dozens of `clsx` calls per render in a big list.
// Profile it; but usually this is not the bottleneck. React is.
```

Class-name concatenation itself is cheap. It's only a concern in extreme cases (thousands of elements re-rendering with complex logic).

## Deliverable

Three short tasks.

**1. Measure your CSS.**

- Production CSS size (gzipped). For a Tailwind app, aim for < 50KB.
- Unused-bytes percentage via Coverage on your top three pages.
- If size is large, identify the cause (dynamic classes not tree-shaking, over-broad safelist, unused component library).

**2. Apply `content-visibility`.**

Pick a long page (a list, a docs page, an article with lots of content). Add `content-visibility: auto` with `contain-intrinsic-size` to the repeating items below the fold. Measure:

- Initial rendering time in the Performance panel.
- First-paint metrics (FCP, LCP).
- Total blocking time.

You should see a measurable improvement. Commit it.

**3. If on Tailwind v3, evaluate v4.**

Read the v4 release notes. Estimate the migration effort. If you're in a long-lived codebase, propose the migration with the build-time speedup as the headline benefit. Dev time compounds.

## What's next

You now understand the rendering pipeline, the network, the critical path, the main thread, React, Next.js, and CSS. Chapter 8 is about the discipline that ties it all together: measurement. How to instrument RUM, how to read WebPageTest like a pro, and how to enforce perf budgets in CI.
