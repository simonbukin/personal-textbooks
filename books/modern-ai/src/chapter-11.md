# Chapter 11: Data Strategy & Feedback Loops

## Why This Matters

Code can be copied in an afternoon. Prompts leak the moment someone opens a browser's network inspector. Fine-tuned model weights, if you're using an API provider, don't even belong to you. So what's actually defensible in AI? Data. Specifically, proprietary data that compounds in value through deliberate feedback loops. If you leave this chapter understanding one thing, make it this: the companies winning in AI have built systems that get smarter every time a user touches them. Clever prompts and large parameter counts don't compound. Data does.

This is about building infrastructure that captures the right signals, processes them into something useful, and feeds them back into your system in a way that creates a compounding advantage. The flywheel metaphor is overused in tech, but it's apt here. Each rotation makes the next one easier, and the gap between you and a competitor who starts later grows with every cycle.

The catch is that this doesn't happen automatically. You have to design for it from day one. Most AI products log their outputs diligently but completely ignore the signals that would tell them whether those outputs were any good. They collect exhaust when they should be collecting feedback. By the end of this chapter, you'll know how to build the instrumentation that turns production traffic into a real competitive advantage.

## Production Traffic as Training Data

Every interaction a user has with your AI system generates signal. The question is whether you're capturing it. Most teams aren't, not because they're lazy, but because they haven't thought carefully about what signals exist and which ones matter.

**Implicit signals** are the ones users generate without intending to. When a user accepts an AI-generated completion, that's a weak positive signal. When they edit it, especially specific parts, that's a much richer signal: it tells you what the model got right and where it fell short. When a user regenerates a response, that's a clear negative signal about the previous attempt. Session abandonment (when a user starts an interaction and walks away) suggests the system failed to provide value, though you'll need to distinguish abandonment from task completion. Time-to-action, how long a user takes before accepting, editing, or rejecting output, is a proxy for confidence: fast acceptance suggests high quality, long pauses suggest the user is uncertain or the output needs careful review.

**Explicit signals** are the ones users intentionally provide. Thumbs up/down buttons, star ratings, written corrections, flag-as-wrong buttons. These are higher quality per-signal than implicit ones, but you'll get far fewer of them. The tradeoff is friction vs. signal quality: a simple thumbs up/down captures more responses but less information than a detailed correction form. In practice, you want both. Low-friction mechanisms for volume and high-friction mechanisms for the cases where detailed feedback is most valuable, like errors on high-stakes tasks.

Data logging architecture for this needs to be more than an afterthought. At minimum, capture: the full input context (prompt, retrieved documents, conversation history), the model's output, the model version and parameters used, a timestamp, a user identifier (pseudonymized as appropriate), and whatever feedback signals the user generates. Store these as structured events, not as append-only log files you'll never parse. You want to be able to query "show me all cases where users edited the output within 30 seconds" or "find responses that were regenerated more than twice."

The compounding flywheel: more usage generates more signal, which, if properly processed, improves your system (through fine-tuning, prompt refinement, retrieval improvements, or eval dataset expansion), which makes the product better, which drives more usage. Each rotation tightens the loop. A competitor who launches six months later isn't just six months behind; they're missing six months of compounded learning. Data flywheels are defensible in a way that clever engineering alone is not.

A minimal logging schema that captures the essentials:

```python
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
import json
import hashlib

@dataclass
class AIInteractionEvent:
    """Captures a single AI interaction with feedback signals."""
    interaction_id: str
    user_id_hash: str  # Pseudonymized
    timestamp: datetime

    # Input context
    system_prompt_version: str
    user_input: str
    retrieved_context_ids: list[str] = field(default_factory=list)
    conversation_turn: int = 0

    # Model details
    model_id: str = ""
    model_version: str = ""
    temperature: float = 0.0
    max_tokens: int = 0

    # Output
    raw_output: str = ""
    latency_ms: int = 0
    token_count_input: int = 0
    token_count_output: int = 0

    # Implicit signals (populated asynchronously)
    accepted: Optional[bool] = None
    edited: Optional[bool] = None
    edit_distance: Optional[int] = None  # Levenshtein from output to final
    regenerated: bool = False
    regeneration_count: int = 0
    time_to_action_ms: Optional[int] = None
    session_completed: Optional[bool] = None

    # Explicit signals
    thumbs_up: Optional[bool] = None
    rating: Optional[int] = None  # 1-5
    user_correction: Optional[str] = None
    flagged_issue: Optional[str] = None

    def to_json(self) -> str:
        return json.dumps(self.__dict__, default=str)

    @staticmethod
    def pseudonymize_user(user_id: str, salt: str) -> str:
        return hashlib.sha256(f"{salt}:{user_id}".encode()).hexdigest()[:16]
```

