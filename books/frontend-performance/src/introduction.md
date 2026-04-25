# Introduction

## Who this is for

You're a frontend engineer. Your team ships a Next.js + Tailwind application. You want to be the person on the team who *owns* performance — the one everyone asks before a launch, the one who spots regressions in a PR at a glance, the one who can diagnose a slow page from a WebPageTest waterfall in 60 seconds flat.

This book is a curriculum, not a reference. It's designed to be read in order, worked through in practice, and revisited. Every chapter has concepts, worked examples with real code, and a deliverable — something you actually do, in your actual codebase, to prove to yourself you've internalized the material.

## How to use this book

**Read in order, the first time.** The chapters build on each other. Browser internals (Chapter 1) underpin the network discussion (Chapter 2). The network underpins the critical rendering path (Chapter 3). React rendering (Chapter 5) only makes sense after you understand how the main thread works (Chapter 4). Next.js (Chapter 6) presupposes all of it.

**Do the deliverables.** Each chapter ends with one. Theory without application rots. These aren't homework problems — they're calibration exercises. If you can't do the deliverable, you don't know the material.

**Keep DevTools open constantly.** Performance is a measured discipline. Every claim in this book can be verified with the right tool. You should be opening the Performance panel, the Network panel, the Coverage tab, the Memory profiler, and WebPageTest traces weekly, then daily, until reading them is second nature.

**Budget 3–5 months.** At 1–2 weeks per chapter alongside a day job, that's the realistic timeline. You can go faster, but deliverables take time and the measurement habits need reps to form.

## How this is structured

- **Part I — Foundations.** The non-negotiables: what perf means, how the browser renders, how the network works, how to get the first paint fast.
- **Part II — Runtime.** JavaScript on the main thread, and the React rendering model built on top of it.
- **Part III — The Framework.** Next.js specifics — App Router, caching, rendering strategies, bundling — and CSS/Tailwind performance.
- **Part IV — Practice.** Measurement and RUM, frontier topics that separate experts from practitioners, and the meta-skill of getting performance work actually shipped.

## A note on currency

Web performance moves fast. Chrome ships features monthly. Next.js changes defaults between major versions. This book was written against the state of the web as of early 2026: React 19, Next.js 15, Tailwind v4, INP as a stable Core Web Vital, PPR shipping in Next.js, view transitions working cross-document. Treat dates and "newly shipping" claims as a snapshot. The underlying mental models — the rendering pipeline, the event loop, reconciliation, HTTP semantics — don't change. Those are what you're really learning.

## What success looks like

By the end of this book, you should be able to:

- Read a Performance panel flame chart and name every block within 60 seconds.
- Diagnose a bad LCP, INP, or CLS number from RUM attribution data alone, without needing to reproduce it locally.
- Explain the four Next.js caches, where each lives, and how to invalidate each — from memory.
- Predict, before profiling, whether a given React change will help or hurt rendering cost, and be right most of the time.
- Write a perf RFC that gets approved and shipped.
- Teach any of this to a teammate on a whiteboard.

Let's begin.
