# Chapter 10: Fine-tuning & Model Adaptation

## Why This Matters

Fine-tuning is the first thing most teams reach for when prompting doesn't get them to 100%. It feels like progress: you're training a model, you're "doing ML," you're customizing the system to your domain. The problem is that fine-tuning sits at a dangerous intersection of high cost, high complexity, and hard-to-measure benefit. If you don't have an eval suite that tells you exactly where your current system fails, fine-tuning is a coin flip dressed up as engineering. You might improve your target metric. You might degrade capabilities you weren't measuring. You won't know which happened unless your evaluation infrastructure is already solid.

This chapter is about making that decision honestly. We'll walk through the full adaptation hierarchy, from prompt engineering through pretraining, and develop a clear framework for when each approach is worth the investment. You'll learn what fine-tuning actually changes inside a model, how LoRA and QLoRA make it tractable on reasonable hardware, and when distillation or open-source models are the right play. But the throughline is disciplined decision-making. The teams that get the most out of fine-tuning are the ones that tried everything else first and can prove, with numbers and not vibes, that fine-tuning closed a specific gap.

By the end, you'll have both the conceptual framework and the practical skills to fine-tune a model when it's warranted. More importantly, you'll have the judgment to recognize when it isn't, which in practice is most of the time.

## The Decision Matrix: When to Fine-tune

A natural hierarchy of model adaptation exists, and each step up adds cost, complexity, and maintenance burden alongside its potential performance gains: **prompt engineering** → **retrieval-augmented generation (RAG)** → **fine-tuning** → **pretraining from scratch**. The correct default is to start at the left and move right only when you've exhausted the cheaper option and have eval data proving the next step would help. Most teams skip straight to fine-tuning because it feels like "real ML work," and they pay for that impatience in wasted cycles and ambiguous results.

Prompt engineering is where you should spend the most time before even considering fine-tuning. A well-structured system prompt with few-shot examples, clear formatting instructions, and chain-of-thought scaffolding can get you surprisingly far. If you haven't tried structured output formats, XML tagging, and role-based prompting with at least 20-30 diverse test cases, you haven't exhausted prompt engineering. RAG comes next. If your model needs domain-specific knowledge, don't bake it into the weights. Retrieve it at inference time. RAG is cheaper, more updatable, and auditable in ways that fine-tuned knowledge never will be. When the model gets something wrong with RAG, you can inspect the retrieved context and fix the source. When a fine-tuned model gets something wrong, you're retraining.

So when does fine-tuning actually make sense? The honest answer is narrower than most people think. **Fine-tuning for style and format** is usually worth it. If you need a model to consistently produce output in a very specific structure, tone, or persona, and few-shot examples aren't getting you there, fine-tuning can lock that behavior in reliably. **Fine-tuning for knowledge** is usually not worth it. RAG handles this better for almost every use case, and it doesn't suffer from the staleness problem where your fine-tuned knowledge becomes outdated the moment new information arrives. **Fine-tuning for behavioral policies** is sometimes worth it. If you need a model that consistently applies specific decision rules, refuses certain categories of requests, or follows a complex interaction protocol, fine-tuning can encode those policies more reliably than prompting alone.

The correct question to ask before any fine-tuning project is brutally specific: "What does fine-tuning solve that prompting and RAG can't?" If you can't answer that with a concrete metric ("our structured output compliance is at 87% with prompting and we need 98%") you don't have a fine-tuning problem. You have an evaluation problem. Solve that first.

> 💸 **Cost**: Fine-tuning costs extend well beyond the training run. There's data curation, eval infrastructure, model versioning, and ongoing maintenance when the base model gets updated and your fine-tune becomes stale. Budget for the full lifecycle, not just the training run.

## Instruction Tuning Conceptually

When you fine-tune a model, you're changing the model itself, not just its behavior. The **weights** — the billions of numerical parameters that define the model's knowledge, style, and capabilities — get updated. This differs from prompt engineering in kind, not degree: prompt engineering steers a fixed model's behavior through its inputs. Understanding this distinction matters because weight changes are permanent, global, and can have unintended consequences that prompt changes simply can't.

