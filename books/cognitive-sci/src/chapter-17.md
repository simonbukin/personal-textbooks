# Chapter 17: Reasoning: Logic, Heuristics, and the Clever Shortcuts That Mostly Work

Here is a simple problem. Four cards lie on a table. Each card has a letter on one side and a number on the other. You can see:

**E** -- **K** -- **4** -- **7**

The rule is: "If a card has an E on one side, then it has a 4 on the other side."

Your task: which cards must you flip to test whether this rule is true?

Take a moment. Most people say E and 4. The correct answer is E and 7.

You need to flip E because it could have something other than 4 on the back, which would violate the rule. You need to flip 7 because it could have an E on the back, which would also violate the rule (an E paired with a non-4). You do not need to flip 4 because even if there is an E on the other side, that is consistent with the rule, and if there is a K, the rule says nothing about K cards. You do not need to flip K because the rule makes no claims about cards with K.

Fewer than 10 percent of university students get this right on their first attempt. These are not unintelligent people. They understand the task. They are trying. They simply are not performing the logical operation that the problem demands.

This result, published by Peter Wason in 1968, opened a research program that has changed how we understand human reasoning. The central lesson is not that humans are stupid. It is that human reasoning was not built to implement formal logic. It was built to do something else, something that usually works well in the environments where reasoning evolved but that breaks down predictably in certain artificial contexts.

---

## Deductive Reasoning: What Logic Demands vs. What Humans Do

Deductive reasoning is reasoning from premises to a conclusion that must follow if the premises are true. If all mammals are warm-blooded, and if a whale is a mammal, then a whale must be warm-blooded. The conclusion is guaranteed by the structure of the argument, regardless of content.

Formal logic provides the rules for valid deduction. Modus ponens: if P then Q; P; therefore Q. Modus tollens: if P then Q; not Q; therefore not P. These rules are not controversial; they are mathematical facts about how truth is preserved under certain inference patterns.

Humans are reasonably good at modus ponens. If you tell someone "If it's raining, the ground is wet" and then tell them "It's raining," they will reliably conclude the ground is wet. But modus tollens — the logically equivalent inference in the other direction — is harder. "If it's raining, the ground is wet; the ground is not wet; therefore it's not raining." People make this inference less often and less confidently, even though it is equally valid.

More revealingly, people commit systematic logical errors. They endorse the fallacy of affirming the consequent ("If it's raining, the ground is wet; the ground is wet; therefore it's raining") at high rates. They confuse necessary and sufficient conditions. They are influenced by the believability of conclusions, accepting logically invalid arguments when the conclusion happens to be true and rejecting valid arguments when the conclusion is implausible. This is called the belief bias effect, and it is robust.

### The Wason Selection Task in Detail

The selection task described in the opening is the single most studied problem in the psychology of reasoning. Its power lies in how sharply it exposes the gap between competence (what logic requires) and performance (what people do).

The standard finding, roughly 90 percent failure, is highly resistant to intervention. Training in logic helps only modestly. Even professional logicians do not perform perfectly, though they do better than average. The error is not about intelligence or education. It appears to reflect something about how conditional reasoning naturally works in humans.

But here is the twist that makes the task truly interesting. Change the content from abstract letters and numbers to a social rule, and performance skyrockets. Consider this version: Four people are at a bar. You can see their drink (beer or soda) and their age (25 or 16). The rule is: "If a person is drinking beer, they must be over 18." Which people do you need to check?

Suddenly, people ace it. You check the beer drinker and the 16-year-old. Logically, this is identical to checking E and 7. But the social context (detecting cheaters, enforcing a rule) transforms performance.

This content effect led Leda Cosmides and John Tooby to propose that humans have a specialized cognitive mechanism for detecting cheaters in social contracts. On their evolutionary account, our reasoning ancestors needed to detect people who took benefits without paying costs, and natural selection built a module for this specific type of conditional reasoning. Whether you buy the modular, evolutionary explanation or prefer a broader account based on pragmatic reasoning about familiar scenarios, the empirical fact is clear. Content matters enormously for human reasoning, and formal structure matters less than logicians would hope.

---

## Inductive Reasoning: Generalizing Under Uncertainty

Deductive reasoning gives certainty but is limited to what the premises already contain. Most real-world reasoning is inductive, drawing general conclusions from specific observations, predicting the future from past experience, reasoning from samples to populations.

Inductive reasoning is inherently uncertain. You have seen the sun rise every day of your life, so you conclude it will rise tomorrow. This inference is overwhelmingly reasonable but not logically guaranteed. This is David Hume's problem of induction, and it remains philosophically unsolved even as it is practically irrelevant.

Humans are generally competent inductive reasoners, but they show systematic patterns that diverge from the standards of probability theory. The most consequential of these is base rate neglect.

### Base Rate Neglect

A disease affects 1 in 1,000 people. A test for the disease has a 95 percent accuracy rate (both sensitivity and specificity). You test positive. What is the probability you actually have the disease?

Most people say something close to 95 percent. The actual answer is about 2 percent.

