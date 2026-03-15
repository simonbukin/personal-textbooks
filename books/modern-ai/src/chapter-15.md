# Chapter 15: Build Something Real

You started this book as someone who could use AI tools: call an API, write a prompt, maybe wire up a chatbot. Fourteen chapters later, you're someone who understands what's happening beneath the interface. You know why LLMs hallucinate and what to do about it. You can build retrieval systems that ground model outputs in verified knowledge. You can design agents that use tools, evaluate their own work, and recover from failures. You can model costs, assess risks, advise on strategy, and red-team the systems you build. You've moved from consumer to practitioner.

That transition matters because the field is moving fast enough that the tools you learned will change, but the judgment you've built won't. Frameworks will be rewritten, model capabilities will shift, APIs will be redesigned. The mental models from Chapter 1, the eval discipline from Chapter 2, the production instincts from Chapter 9, and the honest assessment skills from Chapters 12 and 14 — those compound. They're what make you useful in a room where everyone else is optimizing prompts and hoping for the best.

A pattern you've seen throughout the book: the people who build the best AI systems aren't the ones who know the most about models. They're the ones who know the most about the problems they're solving and have enough AI knowledge to apply models effectively. The reverse, deep model expertise applied to a vague problem, produces impressive demos that never ship. The judgment to tell the difference is the real skill, and it's one that only comes from building, failing, learning, and building again.

Now prove it. The final exercise in this book isn't a tutorial or a guided walkthrough. It's a project specification, the kind you'd receive as a senior engineer on an AI team. There's no starter code, no step-by-step instructions, no "if you get stuck, try this." You have the knowledge. Build something that demonstrates it.

## The Capstone Project

Build a **substantial agentic system** that solves a real problem for real users. "Substantial" means it can't be a single API call with a prompt wrapper; it must involve multiple components working together. "Real problem" means you should be able to explain, in one sentence, who would use this and why. "Real users" means at least one person other than you should be able to use it without your guidance.

### What "Real" Means

The distinction between a portfolio project and a real system is the same distinction that runs through every chapter of this book: reliability under real conditions. A portfolio project works when you demo it. A real system works when someone else uses it without your guidance, on inputs you didn't anticipate, at a scale you didn't test, and on a Tuesday when you're not watching the logs.

You won't achieve perfect reliability; you know that by now. The goal is to achieve *known* reliability: a system where you can state precisely what it does well, what it does poorly, and what you'd need to do to improve the weak areas. That self-knowledge, documented clearly, is worth more than a system that seems to work but whose failure modes are unexplored.

### Requirements

Your project must include all six of the following components. Each one tests a different skill from this book, and together they demonstrate the breadth of knowledge that separates an AI practitioner from someone who can call an API.

**1. Agentic System with Tool Use and MCP Integration**

The core of your project is an agent that plans, executes, and self-corrects. It must use at least three distinct tools, not three variations of the same tool, but three tools that serve different purposes (e.g., database queries, file manipulation, API calls, web search). At least one tool must be exposed via an MCP server that you build. The agent should handle multi-step tasks where the output of one tool informs the next action.

**2. Full Eval Suite**

Your system must have a quantitative eval suite. Not "I tried it and it looked good," but measured metrics on a defined test set. At minimum, report:

- **Precision:** Of the outputs your system produces, what fraction are correct?
- **Recall:** Of the correct outputs that should have been produced, what fraction did your system actually produce?
- **Task completion rate:** For end-to-end tasks, what percentage does the system complete successfully without human intervention?

Your test set should contain at least 30 cases, and you should report confidence intervals or variance across runs. If your system involves retrieval, report retrieval metrics (relevance, coverage) separately from generation metrics.

**3. Cost Model**

Document what your system costs to operate at three scales: current usage (1x), 10x, and 100x. Include API costs, infrastructure costs, and estimated engineering maintenance. Identify the cost-dominant component at each scale; the answer may change as you scale. If costs at 100x are prohibitive, propose architectural changes that would bring them down (model routing, caching, fine-tuning a smaller model).

**4. Security Audit**