**Instruction tuning** (sometimes called supervised fine-tuning or SFT) is the most common form of fine-tuning for practitioners. You provide the model with examples of input-output pairs that demonstrate the behavior you want: "given this prompt, produce this response." The model's weights are updated to increase the probability of generating responses similar to your examples. Conceptually, you're shifting the model's distribution, making certain kinds of outputs more likely and others less likely. The model doesn't "learn" your examples the way a database stores records; it adjusts its internal representations to make outputs like your examples more probable across similar inputs.

What separates successful fine-tuning from wasted effort: **data quality determines the ceiling**. This is empirically well-established across the field. One hundred carefully curated, high-quality examples will typically outperform 10,000 noisy, inconsistent ones. Each training example is a signal to the model about what "good" looks like. If your examples are contradictory, poorly formatted, or contain errors, you're teaching the model to be contradictory, poorly formatted, and error-prone. The most common fine-tuning failure mode is insufficient data curation, not insufficient data. Teams scrape thousands of examples, throw them at the model, and wonder why performance degraded. The model learned exactly what you taught it. You just taught it the wrong things.

**Catastrophic forgetting** is the other major risk of fine-tuning, and it catches people off guard. When you fine-tune a model on domain-specific data, you're updating weights that were previously tuned for general capabilities. Those updates can overwrite the general knowledge encoded in those same weights. A model fine-tuned heavily on legal documents might become excellent at legal analysis while losing its ability to write coherent Python or engage in general conversation. The model didn't "forget" in the human sense. The weight updates that improved legal performance happened to degrade the representations that supported other capabilities.

Mitigating catastrophic forgetting is a real engineering challenge. The most practical strategies: keep your fine-tuning dataset diverse enough that it doesn't push the model too far into a single domain, use a low learning rate so weight updates are small and incremental, and most importantly, include general-capability examples in your fine-tuning mix alongside your domain-specific data. If you fine-tune on 500 legal examples, mix in 200 general instruction-following examples to anchor the model's broader capabilities. And always, always evaluate on both your target domain and a general capability benchmark before and after fine-tuning. If your legal accuracy went from 78% to 94% but your general helpfulness dropped from 91% to 72%, you've traded one kind of performance for another.

> ⚡ **Production Tip**: Before fine-tuning, create a "before" snapshot of your eval results across both your target domain and general capabilities. After fine-tuning, run the exact same eval suite. The delta on your target metric is the benefit. The delta on general capabilities is the cost. Only ship if the tradeoff is actually favorable.

## LoRA and PEFT: Practical Fine-tuning with Limited Compute

Full fine-tuning updates every parameter in the model. For a 7-billion-parameter model, that means adjusting 7 billion floating-point numbers, which requires enough GPU memory to hold the model weights, the optimizer states, and the gradients. Easily 60-80 GB of VRAM for even a modestly sized model. For a 70B model, you're looking at a multi-GPU cluster. This is why fine-tuning was, until recently, the province of well-funded labs with racks of A100s.

**LoRA** — **Low-Rank Adaptation** — changed the economics entirely. When you fine-tune a model, the weight updates tend to have low intrinsic rank. That means the matrix of changes you're making to any given weight matrix can be well-approximated by the product of two much smaller matrices. Instead of updating a weight matrix W (say, dimensions 4096 x 4096, or about 16 million parameters), you learn two small matrices A and B where A is 4096 x 16 and B is 16 x 4096. The update is approximated as BA, which has only about 131,000 parameters — less than 1% of the original. The original weights are frozen; only the small adapter matrices are trained.

Why does this work? Fine-tuning for a specific task doesn't require reshaping the model's entire knowledge structure. It requires nudging it in a particular direction, and that nudge lives in a low-dimensional subspace of the full parameter space. The rank of the adapter (the "16" in our example, controlled by the `r` parameter) determines how expressive the adaptation can be. Ranks of 8-64 cover most practical use cases. Higher ranks give more expressive power at the cost of more parameters to train and more risk of overfitting.