```python
# Example: logging an interaction with feedback
import uuid
from datetime import datetime

event = AIInteractionEvent(
    interaction_id=str(uuid.uuid4()),
    user_id_hash=AIInteractionEvent.pseudonymize_user("user_123", "your-salt"),
    timestamp=datetime.utcnow(),
    system_prompt_version="v2.3",
    user_input="Summarize this contract's termination clauses",
    model_id="claude-sonnet-4-20250514",
    model_version="20250514",
    temperature=0.3,
    max_tokens=2048,
    raw_output="The contract contains three termination clauses...",
    latency_ms=1840,
    token_count_input=3200,
    token_count_output=450,
)

# Later, when user provides feedback:
event.accepted = True
event.edited = True
event.edit_distance = 47  # Small edits — mostly good
event.time_to_action_ms = 12000
event.thumbs_up = True
```

## Preference Data Collection

Preference data (records of which output a human preferred over an alternative) is the currency of RLHF and DPO. If you're fine-tuning or planning to fine-tune, collecting high-quality preference data from your users is one of the most valuable things you can do. Even if you're not fine-tuning today, preference data is gold for eval datasets and prompt iteration.

UI design for preference collection is deceptively important. Showing two outputs side by side and asking "which is better?" works for dedicated annotation tasks but is too intrusive for production users. Better approaches embed preference capture into the natural workflow. If your product generates text, let users regenerate and track which version they keep. If it suggests multiple options, track which one they select. If it generates code, track which version passes their tests. These are implicit A/B comparisons that happen organically.

For explicit A/B comparisons, the design matters more than you'd expect. Research on annotation interfaces consistently shows that presentation order biases ratings. The first option shown tends to be preferred, all else equal. Randomize presentation order. Keep comparison tasks short; annotator fatigue degrades quality after about 45 minutes of sustained comparison work. Provide clear rubrics. "Which is better" is ambiguous; "which is more factually accurate" or "which follows the instructions more precisely" produces more consistent labels.

**Annotation pipelines** for production-grade preference data need several components: a task queue that distributes examples to annotators, a rubric that defines evaluation criteria, a mechanism for quality control, and storage that links annotations back to the original interaction. Tools like Argilla, Label Studio, and Lilac handle the infrastructure, but the hard part is the rubric design. Your rubric needs to be specific enough that two annotators would agree most of the time but general enough to cover the range of tasks your system handles.

**Inter-rater reliability**, the degree to which different annotators agree, is your quality metric for annotation. Cohen's kappa above 0.7 is generally considered good; below 0.4 suggests your rubric needs work or your task is genuinely ambiguous. Track this continuously, not just at setup time. Annotator agreement tends to drift as people develop their own interpretations of ambiguous cases. Regular calibration sessions, where annotators discuss disagreements and align on edge cases, are essential but frequently skipped because they feel expensive. They're cheaper than training on noisy labels.