The math: out of 1,000 people, 1 has the disease and tests positive. Of the remaining 999, about 50 (5 percent) test positive despite being healthy. So there are roughly 51 positive tests, of which only 1 is a true positive. Your chance of having the disease is approximately 1/51, or about 2 percent.

People routinely neglect the base rate, the prior probability that the condition exists, and focus on the diagnostic evidence. This is not a trivial error. It leads to genuine misunderstanding in medical, legal, and forensic contexts. Physicians, despite their training, are not immune.

However, the framing matters. When the same problem is presented in natural frequency format ("Out of 1,000 people, 1 has the disease and tests positive; 50 don't have it but test positive anyway; so if you test positive, you're 1 of roughly 51 — what's your chance of being the one?"), performance improves dramatically. Gerd Gigerenzer and colleagues have argued that our reasoning machinery works well with natural frequencies because those are the formats our minds evolved to process, and that base rate neglect is partly an artifact of presenting information in a format (single-event probabilities) that is historically unnatural for humans.

---

## Analogical Reasoning: Transferring Structure

Analogical reasoning, seeing structural similarities between different domains and using one to reason about the other, is among the most powerful and distinctively human forms of reasoning. When Rutherford modeled the atom as a miniature solar system, he was reasoning by analogy. When a student understands electrical current by thinking about water flowing through pipes, they are using analogy.

Dedre Gentner's structure-mapping theory provides the most influential account of how analogy works. On her view, analogy involves aligning the relational structure of two domains — finding correspondences not between surface features (atoms do not look like planets) but between the relations among elements. The solar system analogy works because the relation "revolves around" maps from planets-around-sun to electrons-around-nucleus, and the relation "attracted by gravitational force" maps onto "attracted by electromagnetic force."

The challenge with analogical reasoning is transfer: people are very bad at spontaneously noticing useful analogies. In classic studies by Mary Gick and Keith Holyoak, participants who read a story about a military commander dividing his forces to converge on a fortress from multiple sides were largely unable to apply the same strategy to an analogous medical problem (using multiple low-intensity radiation beams converging on a tumor), even when the stories appeared in the same session. When explicitly told the stories were related, they solved the problem easily.

This suggests that retrieving a relevant analog from memory is the bottleneck, not performing the mapping once the analog is identified. Surface similarity drives retrieval far more than structural similarity does. You are more likely to think of a previous medical case when confronting a medical problem, even if the structurally relevant analog comes from a completely different domain.

---

## The Psychology of Argument: Confirmation and Motivated Reasoning

Beyond formal reasoning tasks, there is the question of how people evaluate arguments, evidence, and claims in everyday life. Two phenomena dominate this landscape.

**Confirmation bias** is the tendency to seek, interpret, and remember information that confirms your existing beliefs, while neglecting or discounting information that contradicts them. This is one of the most robust findings in all of psychology. It has been demonstrated in hundreds of studies across diverse contexts. It is not a product of laziness or stupidity; it affects experts and novices, scientists and laypeople, across every domain studied.

Wason himself demonstrated an early form of confirmation bias with his "2-4-6" task. Participants were told that the sequence 2, 4, 6 fit a rule and were asked to discover the rule by proposing other sequences. Most people hypothesized "ascending even numbers" and tested sequences like 8, 10, 12 — receiving confirmation each time. Very few proposed disconfirming sequences like 1, 3, 5 (which also fits the actual rule: "any ascending sequence"). People actively seek confirmation and rarely seek disconfirmation, even when disconfirmation is more informative.

**Motivated reasoning** goes further. When people have an emotional stake in a conclusion, because it aligns with their political identity, their self-image, or their financial interests, they do not just passively absorb confirming evidence. They actively construct justifications, scrutinize threatening evidence more carefully than supporting evidence, and shift their standards of proof depending on whether they like the conclusion. Dan Kahan's research on cultural cognition shows that politically contentious scientific findings (climate change, gun control) are evaluated not on their merits but through the lens of identity.

### Why Being Smart Doesn't Help (And Might Hurt)

One might hope that intelligence protects against reasoning errors. The evidence is mixed and, in some cases, counterintuitive. Higher cognitive ability does reduce susceptibility to some biases. Smarter people are better at the selection task, less likely to commit certain base rate errors, and more likely to reason correctly about syllogisms.

But for motivated reasoning, intelligence may actually make things worse. More cognitively sophisticated people are better at constructing elaborate justifications for their preferred conclusions. They are better at finding flaws in arguments they dislike and at generating counterarguments. Keith Stanovich has called this the "smart person problem": general intelligence gives you more powerful reasoning tools, but those tools can be deployed in the service of motivated conclusions just as easily as in the service of truth.

This is why debiasing through education alone has limited effectiveness. Knowing about biases does not automatically prevent them, any more than knowing about optical illusions prevents you from seeing them.

---

## Primary Text Spotlight: Wason (1968), "Reasoning About a Rule"

Peter Wason's 1968 paper in the *Quarterly Journal of Experimental Psychology* introduced the selection task to the research literature and launched an entire subfield. It is a clear and economical paper.

