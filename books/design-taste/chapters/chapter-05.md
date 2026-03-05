# Chapter 5: Interaction and Motion

*Animation is not decoration — it's information about state, relationship, and consequence.*

---

## Opening

Every interface has a static appearance and a dynamic behavior. The static appearance is what you see in screenshots: layout, typography, color. The dynamic behavior is what happens when you interact: buttons press, panels slide, pages transition, loading states animate.

Most interfaces get the static right and the dynamic wrong. The layout is considered. The typography is refined. Then interaction states are added as an afterthought — a hover effect here, a loading spinner there, a page fade-in because transitions are "nice." The motion has no system, no rationale, no relationship to the design's intent.

But motion is information. A sidebar that slides in from the left tells users "this content lives off-screen to the left." A modal that fades in from opacity zero tells users "this content was invisible and is now visible." A button that shrinks on press tells users "your input registered." Every animation is a micro-narrative: something was one way, now it's another way, and here's the story of that change.

When motion is treated as decoration, it decorates. When motion is treated as communication, it communicates. This chapter covers the mechanics — easing, duration, orchestration — but the real lesson is that motion choices are design choices. They shape how users understand your interface.

---

## Motion as Information

Without motion, state changes are jump cuts. A user clicks a button and suddenly a modal is on screen. Where did it come from? Is it connected to the button they clicked? Without any transition, the user has to mentally reconstruct what happened. Most users do this unconsciously and successfully, but the cognitive work is real.

Motion fills in the narrative. The modal scales up from the button's location, and the user sees the spatial relationship — the modal "emerged" from the button. A sidebar slides in from the left edge, and the user understands where the sidebar "lives" — off-screen to the left, available to slide back out. A list item slides out when deleted, and the items below slide up to fill the gap — the user sees the removal as a continuous process rather than a sudden rearrangement.

This is what Val Head, who wrote the defining book on interface animation, calls **motion as information architecture**. The animations aren't aesthetic choices (though they can be aesthetic). They're structural choices that communicate how the interface is organized in space and how elements relate to each other.

### Spatial Models

Every interface has an implicit spatial model — a sense of where things "are" even when they're not visible. Animation makes this model explicit.

A navigation drawer that slides in from the left establishes that the navigation exists in a space to the left of the content. If you also have a panel that slides in from the right, you've established a spatial model with three regions: left (navigation), center (content), right (secondary panel).

A modal that scales from the center establishes that modals exist "in front of" the page, in depth. They emerge from the page surface and will recede back into it.

A page transition that slides the new page in from the right establishes a linear spatial model — pages exist on a horizontal line, and moving between them is like flipping through a deck of cards.

These spatial models can be consistent or contradictory. A consistent model reinforces intuition: users understand where things are, even off-screen. A contradictory model creates confusion: if the menu sometimes slides from the left and sometimes fades in from nowhere, users lose track of the interface's spatial logic.

Choose a spatial model and make it consistent. When you animate, you're not just adding visual interest — you're teaching users how your interface is organized.

---

## Easing: The Physics of Feel

**Easing** describes how an animation's value changes over time. A ball dropping doesn't fall at constant speed — it accelerates due to gravity. A car doesn't instantly reach highway speed — it accelerates from zero. The physical world is full of acceleration and deceleration, and animations that ignore this feel robotic.

Linear motion — constant speed from start to finish — feels artificial. Nothing in the physical world moves linearly. When an interface element moves linearly, it feels mechanical, lifeless, like a robot sliding across the screen.

**Eased motion** follows curves that mimic physical behavior. The most common curves:

### Ease-Out

Fast start, slow finish. The element accelerates quickly at the beginning, then decelerates as it approaches its destination. Like a ball rolling to a stop, or a door swinging shut.

Ease-out is the right choice for elements *entering* the scene. They arrive quickly and settle into place. The deceleration at the end gives the animation a sense of landing — the element doesn't just stop, it comes to rest.

CSS: `cubic-bezier(0, 0, 0.2, 1)`

### Ease-In