```python
from dataclasses import dataclass
from enum import Enum

class PreferenceLabel(Enum):
    A_MUCH_BETTER = "a_much_better"
    A_SLIGHTLY_BETTER = "a_slightly_better"
    TIE = "tie"
    B_SLIGHTLY_BETTER = "b_slightly_better"
    B_MUCH_BETTER = "b_much_better"

@dataclass
class PreferenceRecord:
    """A single preference judgment between two outputs."""
    record_id: str
    prompt: str
    response_a: str
    response_b: str

    # Metadata
    model_a: str
    model_b: str
    presentation_order: str  # "a_first" or "b_first" (randomized)

    # Annotation
    annotator_id: str
    label: PreferenceLabel
    rubric_version: str
    annotation_time_seconds: float
    annotator_confidence: int  # 1-5
    free_text_rationale: str = ""

def compute_cohens_kappa(
    labels_rater_1: list[str], labels_rater_2: list[str]
) -> float:
    """Compute Cohen's kappa for inter-rater reliability."""
    assert len(labels_rater_1) == len(labels_rater_2)
    n = len(labels_rater_1)
    categories = list(set(labels_rater_1 + labels_rater_2))

    # Observed agreement
    agree = sum(1 for a, b in zip(labels_rater_1, labels_rater_2) if a == b)
    p_o = agree / n

    # Expected agreement by chance
    p_e = sum(
        (labels_rater_1.count(c) / n) * (labels_rater_2.count(c) / n)
        for c in categories
    )

    if p_e == 1.0:
        return 1.0
    return (p_o - p_e) / (1 - p_e)
```

## Synthetic Data Generation

Using frontier models to generate training data for smaller, cheaper models is one of the most practically valuable techniques in modern AI engineering. If Claude Opus can do a task well but costs too much to run at scale, you can use it to generate thousands of labeled examples and then fine-tune a smaller model (Claude Haiku, Llama, Mistral) on those examples. The smaller model won't match the frontier model's quality on every case, but for well-scoped tasks, it can get close enough at a fraction of the cost.

Quality control is where most synthetic data efforts fail. A frontier model generating training data will produce some excellent examples, some mediocre ones, and some that are subtly wrong. If you train on all of them indiscriminately, you're baking those errors into your smaller model. The standard approach: filter either with another model (use a different frontier model to judge quality, reducing the chance of correlated errors) or with human review of a sample. A common pipeline: generate 10,000 examples with the frontier model, filter to the top 2,000 using a quality classifier, human-review 200 of those for spot-checking, and train on the filtered set.

The **bootstrap problem** is real: you need some initial data to get started, and if you don't have any, you're generating examples without a clear target quality level. Hand-craft 20-50 gold-standard examples first, use those as few-shot examples for the frontier model's generation, and then iterate. Your hand-crafted examples define the quality bar; the frontier model scales that bar to thousands of examples. Each round of generation, filtering, and review should improve the quality of both your training data and your evaluation criteria.

**Legal and terms-of-service considerations** are not optional. Most model providers' terms of service have specific language about using outputs to train competing models. As of early 2026, OpenAI's terms restrict using outputs to develop models that compete with OpenAI. Anthropic's terms are more permissive but still have restrictions. Open-weight models like Llama 3 have their own license terms. Read the actual terms, not blog post summaries, before building a synthetic data pipeline. If you're generating synthetic data from a proprietary model to fine-tune an open model, you may be in a legal gray area that's actively being litigated.

