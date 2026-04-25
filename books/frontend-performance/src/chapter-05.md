# Chapter 5: The React Rendering Model

Most React developers know the API. Fewer know the machine. The difference between knowing `useState` and knowing *when and why* React re-renders — that's the difference between optimizing by vibe and optimizing by first principles.

This chapter is the mental model. It's what you need to predict, before profiling, whether a change will help or hurt.

## Two phases: render and commit

A React update has two phases.

**The render phase** is pure (in the functional sense): React calls your components, each returns JSX, React builds a new tree. Nothing touches the DOM yet. React can interrupt and discard this work at any point. In concurrent mode, it does.

**The commit phase** is where React applies the computed changes to the DOM. It runs synchronously. It cannot be interrupted. It's where refs are attached, effects fire, and the browser gets asked to update layout.

When people say "React is slow," they almost always mean the render phase — too many components rendering, or rendering too often. When they say "the DOM update was slow," they often mean the commit phase — too many nodes changed at once, or the update forced a bunch of layout.

Both matter. The tools to diagnose each are different (Profiler for render, Performance panel for commit).

## What causes a re-render?

This is the question everyone should be able to answer cold. A React component re-renders when any of the following happens:

1. **Its state changes** (a `useState` setter is called with a different value, a `useReducer` dispatches an action).
2. **Its parent re-renders** — *even if its props don't change*. By default, child components re-render when parents do. This is the one that burns most people.
3. **A context it consumes has a new value.** Every consumer of that context re-renders.
4. **A subscribed store value changes** (Zustand, Redux, Jotai, `useSyncExternalStore`).

What does *not* cause a re-render:

- A prop changing by reference only, if the component is wrapped in `React.memo` and the previous/new props are shallowly equal.
- A ref value changing (refs are mutable without triggering renders — by design).
- A CSS change.

The second point is subtle enough that I'll say it again: **a parent re-rendering causes all children to re-render by default, regardless of whether their props changed**. Optimizing this is what `React.memo` is for.

### State updates and bailout

If you call `setState(nextValue)` and `Object.is(nextValue, currentValue)` is true, React bails out — no re-render. But this only catches reference-equal updates.

```jsx
// Bails out — same number
const [n, setN] = useState(5);
setN(5);  // no re-render

// Does re-render — different object reference, even though contents equal
const [obj, setObj] = useState({ a: 1 });
setObj({ a: 1 });  // re-renders; different reference
```

This is why immutable updates with `setState({ ...old, a: 2 })` need you to be deliberate — you're creating a new reference, which is sometimes what you want and sometimes unnecessary.

## Reconciliation

When React renders, it produces a tree. On the next render, it has two trees (old and new) and needs to figure out what changed in the DOM. This is reconciliation.

The algorithm is roughly:

- If the type at a given position is the same (`<div>` and `<div>`, or `Foo` and `Foo`), reuse the DOM node and update props.
- If the type differs (`<div>` vs. `<span>`, or `Foo` vs. `Bar`), throw away the old subtree and mount the new.
- For lists of siblings, use the `key` prop to match old and new items.

The practical consequence: **changing the type of a component unmounts its whole subtree**. Don't conditionally swap between two different component types rendering similar content — wrap them in a shared parent instead, or reuse the type.

```jsx
// Bad: swapping types unmounts state on every toggle
{isEdit ? <EditableView data={x} /> : <ReadOnlyView data={x} />}

// Better: one component that handles both modes
<View mode={isEdit ? 'edit' : 'read'} data={x} />
```

### Keys actually matter

`key` isn't just a warning suppressor. It's how React matches old and new items in a list. The wrong key causes unnecessary unmounts and mounts — losing state, losing DOM nodes, losing focus.

```jsx
// Bad: index as key. If you insert at position 0, everyone gets unmounted.
{items.map((item, i) => <Row key={i} data={item} />)}

// Good: stable ID from the data
{items.map(item => <Row key={item.id} data={item} />)}
```

Index as a key is acceptable only for truly static lists that never reorder or change length. Almost never, in other words.

## `React.memo`, `useMemo`, `useCallback`

The memoization trio. Each has a specific use, and each has a cost.

### `React.memo`

Wraps a component. Skips the render if its props haven't changed by shallow equality.

```jsx
const ExpensiveChild = React.memo(function ExpensiveChild({ data }) {
  // ... expensive rendering
});
```

For `React.memo` to do anything, the parent must pass stable references. If you pass a new object or function on every render, shallow equality fails and memo doesn't save you.

```jsx
function Parent() {
  // This creates a new object every render.
  // Even if you wrap ExpensiveChild in React.memo, it re-renders every time.
  return <ExpensiveChild config={{ theme: 'dark' }} />;
}
```

