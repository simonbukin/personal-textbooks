# Chapter 7: UX Thinking — Beyond Screens

*The best interface is the one that doesn't make you think about the interface.*

---

## Opening

Every chapter so far has been about visual craft — typography, color, layout, motion, systems. These are the *what* of interface design: what elements look like, how they're arranged, how they move.

This chapter shifts to the *why*. Why does this button exist? What is the user actually trying to accomplish? Why do some interfaces feel effortless while others create friction?

UX thinking isn't a separate skill from visual design — it's the strategic layer that gives visual decisions meaning. You can create a beautiful button with perfect typography and thoughtful animation, but if that button leads users to a dead end, or asks them to make a decision they don't understand, or appears when they don't need it, the craft is wasted.

The goal of this chapter is to develop the mental models that connect visual decisions to user outcomes. By the end, you should be able to evaluate any interface not just aesthetically but functionally: does this design serve the user's actual goal?

---

## Mental Models and the Gulf of Execution

Every user approaches your interface with a **mental model** — a set of assumptions about how it works, built from every other interface they've used. They expect buttons to be clickable and labels to be descriptive. They expect navigation at the top or left. They expect search to find what they type.

Don Norman, in *The Design of Everyday Things*, identified two "gulfs" that separate users from their goals:

**The Gulf of Execution:** The distance between what the user wants to do and how the interface lets them do it. If a user wants to change their email notification settings, how many clicks, how many screens, how much reading stands between their goal and its accomplishment?

**The Gulf of Evaluation:** The distance between what the system did and whether the user can tell. If a user saves a document, do they know it saved? If they schedule a meeting, do they see confirmation? If they break something, do they understand what happened?

Good design minimizes both gulfs. Great design makes them invisible — the user thinks of a goal, and the path to that goal is immediately obvious; the user takes an action, and the result is immediately clear.

### Narrowing the Gulf of Execution

To narrow the execution gulf, ask: **how many steps stand between intent and accomplishment?**

Every step is friction. Every step is an opportunity for the user to get lost, make an error, or give up. The design goal is to eliminate unnecessary steps and make necessary steps obvious.

This is why direct manipulation is powerful. Dragging an item to delete it is faster than selecting the item, opening a menu, finding delete, and confirming. One step versus four. The action matches the intent.

This is why good defaults matter. If 80% of users will choose the same option, pre-select it. Don't make them think about something they don't need to think about.

This is why progressive disclosure works. Don't show users options they don't need yet. Start simple; reveal complexity only when the user signals they need it.

### Narrowing the Gulf of Evaluation

To narrow the evaluation gulf, ask: **does the user understand what happened?**

Every state change needs feedback. A button press needs an immediate response: color change, animation, something that says "I received your click." A form submission needs confirmation: success message, redirect, visual change. An error needs explanation: what went wrong, what to do about it.

The feedback should match the significance of the action. Clicking a minor toggle can have minor feedback — a quiet animation. Deleting your account should have significant feedback — a confirmation dialog, a success/error message, maybe an email.

The worst violation is silence. The user clicks, nothing visibly happens, and they don't know: did it work? Should they click again? Is the system thinking? Silence creates uncertainty. Uncertainty creates friction.

---

## Affordances, Signifiers, and Feedback

These three terms — all from Norman — provide a vocabulary for talking about how interfaces communicate what's possible.

### Affordances

