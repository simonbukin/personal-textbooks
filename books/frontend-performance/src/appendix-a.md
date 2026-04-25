# Appendix A: Reading List

The curated list. Everything here is worth your time. Prioritized by how foundational it is.

## Books

**High Performance Browser Networking** — Ilya Grigorik (O'Reilly). Free to read at [hpbn.co](https://hpbn.co). The definitive reference for how the network actually works, from TCP up through HTTP/2 and WebRTC. Dense. Worth every page. If you read one book from this list, make it this one. (The canonical edition is from 2013 and predates HTTP/3, but the foundational material is still entirely correct.)

**Designing for Performance** — Lara Hogan (O'Reilly, 2014). Free at [designingforperformance.com](http://designingforperformance.com). Older, but the "how to set up a performance culture" material is timeless. Short, non-technical parts of it are great to hand to PMs and designers.

**Image Optimization** — Addy Osmani (Smashing Magazine). The definitive guide to modern image pipelines: formats, responsive images, lazy loading, CDNs, next/image-style tooling. Approachable. Update your whole image strategy after reading this.

**Web Performance in Action** — Jeremy Wagner (Manning). Good broad introduction if someone on your team is new to perf. More practical than theoretical. Aimed at a different audience than you at this point, but worth recommending when you need to onboard someone.

## Blogs and people to follow

These are the voices. You don't have to read every post, but subscribe to their feeds (or follow them on whatever social platform still works) so new content drifts past you.

**Addy Osmani** ([addyosmani.com](https://addyosmani.com)). Chrome DevRel. Core Web Vitals, image optimization, JavaScript cost. The "Cost of JavaScript" annual update alone is required reading.

**Harry Roberts** ([csswizardry.com](https://csswizardry.com)). Deep CSS performance material. Dense, opinionated, often revisiting and refining earlier posts. His perf articles are short masterclasses.

**Jake Archibald** ([jakearchibald.com](https://jakearchibald.com)). Chrome DevRel emeritus. Service workers, images, the event loop, cache semantics. Writes rarely but every post is a banger.

**Paul Calvano**. HTTP Archive, caching, CDN behavior. Deep data-driven analysis.

**Rick Viscomi** and **Barry Pollard**. Web Almanac chapter authors, Core Web Vitals authorities. Both post regular updates on real-world web performance data.

**Tim Kadlec** ([timkadlec.com](https://timkadlec.com)). Third-party scripts, performance budgets, the business of perf.

**Noam Rosenthal**. Interop work, View Transitions, the CSS WG perspective on perf.

**Philip Walton** ([philipwalton.com](https://philipwalton.com)). `web-vitals` library author. Attribution, INP, RUM methodology.

**Alex Russell** ([infrequently.org](https://infrequently.org)). Sharp opinions about the state of the web, especially around JS weight and mobile. You won't agree with all of it. That's not the point.

**Mark Erikson** (Redux maintainer). React rendering perf, state management tradeoffs. Extremely thorough technical posts.

**Dan Abramov** and the React team. Not a blog per se, but React docs plus the React team's occasional posts shape the mental model directly.

**Lee Robinson** and **Delba de Oliveira** (Vercel/Next.js). The authoritative voices on App Router semantics. Their talks from Next.js Conf are worth watching.

## Newsletters

**Perf.email** — curated weekly perf links. Low volume, high signal.

**PerfPlanet Calendar** — every December, a daily perf post from a different author. Archived by year. Huge trove.

**Web Performance Today** — less frequent, more focused on the business/measurement side.

## Podcasts and conferences

**PerfNow** — annual conference in Amsterdam. Recordings on YouTube. The premier deep-technical perf conference.

**performance.now()** (same event, the conference name with the parens). All videos free online.

**Chrome Developers YouTube channel**. Highly variable but the Core Web Vitals / performance deep-dives are good.

## Reference material

**HTTP Archive Web Almanac** ([almanac.httparchive.org](https://almanac.httparchive.org)). Published annually. A data-driven survey of the state of web development, with dedicated chapters on JavaScript, CSS, images, caching, performance. When someone asks "is this normal?" — Web Almanac usually has the answer.

**chromestatus.com**. Chrome's feature-status tracker. The authoritative source for "is this API shipped yet, in which browsers, behind what flags?" If you're investigating a frontier API, start here.

**web.dev** (Google). Curated guides, often the canonical resource for a specific feature. Their Core Web Vitals material and their Learn Performance course are both excellent.

**MDN**. The reference. Always accurate on standards. Often has performance notes embedded in API docs.

**caniuse.com**. Browser support data. Check before using anything not-yet-universal.

**csstriggers.com**. Every CSS property's cost (layout/paint/composite) on change. Bookmark.

**bundlephobia.com**. "How big is this npm package?" Check before you install anything.

## Primary sources

When a definition matters — "what exactly is INP?", "how is CLS computed?" — the W3C and WICG specs are the ground truth. They're not always readable, but when you need to settle an argument, go to the source.

- [Event Timing API](https://www.w3.org/TR/event-timing/) — INP.
- [Layout Instability API](https://wicg.github.io/layout-instability/) — CLS.
- [LCP API](https://www.w3.org/TR/largest-contentful-paint/).
- [Long Animation Frames API](https://wicg.github.io/long-animation-frames/) — LoAF.
- [Fetch Standard](https://fetch.spec.whatwg.org/) — `fetch()` semantics.
- [Web Performance Working Group](https://www.w3.org/webperf/).

## What to read this quarter

If you want a concrete reading plan for the next 3 months alongside this book:

**Month 1**
- Skim High Performance Browser Networking, Parts I–II (network fundamentals through HTTP).
- Read the latest Addy Osmani "Cost of JavaScript."
- Read every Harry Roberts post from the last year.

**Month 2**
- The most recent HTTP Archive Web Almanac's chapters on JavaScript, CSS, and performance.
- Philip Walton's posts on INP attribution and the web-vitals library.
- All of web.dev's Core Web Vitals guides.

**Month 3**
- Follow up on one or two frontier topics (Speculation Rules, View Transitions, Compression Dictionary Transport) with the spec + implementation posts.
- Read RFCs or talks from your framework's maintainers on where the framework is headed.

After three months, you'll have the breadth to hold your own on any perf topic. After a year of the weekly perf review you set up in Chapter 8, you'll have the depth.