Slow start, fast finish. The element moves slowly at first, then accelerates as it leaves. Like an object being pulled away by gravity, or a ball being thrown.

Ease-in is the right choice for elements *exiting* the scene. They hesitate momentarily, then accelerate away. This creates a sense of departure — the element was here, and now it's being pulled elsewhere.

CSS: `cubic-bezier(0.4, 0, 1, 1)`

### Ease-In-Out

Slow start, fast middle, slow finish. The element accelerates to a peak speed, then decelerates. Like a car pulling away from a stoplight, cruising, and pulling up to the next light.

Ease-in-out is the "safe default" — it works acceptably for most transitions. But it often feels mushy, lacking the crispness of ease-out or the dynamism of ease-in. For short transitions (under 300ms), ease-out usually feels better. Ease-in-out works better for longer, more pronounced transitions.

CSS: `cubic-bezier(0.4, 0, 0.2, 1)`

### Spring/Bounce

Spring easing overshoots the target, then settles back. Like a spring or a bouncing ball. This creates a physical, playful feeling — the element has weight and momentum.

Spring easing is excellent for interfaces that want to feel lively, physical, or game-like. It's less appropriate for serious, corporate, or data-heavy interfaces where gravitas matters more than playfulness.

Many frameworks (Framer Motion, React Spring) offer spring physics directly. In CSS, you can approximate bounce with custom bezier curves that dip below 0 or above 1, but true spring physics requires JavaScript.

### Choosing Easing as a Personality

The easing curve you choose is a personality choice. A product that uses ease-out everywhere feels efficient, decisive, no-nonsense. A product that uses springs everywhere feels playful, physical, alive. A product that uses linear motion feels... broken, usually, though there are avant-garde contexts where mechanical motion is deliberate.

Most interfaces benefit from consistent easing. Pick a standard ease-out for entrances, a standard ease-in for exits, and use them everywhere. The consistency creates a sense of coherent physics — a sense that this interface exists in a world with rules.

---

## Duration: The 50ms That Matters

If easing is *how* an animation moves, duration is *how long* it takes. Duration is measured in milliseconds, and the right duration depends on the animation's purpose.

### Guidelines by Animation Type

**Instant feedback (100-150ms):** Button presses, toggles, checkboxes, small state changes. These should feel immediate — the user does something, the interface responds instantly. Much longer and the interface feels sluggish. Much shorter and the animation is imperceptible.

**State transitions (200-300ms):** Accordion opens, tab switches, dropdown menus, tooltip appearances. These are meaningful state changes that benefit from visible motion — the user should see the change happen, not just see the result. 200ms is snappy; 300ms is comfortable.

**Page-level transitions (300-500ms):** Page navigation, modal entrances, panel slides. These are larger changes that deserve more prominent motion. The animation is part of the user's experience of moving through the interface. 300ms is brisk; 500ms is deliberate.

**Deliberate slow motion (500ms+):** Cinematic effects, loading indicators that communicate "this takes time," attention-grabbing animations that the user is meant to watch. Use rarely and intentionally. Anything over 500ms that isn't deliberate will feel slow.

**Sub-100ms:** Imperceptible. Below about 80ms, humans can't distinguish motion from instant change. There's no point animating at these durations.

### The Size Factor

Larger elements need longer durations. A small toggle switching states can animate in 100ms. A full-screen modal entering needs 300ms or more. The element has to travel farther — visually, the transition covers more pixels — and motion that's too fast for the distance feels jarring.

Conversely, short durations on small elements feel snappy. A 300ms toggle feels sluggish. A 150ms toggle feels responsive.

The rule of thumb: scale duration with visual distance. Small movements get short durations. Large movements get longer durations.

### The 50ms Sweet Spot

Between "snappy" and "jarring" is a narrow window. Consider a toggle switch. At 300ms, it feels sluggish — you've already moved on, but the UI is still catching up. At 200ms, it feels responsive — the switch moves briskly, arriving just as your attention returns to it. At 150ms, it feels snappy — the switch barely seems to move, just swaps state quickly. At 100ms, depending on the visual treatment, it might feel instant or it might feel jarring — like a jump-cut rather than a motion.

