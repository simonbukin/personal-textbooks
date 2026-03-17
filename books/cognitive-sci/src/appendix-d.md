# Appendix D: How to Read a Cognitive Science Paper

If you have never read an empirical research paper, the experience can be disorienting. The format is unfamiliar, the language is dense, and the statistics look like hieroglyphics. This appendix is a practical guide to getting through a paper, understanding what it claims, and -- most importantly -- evaluating whether you should believe it.

You do not need a statistics background. You need patience, a willingness to re-read sentences, and the framework below.

---

## The Anatomy of a Paper

Almost every empirical paper in cognitive science follows the same structure: Abstract, Introduction, Methods, Results, Discussion. Some journals vary the labels, but the logic is the same. Here is what each section does and what to look for.

### Abstract

The abstract is a 150-300 word summary of the entire paper. It tells you: what question was asked, what method was used, what was found, and what it means.

**What to look for:** The abstract gives you the authors' best case for why you should care. Read it to decide whether the paper is relevant to your question. But do not trust the abstract's characterization of the results -- authors routinely overstate their findings in abstracts. The abstract is an advertisement; the Methods and Results sections are the product.

**Red flag:** If the abstract uses strong causal language ("X causes Y") but the study is correlational, be cautious. This is surprisingly common.

### Introduction

The introduction reviews the existing literature, identifies a gap or unresolved question, and explains how the current study addresses it. It typically ends with explicit hypotheses or research questions.

**What to look for:** The introduction tells you what the authors think the state of the field is. Pay attention to which prior studies they cite and which they omit. No introduction is a neutral summary -- it is an argument for why this study needs to exist. That is fine, but be aware that you are reading an advocate's brief, not a balanced review.

**Useful move:** If a paper interests you, look at its reference list for review articles on the same topic. Reviews give you a broader picture than any single paper's introduction.

### Methods

This is the most important section of the paper. It tells you exactly what was done: who the participants were, what they were asked to do, what was measured, and how the data were analyzed.

**What to check:**

*Participants.* How many? (Sample size matters enormously. A study with 20 participants per condition should be trusted less than one with 200.) Who were they? (Undergraduates at a single university? Online workers? Children? Clinical patients?) Were they compensated? Were any excluded from analysis, and why?

*Task and materials.* What did participants actually do? Can you picture the experience of being a participant? If the task seems artificial or confusing, the results may not generalize to real-world cognition.

*Design.* Was it between-subjects (different people in different conditions) or within-subjects (same people in all conditions)? Was assignment to conditions random? If not, why not?

*Measures.* What was the dependent variable -- reaction time, accuracy, brain activation, self-report? Each has strengths and weaknesses. Self-report measures are vulnerable to demand characteristics (participants guessing what the experimenter wants). Reaction time is more objective but can be noisy.

**Red flag:** If the Methods section is vague about any of the above, that is a problem. You should be able to replicate the study from the Methods section alone. If you cannot, the reporting is inadequate.

### Results

This is where most readers panic. Do not panic. You can extract the key information without understanding every statistical test.

**The essentials:**

*p-values.* A p-value tells you the probability of observing results this extreme (or more extreme) if the null hypothesis were true -- that is, if there were actually no effect. A p-value of .03 means: "If nothing were really going on, there would be a 3% chance of seeing data this extreme."

By convention, p < .05 is considered "statistically significant." This threshold is arbitrary and widely criticized, but it remains the standard.

What p-values do NOT tell you: they do not tell you the probability that the hypothesis is true. They do not tell you how large or important the effect is. A tiny, meaningless effect can be statistically significant with a large enough sample. A p-value of .04 is not meaningfully different from .06, despite the fact that one is "significant" and the other is not.

*Effect sizes.* Effect sizes tell you how large the effect is, independent of sample size. Common measures include Cohen's d (for comparing group means; 0.2 = small, 0.5 = medium, 0.8 = large), eta-squared or partial eta-squared (proportion of variance explained), and correlation coefficients (r).

Effect size is more informative than the p-value. A study might find a "statistically significant" effect with d = 0.1 -- technically significant with a huge sample, but practically meaningless. Conversely, a meaningful effect (d = 0.6) might be "non-significant" in a small study simply because the study lacked the power to detect it.

*Confidence intervals.* A 95% confidence interval gives you a range within which the true effect likely falls. Wide confidence intervals mean the estimate is imprecise. If a confidence interval for a difference between groups includes zero, the effect is not statistically significant at the .05 level.

**Useful shortcut:** If you are new to reading results sections, focus on three things: (1) Was the predicted effect statistically significant? (2) How large was the effect? (3) How precise is the estimate (look at confidence intervals)? You can skip the details of the statistical model for now.

**Red flag:** If a paper reports many statistical tests but only highlights the ones that are significant, be suspicious. This may indicate that the authors ran many analyses and only reported the ones that "worked" -- a practice called p-hacking.

### Discussion

The discussion interprets the results, relates them back to the literature reviewed in the introduction, acknowledges limitations, and suggests future directions.

**What to trust:** The discussion is where authors speculate, and speculation is fine as long as it is clearly labeled. Look for hedging language ("This suggests," "One possible interpretation," "Future research should test whether"). If the discussion makes strong claims that go beyond what the data actually showed, that is a problem.

**What to look for:** The limitations section is often the most honest part of the paper. Authors are required to acknowledge weaknesses, and many do so thoughtfully. If the limitations section is perfunctory (one or two sentences about sample size), the authors may not be taking their own study's weaknesses seriously.

---

## A Worked Example: Evaluating a Claim

Suppose you encounter the claim: "Power posing for two minutes increases testosterone and makes people more willing to take risks." Here is how you would evaluate it.