```python
import anthropic
import json
from typing import Optional

client = anthropic.Anthropic()

def generate_synthetic_examples(
    task_description: str,
    gold_examples: list[dict],
    n_generate: int = 100,
    model: str = "claude-sonnet-4-20250514",
) -> list[dict]:
    """Generate synthetic training examples using a frontier model."""

    # Format gold examples as few-shot demonstrations
    demos = "\n\n".join(
        f"Input: {ex['input']}\nOutput: {ex['output']}"
        for ex in gold_examples[:5]
    )

    results = []
    batch_size = 10  # Generate multiple per call for efficiency

    for i in range(0, n_generate, batch_size):
        response = client.messages.create(
            model=model,
            max_tokens=4096,
            messages=[{
                "role": "user",
                "content": f"""Generate {batch_size} training examples for this task:

{task_description}

Here are gold-standard examples showing the expected quality:

{demos}

Generate {batch_size} new, diverse examples in the same format.
Each should cover a different scenario. Output as JSON array with
"input" and "output" fields.

Important: Vary complexity, edge cases, and domains. Do not repeat
patterns from the examples above."""
            }]
        )

        try:
            # Parse the generated examples
            text = response.content[0].text
            # Extract JSON from response
            start = text.index('[')
            end = text.rindex(']') + 1
            examples = json.loads(text[start:end])
            results.extend(examples)
        except (json.JSONDecodeError, ValueError):
            continue  # Skip malformed batches

    return results[:n_generate]

def filter_with_judge(
    examples: list[dict],
    task_description: str,
    quality_threshold: float = 0.8,
    judge_model: str = "claude-sonnet-4-20250514",
) -> list[dict]:
    """Filter synthetic examples using a model judge."""

    filtered = []
    for ex in examples:
        response = client.messages.create(
            model=judge_model,
            max_tokens=256,
            messages=[{
                "role": "user",
                "content": f"""Rate this training example for quality.

Task: {task_description}

Input: {ex['input']}
Output: {ex['output']}

Rate on these criteria (0.0 to 1.0 each):
- Correctness: Is the output factually/logically correct?
- Relevance: Does the output address the input?
- Quality: Is this a good training example (clear, unambiguous)?

Respond with JSON: {{"correctness": X, "relevance": X, "quality": X}}"""
            }]
        )

        try:
            text = response.content[0].text
            start = text.index('{')
            end = text.rindex('}') + 1
            scores = json.loads(text[start:end])
            avg_score = sum(scores.values()) / len(scores)
            if avg_score >= quality_threshold:
                ex['quality_scores'] = scores
                filtered.append(ex)
        except (json.JSONDecodeError, ValueError, KeyError):
            continue

    return filtered
```

## Data Quality Fundamentals

Empirical evidence is clear and counterintuitive to anyone who grew up in the "big data" era: for fine-tuning language models, 100 carefully curated examples routinely outperform 10,000 noisy ones. This has been demonstrated across multiple studies, most notably in the LIMA paper (Zhou et al., 2023), which showed that fine-tuning with just 1,000 high-quality examples could produce very capable models. The mechanism is straightforward: a language model already has broad capabilities from pretraining, and fine-tuning is about steering those capabilities, not teaching new ones. Noisy data sends conflicting steering signals; curated data sends a clear one.

**Curation as craft** means treating each training example as a deliberate choice. Does this example represent the behavior you want? Is the output genuinely good, or just acceptable? Are the instructions clear enough that a different annotator would produce a similar output? Would you be comfortable if the model reproduced this example's style and quality for every user query? If the answer to any of these is no, the example is hurting more than it's helping. This sounds extreme, but the math is simple: a noisy example actively degrades the signal from your good examples.

**Diversity and coverage** matter as much as quality. A dataset of 100 perfect examples that all cover the same narrow task will produce a model that's great at that task and terrible at everything else. You want your curated set to span the range of inputs your system will encounter in production — different task types, different complexity levels, different domains, different failure modes. A useful heuristic: after curating your dataset, ask whether each major category of production traffic is represented. If you see a gap, fill it before adding more examples to categories you've already covered.

**Deduplication** is boring but essential. Duplicate or near-duplicate examples in your training data bias the model toward the duplicated patterns, beyond just wasting compute. Exact deduplication is trivial (hash and compare), but near-deduplication requires embedding-based similarity detection. Compute embeddings for all your training examples, flag any pairs with cosine similarity above 0.95, and manually review them. You'll typically find 5-15% near-duplicates in any organically collected dataset, and removing them consistently improves fine-tuning outcomes.

## Privacy and Data Governance

Using production data to improve your AI system means handling user data, and handling user data means navigating a complex legal landscape. Get this wrong and you face seven-figure fines. It isn't a "we'll figure it out later" problem.

**GDPR Article 6** requires a lawful basis for processing personal data. For AI training on user data, the most common bases are consent (the user explicitly agrees) and legitimate interest (you have a business reason that doesn't override the user's rights). Legitimate interest requires a balancing test: your interest in improving your product vs. the user's interest in not having their data used for training. This balancing test is not a formality; regulators have fined companies that treated it as one. If you're operating in the EU or processing EU residents' data, you need legal counsel on this, not a blog post.

**CCPA** (and its successor CPRA) gives California residents the right to opt out of the sale or sharing of their personal information. If you're using user data to train models and those models are part of your product, there's an active legal debate about whether that constitutes "sharing" under CCPA. Provide a clear opt-out mechanism and honor it. Assuming your use case isn't covered and hoping no one challenges you is the risky alternative.