**QLoRA**, introduced by Dettmers et al. in 2023, took this further by combining LoRA with quantization. The base model weights are stored in 4-bit precision (instead of the usual 16-bit), cutting memory requirements by 4x. The LoRA adapter matrices are trained in higher precision, then the gradients are computed through the quantized base model. The result: you can fine-tune a 65B parameter model on a single 48GB GPU, or a 7B model on consumer hardware with 16GB of VRAM. QLoRA made fine-tuning accessible to individual practitioners and small teams without access to data center hardware.

The Hugging Face ecosystem has made this very practical. The **PEFT** (Parameter-Efficient Fine-Tuning) library provides a clean abstraction over LoRA, QLoRA, and several other adapter methods. Combined with the `transformers` and `datasets` libraries, you can go from a dataset to a fine-tuned model in under 100 lines of Python. A complete LoRA fine-tuning setup:

```python
# lora_finetune.py
# Fine-tunes a small model with LoRA on a custom instruction dataset.
# Requires: pip install transformers peft datasets accelerate bitsandbytes

import torch
from datasets import Dataset
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling,
)
from peft import LoraConfig, get_peft_model, TaskType

# --- Configuration ---
BASE_MODEL = "meta-llama/Llama-3.2-1B-Instruct"  # Small enough for consumer GPU
OUTPUT_DIR = "./lora-finetuned-model"
LORA_R = 16          # Rank of the adapter matrices
LORA_ALPHA = 32      # Scaling factor (alpha / r = effective learning rate multiplier)
LORA_DROPOUT = 0.05  # Dropout on adapter layers for regularization

# --- Load model and tokenizer ---
tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    BASE_MODEL,
    torch_dtype=torch.bfloat16,
    device_map="auto",
)

# --- Configure LoRA ---
lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=LORA_R,
    lora_alpha=LORA_ALPHA,
    lora_dropout=LORA_DROPOUT,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],  # Attention layers
    bias="none",
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# Typical output: "trainable params: 1,572,864 || all params: 1,237,886,976 || trainable%: 0.127"

# --- Prepare training data ---
# In practice, load your curated dataset from disk or Hugging Face Hub.
# This example uses a small inline dataset to show the format.
raw_examples = [
    {
        "instruction": "Summarize the key risks of this contract clause.",
        "input": "The Vendor shall indemnify the Client against all claims arising from "
                 "the Vendor's negligence, provided that the Client notifies the Vendor "
                 "within 30 days of becoming aware of such claim.",
        "output": "Key risks: (1) 30-day notification window is tight and could be missed, "
                  "voiding indemnification. (2) 'Negligence' is undefined — disputes over "
                  "what qualifies are likely. (3) No cap on indemnification liability.",
    },
    {
        "instruction": "Identify the governing law in this agreement.",
        "input": "This Agreement shall be governed by and construed in accordance with "
                 "the laws of the State of Delaware, without regard to its conflict of "
                 "laws provisions.",
        "output": "Governing law: State of Delaware. Note: conflict of laws provisions "
                  "are explicitly excluded, which means Delaware substantive law applies "
                  "even if another jurisdiction's laws might otherwise be relevant.",
    },
    # ... In practice, you'd have 100-500 high-quality examples like these.
]


def format_example(example: dict) -> str:
    """Format a single example into the chat template the model expects."""
    text = (
        f"### Instruction:\n{example['instruction']}\n\n"
        f"### Input:\n{example['input']}\n\n"
        f"### Response:\n{example['output']}{tokenizer.eos_token}"
    )
    return text


def tokenize(example: dict) -> dict:
    text = format_example(example)
    tokenized = tokenizer(
        text,
        truncation=True,
        max_length=512,
        padding="max_length",
    )
    tokenized["labels"] = tokenized["input_ids"].copy()
    return tokenized


dataset = Dataset.from_list(raw_examples)
tokenized_dataset = dataset.map(tokenize, remove_columns=dataset.column_names)

# --- Training ---
training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,  # Effective batch size = 16
    learning_rate=2e-4,
    weight_decay=0.01,
    warmup_steps=10,
    logging_steps=10,
    save_strategy="epoch",
    bf16=True,
    report_to="none",  # Set to "wandb" for experiment tracking
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=tokenized_dataset,
    data_collator=DataCollatorForLanguageModeling(tokenizer, mlm=False),
)

trainer.train()

# --- Save the adapter (not the full model) ---
model.save_pretrained(OUTPUT_DIR)
tokenizer.save_pretrained(OUTPUT_DIR)
print(f"LoRA adapter saved to {OUTPUT_DIR}")
print(f"Adapter size on disk: ~{sum(p.numel() for p in model.parameters() if p.requires_grad) * 2 / 1e6:.1f} MB")

# --- Inference with the fine-tuned adapter ---
from peft import PeftModel

base_model = AutoModelForCausalLM.from_pretrained(
    BASE_MODEL,
    torch_dtype=torch.bfloat16,
    device_map="auto",
)
model = PeftModel.from_pretrained(base_model, OUTPUT_DIR)

prompt = (
    "### Instruction:\nSummarize the key risks of this contract clause.\n\n"
    "### Input:\nEither party may terminate this agreement with 7 days written notice. "
    "Upon termination, all licenses granted herein shall immediately cease.\n\n"
    "### Response:\n"
)

inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
with torch.no_grad():
    outputs = model.generate(**inputs, max_new_tokens=200, temperature=0.7)
print(tokenizer.decode(outputs[0], skip_special_tokens=True))
```

