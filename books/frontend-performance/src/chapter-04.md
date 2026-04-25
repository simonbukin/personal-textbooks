# Chapter 4: JavaScript Performance and the Main Thread

This is where INP lives or dies. Loading is about bytes; runtime is about your JavaScript not holding the main thread hostage. A page that loads in 1.2s but blocks the main thread for 800ms every time the user types is a failure.

By the end of this chapter you should understand:

- What long tasks are, why they're the root cause of most INP problems, and how to break them up.
- What the three phases of an INP interaction are, and how to diagnose which one is slow.
- What `scheduler.yield()`, `postTask`, `useTransition`, and `useDeferredValue` do — specifically, what each is for.
- When web workers are the right tool.
- How to find and fix memory leaks.

## The cost of JavaScript

Every byte of JavaScript you ship has four separate costs:

1. **Network transfer** — download time. Linear in size. Mitigated by compression and caching.
2. **Parse** — the browser turns source into an AST. On modern V8 (~60MB/s on a mid-range phone), 300KB of JS is ~5ms, but this scales with the complexity of the code, not just size.
3. **Compile** — converting to bytecode and eventually machine code. Also CPU-bound, happens on first execution and on hot paths.
4. **Execute** — running it. This is the open-ended one; most of the pain is here.

The headline figure from Addy Osmani's "The Cost of JavaScript" updates (read the latest): on a median mobile device, parsing and compiling 1MB of JS takes something like 1–2 seconds of main-thread time. That time contributes nothing to what the user sees.

The implication is blunt: *ship less JavaScript*. Everything else is mitigation.

Next.js gives you several ways to ship less:

- Server Components (that don't ship to the client at all).
- `next/dynamic` to code-split components whose code isn't needed at first paint.
- `optimizePackageImports` in `next.config.js` to tree-shake certain problem libraries.

We cover each in Chapter 6. For now, your instinct should be: any client component that doesn't *need* to be a client component is shipping bytes for no reason.

## Long tasks

A "long task" is any task on the main thread that takes more than 50ms. The 50ms threshold isn't arbitrary — it's derived from the RAIL model (Response, Animation, Idle, Load), which targets 100ms as the maximum latency for an input to feel instant. If an input arrives during a 50ms task, it waits up to 50ms before processing starts — still within the budget. A 200ms task? That input could be waiting 200ms before it's even handled.

### Observing long tasks

```js
new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    console.log(`Long task: ${entry.duration}ms`, entry);
  }
}).observe({ type: 'longtask', buffered: true });
```

The Long Tasks API tells you *that* there's a long task. What it doesn't tell you is *what's in it* — the API doesn't give you call stacks or attribution.

### The Long Animation Frames API (LoAF)

Newer, much better. A Long Animation Frame is any rendering opportunity that took > 50ms (from the start of work to the next paint). LoAF gives you:

- Total duration.
- Scripts that ran during the frame (with source URLs and function names).
- How much time was spent in style, layout, paint.
- Where blocking came from.

```js
new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    console.log('LoAF:', {
      duration: entry.duration,
      renderStart: entry.renderStart,
      styleAndLayoutStart: entry.styleAndLayoutStart,
      scripts: entry.scripts,
    });
  }
}).observe({ type: 'long-animation-frame', buffered: true });
```

This is the API that modern INP debugging is built on. If your RUM supports LoAF (the `web-vitals` library does, as of the "attribution" build), use it.

## INP: the three phases

When a user clicks (or taps, or presses a key), the whole interaction has three phases:

```text
  [ Input delay ]  →  [ Processing time ]  →  [ Presentation delay ]
         ↑                      ↑                         ↑
  Between input and       Your handlers           Between handlers
  when a handler              running             finishing and the
  can start                                       next paint
```

- **Input delay.** The interaction fires, but the main thread is busy with something else. The event sits in the queue. Typical cause: a long task running at the moment of interaction.
- **Processing time.** Your event handlers run. If you have a `onClick` that sets state, this is where it runs, along with the React render it triggers.
- **Presentation delay.** Handlers are done, React has computed the new UI, but the browser still has to do style, layout, paint, composite. Usually short, but can balloon if you've invalidated lots of layout.

INP is the total: input delay + processing + presentation. You need to know *which phase* is slow to fix it.

### Diagnosing each phase

1. **High input delay.** The main thread was busy. Look for long tasks happening around the interaction. Often third-party scripts, hydration work, or a long useEffect initializing.
2. **High processing time.** Your handlers are slow. Profile them directly. Usually:
   - Synchronous state updates triggering huge re-renders.
   - Setting state in a loop.
   - Running an expensive calculation before yielding.
3. **High presentation delay.** You updated a ton of DOM. Look at the commit phase. Usually fixable with virtualization or by isolating the re-render to a smaller subtree.

The Performance panel in Chrome DevTools shows this breakdown directly. Click any interaction in the Interactions track and you see a bar with the three phases labeled.

## Breaking up long tasks

The fundamental move: when you have work that takes > 50ms, don't do it all in one go. Yield to the browser between chunks.

### The scheduling API hierarchy

- **`setTimeout(fn, 0)`** — works, but it drops your task to the bottom of the queue and loses priority information. Classic "yield" trick, inferior now.
- **`await new Promise(r => setTimeout(r, 0))`** — same thing but awaitable.
- **`scheduler.postTask(fn, { priority })`** — schedule explicitly. Priorities are `user-blocking` (runs ASAP), `user-visible` (default, feels interactive), `background` (when idle).
- **`scheduler.yield()`** — the modern winner. Yields control, preserves priority, resumes continuation in the queue. Supported in Chrome 129+, Edge, polyfilled in older.
- **`requestIdleCallback(fn)`** — runs when the browser is idle. Good for truly deferrable work but can be starved for tens of seconds.
- **`isInputPending()`** — "is there a pending user input?" Call it in a long loop and yield if true. Works but more manual than `scheduler.yield()`.

### The yield-in-a-loop pattern

Here's a canonical example: processing a large array.

```js
// The blocking version
function processAll(items) {
  const results = [];
  for (const item of items) {
    results.push(expensiveTransform(item));
  }
  return results;
}
```

If `items.length` is 10,000 and each `expensiveTransform` takes 0.05ms, total is 500ms. The main thread is frozen for 500ms. Every interaction during that time sits in the queue.

```js
// The yielding version
async function processAll(items) {
  const results = [];
  for (let i = 0; i < items.length; i++) {
    results.push(expensiveTransform(items[i]));

    // Every 100 items, yield so the browser can do other work
    if (i % 100 === 0 && i > 0) {
      await scheduler.yield();
    }
  }
  return results;
}
```

Same total work. Interactions stay responsive. Frame rate doesn't tank. Total wall-clock time is marginally longer because of the yields, but the user experience is dramatically better.

When you have a large batch of computation on the main thread (virtualization, search indexing, data transformation, spreadsheet recalc), this is the pattern you reach for.

### Debounce vs. throttle, precisely

Both of these are for rate-limiting handlers, but they're not interchangeable.

- **Debounce:** wait until the user stops doing the thing, then run once. Use for: search-as-you-type (only query when typing pauses), resize listeners.
- **Throttle:** run at most once per N milliseconds, regardless of how often called. Use for: scroll listeners, mousemove, any high-frequency event where you want periodic updates.

Wrong choice costs you either responsiveness (debounce where throttle is needed — scroll feels laggy) or wasted work (throttle where debounce is needed — querying on every keystroke).

## React's contribution: transitions and deferred values

React 18+ gives you two hooks that make yielding much nicer, *within* React's rendering model.

### `useTransition`

Marks a state update as non-urgent. React can interrupt it to handle more-urgent updates (like typing in an input).

```jsx
const [isPending, startTransition] = useTransition();
const [query, setQuery] = useState('');

const handleChange = (e) => {
  setQuery(e.target.value);  // urgent — keeps input responsive
  startTransition(() => {
    setResults(search(e.target.value));  // non-urgent — can be interrupted
  });
};
```

While the transition is running, the input stays responsive because React can throw away the in-progress render and start over if the user types again.

### `useDeferredValue`

Similar mental model, different ergonomics. You get a *deferred* version of a value that React updates in the background.

```jsx
const [query, setQuery] = useState('');
const deferredQuery = useDeferredValue(query);

return (
  <>
    <input value={query} onChange={e => setQuery(e.target.value)} />
    <ExpensiveList query={deferredQuery} />
  </>
);
```

`query` updates immediately (so the input is responsive). `deferredQuery` lags behind, but the expensive list only re-renders when the deferred value "catches up" — on idle, after the urgent updates settle.

### When to use which

- **`useTransition`** when *you're writing the state setter* and can wrap it. Gives you `isPending` for free (show a spinner during the background work).
- **`useDeferredValue`** when you're *consuming* a value and the producer is elsewhere. Also good for passing down to memoized children that are expensive.

Both require the expensive child to be wrapped in `React.memo` or otherwise cheap to re-render with the unchanged deferred value. Otherwise you get no benefit.

## Memory: leaks, bloat, and finding them

Memory isn't a Core Web Vital, but in long-lived single-page apps, memory leaks become INP problems. GC pauses can be dozens of milliseconds. A page that leaks until Chrome starts throttling it feels terrible.

### The vocabulary

- **Heap size** — total JS memory in use.
- **Shallow size** — size of an object itself, not counting what it references.
- **Retained size** — the size of everything that becomes garbage if this object is collected. The thing you actually care about.
- **Detached DOM node** — a DOM node no longer in the document but still referenced from JavaScript. Classic leak.

### Common React leak patterns

1. **Event listeners not cleaned up.**

   ```jsx
   useEffect(() => {
     const handler = () => { /* ... */ };
     window.addEventListener('resize', handler);
     return () => window.removeEventListener('resize', handler);  // ← Don't forget
   }, []);
   ```

2. **Timers/intervals not cleaned up.**

   ```jsx
   useEffect(() => {
     const id = setInterval(tick, 1000);
     return () => clearInterval(id);
   }, []);
   ```

3. **Subscriptions retained after unmount.** Any external store (websocket, observable, event emitter) needs an unsubscribe in the cleanup.

4. **Closures over large objects.** A small callback captures a large parent scope and gets held by a long-lived subscription. Look for `useEffect`/`useCallback` that close over big chunks of data.

5. **Large objects stuck in refs or context.** State that's never updated but also never released because the context provider outlives the data.

### Finding leaks in DevTools

1. Open DevTools, go to Memory tab.
2. Take a heap snapshot.
3. Perform some action (navigate, open a modal, interact).
4. Perform the inverse (navigate back, close the modal, stop interacting).
5. Force GC (trash icon).
6. Take another snapshot.
7. Compare snapshots (use the "Comparison" view).

If "Delta" shows objects that should have been freed but weren't, those are your leaks. Sort by retained size. Click an object to see what's holding it.

Use the "Detached DOM" view to find orphaned DOM nodes directly — if you see thousands of them, a component is leaking refs.

## Web workers: CPU-bound work off the main thread

For genuinely CPU-heavy computation — image processing, CSV parsing, cryptography, heavy data transformations — web workers are the right tool. They run on a separate thread with a separate event loop. The main thread stays responsive.

Workers have real limitations:

- No DOM access. Workers can't touch `document` or `window`.
- Communication via `postMessage` (structured clone or transfer).
- Transferring large data is cheap (zero-copy) only if you use `Transferable` objects (ArrayBuffer, MessagePort, etc.); otherwise it's a deep clone.

### Comlink

Raw `postMessage` is ergonomically miserable. [Comlink](https://github.com/GoogleChromeLabs/comlink) wraps it in a proxy so you can call worker functions like regular async functions.

```js
// worker.js
import { expose } from 'comlink';
expose({
  async parseCSV(text) {
    // ... heavy work ...
    return parsed;
  }
});

// main.js
import { wrap } from 'comlink';
const worker = wrap(new Worker(new URL('./worker.js', import.meta.url)));
const parsed = await worker.parseCSV(csvText);  // runs on the worker thread
```

Rule of thumb for when to reach for a worker: if a computation takes more than 200ms on a mid-range phone, and it doesn't need DOM access, put it in a worker.

### Next.js and workers

Next.js supports workers via standard `new Worker(new URL(...))` syntax. You can also use `next/dynamic` to lazy-load worker-heavy modules. Be aware that Server Components can't use workers (no `window`), so this is a client-side tool.

## Profiling with the Performance panel: interaction-focused

For INP specifically, the workflow is:

1. Open DevTools → Performance.
2. Throttle CPU (6x slowdown simulates a mid-range phone).
3. Throttle Network (Fast 4G for baseline).
4. Click Record.
5. Perform the interaction you want to debug.
6. Stop.
7. Look at the Interactions track. Click the interaction.

The panel shows the three phases visually:

- Input delay — the bar from the event arrival to the start of processing.
- Processing — the bar during handler execution (you can see the stack below).
- Presentation — the bar from end of handler to next paint.

### Reading the commit phase

For React apps, the interesting part is often the commit phase — the moment React applies its changes to the DOM. Look for:

- Purple "Layout" blocks right after your handler. These are forced layouts. Probably from code reading `offsetWidth` after mutating.
- "Recalc style" blocks. Can balloon if you changed many elements.
- Paint bars. Usually small, but big paints suggest something like a huge canvas redraw.

### The React DevTools Profiler

Complementary to the browser Performance panel. It specifically shows you:

- Which components rendered on a given commit.
- Why each one rendered (props changed, state changed, parent rendered, context changed, hooks changed).
- How long each component's render took.

Use the browser Performance panel to see *the main thread as a whole*. Use the React Profiler to see *what React was doing specifically*. Both, every time.

## What not to worry about

A short list of things engineers optimize that don't matter:

- **Micro-optimizing JS** (for loop vs. forEach, ternary vs. if). The difference is typically nanoseconds; the bottleneck is elsewhere.
- **Avoiding small function calls** for "inlining" purposes. V8 inlines most of this for you.
- **Prematurely memoizing** (`useMemo`, `useCallback`) every value. Usually neutral or negative, especially with React Compiler. Measure before optimizing.
- **Arguing about immutable-update library performance.** Immer, immutable.js, and hand-written spreads are all fine for 99% of use cases.

What *does* matter, broadly:

- Shipping less JavaScript.
- Not doing synchronous work > 50ms on the main thread.
- Not re-rendering huge trees for small changes.
- Not leaking memory.

Stick to those and the micro-stuff usually takes care of itself.

## Deliverable

Pick three of the most common interactions in your app (opening a modal, typing in a search, clicking a tab, etc.). For each:

1. **Profile it.** Performance panel, CPU 6x slowdown, click through the interaction.
2. **Identify the INP phase breakdown.** Input delay? Processing? Presentation?
3. **Diagnose the slow phase.** Long task before the interaction? Huge render tree? Forced synchronous layout in the commit?
4. **Fix one.** Break up a task with `scheduler.yield`, wrap a state update in `useTransition`, memoize a component, virtualize a list, whatever the cause requires.
5. **Measure the before/after.** The Performance panel shows INP per interaction. Run three times each and compare medians.

Additionally: instrument your app with the `web-vitals` library's attribution build if you haven't. Ship INP data (with attribution — the LoAF scripts, the interaction target, the phase breakdown) to your analytics. You'll reference it in Chapter 8 when we cover RUM properly.

```jsx
// app/web-vitals.jsx
'use client';
import { useEffect } from 'react';
import { onINP } from 'web-vitals/attribution';

export function WebVitals() {
  useEffect(() => {
    onINP((metric) => {
      // Send to your analytics
      console.log('INP', metric.value, metric.attribution);
      // metric.attribution includes: interactionTarget, inputDelay, processingDuration,
      // presentationDelay, longAnimationFrameEntries, loadState
    });
  }, []);
  return null;
}
```

## What's next

Chapter 5 goes into React itself: the rendering model, reconciliation, when and why components re-render, and the toolkit of `memo`, `useMemo`, `useCallback`, context, and compiler-assisted optimizations. Everything in this chapter was about the main thread as a resource; the next chapter is about what React does with that resource.