Sector-specific rules add another layer. HIPAA for health data, FERPA for education data, GLBA for financial data. Each has specific requirements that go beyond general privacy law. If you're building AI in a regulated industry, your data pipeline needs to comply with sector-specific rules from the start, not as a retrofit.

**Anonymization** is harder than most engineers realize. Removing names and email addresses is pseudonymization at best. True anonymization means the data cannot be re-identified even with additional information. **Differential privacy** adds calibrated noise to data or query results so that no individual's contribution can be isolated. **PII scrubbing** uses pattern matching and NER models to identify and remove personally identifiable information, but it's never perfect. Unusual name formats, embedded identifiers in free text, and context-dependent PII (a job title that uniquely identifies someone at a small company) all evade automated scrubbing. Build your pipeline with the assumption that automated PII scrubbing will miss some things, and add human review for high-risk data.

**Retention policies** define how long you keep data. Data minimization (keep only what you need, for only as long as you need it) is both a GDPR requirement and good engineering practice. Define retention periods at the outset: interaction logs might be retained for 90 days for debugging, aggregated analytics for 2 years, and training datasets for the life of the model plus a compliance buffer. Implement automated deletion and audit it.

**Audit trails** document what data you collected, why, how it was processed, and who had access. If a regulator or a user asks "what did you do with my data?", you need to be able to answer precisely and provably. This means immutable logs of data processing operations, access controls with logging, and versioned records of which data was used to train which model version.

```python
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from enum import Enum
import re

class RetentionPolicy(Enum):
    DEBUG_LOGS = 90       # days
    INTERACTION_DATA = 365
    TRAINING_DATA = 1095  # 3 years
    AUDIT_LOGS = 2555     # 7 years

class LawfulBasis(Enum):
    CONSENT = "consent"
    LEGITIMATE_INTEREST = "legitimate_interest"
    CONTRACT = "contract_performance"

@dataclass
class DataGovernanceRecord:
    """Track data processing for compliance."""
    record_id: str
    data_source: str
    lawful_basis: LawfulBasis
    purpose: str
    retention_policy: RetentionPolicy
    pii_scrubbed: bool = False
    anonymized: bool = False
    user_consent_timestamp: datetime | None = None
    opt_out: bool = False
    processing_log: list[dict] = field(default_factory=list)

    def is_expired(self) -> bool:
        if not self.processing_log:
            return False
        created = self.processing_log[0].get("timestamp", datetime.utcnow())
        expiry = created + timedelta(days=self.retention_policy.value)
        return datetime.utcnow() > expiry

    def log_processing(self, action: str, actor: str):
        self.processing_log.append({
            "timestamp": datetime.utcnow(),
            "action": action,
            "actor": actor,
        })

def scrub_pii(text: str) -> str:
    """Basic PII scrubbing — NOT sufficient for production use alone."""
    # Email
    text = re.sub(r'\b[\w.+-]+@[\w-]+\.[\w.]+\b', '[EMAIL]', text)
    # Phone (US formats)
    text = re.sub(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b', '[PHONE]', text)
    # SSN
    text = re.sub(r'\b\d{3}-\d{2}-\d{4}\b', '[SSN]', text)
    # Credit card (basic)
    text = re.sub(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b', '[CC]', text)
    return text
```

> ## Reality Check
>
> The "data flywheel" is one of the most invoked concepts in AI strategy decks and one of the least often implemented. The reason is mundane: it requires deliberate instrumentation from day one, and most teams are too busy shipping features to build feedback infrastructure. They log model outputs religiously but never log whether users actually found those outputs useful. They collect thumbs-up/down clicks but never close the loop by incorporating that signal into model improvements. The flywheel only spins if every stage is connected (collection, processing, improvement, deployment) and most teams have gaps they don't even know about. Before you claim you have a data flywheel, trace the full loop and verify that signal actually flows from users to model improvements and back. Most of the time, it doesn't.

## Case Study: Harvey AI