**Step 1: Find the original paper.** The claim comes from Carney, Cuddy, and Yap (2010), published in *Psychological Science*. Read the abstract: 42 participants were randomly assigned to hold "high-power" or "low-power" poses for two minutes. The high-power group showed increased testosterone, decreased cortisol, and more risk-taking behavior.

**Step 2: Check the methods.** Sample size: 42 total (21 per condition). This is very small for detecting hormonal changes, which are noisy. Participants were undergraduate students at a single university.

**Step 3: Check the results.** The effects were statistically significant but the sample is tiny, meaning the estimates are imprecise and the study is likely underpowered. Small studies that find significant effects tend to overestimate effect sizes (this is called the "winner's curse").

**Step 4: Look for replications.** A large pre-registered replication by Ranehill et al. (2015) with 200 participants found no effect on hormones or risk-taking. A subsequent multi-lab replication also failed. Carney, the first author, publicly stated that she no longer believes the effect is real. Cuddy maintains a version of the claim (that power posing affects feelings of power, if not hormones).

**Step 5: Assess.** The original study had too few participants, the key effects have not replicated, and the first author has distanced herself from the findings. The hormonal claims are not credible. There may be a small effect on self-reported feelings, but the original strong claims are not supported.

This process -- find the original, check the methods, check the sample, look for replications -- takes about 30 minutes for a single claim. It is the single most valuable critical thinking skill this book can teach you.

---

## How to Spot P-Hacking

P-hacking refers to practices that inflate the false-positive rate: running multiple analyses and reporting only significant ones, adding participants until a result becomes significant, excluding data points post hoc, or testing many dependent variables.

**Signs to watch for:**

- A p-value that is just barely under .05 (e.g., p = .048). Not inherently suspicious, but combined with other red flags, it suggests the result was fragile and may not replicate.
- Many dependent variables tested with only some showing significant effects, and no correction for multiple comparisons.
- Unusual exclusion criteria that are not clearly justified. If 15% of participants were excluded and the exclusions are not based on pre-specified criteria, the results may be artifacts.
- Reported sample sizes that seem oddly specific (e.g., "we tested 37 participants") with no power analysis justifying the sample size. This can indicate that data collection stopped when significance was reached.
- A "just so" story in the discussion that explains away non-significant results while emphasizing significant ones.

None of these is definitive proof of p-hacking. Researchers can do all of these things innocently. But a paper with several of these features should be trusted less than one with none of them.

---

## What Pre-Registration Means

Pre-registration is the practice of publicly registering a study's hypotheses, methods, sample size, and analysis plan before collecting data. The registration is time-stamped and (usually) publicly accessible.

**Why it matters:** Pre-registration makes p-hacking much harder. If the analysis plan is specified in advance, the researcher cannot retroactively choose the analysis that gives the best result. If the predicted effect does not emerge, the researcher must report that. Additional exploratory analyses can be run, but they must be clearly labeled as exploratory.

**Where to check:** Pre-registrations are typically posted on the Open Science Framework (osf.io) or AsPredicted (aspredicted.org). Many journals now badge pre-registered studies, and "Registered Reports" are a format where the study is peer-reviewed and accepted for publication before data are collected, eliminating publication bias entirely.

**A pre-registered study is not automatically correct.** It can still have design flaws, use an unrepresentative sample, or misinterpret results. But it is considerably more trustworthy than a non-pre-registered study making the same claim, because the most common sources of false positives have been constrained.

---

## How to Check Replication Status

When you encounter a finding you want to evaluate, here is where to look:

1. **Google Scholar.** Search for the original paper, then look at "Cited by" to find replication attempts. Filter by date to find recent work.

2. **Curate Science (curatescience.org).** A database that tracks replications of specific studies. Not comprehensive, but useful when a study is included.

3. **PsychFileDrawer and ReplicationWiki.** Repositories of replication attempts, including failures. The coverage is patchy but growing.

4. **Many Labs projects.** Large-scale, multi-site replication projects (Many Labs 1 through 5, and counting) have tested dozens of classic effects. Their results are publicly available and highly informative.

5. **Registered Replication Reports (RRRs).** Published in the journal *Advances in Methods and Practices in Psychological Science*. Each RRR is a pre-registered, multi-lab replication of a single influential finding. The results are definitive.

6. **Twitter/Bluesky/Academic social media.** Researchers discuss replication results in real time. This is messy and unfiltered, but often faster than waiting for publications.

---

## A Checklist for Quick Evaluation

When you do not have time for a deep dive, run through these questions:

- How many participants were in the study? (Under 50 per condition: be cautious.)
- Was the study pre-registered? (If yes, more trustworthy.)
- Has the finding been independently replicated? (If yes, much more trustworthy.)
- How large is the effect? (If the effect size is small and the sample is small, the result is likely noise.)
- Was the study published in a reputable peer-reviewed journal? (Not a guarantee of quality, but a minimal filter.)
- Are the authors making claims that go beyond what the data show? (Common and worth noting.)
- Does the finding seem too clean, too neat, or too good to be true? (Trust that instinct. Clean results in messy domains are sometimes the product of questionable research practices.)

No single criterion is sufficient. But a study that scores well on most of these is a better bet than one that does not.

---

## A Note on Humility

Reading papers critically is not the same as dismissing everything. Most published findings in cognitive science contain some signal, even if the effect is smaller or less general than originally claimed. The goal is not cynicism but calibration: believing things in proportion to the evidence, holding conclusions loosely, and updating when new evidence arrives.

If this appendix has done its job, you will never again read a headline that says "Scientists discover X" without asking: how many participants, what was the effect size, and has anyone replicated it?

That habit is worth more than any single finding in this book.