A few things to notice about this code. The `target_modules` parameter specifies which layers get LoRA adapters. Targeting the attention projection layers (q, k, v, o) is the standard approach because attention is where most of the task-specific adaptation happens. The `lora_alpha` parameter controls scaling: the effective weight of the adapter is `alpha / r`, so `alpha=32` with `r=16` gives a multiplier of 2. The saved adapter is tiny, often under 10 MB, compared to the multi-gigabyte base model. You can swap different LoRA adapters onto the same base model for different tasks, which is very practical in production when you need multiple specialized behaviors from a single model deployment.

> 🤔 **Taste Moment**: The rank `r` is the most important hyperparameter in LoRA, and there's no formula for choosing it. Start with `r=16` for most tasks. If the model isn't adapting enough, try `r=32` or `r=64`. If you're overfitting (training loss drops but eval performance doesn't improve or degrades), drop to `r=8`. The right rank depends on how far from the base model's natural behavior your target task is — simple style changes need low rank, complex behavioral changes need higher rank.

## RLHF and Preference Tuning at a Conceptual Level

Instruction tuning teaches a model what to say. **Preference tuning** teaches it what's better, and that distinction matters more than it might seem. When you instruction-tune a model, you're saying "given this input, produce this output." When you preference-tune, you're saying "given this input, output A is better than output B." The model learns to produce good outputs and to distinguish between degrees of quality. This mechanism produces the polish and judgment that separates frontier models from raw instruction-tuned checkpoints.

**Reinforcement Learning from Human Feedback (RLHF)** is the original approach, and understanding it conceptually is important even if you'll never implement it directly. The process has three stages. First, you collect comparison data: human annotators look at pairs of model outputs for the same prompt and indicate which is better. Second, you train a **reward model** on this preference data — a separate neural network that learns to predict which output a human would prefer. Third, you use reinforcement learning (specifically, Proximal Policy Optimization or PPO) to fine-tune the language model to produce outputs that score highly according to the reward model. The language model is the "policy," the reward model provides the "reward signal," and RL handles the optimization.

Most practitioners don't do RLHF directly because it's difficult to get right. You need substantial human annotation infrastructure: not a few hundred comparisons, but thousands to tens of thousands, with careful quality control and annotator calibration. The reward model can develop blind spots or biases that the RL process then amplifies. And PPO is notoriously unstable: it requires careful hyperparameter tuning, and the training can collapse or diverge if the reward model provides inconsistent signals. RLHF is what makes Claude, GPT-4, and Gemini feel polished and aligned, but the teams running it have dedicated infrastructure and years of institutional knowledge.