The difference between 150ms and 200ms is 50 milliseconds. That's imperceptible in isolation but perceptible in the motion. One feels snappy; one feels comfortable. Both are valid; neither is wrong. The choice is about the personality you want.

This 50ms precision is what separates considered motion from default motion. Most engineers set duration to whatever the framework suggests — 200ms or 300ms, doesn't matter much, right? But feel the difference. A 200ms accordion and a 250ms accordion feel different. A 150ms button and a 200ms button feel different. The difference might seem negligible in description, but it's palpable in experience.

---

## Orchestration: Choreographing Multiple Elements

When multiple elements animate simultaneously, they need choreography. Without coordination, simultaneous motion feels chaotic — a bunch of things moving independently. With coordination, it feels intentional — a system of elements moving in concert.

### Staggered Entrances

When multiple elements enter the scene — a list of cards, a grid of icons, a menu of items — stagger their entrance. Each element appears 30-60ms after the previous one, creating a cascade effect.

Staggered entrances read as "coordinated" rather than "simultaneous blob." The eye tracks the cascade, perceiving order and intention. Without stagger, a grid of 12 cards fading in simultaneously looks like a single surface materializing — less interesting, less intentional.

The stagger should be subtle. 30-50ms between elements is usually enough. More than 100ms feels slow and sequential rather than coordinated.

### Coordinated Exits and Entrances

When one element exits and another enters — a tab panel switch, a page transition — overlap the timing slightly. The outgoing element starts fading out, and while it's still partially visible, the incoming element starts fading in. This overlap creates continuity — there's no "dead frame" where nothing is visible.

The overlap doesn't need to be large. 50-100ms of overlap is often enough. The exiting element hits 50% opacity, and the entering element starts at 0% opacity and rises. The transition feels smooth rather than sequential.

### Motion Hierarchy

In orchestrated motion, not every element should animate equally. The most important element should have the most prominent motion; supporting elements should be subtler.

When a hero section enters, maybe the headline animates prominently while the supporting text and buttons fade in more subtly. When a modal opens, maybe the modal itself scales and fades while the backdrop simply fades. The hierarchy of visual importance should be reflected in the hierarchy of motion prominence.

This creates focus. In a busy animation with many elements, the user's eye is drawn to the most prominent motion. That prominent element should be the most important one.

---

## Scroll-Driven Animation

Scroll-triggered animations — effects that activate as the user scrolls down the page — are powerful but frequently misused.

### When Scroll Animation Serves

Scroll animation serves when it **communicates content structure**. A storytelling page where sections reveal in sequence as you scroll — each section building on the last — uses scroll as a narrative device. The motion shows relationships: "this section follows from the previous one." Parallax effects that create a sense of depth reinforce spatial structure: foreground elements move faster than background elements, creating layering.

Scroll animation serves when it **provides feedback**. A progress indicator that fills as you read. A navigation element that highlights your current section. Elements that fade in as they enter the viewport, confirming that new content is available. These use scroll animation to communicate state.

### When Scroll Animation Fails

Scroll animation fails when it's **showing off**. Gratuitous parallax on every section, where elements float and shift for no communicative purpose, is motion-as-decoration. The animation draws attention to itself rather than serving the content.

Scroll animation fails when it **scroll-jacks**. Scroll-jacking overrides native scroll behavior — the user scrolls, but instead of moving down the page, something else happens. A slide transitions, or the scroll speed changes, or the direction reverses. Scroll-jacking violates user expectations and often breaks accessibility tools. It feels like the interface is fighting the user.

Scroll animation fails when it's **too slow or too prominent**. Animations that require waiting — elements that don't appear until a second after they enter the viewport, effects that take too long to complete — create friction. The user is waiting for the interface to catch up.

### The Rule of Thumb

If the animation teaches the user something about the content's structure or relationship, it's serving. If it just looks cool, it's probably not worth the disorientation. When in doubt, less is more.

