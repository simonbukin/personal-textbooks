# Chapter 1: The Browser Rendering Pipeline

If you don't know what the browser does between receiving HTML and painting pixels, every optimization is a guess. This chapter is about building the mental model that makes the rest of the book make sense.

By the end you should be able to answer, from memory:

- What steps does the browser go through to display a page?
- Which of those steps can happen in parallel?
- Which CSS properties are cheap to animate, and why?
- What's the difference between the main thread and the compositor thread, and why does it matter when JavaScript gets stuck?

## The pipeline

The classic mental model has six phases. They run in order for any given frame, though different parts of the page can be at different phases simultaneously.

```text
  Bytes
    ↓
  Parse (HTML → DOM, CSS → CSSOM)
    ↓
  Style (match selectors to nodes)
    ↓
  Layout (compute geometry: x, y, width, height)
    ↓
  Paint (fill pixels per layer: colors, text, borders, shadows)
    ↓
  Composite (assemble layers into the final image on screen)
```

Let's walk each step.

### Parse

The browser receives HTML bytes and turns them into a DOM tree. It simultaneously discovers CSS resources (linked stylesheets, inline `<style>`) and parses those into a CSSOM.

Two things to know:

1. **HTML parsing is streaming.** The browser does not wait for the entire HTML to arrive. It parses tokens as they stream in and builds the DOM incrementally. This is why `<link rel="preload">` and putting critical CSS in `<head>` works — the browser discovers them early.
2. **CSS blocks rendering.** The browser will not paint anything until the CSSOM is ready, because rendering before CSS arrives would mean showing unstyled content and then re-rendering it. This is why CSS is *render-blocking* by default. Scripts interact with this in important ways, covered below.

### Style

For every DOM node, the browser computes its final styles — which selectors match, what the resulting property values are after the cascade. This is a surprisingly expensive step on complex pages with many selectors and deep trees. Tailwind's utility-class approach produces fewer, simpler selectors than a hand-written CSS file, which is one small reason it performs well.

### Layout

The browser computes the geometry of every visible box — position, width, height, line wrapping. This is a *global* computation in the sense that changing one element's size can affect siblings, descendants, and ancestors (inline-block content, flex children, grid items, etc.).

Layout is sometimes called "reflow." When you change something that forces layout to re-run — setting `width`, `height`, `top`, `left`, adding/removing a DOM node — that's triggering a reflow. Reflows are expensive and often cascade.

### Paint

For each element, the browser fills in pixels — text, colors, borders, shadows, gradients. Paint happens per-layer. If an element is on its own layer (see Composite below), repainting it does not force repainting other layers.

### Composite

Separate layers are assembled into the final image shown on screen. This step happens on the *compositor thread*, which is separate from the main thread. Moving a layer around — translating, scaling, fading — can often be done with no layout and no repaint, just by changing where the compositor places the pre-painted layer.

This is the single most important performance fact in the pipeline: **if your animation only changes `transform` or `opacity`, it can run entirely on the compositor thread, at 60fps, even while JavaScript is frozen**. Any other CSS property change forces the main thread to re-run layout or paint.

## What triggers what

There's a fantastic reference site — [csstriggers.com](https://csstriggers.com/) — that lists every CSS property and which stages (layout, paint, composite) it triggers when you change it. Skim it once, bookmark it forever.

The three-tier hierarchy, simplified:

| You change...      | It costs...                  | Examples                              |
| ------------------ | ---------------------------- | ------------------------------------- |
| `transform`, `opacity`, `filter` | Composite only           | Moving, scaling, fading               |
| `background-color`, `color`, `visibility`, `box-shadow` | Paint + composite | Hover colors, shadow changes          |
| `width`, `height`, `top`, `font-size`, `margin`, adding DOM nodes | Layout + paint + composite | Anything that changes geometry         |

When building animations, this directly dictates what to animate:

```css
/* BAD: animates `left`, triggers layout every frame */
@keyframes slide-bad {
  from { left: 0; }
  to { left: 100px; }
}

/* GOOD: animates `transform`, composite-only */
@keyframes slide-good {
  from { transform: translateX(0); }
  to { transform: translateX(100px); }
}
```

On a heavy page, the first version can stutter visibly. The second runs smoothly even under main-thread pressure.

## Layers and compositing

A "layer" is a bitmap the compositor can manipulate independently. Browsers create layers automatically for things like:

- Elements with `transform: translateZ(0)` or `transform: translate3d(...)`
- Elements with `will-change: transform` or `will-change: opacity`
- `<video>` and `<canvas>`
- Elements with CSS `position: fixed` (in many cases)
- Elements with 3D transforms or certain filters

**`will-change: transform`** is how you explicitly promise the browser "I'm going to animate this soon, please put it on its own layer in advance." It's a hint, not a guarantee, and it has costs:

- Each layer consumes memory (a bitmap the size of the element's bounding box).
- Too many layers (hundreds) and the compositor itself becomes a bottleneck.
- Layers that exist but don't actually animate are pure waste.

Rule of thumb: only add `will-change` right before an animation starts and remove it afterward. Never apply it blanket-style to a class that many elements share.

The older hack `transform: translateZ(0)` promotes to a layer as a side effect of enabling 3D transforms. It's still seen in the wild but `will-change` is the modern, intentional way.

## The main thread vs. the compositor thread

Browsers have multiple threads. The ones that matter for perf:

- **Main thread.** Runs JavaScript, parses HTML/CSS, computes styles, does layout, does paint. This is the bottleneck on most pages. When it's busy, everything queued behind it waits.
- **Compositor thread.** Assembles layers into frames, handles smooth scrolling, and can independently animate `transform` and `opacity` changes that are already on their own layer.
- **Raster threads.** Paint tiles in parallel, feeding into the compositor.
- **Network thread.** Handles HTTP requests (more in Chapter 2).

This is why a frozen main thread can still let you scroll smoothly (the compositor is doing that), and why a composited animation can keep running during a long JavaScript task. It's also why adding a `passive: true` event listener on scroll matters — a non-passive scroll listener forces the scroll to wait for the main thread before the compositor knows whether you called `preventDefault()`.

## Reflow and layout thrashing

The most common runtime performance mistake: reading a layout property, then writing one, then reading, then writing — in a loop.

```js
// BAD: forces a synchronous layout on every iteration
const items = document.querySelectorAll('.item');
items.forEach(item => {
  item.style.width = item.offsetWidth + 10 + 'px';
  // Reading offsetWidth forces layout.
  // Writing style.width invalidates layout.
  // Next iteration reads offsetWidth again → synchronous layout.
});
```

Each `offsetWidth` read *forces* the browser to run layout immediately, because the previous write may have invalidated it. A hundred items means a hundred synchronous layouts. On a complex page this can take hundreds of milliseconds.

The fix: batch reads and writes.

```js
// GOOD: read all, then write all
const items = document.querySelectorAll('.item');
const widths = Array.from(items).map(item => item.offsetWidth);
items.forEach((item, i) => {
  item.style.width = widths[i] + 10 + 'px';
});
```

Layout properties that force synchronous layout when read include: `offsetTop`, `offsetLeft`, `offsetWidth`, `offsetHeight`, `clientTop`, `clientLeft`, `clientWidth`, `clientHeight`, `scrollTop`, `scrollLeft`, `scrollWidth`, `scrollHeight`, `getBoundingClientRect()`, `getComputedStyle()`, and several more. Paul Irish's Gist on "What forces layout / reflow" is the canonical list. Memorize the common ones.

## The event loop and rendering

The browser's main thread runs an event loop, which on each iteration:

1. Picks one task from the task queue (e.g., a click handler, a `setTimeout` callback, a network response).
2. Runs it to completion.
3. Drains the microtask queue (promises, `queueMicrotask`).
4. *Possibly* runs a rendering step: `requestAnimationFrame` callbacks, style/layout/paint, then hands off to the compositor.
5. Loops.

Crucially, **rendering only happens between tasks**. If a task runs for 200ms, no frame is painted for 200ms. The user sees a frozen page.

At a screen refresh rate of 60Hz, the browser wants to produce a frame every 16.67ms. At 120Hz, every 8.33ms. Any task longer than that budget is eating into frame time. Any task longer than 50ms is a "long task" — a metric the browser explicitly tracks and which is the single strongest predictor of bad INP.

### The key scheduling APIs

You should know what each of these does, specifically:

- **`setTimeout(fn, 0)`** — schedules `fn` as a new macrotask. Runs after current microtasks drain, after any pending renders. Traditional "yield to the browser" trick.
- **`queueMicrotask(fn)`** — schedules `fn` as a microtask. Runs before any rendering, before any other task. Use for "I need to run this after the current synchronous code but before yielding."
- **`requestAnimationFrame(fn)`** — runs `fn` just before the next paint. Use for visual updates. The callback gets a high-resolution timestamp.
- **`requestIdleCallback(fn)`** — runs `fn` during idle periods. Can be starved if the main thread stays busy. Good for "this would be nice to do eventually" work.
- **`scheduler.postTask(fn, { priority })`** — the modern, explicit priority-based scheduler. Priorities: `user-blocking`, `user-visible`, `background`. Increasingly the right choice for non-trivial scheduling.
- **`scheduler.yield()`** — the new hotness (shipping in Chrome 129+). Lets you yield in the middle of a long task and continue on the next scheduling point, preserving priority. Replaces the `setTimeout(0)` yield idiom with something that doesn't drop to background priority.

### Yielding: the one trick you'll use a lot

Say you have a function that takes 200ms to process a list of 10,000 items. That's 200ms the main thread is frozen. An INP disaster.

You want to chunk it. The naive approach:

```js
async function processAll(items) {
  for (const item of items) {
    process(item);
  }
}
```

The yielding approach:

```js
async function processAll(items) {
  for (let i = 0; i < items.length; i++) {
    process(items[i]);
    if (i % 100 === 0) {
      // Yield every 100 items so the browser can handle input, paint, etc.
      await scheduler.yield(); // or: await new Promise(r => setTimeout(r, 0));
    }
  }
}
```

Between yields the browser can handle a click, run an animation frame, respond to scroll. The total time is slightly longer, but the page stays responsive. This pattern shows up constantly — virtualization, search indexing, data transformation, any CPU-heavy batch. We'll return to it in Chapter 4.

## The preload scanner

One last piece that surprises people: modern browsers don't just parse HTML top-to-bottom and discover resources in order. They also run a lightweight secondary parser called the **preload scanner** that scans ahead through the HTML, finds `<link>`, `<script>`, `<img>`, and other resources, and kicks off their requests *in parallel* while the main parser handles DOM construction.

This is why `<script>` at the top of `<head>` isn't as bad as it used to be — the preload scanner can spot subsequent resources even while the blocking script is waiting. But it's also why certain patterns defeat the scanner, notably:

- Resources discovered via JavaScript (`import()` a route, fetch an image URL from JSON).
- CSS `@import` chains (the scanner can find the first CSS file, but the import inside it isn't visible until the first is parsed).
- Background images set via CSS (the scanner can't parse CSS, so it doesn't know about them until the CSSOM is built).

Keeping critical resources discoverable by the preload scanner — declared directly in HTML — is a recurring theme in Chapter 3.

## Reading a Performance panel recording

Open Chrome DevTools, go to the Performance panel, click Record, reload your page, stop the recording. You're now looking at a flame chart and a bunch of tracks.

Key tracks, from top to bottom in a typical recording:

- **Frames.** Each rectangle is one rendered frame. Green = good frame (≤ 16.67ms). Yellow/red = long frame.
- **Timings.** Your marks, measures, and Core Web Vitals events (FCP, LCP, etc.) as labeled bars.
- **Interactions.** Each user interaction (click, key press) with its full input-delay → processing → presentation breakdown. This is where INP lives.
- **Main thread.** The big flame chart. Tasks are top-level rectangles; functions they call are the children below. Red triangles = long tasks. This is the most important track.
- **Network.** Requests as bars, colored by resource type, with their lifecycle stages.
- **Renderer.** Style, Layout, Paint, Composite events.
- **GPU.** What the GPU is doing.

The flame chart reads top-down for the call stack: top item is the outermost function, each child below is what it called. The horizontal axis is time. Width of a bar is how long that function took.

### What to look for on first read

1. **Long tasks.** Anything with a red triangle on its top-right corner. Click it to see the stack.
2. **The LCP event** in the Timings track. Click it to see which element was LCP.
3. **Any purple "Layout" bars.** Ideally layout happens once or twice during initial load. Dozens means trouble.
4. **The waterfall in the Network track.** Does the critical path make sense? What's blocking what?
5. **Idle time.** Gaps in the main thread flame chart mean the browser was waiting — usually for network. If you see large idle gaps before LCP, your problem is network, not JavaScript.

The first few times you open a recording, it will feel overwhelming. That's expected. It gets easier with reps — and this book is one long set of reps.

## Deliverable

Open Chrome DevTools Performance panel on your own app. Record a cold page load (use the "Network: Slow 4G, CPU: 4x slowdown" preset to simulate a mid-range mobile device). Then, without reading any answers off a screen:

1. Identify the **longest task** on the main thread. Click into its stack. What's the outermost frame? What's the deepest frame? Write it down.
2. Identify **one Layout event** and **one Paint event**. What triggered each?
3. Find the **LCP marker** in the Timings track. What element was the LCP? Was it blocked on a network request, a script, or layout?
4. Identify **at least one composited layer** by opening the Layers panel (More Tools → Layers). How many layers does your page have total?
5. Write a short paragraph answering: *"If I wanted to cut 200ms off this page load, where would I start, based on this trace?"*

The goal is not to fix anything yet. The goal is to be able to read the trace. You'll be doing this a lot, and if the chart still feels opaque at the end of this exercise, redo it before moving on. Every chapter from here assumes you can read a flame chart.

## What's next

Chapter 2 drops below the browser into the network stack. The rendering pipeline is bounded at the top by when bytes arrive, and bytes arrive at the speed of the network. You can't optimize what you can't see, and most engineers can't read a network waterfall well. We'll fix that.