**Direct Preference Optimization (DPO)**, introduced by Rafailov et al. in 2023, simplifies this considerably. DPO derives a closed-form loss function that directly optimizes the language model on preference pairs, without needing a separate reward model or RL training loop. Instead of the three-stage RLHF pipeline, you have a single supervised training step. You provide pairs of (prompt, chosen response, rejected response), and the model learns to increase the probability of chosen responses relative to rejected ones. The theoretical guarantees are equivalent to RLHF under certain assumptions, but the practical stability is much better.

DPO has become the go-to approach for teams that want preference-aligned behavior without RLHF infrastructure. Data requirements are lower (hundreds to low thousands of preference pairs can produce meaningful improvements), training is stable (standard supervised learning, no RL instabilities), and results are competitive with RLHF for most practical purposes. If you're fine-tuning an open-source model and want to improve its judgment, helpfulness, or safety beyond what instruction tuning achieves, DPO is almost certainly the right starting point.

> 🔒 **Security**: Preference tuning is where safety behaviors are primarily instilled. If you fine-tune a model — even with LoRA — you can inadvertently weaken safety training. Always test your fine-tuned model against safety benchmarks, not just task performance. A model that's 5% better at your target task but 20% worse at refusing harmful requests is not an improvement.

## Distillation: Using Big Models to Train Small Ones

A scenario that comes up constantly in production AI: you've built a system that works beautifully with Claude Opus or GPT-4, but the latency is 3 seconds per request, the cost is $0.02 per call, and you're processing 10 million requests per day. The math doesn't work. You need a smaller, faster, cheaper model that preserves the behavior you've spent weeks engineering. **Distillation** solves this.

**Knowledge distillation** is the process of training a smaller "student" model to mimic the behavior of a larger "teacher" model. The classic approach, introduced by Hinton et al. in 2015, trains the student on the teacher's **soft labels** — the full probability distribution over outputs, not just the top prediction. When a teacher model predicts "Paris" as the capital of France with 97% probability and "Lyon" with 1% probability, those secondary probabilities contain information about the relationships between concepts. Training on soft labels transfers richer knowledge than training on hard labels (just "Paris") alone.

In the LLM era, distillation most commonly takes a more pragmatic form: you use a frontier model to generate high-quality training data, then fine-tune a smaller model on that data. The workflow: run your target prompts through Claude Opus or GPT-4, collect the responses, curate them (removing failures, fixing edge cases), and use the resulting dataset to fine-tune a smaller model like Llama 3 8B or Mistral 7B. The smaller model learns to approximate the larger model's behavior on your specific task distribution. It won't match the teacher's general capabilities, but for your particular use case, it can get very close.

When does distillation make economic sense? The calculation is straightforward. If a frontier API call costs $0.01 and takes 2 seconds, and you need sub-100ms latency or process millions of requests daily, the API cost and latency are prohibitive. A distilled 7B model running on a single GPU can serve requests in 50ms at a fraction of the per-request cost. The breakeven depends on your volume, but for most high-volume applications, the infrastructure cost of self-hosting a small model is lower than the API cost of a frontier model within weeks to months. The tradeoffs are real. You're taking on model serving infrastructure, you lose the automatic improvements when the frontier model gets updated, and your model is frozen at the capability level of the training data. But for the right use cases, distillation is the economically rational choice.

A subtlety that matters for production: distillation works best for **constrained tasks** with well-defined input and output spaces. If your task is "classify customer support tickets into 15 categories," distillation will work brilliantly. If your task is "have an open-ended conversation about anything the user asks," distillation will produce a model that's noticeably worse than the teacher on the long tail of unusual requests. The narrower your task, the better distillation works, because a small model can cover a narrow distribution more completely.