---

## View Transitions API: Native Page Transitions

The View Transitions API, now supported in all major browsers, provides native page transitions without JavaScript animation libraries. This changes how cross-page and SPA navigation should be implemented.

### How It Works

The API captures a snapshot of the current state, then captures the new state, and animates between them. The browser handles the complexity.

For single-page apps:

```javascript
document.startViewTransition(() => {
  // Update the DOM
  updateContent();
});
```

For multi-page apps (MPAs), add a CSS opt-in:

```css
@view-transition {
  navigation: auto;
}
```

The browser automatically cross-fades between pages. No JavaScript required for basic transitions.

### Customizing Transitions

The default is a cross-fade, but you can customize with CSS:

```css
/* Slow down the transition */
::view-transition-old(root),
::view-transition-new(root) {
  animation-duration: 400ms;
}

/* Slide the new page in from the right */
::view-transition-new(root) {
  animation: slide-from-right 300ms ease-out;
}
```

### Named Transitions for Element Continuity

The most powerful feature: elements can maintain visual continuity across state changes. If a card on page A has the same `view-transition-name` as an element on page B, the browser animates between them:

```css
/* Page A: card in a list */
.card-thumbnail {
  view-transition-name: hero-image;
}

/* Page B: same image, now larger */
.detail-hero {
  view-transition-name: hero-image;
}
```

When navigating from the list to the detail page, the thumbnail smoothly transforms into the hero image — position, size, and all. This creates the feeling of spatial continuity that users expect from native apps.

### When to Use View Transitions

**Page navigation.** The API is designed for this. Cross-fades between pages feel more intentional than hard cuts.

**Major state changes.** Tab switches, accordion expansions, modal transitions — any significant DOM change benefits from the snapshot-and-animate approach.

**List to detail.** The named transitions enable the "shared element transition" pattern that makes navigation feel connected.

### Implementation Notes

View Transitions work best when you:
- Keep transition durations short (200-400ms)
- Use named transitions sparingly for key elements, not everything
- Provide reduced-motion alternatives via `prefers-reduced-motion`
- Test on slower devices — the API is performant, but heavy DOMs can lag

For new projects, View Transitions should be your first choice for page-level animation. They're more performant than JavaScript alternatives, require less code, and integrate with browser navigation (including back/forward).

---

## Taste Interlude: The 50ms That Separates Snappy from Jarring

This is where craft lives — in the threshold between "responsive" and "too fast."

Take a common interaction: clicking a button that reveals a dropdown menu. At 300ms, the dropdown emerges smoothly. You see it unfold. It feels deliberate, maybe slightly leisurely. At 250ms, similar but quicker. At 200ms, it's brisk — the dropdown is there almost instantly, but there's still a visible motion. At 150ms, it's snappy — you barely see the motion, but you perceive that something happened rather than something appeared. At 100ms, depending on the dropdown's size, it might feel instant, or it might feel jarring — a jump-cut that surprises rather than informs.

The difference between 150ms (snappy) and 100ms (potentially jarring) is 50 milliseconds. You cannot consciously perceive that difference in isolation. But you can feel it. One lands right; one feels off.

This threshold isn't fixed. It depends on the element's size, the amount of motion (a fade-only transition can be faster than a slide + fade), the context (a button press that shows a tooltip can be faster than a button press that opens a complex menu), and the product's overall personality (a playful product can handle faster, snappier motion than a serious one).

Finding the right duration is not a calculation — it's a calibration. Build the interaction. Watch it. Feel whether it's right. Adjust by 25-50ms. Watch again. The process is iterative and perceptual, not formulaic.

How do you develop this feel? Build the same interaction at five different durations. Put them side by side. Watch all five repeatedly. Notice where your body relaxes into "yes, that one." The relaxation is your taste recognizing correctness. Over time, you'll start knowing roughly where to start — 150ms for small transitions, 250ms for medium ones, 400ms for large ones — but the final calibration is always by feel.

---

## AI Integration

Motion is an area where AI can provide systematic approaches but typically fails at feel.