Identify the top 3 attack vectors for your system and document mitigations for each. At minimum, address: prompt injection (how could a malicious input hijack your agent?), data exfiltration (could an attacker use your tools to access information they shouldn't?), and privilege escalation (could an attacker cause your agent to perform actions beyond its intended scope?). For each vector, document: the attack, a concrete example, your mitigation, and residual risk.

**5. Business Brief**

Write a one-page document that answers: Who is this for? What problem does it solve? What's the ROI hypothesis? What's the competitive landscape? Why would someone pay for this (or, if internal, why would a team allocate headcount to maintain it)? This brief should be understandable by a non-technical executive.

**6. Honest Post-Mortem**

After building the system, write a post-mortem that answers:

- What broke during development? What failure modes surprised you?
- What would you redesign if you started over? What architectural decisions would you change?
- Where does the system still fail? Be specific. "It sometimes gets confused" isn't useful; "it fails on multi-hop questions where the relevant documents are in different collections" is.
- What did you learn that you didn't expect to learn?

The post-mortem is the most important deliverable. It demonstrates the judgment and intellectual honesty that distinguish senior practitioners from junior ones. Anyone can build a system that works on the happy path; the value is in understanding the unhappy paths and communicating them clearly.

### Evaluation Criteria

Your project will be evaluated on five dimensions, in order of importance:

1. **Honest assessment of limitations**: Does your documentation accurately describe what the system can't do? Are your metrics reported with appropriate caveats? Does your post-mortem demonstrate genuine self-awareness about the system's weaknesses?

2. **Eval rigor**: Is your eval suite comprehensive enough to give confidence in the reported metrics? Does it cover edge cases and failure modes, not just the happy path? Are results reproducible?

3. **Technical correctness**: Does the system work as described? Are the architectural decisions sound? Is the code production-quality, not perfect, but clear, maintainable, and reasonably robust?

4. **Production-readiness**: Could this system be deployed and maintained by someone other than you? Does it handle errors gracefully? Is it monitored? Are there runbooks for common failure modes?

5. **Business clarity**: Does the business brief make a coherent argument? Is the cost model realistic? Would a non-technical stakeholder understand the value proposition?

### Project Ideas

If you need a starting point, consider these, but you're encouraged to build something that solves a problem you actually have. The best capstone projects come from real frustration with an existing workflow, not from a list of suggestions.

- An AI research assistant that searches academic papers, synthesizes findings, and produces structured summaries with citations, with an MCP server that connects to an institutional knowledge base. The eval challenge here is measuring citation accuracy and synthesis quality against expert judgment.
- An automated code migration tool that analyzes a codebase in one framework and produces equivalent code in another, with tests to verify behavioral equivalence. The interesting engineering challenge is defining "equivalent": behavioral equivalence is testable; stylistic equivalence is not.
- A document processing pipeline that extracts structured data from unstructured documents (contracts, invoices, reports), validates extractions, and routes exceptions to human review. This is close to a real enterprise product, and the cost model is particularly instructive because vision model calls dominate the expense.
- An internal knowledge base agent that answers employee questions by searching documentation, Slack history, and ticket systems — with eval against a curated Q&A test set. The data governance challenge here is real; Slack messages contain sensitive information that requires careful access controls.
- A compliance monitoring system that tracks regulatory changes in a specific domain, identifies which changes affect your organization, and generates impact assessments with citations. The hardest part is the eval: how do you measure whether an impact assessment is complete?

### Timeline

This project should take 20-40 hours, depending on scope and your familiarity with the specific domain. Don't scope something that takes 100 hours. A smaller, complete system with thorough evaluation is worth more than a large, incomplete one. The most common mistake is building too much system and not enough eval. If you find yourself spending 30 hours on code and 2 hours on evaluation, you've got the ratio backwards. Aim for at least 30% of your time on eval, documentation, and the post-mortem.

### What Comes After This Book

The field will look different a year from now. Models will be more capable, tools will be more mature, and some of the techniques in this book will be superseded by better approaches. That's fine. The goal was never to give you a static set of tools. It was to give you the foundation to evaluate new tools as they arrive, the judgment to distinguish signal from hype, and the engineering discipline to build systems that work in the real world.

Practitioners who stay effective in this field share three habits: they build things (not just read about them), they measure outcomes (not just ship features), and they stay honest about what they don't know (not just confident about what they do). The first habit keeps you grounded. No amount of reading substitutes for the experience of watching your agent loop infinitely on a task you thought was simple. The second keeps you calibrated. Metrics are the difference between "I think it's working" and "I know it's working, and here's the evidence." The third keeps you credible. In a field where overconfidence is the norm, intellectual honesty is a real competitive advantage.

If this book has helped you develop those habits, it's done its job.

---

A system that works 95% of the time with a clear explanation of the remaining 5% is better than one that "usually works." That principle, reliability through honesty rather than hope, is what this book has been about from the first page.

You know more than you did when you started. You know less than you will in a year. Both of those things are exactly right. Go build something that embodies what you've learned, document what you discover along the way, and share it with someone who's a few chapters behind you.