Fix: hoist the object (for static values) or wrap in `useMemo` (for derived values).

### `useMemo`

Caches the result of a computation between renders, re-running only when dependencies change.

```jsx
// Expensive derivation cached
const sortedItems = useMemo(() => items.toSorted((a, b) => a.x - b.x), [items]);

// Stable object reference for a memoized child
const config = useMemo(() => ({ theme, layout }), [theme, layout]);
```

Two uses: memoizing *expensive* computations, and memoizing *references* for passing down to memoized children.

### `useCallback`

The function version of `useMemo`. Literally: `useCallback(fn, deps)` is equivalent to `useMemo(() => fn, deps)`.

```jsx
const handleClick = useCallback((id) => {
  dispatch({ type: 'select', id });
}, [dispatch]);

// Now handleClick is stable across renders as long as dispatch is.
// Safe to pass to a memoized child.
```

### The cost of memoization

Every `useMemo` and `useCallback`:

- Adds bookkeeping overhead (dependency comparison each render).
- Retains the previous value in memory.
- Adds a call site that has to be kept in sync when dependencies change.

For cheap operations, memoizing is a *pessimization* — you spend more on the comparison than on the work you skip. Rule of thumb:

- Memoize computations that are genuinely expensive (> a few ms).
- Memoize values that are passed to memoized children.
- Don't memoize primitives, trivial derivations, or things that never reach a memoized boundary.

### React Compiler changes this calculus

React Compiler (formerly "React Forget") is a build-time tool that automatically memoizes. When enabled, it analyzes your components and inserts the equivalent of `useMemo` and `useCallback` around values and functions that should be stable.

As of late 2024 / early 2025, React Compiler is in general release and usable. If your codebase has it enabled, most manual `useMemo` and `useCallback` becomes redundant. You can write simpler code and let the compiler memoize.

The compiler does NOT wrap components in `React.memo` automatically (that changes semantics). You still do that by hand — but you don't need to fight with stabilizing references as much because the compiler does it.

Check whether your Next.js project has it enabled:

```js
// next.config.js
module.exports = {
  experimental: {
    reactCompiler: true,
  },
};
```