Here's an exercise: describe your motion principles to AI. Write them out explicitly. "All enter animations use ease-out at 200ms. Exit animations use ease-in at 150ms. Stagger is 40ms between elements. Page transitions are 300ms with a 50ms overlap." Give the AI these rules and ask it to generate code for 10 novel interaction scenarios — interactions you haven't built yet.

Evaluate whether the output feels correct.

The AI will follow your rules. The durations will be right. The easing curves will match your spec. But something will likely feel off. Maybe the AI used your 200ms standard for a tiny tooltip where 150ms would feel better. Maybe it staggered a two-element animation when stagger wasn't needed. Maybe the 300ms page transition feels slow for this particular content.

Where the AI's output feels wrong, your principles need refinement. The problem is that you gave it rules, but rules don't capture edge cases. "200ms for enter animations" is a starting point, but the actual right duration depends on element size, visual distance, context, and personality — factors that are hard to specify in rules.

This is useful for two reasons. First, you identify where your principles are incomplete — where human judgment is still required. Second, you get a sense of where AI motion design is reliable (following explicit rules) and where it needs supervision (calibrating feel).

---

## Projects

### Project 1: Interaction Inventory

Take one common UI pattern — dropdown, modal, toast notification, or card expand. Build it five ways, each with a different animation personality.

**The five personalities:**
1. **Snappy:** Minimal duration, sharp easing, no flourish
2. **Bouncy:** Spring easing, overshoot, physical feel
3. **Slow/luxurious:** Longer duration, pronounced motion, cinematic
4. **Dramatic:** Large scale change, perhaps with blur or color shift
5. **Barely-there:** Subtle opacity and position changes, almost imperceptible

**Constraints:**
- Same HTML structure for all five
- Only CSS/JS animation differences
- Each personality should be clearly distinguishable
- Must include enter and exit states

**Deliverable:**
- A comparison page showing all five versions side by side
- A 300-word writeup describing the feel of each and where it would be appropriate

**Taste check:**
- Which version feels most "default"? Which feels most distinctive?
- If you were building a fintech dashboard, which would you use? A children's game? A luxury brand?
- Show the comparison to someone unfamiliar with animation. Can they articulate what's different, even if they can't name it technically?

### Project 2: Page Choreography

Build a 3-page microsite with fully choreographed page transitions.

**Requirements:**
- Coordinated exits: when leaving a page, elements exit in a choreographed sequence
- Page transition: the transition between pages should have intentional motion
- Coordinated entrances: when arriving on a page, elements enter in a choreographed sequence
- Use View Transitions API or Framer Motion (or equivalent)

**Constraints:**
- Transitions must feel coherent across all three pages — same personality, same system
- No element should animate longer than 400ms total
- Stagger should be consistent
- The motion should communicate spatial relationships (where do pages "live" relative to each other?)

**Deliverable:**
- Live microsite with working transitions
- The motion is the deliverable — the content can be placeholder

**Taste check:**
- Record screen captures of the transitions. Do they feel intentional or chaotic?
- Time the total transition (from click to fully settled). Is it appropriate for the content?
- Could someone understand your spatial model from the transitions alone?

### Project 3: Motion Style Guide

Write and build an interactive motion guide for a hypothetical design system.

**The guide must include:**
- Philosophy: What role does motion play in this design system? What personality does it express?
- Easing curves: The standard curves for enter, exit, and emphasis, with CSS values
- Duration guidelines: Default durations for each animation type (feedback, state, page)
- Stagger patterns: How to stagger multi-element animations
- Enter/exit patterns: Standard patterns for common scenarios (dropdown, modal, toast, page)
- Live examples: Each pattern demonstrated with working code

**Deliverable:**
- A documentation page with live, interactive examples
- Complete enough that a junior engineer could implement motion for any new component by following the guide

**Taste check:**
- Have someone unfamiliar with your system try to implement a new interaction following only your guide. Does the result feel consistent with your other examples?
- Six months from now, could you return to this guide and implement consistent motion for new features?