> 💸 **Cost**: Before building a distillation pipeline, do the math. Calculate your current API spend, estimate the infrastructure cost of self-hosting (GPU rental, serving framework, monitoring, on-call), and add the one-time cost of building the pipeline. Distillation often pays for itself at >1M requests/month, but the breakeven varies wildly depending on your task complexity and latency requirements.

> ⚡ **Production Tip**: When generating distillation data with a frontier model, always include diverse examples and edge cases. The student model will only be as good as the training distribution. If you generate 10,000 examples of "normal" inputs and zero examples of edge cases, the student will handle normal inputs well and fail catastrophically on anything unusual. Budget 20-30% of your distillation dataset for edge cases and failure modes.

## Open Source Models (as of Early 2026)

The open-source model landscape has shifted considerably since 2023, when Meta released the original Llama and kicked off a wave of open-weight models that reshaped the field. As of early 2026, the gap between open-source and frontier proprietary models has narrowed enough that for many production use cases, an open-source model is the right answer over a frontier API.

**Llama 3** from Meta is the current standard-bearer. The Llama 3 family spans from 1B to 405B parameters, with the 8B and 70B variants being the most practically relevant. The 8B model handles instruction following, summarization, and structured extraction at a level that would have been frontier-only two years ago. The 70B model is competitive with early GPT-4 on many benchmarks and useful for complex tasks. The 405B model approaches current frontier performance but requires significant infrastructure to serve. Meta's permissive license allows commercial use, which matters if you're building a product.

**Mistral** and its mixture-of-experts variant **Mixtral** from Mistral AI have been consistently punching above their weight class. Mixtral's sparse architecture, where only a subset of the model's parameters activate for any given token, provides an excellent efficiency-to-capability ratio. You get close to the performance of a dense model twice the size at roughly the inference cost of the smaller model. Mistral has also been aggressive about releasing models with strong multilingual capabilities, making them a natural choice for non-English applications.

**Qwen** from Alibaba is the dark horse that's become impossible to ignore. The Qwen 2.5 series, particularly the 72B variant, has posted benchmark numbers competitive with or exceeding Llama 3 70B on many tasks. Qwen's strength is especially notable on coding benchmarks and multilingual tasks, and their licensing is commercially permissive. If you're evaluating open-source models in early 2026 and not including Qwen in your comparison, you're leaving performance on the table.

An honest capability comparison: for **constrained, well-defined tasks** (classification, extraction, summarization, format transformation) the best open-source models at 70B+ are within 5-10% of frontier proprietary models. That gap often closes further with task-specific fine-tuning. For **open-ended, complex reasoning** (multi-step analysis, creative problem-solving, handling ambiguous instructions) frontier models still hold a meaningful advantage, particularly the reasoning variants like o3 and Claude's extended thinking mode. Open-source models are excellent at following instructions they've seen during training; they're weaker at generalizing to novel instruction patterns.

When does open source beat frontier? Four clear cases. First, **privacy requirements**: if your data cannot leave your infrastructure (healthcare, legal, financial, government) self-hosted open-source models are the only option. No amount of API provider assurances replaces data never leaving your network. Second, **latency-critical applications**: a 7B model on a local GPU can serve responses in 30-50ms. No API call, regardless of the provider's infrastructure, can match that. Network round-trip time alone exceeds it. Third, **very high volume with constrained tasks**: when you're processing millions of requests per day on a well-defined task, the economics of self-hosting almost always beat API pricing. Fourth, **offline and edge deployment**: models running on devices, in air-gapped environments, or in locations with unreliable internet connectivity require self-hosted solutions.

Self-hosting tradeoffs are real and you should go in with open eyes. **Data privacy** is the strongest argument. Your data never leaves your infrastructure, full stop. **Latency** can be excellent for small models but degrades quickly with model size; serving a 70B model with reasonable latency requires serious GPU infrastructure. **Cost at scale** favors self-hosting for high volume, but there's a substantial upfront investment in infrastructure, serving frameworks (vLLM, TGI, or similar), and operational tooling. **Maintenance burden** is the hidden cost. You're responsible for model updates, GPU driver compatibility, serving framework upgrades, monitoring, and on-call rotations. A frontier API abstracts all of this away. When you self-host, you own it.