If enabled, you can safely remove most hand-rolled `useMemo` and `useCallback` for reference stability. Keep them only for genuinely expensive computations (which the compiler won't find on its own).

## Context: the re-render trap

Context is often a performance footgun. Every consumer of a context re-renders when the value changes — by reference. And the usual pattern of "put all my app state in one context" means every state change re-renders every consumer.

```jsx
// BAD
const AppContext = createContext();

function Provider({ children }) {
  const [user, setUser] = useState();
  const [theme, setTheme] = useState();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  // New object every render.
  // Every consumer re-renders on every Provider render.
  const value = { user, setUser, theme, setTheme, sidebarOpen, setSidebarOpen };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}
```

The fixes, in order of increasing intervention:

### 1. Split contexts by update frequency

```jsx
const UserContext = createContext();
const ThemeContext = createContext();
const LayoutContext = createContext();
```

Consumers of `UserContext` don't re-render when the theme changes. Easy, high-leverage.

### 2. Memoize the value

```jsx
const value = useMemo(() => ({ user, setUser }), [user, setUser]);
```

Prevents a new object reference on every Provider render. Only helps if the *values* are also stable.

### 3. Split state and dispatch

```jsx
const StateContext = createContext();
const DispatchContext = createContext();

// Consumers that only need dispatch don't re-render on state change.
```

Redux-like pattern. Very effective when you have components that trigger updates but don't read state.

### 4. Use an external store

For anything complex, reach for Zustand, Jotai, or another store. These libraries implement *selector-based* subscriptions — components subscribe to specific slices and only re-render when those slices change.

```jsx
// Zustand
const useStore = create(set => ({
  user: null,
  theme: 'light',
  setTheme: (t) => set({ theme: t }),
}));

// Only re-renders when theme changes
const theme = useStore(state => state.theme);
```

Context is great for static or slow-changing values (theme, auth, locale). For frequently-updated state, an external store with selectors is almost always better for performance.

### 5. `useContextSelector`

The `use-context-selector` library lets you subscribe to a derived slice of context, avoiding re-renders when other parts change. The React team has proposed native `useContextSelector` but as of writing it's not shipped.

## Concurrent React: the short version

Concurrent rendering is the set of features that let React interrupt, pause, and resume renders. Shipped with React 18, refined in 19.

The things to know:

- **Transitions** (`useTransition`, `useDeferredValue`) — already covered in Chapter 4. Mark updates as interruptible.
- **Suspense** — lets components declaratively wait for data. A Suspense boundary shows a fallback while its children are loading. Critical to the App Router streaming model (Chapter 6).
- **Automatic batching** — multiple state updates in the same tick are batched into a single re-render, even across promises and timeouts. As of React 18, batching is automatic.
- **`use()` hook** — React 19's new hook for unwrapping promises and context inside components. Suspends if the promise isn't resolved.
- **Server Components** — covered in depth in Chapter 6. They render on the server and don't ship JS to the client.

### The mental model for transitions

React maintains the idea of "priority." Urgent updates (input, clicks) run immediately. Transitions run at lower priority and can be thrown away if a new urgent update arrives.

This is key to responsiveness: the user's typing keeps up with their keystrokes because the transition containing the expensive work can be abandoned and restarted.

## Lists and virtualization

Rendering 10,000 rows is slow. Rendering 50 rows and pretending there are 10,000 is fast. That's virtualization.

The idea: only render the items currently in view (plus a small buffer). As the user scrolls, mount and unmount rows dynamically.

Recommended libraries:

- **TanStack Virtual** (formerly react-virtual) — headless hooks, very flexible, framework-agnostic.
- **react-virtuoso** — more batteries-included, handles variable row heights and message-list patterns well.

```jsx
// TanStack Virtual sketch
import { useVirtualizer } from '@tanstack/react-virtual';

function List({ items }) {
  const parentRef = useRef();
  const rowVirtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 40,
    overscan: 5,
  });

  return (
    <div ref={parentRef} style={{ height: 600, overflow: 'auto' }}>
      <div style={{ height: rowVirtualizer.getTotalSize(), position: 'relative' }}>
        {rowVirtualizer.getVirtualItems().map(virtual => (
          <div
            key={virtual.key}
            style={{
              position: 'absolute',
              top: 0,
              transform: `translateY(${virtual.start}px)`,
            }}
          >
            {items[virtual.index].name}
          </div>
        ))}
      </div>
    </div>
  );
}
```

The threshold at which virtualization becomes worthwhile is lower than people think. On a mid-range phone, 200 moderately complex rows is already noticeable. 1000 is a problem. Virtualize anything that could reasonably grow to > 100 rows.

Caveat: virtualization breaks Ctrl-F page-search (the items aren't in the DOM). For text-heavy content where search matters, consider `content-visibility: auto` instead (Chapter 7).

## The React Profiler

React DevTools has its own Profiler tab. It's the best tool for answering "why did this component render?"

The workflow:

1. Install React DevTools.
2. Open the Profiler tab.
3. Click record, do the interaction, stop.
4. Each "commit" is a flame graph showing which components rendered.
5. Click a component to see *why* it rendered: "Props changed", "Hooks changed", "Parent rendered", etc.

The killer feature: turn on "Record why each component rendered" in the Profiler settings (the gear icon). Now each component shows its render reason. Unexpected re-renders jump out.

What to look for:

- Components rendering with no prop changes (their parent rendered; candidate for `memo`).
- Components re-rendering because of a specific prop (that prop is unstable; memoize it).
- A deep subtree re-rendering because a shallow context changed (split the context or use a store).

## A note on pattern matching vs. measuring

A subtle trap: once you learn all these patterns, it's tempting to apply them preemptively. Memoize everything, split every context, virtualize every list.

Resist. Most of these have costs. The right discipline is:

1. **Ship the simple thing.**
2. **Measure.** Profiler, Performance panel, RUM.
3. **If there's a problem, find it precisely.**
4. **Apply the specific fix.**
5. **Measure again.**

Patterns you apply without measurement often trade one perf problem for a different one (memoization overhead, fragmented state, harder-to-read code). Know them all, use them when you see the evidence.

## Deliverable

Two parts this time.

**Part 1: Profile a real interaction.**

Pick an interaction in your app that feels laggy (or that you suspect is). Use the React Profiler to capture a commit. Identify:

- How many components rendered?
- Which ones rendered "unexpectedly" (prop reference changed but value didn't, or parent re-rendered for no meaningful reason)?
- Fix one. Typical fix: wrap a component in `React.memo` and stabilize its props, or split a context.
- Re-profile and confirm the fix.

**Part 2: Write an internal doc.**

*"When to memoize in our codebase."*

Include:

- Whether React Compiler is enabled (if not: should it be?).
- What `useMemo` and `useCallback` are actually doing in the common case.
- When `React.memo` is worth it.
- A short list of patterns your team should avoid (creating objects in render and passing them to memoized children, using index as key, one-big-context).
- Examples from your actual code, with before/after.

Make this doc the first thing you point new hires to. The conceptual clarity saves a *lot* of bad code review discussions.

## What's next

Now you have the browser, the network, the main thread, and React's model. Chapter 6 is the big one: Next.js. Rendering strategies, the App Router, Server Components, the caching model, bundling, images, fonts, scripts, edge vs. node — all of it, with opinions.