Wason presented participants with four cards showing, respectively, a vowel, a consonant, an even number, and an odd number (the specific stimuli varied across experiments). The conditional rule was of the form "If P then Q." Participants had to select which cards to turn over to determine whether the rule was true or false.

The core finding: the vast majority selected the P card and the Q card (e.g., the vowel and the even number), rather than the logically correct P and not-Q combination. Wason interpreted this as a failure of modus tollens reasoning: people naturally verify (look for confirming instances) rather than falsify (look for disconfirming instances).

What gives the paper enduring significance is the question it forced the field to confront. If humans are not natural logicians, what are they? The paper did not answer this question (decades of subsequent work have offered various answers), but it posed it with a clarity that demanded a response.

**Subsequent developments:** The content effect discovered later (Wason & Shapiro, 1971; Griggs & Cox, 1982; Cosmides, 1989) deepened the puzzle. The finding that performance is dramatically affected by content showed that reasoning cannot be separated from knowledge, context, and pragmatic interpretation. This in turn influenced debates about the modularity of mind, evolutionary psychology, and the relationship between reasoning and rationality.

**Epistemic status: Robust.** The basic selection task finding, poor performance on abstract conditionals and improved performance on social contracts, has been replicated across cultures and settings. The theoretical explanation remains debated.

---

## What This Gets Right / What's Still Open

**What we can be fairly confident about:**

- Humans are not natural formal logicians. Performance on deductive reasoning tasks systematically departs from logical norms, and these departures are not random but patterned.
- Content and context powerfully affect reasoning. The same logical structure produces different performance depending on whether it is abstract or embedded in familiar, meaningful scenarios.
- Base rate neglect is real and consequential, though it is reduced when information is presented in natural frequency formats.
- Confirmation bias is pervasive and resistant to simple interventions.
- Analogical reasoning is a powerful cognitive tool, but spontaneous transfer across domains is rare without explicit prompting.

**What remains open:**

- Whether the content effect on the selection task reflects a domain-specific cheater detection module (Cosmides and Tooby) or domain-general pragmatic reasoning processes. This debate has not been conclusively resolved.
- The extent to which reasoning errors reflect genuine irrationality versus rational responses to pragmatic features of experimental tasks. Some errors that look irrational from a logical standpoint may be sensible responses to how conversational communication normally works.
- Whether dual-process theories (System 1 / System 2, discussed in the next chapter) provide the right framework for understanding reasoning failures, or whether they are too vague to be explanatory.
- How much reasoning can be improved through training and education. The evidence for long-term debiasing is weaker than you might expect.

---

## Real-World Application: Designing Better Decision Contexts

If human reasoning predictably departs from logical and statistical norms, how should institutions respond?

### Nudges and Their Limits

The behavioral economics movement, catalyzed by Thaler and Sunstein's *Nudge* (2008), argued that institutions should redesign "choice architecture" to account for predictable reasoning errors. Default options exploit status quo bias. Simplified forms reduce cognitive load. Reframing statistics in frequency formats improves comprehension.

Some nudges have strong evidence behind them. Changing organ donation from opt-in to opt-out dramatically increases donation rates. Automatic enrollment in retirement plans increases savings. These are real, large effects with robust evidence.

But the broader nudge program has a more complicated record than popular accounts suggest. A large-scale meta-analysis by Maier et al. (2022) found that the average effect of behavioral interventions was much smaller than initial studies suggested, with substantial publication bias inflating early estimates. Many nudges work in laboratory settings but show reduced effects in the field. Some show no effect at all when independently replicated.

This does not mean behavioral insights are useless. It means the gap between "humans make systematic reasoning errors" (robust finding) and "we can reliably fix those errors with simple interventions" (much less robust) is larger than the popular literature implies.

### What Does Help

The most effective strategies for improving reasoning tend to be structural rather than psychological. Checklists in medicine reduce errors not by making doctors think better but by changing the task from a memory challenge to a verification task. Statistical decision aids improve diagnostic accuracy not by debiasing physicians but by doing the computation for them. Adversarial collaboration, structured debate between people with opposing views, can improve reasoning about contested questions, not by eliminating bias but by ensuring that both sides' biases are represented.

The general principle is this: rather than trying to fix human reasoning, design environments that work with its strengths and compensate for its weaknesses.

---

## Checkpoint

Before moving on, you should be able to affirm the following:

- You can explain the Wason selection task, state the correct answer (E and 7), and explain why most people get it wrong.
- You can describe the content effect (why the same logical structure becomes easy when framed as a social rule) and state at least one theoretical explanation.
- You can explain base rate neglect with an example and describe how natural frequency formats reduce the error.
- You can define confirmation bias and motivated reasoning and explain how they differ.
- You can explain why higher intelligence does not reliably protect against motivated reasoning.
- You can describe analogical reasoning, state what structure-mapping theory proposes, and explain why spontaneous transfer is rare.
- You can give a balanced assessment of nudges, acknowledging successes while noting that the broader evidence base is weaker than popular accounts suggest.
- You can articulate the general principle that designing better environments may be more effective than trying to debias individual reasoning.