> 🤔 **Taste Moment**: The "open source vs. API" decision isn't permanent. A common and effective pattern is to prototype and validate with a frontier API, then distill to an open-source model for production once you've proven the use case and stabilized the requirements. APIs give you speed during exploration; self-hosting gives you economics and control at scale. Don't lock into either too early.

> 🔒 **Security**: "Open-source" doesn't mean "audited." Just because you can read a model's architecture and weights doesn't mean you know what's in the training data or what behaviors might emerge in edge cases. Run your own safety evaluations on any open-source model before deploying it in a user-facing application. The model card isn't a security audit.

## Reality Check

> Most teams fine-tune too early, for the wrong reasons, and without adequate eval infrastructure to know if it worked. Fine-tuning is often reached for because it feels like "doing more." It's technical, it involves GPUs, and it produces an artifact you can point to. But feeling like progress and being progress are different things. Exhaust prompt engineering and RAG first, build a proper eval suite, then ask whether fine-tuning would actually improve your eval metrics. If you can't measure the improvement, you don't know if you've improved anything.
>
> A common fine-tuning story: a team spends two weeks curating data and training a LoRA adapter. They evaluate it on a handful of cherry-picked examples and declare victory. Three weeks later, users report weird edge-case failures that the base model didn't have. The team discovers they've introduced catastrophic forgetting on a capability they never tested. They spend another two weeks debugging, re-curating, and retraining. The result is marginally better than what a senior engineer could have achieved in two days with better prompting.
>
> None of this argues against fine-tuning. It argues for discipline. Fine-tuning is a precision tool, not a blunt instrument. Use it when you've diagnosed a specific failure mode, when you've proven that prompting and RAG can't address it, when you have an eval suite that measures exactly what you're trying to improve, and when you've established a baseline against which to measure the result. Under those conditions, fine-tuning is powerful. Under any other conditions, it's a distraction.

## Case Study: From API to Self-Hosted — A Document Processing Pipeline

Consider a fintech company processing 500,000 loan applications per month. Each application includes 20-40 pages of documents — pay stubs, tax returns, bank statements — that need structured data extraction. Their initial system uses Claude Sonnet via API. Upload each document, extract fields into JSON. It works well — 96% accuracy on their eval suite of 2,000 annotated documents. But the cost is $45,000/month in API fees, and the 2-3 second latency per document means processing a full application takes 40-60 seconds.

Their hypothesis: they can fine-tune an open-source model to match Claude's accuracy on this specific, well-constrained extraction task. Their approach is methodical. First, they use Claude Sonnet to generate structured extractions for 15,000 documents, then have domain experts review and correct 3,000 of them — fixing errors, standardizing edge cases, and ensuring consistency. Second, they fine-tune Llama 3 8B with LoRA on the corrected dataset. Third, they evaluate on their held-out test set: the fine-tuned model achieves 94.2% accuracy — slightly below Claude's 96%, but within their acceptable threshold. Fourth, they deploy on two A100 GPUs using vLLM, achieving 200ms per document — a 10x latency improvement.

GPU infrastructure costs $8,000/month (cloud) versus $45,000/month in API fees. The fine-tuned model is faster and cheaper, with a 1.8% accuracy tradeoff that the business accepts because the remaining errors go to human review anyway. One-time engineering cost: about six weeks of work, including data curation, training, evaluation, and deployment infrastructure. Breakeven: under two months.

What went right: the task was constrained (structured extraction from known document types), they had excellent eval infrastructure, they curated their training data carefully, and they made a clear-eyed decision about the accuracy-cost tradeoff. What could have gone wrong: if the task had been open-ended, if they hadn't invested in eval infrastructure, or if they'd skipped the data curation step, the fine-tuned model would have been worse than the API in ways they couldn't measure until users complained.

## Practical Exercise

**Fine-tune a small open-source model on a domain-specific task, then honestly evaluate whether it beats a well-prompted frontier model.** (~8 hours)