Harvey AI, a legal AI platform serving law firms and corporate legal departments, is one of the clearest examples of a data flywheel built on expert feedback rather than raw volume. Their competitive advantage is more *expert-labeled* data, not more data overall. Their labelers are practicing lawyers who know when the model's legal analysis is subtly wrong in ways a non-expert would miss.

Harvey's approach inverts the typical consumer AI playbook. Consumer AI products optimize for volume: millions of users generating implicit signals through clicks and engagement. Harvey optimizes for signal quality: hundreds of legal professionals providing detailed corrections to AI-generated legal analysis. A single correction from a senior litigator ("this citation is from a case that was subsequently overruled") is worth more than ten thousand thumbs-up clicks from general users, because it captures domain expertise that the model couldn't acquire from pretraining data alone.

The flywheel works because legal work has a natural feedback structure. A lawyer reviews AI-generated analysis, corrects errors, and those corrections become training data for the next model iteration. The improved model produces fewer errors, which makes lawyers more willing to use it, which generates more corrections on harder edge cases, which improves the model further. Each cycle pushes the model deeper into the long tail of legal knowledge: the unusual jurisdictions, the obscure precedents, the subtleties of statutory interpretation that separate competent legal AI from actually useful legal AI.

This model generalizes to any vertical AI application in a domain with expert practitioners: medical AI with physician feedback, financial AI with analyst corrections, engineering AI with domain-expert review. The data moat comes from expert signal, not user volume. A competitor can't replicate Harvey's dataset by scraping legal texts. They need practicing lawyers who will systematically review and correct AI outputs over months and years.

## Practical Exercise

**Design a data flywheel for a hypothetical AI product.**

Choose one of the following product concepts (or use your own):
- An AI code review tool that flags bugs, style issues, and security vulnerabilities
- An AI customer support agent for a SaaS product
- An AI writing assistant for technical documentation

**Deliverables:**

1. **Signal inventory:** List every implicit and explicit feedback signal your product could capture. For each, specify: the event that generates it, what it tells you about output quality, the expected volume, and the noise level. Minimum 8 signals.

2. **Data logging architecture:** Design the schema for storing interactions and feedback. Specify: what's stored, where, retention policy, and access controls. Include at least one code artifact (schema definition, event class, or pipeline diagram).

3. **Improvement loop:** Describe exactly how collected signals inform system improvements. Be specific — "we'll use the data to improve the model" is not specific enough. Which signals feed into eval datasets? Which into fine-tuning data? Which into prompt iteration? Which into retrieval index updates?

4. **Privacy compliance:** Specify the lawful basis for processing, PII handling, opt-out mechanism, and retention policy. Identify at least two jurisdictions your product would operate in and note the relevant regulations.

5. **Flywheel projection:** Describe the state of your data flywheel at 6 months and 2 years. At 6 months, what has improved? What bottlenecks have you discovered? At 2 years, what competitive advantage has the flywheel created? Be honest about assumptions.

**Acceptance criteria:**
- Signal inventory is comprehensive (covers both implicit and explicit signals) and honest about noise levels
- Architecture is implementable, not just conceptual
- Privacy section references specific regulations, not hand-waving
- Flywheel projection includes realistic bottlenecks, not just optimistic projections

**Evaluation:** Self-assess against the acceptance criteria. Have a peer review the privacy section — this is where engineers most often have blind spots.

**Time estimate:** ~4 hours

## Checkpoint

After completing this chapter, you should be able to say:

- I can design a data collection pipeline that captures both implicit and explicit feedback signals from production AI usage
- I understand why 100 curated training examples typically outperform 10,000 noisy ones, and I can articulate the mechanism
- I can explain the difference between implicit signals (edits, regenerations, time-to-action) and explicit signals (ratings, corrections), including their respective tradeoffs
- I can navigate the legal constraints on using production data for model improvement, including GDPR lawful basis requirements and CCPA opt-out obligations
- I can design a synthetic data pipeline with appropriate quality filtering
- I can measure annotation quality using inter-rater reliability metrics
- I can explain what makes a data flywheel defensible vs. one that exists only in a pitch deck
- I can identify the privacy risks in a data collection pipeline and propose concrete mitigations