An **affordance** is what an object allows you to do. A chair affords sitting. A button affords pressing. A door handle affords pulling or pushing (hopefully it's clear which).

Digital interfaces complicate affordances because pixels have no inherent physical properties. A flat rectangle on screen could be a button, a label, a decorative element, or a container. The affordance isn't inherent — it's communicated.

### Signifiers

A **signifier** is what tells you what an affordance exists. A shadow under a rectangle suggests it's elevated, clickable, a button. A blue underlined text suggests a link. A cursor that changes to a pointer suggests interactivity.

The power of signifiers is that users don't have to think. They perceive the signifier and know what's possible without conscious analysis. The danger is that ambiguous or missing signifiers create confusion — the user doesn't know what they can do.

Modern flat design has created signifier problems. When buttons look like labels (no border, no shadow, just colored text), users sometimes don't know they can click. When interactive elements and static elements have the same visual treatment, users have to guess.

### Feedback

**Feedback** tells users what happened after they did something. The button animates when clicked: "I received your input." The form shows a success message: "Your data was saved." The screen shakes on error: "Something went wrong."

Without feedback, users lose trust in the interface. They clicked and nothing happened — or nothing they could see. They don't know if they should try again. They don't know if the system is working.

### The Three States

Every interactive element needs three communication layers:

1. **What it is** (signifier): This is a button. You can click it.
2. **What will happen** (feedforward): Clicking will submit the form / delete the item / open a modal.
3. **What happened** (feedback): The action succeeded / failed / is processing.

Most interfaces handle the first. Many handle the third. The second — feedforward, communicating what *will* happen before it happens — is often neglected. But feedforward prevents errors. A delete button that says "Delete (cannot be undone)" is clearer than one that just says "Delete."

---

## Jobs-to-Be-Done: What Users Actually Want

Users don't want your product. They want the *outcome* your product delivers.

**Jobs-to-Be-Done** (JTBD) is a framework, developed by Clayton Christensen, for understanding what users actually want. The core insight: people "hire" products to do a job. Understanding the job reveals what the product actually needs to do.

The canonical example is the milkshake. McDonald's wanted to sell more milkshakes. They tried improving the milkshake — better flavor, bigger size, more variety. Sales didn't move.

Then they asked: what job are customers hiring the milkshake to do?

Research revealed: morning commuters were buying milkshakes as something to consume during a boring drive. The milkshake's "competitors" weren't other fast food drinks — they were bananas, bagels, donuts. The job was "make my commute less boring and keep me full until lunch."

Understanding the job led to different improvements. A thicker milkshake (lasts longer during the commute). A wider straw (but not too wide — it should still take time). Maybe bits of fruit for texture. The product changes served the job rather than abstract "quality."

### JTBD for Interface Design

Apply this to interfaces. Don't ask "what features should this screen have?" Ask "what job is the user hiring this screen to do?"

A dashboard's job might be: "Help me quickly understand if anything needs my attention right now." This implies: highlight anomalies, suppress the normal, make the important things visible at a glance. It doesn't imply: show all possible metrics with full detail.

A settings page's job might be: "Help me change the one thing I came to change." This implies: good search/navigation, clear labels, immediate feedback on changes. It doesn't imply: expose every option on one dense page.

An error page's job might be: "Help me recover from whatever just went wrong." This implies: clear explanation, suggested next steps, human voice. It doesn't imply: technical stack traces or generic "error occurred" messages.

When you know the job, you can evaluate design decisions against it. Does this feature help the user do the job? Does this visual treatment make the job easier or harder? Does this flow support the job or distract from it?

---

## The Unhappy Paths

**Empty states.** The first time a user sees a dashboard with no data. The first time they open a feature they haven't used. The first time a search returns no results.

**Error states.** The form validation that fails. The payment that doesn't process. The network request that times out. The server that returns 500.

**Loading states.** The spinner while data fetches. The skeleton screen while content loads. The progress indicator for long operations.

**Edge cases.** The user with 10,000 items when you expected 100. The name with special characters. The timezone that doesn't match the server. The browser that doesn't support the feature.

**Permission states.** The feature the user can't access without upgrading. The action that requires authentication. The organization setting that restricts their role.

These are the **unhappy paths** — the moments when the normal flow doesn't happen. And these are the moments where product quality becomes visible.

Most products spend 90% of design effort on the happy path (everything works as expected) and 10% on unhappy paths. The result: beautiful dashboards that show an ugly "error" modal when something goes wrong. Polished features that show a blank screen when there's no data.

### Empty States

An empty state is not just an absence. It's an opportunity to:

- **Teach:** What is this feature for? How will it be useful once there's data?
- **Guide:** What should the user do to populate this area? Link to the action.
- **Brand:** This is a low-stakes moment for illustration, personality, humanity.

A good empty state tells a story: "You don't have any projects yet. Here's what projects are for. Here's how to create one. Here's an example of what you'll see when you do."

A bad empty state says "No data" — and the user wonders if something is broken.

### Error States

An error state should answer three questions:

1. **What happened?** "Your payment was declined" — not "An error occurred."
2. **Why did it happen?** "Your card's expiration date may be outdated" — if you can diagnose the cause.
3. **What should I do now?** "Try a different card" or "Contact your bank" or "Try again in a few minutes."

The tone should be human. Errors are frustrating; the message shouldn't make them more so. Avoid technical jargon, avoid blame, avoid vague dismissals.

The placement matters. An error message should appear where the user can see it in context. A form field error should be near the field. A global error should be prominent but not disorienting.

### Loading States

Loading states communicate "the system is working." Without them, users don't know if their action registered.

**Spinners** are appropriate for short waits (under 2 seconds). They say "processing" without committing to how long.

**Progress indicators** are appropriate for longer operations where progress is measurable. They say "this will take X long, and you're Y% done."

**Skeleton screens** are appropriate for content loading. They show the shape of the coming content, reducing perceived wait time because something is visible immediately.

The worst loading state is nothing — the user clicks, the screen stays the same, they wonder if anything happened.

### Designing for Unhappy Paths

The principle: **unhappy paths deserve the same design care as happy paths.**

This means: empty states are designed, not afterthoughts. Error messages are written with the same care as marketing copy. Loading states are considered experiences, not spinners dropped in at the last minute.

The reason this matters: unhappy paths are where trust is built or lost. When something goes wrong, the product either helps the user recover or abandons them. The products that help — that provide clear guidance through errors, that make empty states welcoming, that give useful loading feedback — earn trust. The products that show blank screens and cryptic errors lose it.

---

## Lightweight User Research

You don't need a research department to understand your users. You need five people, three tasks, and the discipline to watch without helping.

Steve Krug's *Don't Make Me Think* made this point two decades ago: the first three users reveal 80% of major usability issues. You don't need statistically significant sample sizes. You need *any* users besides yourself, because you're too close to see what's confusing.

### Running a Lightweight Usability Test

**Recruit:** Friends, colleagues, Twitter followers, actual users. Anyone who isn't you and hasn't seen the design before. Five people is enough.

**Define tasks:** Not "explore the site" but specific, goal-directed tasks. "Find the pricing page and tell me which plan you'd choose." "Create a new project and invite a team member." The task should be something a real user would actually do.

**Observe:** Watch them attempt the task. Take notes on everything: where they click, where they hesitate, what they say, where they get confused. Do not help. Do not explain. If they're stuck, let them be stuck — that's the data.

**Synthesize:** After all five sessions, identify the top 3-5 issues that appeared repeatedly. Not every problem mentioned, but the most significant and frequent.

This takes a few hours. You can do it informally — no lab, no recording equipment, just a laptop and a quiet room. The output is a prioritized list of usability problems you didn't see before.

### The Testing Mindset

The hardest part of usability testing is watching someone struggle with your design without intervening. The instinct is to explain: "Oh, that button is actually in the menu." But if you have to explain, the design failed. The user won't have you there to explain in production.

The mindset shift: you're not testing the user, you're testing the design. When a user "fails" a task, the design failed, not the user. Every point of confusion is design feedback.

---

## Taste Interlude: Convention vs. Invention

When should you follow established patterns, and when should you invent?

**Follow convention when:**

- Users have strong mental models. Login flows, checkout processes, settings pages — users expect these to work in familiar ways. Novelty creates friction.
- The interaction is instrumental, not experiential. Users want to accomplish a task and move on. They don't want to learn a new interface for checking their notification settings.
- Trust matters. E-commerce checkout, financial transactions, medical information — anything where users need to trust the process should follow conventions. Unfamiliar patterns create uncertainty.

**Invent when:**

- You're creating differentiation. The product's value comes partly from a novel interaction. Figma's multiplayer cursors were an invention that became a product differentiator.
- The existing convention is bad. Sometimes the established pattern is actually terrible, and improving on it — carefully — is worth the learning curve.
- The experience is exploratory, not instrumental. Onboarding, discovery features, "playground" modes — contexts where users expect to learn and explore.

The key question: **does this departure from convention serve the user or serve the designer's ego?** If you can articulate why the user benefits from a novel approach — faster, clearer, more delightful — the invention might be justified. If the novelty is "because it's cool" or "because it's different," it's probably not.

---

## AI Integration

Before running a usability test, try this: describe your interface to an AI and ask it to predict where users will struggle.

"Here's a checkout flow: [description]. The user wants to purchase an item. Where do you think they might get confused? Where might they hesitate? What questions might they have at each step?"

The AI will generate predictions based on common UX principles. Some predictions will be obvious (the button label is unclear). Some will be wrong. Some will surprise you.

Then run the actual test with real users. Compare AI predictions to actual results.

This calibrates your sense of where AI's UX instincts are reliable versus where real humans surprise you. AI is good at predicting issues with:

- Unclear labels and instructions
- Missing feedback
- Confusing flow order
- Accessibility problems

AI is often surprised by:

- Emotional responses (users don't just navigate, they feel)
- Unexpected mental models (users interpret things differently than expected)
- Context-specific behavior (users in certain situations behave differently)

Understanding this gap helps you know when to trust AI UX analysis and when you need real humans.

---

## Projects

### Project 1: Unhappy Path Audit

Choose a product you use daily. Map every error, empty, loading, and edge-case state you can find.

**Process:**
- Use the product intensively for a week, specifically trying to trigger unhappy paths
- Screenshot and document each unhappy state: empty states, error messages, loading states, edge cases
- Evaluate each: Does it answer what happened, why, and what to do? Is it helpful? Is it human?

**Deliverable:**
- Catalog of unhappy states with screenshots and evaluation
- Redesign the 3 worst states: before screenshot, after design, written rationale
- Ship the redesigns or share them publicly (portfolio piece)

**Taste check:**
- Did the redesigns actually improve the experience, or just look better?
- Could someone encountering your redesigned error state recover without additional help?

### Project 2: Onboarding Redesign

Choose a SaaS tool with a poor onboarding flow (there are many). Redesign it end-to-end.

**Process:**
- Sign up for the tool. Document the existing onboarding: every step, every screen, every decision point
- Identify the JTBD: what job is a new user hiring this product to do? What's the "aha moment"?
- Map the current flow: how many steps to the aha moment? Where are the unnecessary steps? Where is the confusion?
- Redesign: user flow diagram, key screens (high fidelity), written brief explaining decisions

**Constraints:**
- Focus on getting users to the aha moment faster
- Assume you can't change the product's core functionality, only the onboarding experience
- Design for users who have just signed up, not for returning users

**Deliverable:**
- Flow diagram showing before (current) and after (proposed)
- High-fidelity mockups of 5-8 key screens
- 600-word brief explaining decisions: what job is the user hiring? Where was the current flow failing? How does the redesign address it?

### Project 3: 5-Person Usability Test

Run a usability test on something you've built.

**Process:**
1. Choose an interface you've built (could be from earlier projects)
2. Define 3 specific tasks users should be able to accomplish
3. Before testing, write your predictions: where will users struggle?
4. Recruit 5 participants (friends, colleagues, anyone not you)
5. Run 20-minute sessions: task, observe, take notes
6. Synthesize: what were the top 3 issues?
7. Compare predictions to results

**Deliverable:**
- Written predictions (before testing)
- Session notes or recording summaries
- Top 3 issues with evidence
- Redesign proposals for each issue
- Reflection: where were you wrong about your own design?

**Taste check:**
- Were you surprised by what users struggled with?
- Did the issues you predicted actually appear, or did other issues dominate?
- What did this teach you about your blind spots?