The structured approach:

**Part 1: Task Definition and Eval Suite (1.5 hours).** Pick a constrained task in a domain you know well — it could be classification, extraction, summarization, or format transformation. Define exactly what "good" looks like with a rubric. Build an eval suite of at least 50 examples with gold-standard labels. Split into 80% train, 20% held-out test. The held-out set is sacred — you never train on it, and you never look at it until final evaluation.

**Part 2: Establish the Frontier Baseline (1 hour).** Implement the task using a frontier model (Claude Sonnet or GPT-4o) with your best prompting: system prompt, few-shot examples, structured output format. Run it against your full eval suite and record the metrics. This is the number to beat. Don't optimize the prompting forever, but spend enough time that you're confident the prompt is reasonably good.

**Part 3: Data Preparation (1 hour).** Curate your training data. If you have fewer than 100 domain-specific examples, use the frontier model to generate additional training data, then manually review and correct every example. Quality over quantity. Format the data in the instruction-input-output structure your fine-tuning script expects.

**Part 4: Fine-tune with LoRA (2 hours).** Using the code pattern from this chapter, fine-tune a small open-source model (Llama 3.2 1B or 3B) with LoRA on your training data. Experiment with rank (8, 16, 32) and learning rate (1e-4, 2e-4, 5e-4). Track training loss and evaluate on your held-out set after each epoch. Pick the best checkpoint.

**Part 5: Comparative Evaluation (1 hour).** Run your best fine-tuned model and the frontier baseline against the held-out test set. Record accuracy, latency, and any qualitative differences in output quality. Pay attention to failure modes. Does the fine-tuned model fail differently than the frontier model?

**Part 6: Write the Analysis (1.5 hours).** This is the most important part. Write an honest analysis covering: Which model performed better on your eval suite, and by how much? What would it cost to run each model in production at 10,000 requests/day? How long did the fine-tuning pipeline take, and what would ongoing maintenance look like? Would you actually ship the fine-tuned model, or would you stick with the API? Why? The analysis is as important as the fine-tuning. Making this decision clearly, with numbers instead of vibes, is the skill this exercise develops.

## Checkpoint

After completing this chapter, you should be able to confidently say:

**I can explain the prompt → RAG → fine-tune → pretrain decision hierarchy.** You understand that each step adds cost and complexity, and you know the specific conditions under which moving to the next step is justified. You wouldn't fine-tune before exhausting prompt engineering and RAG, and you can articulate why.

**I understand what LoRA does and why it works.** You can explain low-rank decomposition of weight updates to a colleague, you know what the rank parameter controls, and you can set up a LoRA fine-tuning run using Hugging Face PEFT. You understand that the adapter is small and swappable, and you know how to load it onto a base model for inference.

**I can evaluate whether fine-tuning is worth the investment for a specific use case.** You have a mental checklist: Is the task constrained? Have I exhausted prompting and RAG? Do I have an eval suite? Can I measure the improvement? Is the accuracy-cost tradeoff favorable? You can walk through this checklist for any proposed fine-tuning project and give a clear recommendation.

**I know when open-source models are the right choice.** Privacy requirements, latency constraints, high volume with constrained tasks, and offline deployment — you can identify these conditions and make the self-hosting tradeoff calculation. You also understand the maintenance burden and don't underestimate it.

**I understand catastrophic forgetting and how to mitigate it.** You know that fine-tuning can degrade general capabilities, you know to evaluate on both target and general benchmarks, and you know the practical mitigations: low learning rate, diverse training data, mixed general and domain-specific examples.

---

*Key references: Dettmers et al., "QLoRA: Efficient Finetuning of Quantized Language Models" (2023). Rafailov et al., "Direct Preference Optimization: Your Language Model is Secretly a Reward Model" (2023). Hugging Face PEFT library: [https://huggingface.co/docs/peft](https://huggingface.co/docs/peft). MTEB benchmark: [https://huggingface.co/spaces/mteb/leaderboard](https://huggingface.co/spaces/mteb/leaderboard).*
