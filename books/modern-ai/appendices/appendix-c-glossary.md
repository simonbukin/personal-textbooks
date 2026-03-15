# Appendix C: Glossary

Every major technical term from this book, alphabetized. Each entry includes the term, a definition, and the chapter where it's first introduced or most thoroughly discussed.

---

**Agent** — An AI system that plans, executes actions using tools, observes results, and iterates toward a goal. Agents differ from simple LLM calls in that they make autonomous decisions about which actions to take and when to stop. *Chapter 6*

**Alignment** — The problem of ensuring an AI system's behavior matches human intentions and values. In practice, alignment is achieved through RLHF, Constitutional AI, DPO, and other training techniques, none of which provide formal guarantees. *Chapter 14*

**Batch API** — An API pattern where requests are submitted in bulk and processed asynchronously, typically at lower cost and higher latency than real-time APIs. Useful for large-scale eval runs, data processing, and non-latency-sensitive workloads. *Chapter 3*

**Benchmark** — A standardized test suite used to measure model performance on specific tasks. Common benchmarks include MMLU, SWE-bench, GAIA, and HumanEval. Benchmarks track real capability improvements but are subject to Goodhart's Law: when a measure becomes a target, it ceases to be a good measure. *Chapter 1*

**Chain-of-thought (CoT)** — A prompting technique where the model is asked to show its reasoning step by step before producing a final answer. Improves performance on multi-step reasoning tasks by forcing the model to condition each step on the previous one. *Chapter 2*

**Chunking** — The process of splitting documents into smaller segments for embedding and retrieval in RAG systems. Chunk size, overlap, and boundary selection affect retrieval quality. *Chapter 4*

**Circuit breaker** — A reliability pattern that stops retrying a failing service after consecutive failures, allowing the service time to recover. Transitions between closed (normal), open (failing, don't retry), and half-open (testing recovery) states. *Chapter 9*

**Constitutional AI (CAI)** — An alignment approach developed by Anthropic that uses a set of written principles (a "constitution") to guide model behavior. The model critiques and revises its own outputs against these principles, generating training data that supplements human feedback. *Chapter 14*

**Context engineering** — The systematic design of everything that goes into a model's context window — prompts, retrieved documents, tool results, conversation history, and project-level configuration. Distinguished from prompt engineering by its broader scope: optimizing the full information environment, not just the text you write. *Chapter 13*

**Context window** — The maximum number of tokens a model can process in a single call, encompassing both input and output. Context windows range from 4K to 1M+ tokens depending on the model. Context is a finite resource; every token included displaces something else. *Chapter 2*

**Cross-encoder** — A model architecture that processes a query-document pair jointly, producing a relevance score. More accurate than bi-encoder (embedding) retrieval but much slower, making cross-encoders suitable for re-ranking a small set of candidates rather than searching a large corpus. *Chapter 4*

**Distillation** — Training a smaller "student" model to reproduce the behavior of a larger "teacher" model. The student learns from the teacher's output distribution rather than from raw training data, capturing knowledge that would otherwise require a much larger model. *Chapter 10*

**DPO (Direct Preference Optimization)** — An alignment technique that simplifies RLHF by eliminating the separate reward model. DPO directly optimizes the language model on preference data using a reformulated objective. Simpler and more stable than RLHF, widely used for open-source model alignment. *Chapter 14*

**Embedding** — A dense vector representation of text (or other data) in a high-dimensional space where semantic similarity corresponds to geometric proximity. Embeddings enable semantic search, clustering, and retrieval. Produced by specialized embedding models. *Chapter 4*

**Extended thinking** — A model capability where the model generates internal reasoning tokens before producing a visible response. The model allocates its own reasoning budget, trading latency and cost for improved performance on complex problems. Also called "thinking mode" or "inference-time compute scaling." *Chapter 2*

**Eval** — Short for evaluation. A systematic, quantitative assessment of an AI system's performance on a defined test set. Good evals are the foundation of reliable AI engineering. Without them, you're guessing. *Chapter 2*

**Few-shot prompting** — Including example input-output pairs in the prompt to demonstrate the desired behavior. Few-shot examples outperform descriptions of desired behavior for most tasks because they show rather than tell. *Chapter 2*

**Fine-tuning** — Continuing a model's training on a domain-specific dataset to adapt its behavior for a particular use case. Fine-tuning modifies model weights and requires training infrastructure, unlike prompting which works within the existing model. *Chapter 10*

**Function calling** — A model capability where the model outputs structured function call specifications (function name and arguments) rather than free text. The application then executes the function and returns results to the model. The foundation of tool use in production AI systems. *Chapter 5*

**GAIA** — General AI Assistants benchmark. Tests multi-step reasoning, web browsing, and tool use on real-world tasks. Designed to be hard for AI and easy for humans. Top scores near 90% as of early 2026. *Chapter 1*

**Guardrail** — A mechanism that constrains AI system behavior to prevent harmful, off-topic, or otherwise undesirable outputs. Guardrails include input filters, output validators, topic classifiers, and secondary model evaluations. *Chapter 5*

**Hallucination** — When a model generates content that is factually incorrect, fabricated, or unsupported by its input context. Hallucination occurs because LLMs generate statistically likely text, not verified facts. The term is contested. Models don't "hallucinate" in the human sense; they generate, and sometimes what they generate is wrong. *Chapter 1*

**HyDE (Hypothetical Document Embeddings)** — A retrieval technique where the model generates a hypothetical answer to a query, and that answer is embedded and used for retrieval instead of the original query. Bridges the vocabulary gap between questions and answers. *Chapter 4*

**Inference-time compute scaling** — The practice of spending more compute at inference time (via reasoning tokens, multiple passes, or verification steps) to improve output quality on difficult tasks. Represents a shift from improving AI solely through training to also improving it through smarter inference strategies. *Chapter 2*

**Indirect prompt injection** — An attack where malicious instructions are embedded in content the model processes (retrieved documents, tool outputs, user data) rather than in the direct user prompt. Dangerous because the model may follow injected instructions without the user's awareness. *Chapter 5*

**Instruction tuning** — Training a pretrained model on curated instruction-response pairs to make it follow directions. Transforms a text-completion engine into an assistant that answers questions and follows formatting instructions. Also called supervised fine-tuning (SFT). *Chapter 1*

**LangGraph** — A framework for building stateful, multi-step AI workflows as directed graphs. Nodes are processing steps (LLM calls, tool use, decisions), edges define flow. Provides state management, persistence, and human-in-the-loop patterns. *Chapter 8*

**LlamaIndex** — A data framework for connecting LLMs with external data sources. Provides abstractions for data ingestion, indexing, and retrieval, particularly for RAG applications. *Chapter 8*

**LoRA (Low-Rank Adaptation)** — A parameter-efficient fine-tuning technique that adds small trainable matrices to frozen model layers. LoRA reduces the number of trainable parameters (and thus GPU memory and compute requirements) while preserving most of the quality of full fine-tuning. *Chapter 10*

**MCP (Model Context Protocol)** — An open protocol for connecting AI models to external tools and data sources. Defines a standard interface for tool discovery, invocation, and result handling. Enables AI agents to use any tool that implements the protocol without custom integration code. *Chapter 7*

**MMLU (Massive Multitask Language Understanding)** — A benchmark testing knowledge across 57 academic subjects. Largely saturated; top models score above 90%. Useful for tracking broad knowledge but poor at discriminating between frontier models. *Chapter 1*

**Mixture of experts (MoE)** — A model architecture that routes each input to a subset of specialized sub-networks ("experts") rather than processing through the entire model. Enables larger effective model capacity with lower inference cost, since only a fraction of parameters are active per token. Used in models like Mixtral. *Appendix A*

**Model deprecation** — The process by which model providers retire older model versions, requiring users to migrate to newer versions. Migrations can break prompts tuned for specific model behavior and require eval suite validation before switching. *Chapter 9*

**Model routing** — Directing different requests to different models based on task complexity, cost sensitivity, or latency requirements. Simple queries go to a small, fast, cheap model; complex queries go to a large, slow, expensive one. Reduces costs while maintaining quality where it matters. *Chapter 9*

**Multimodal** — Refers to models that process multiple types of input — text, images, audio, video — rather than text alone. Multimodal capabilities enable document understanding, image analysis, and voice interaction. *Chapter 2*

**Next-token prediction** — The fundamental operation of autoregressive language models: given a sequence of tokens, predict the probability distribution over what the next token should be. Everything an LLM does (conversation, code generation, reasoning) emerges from this single operation applied at scale. *Chapter 1*

**Nucleus sampling (top-p)** — A decoding strategy that samples from the smallest set of tokens whose cumulative probability exceeds a threshold *p*. With top-p = 0.9, the model samples from tokens that collectively account for 90% of the probability mass, excluding the long tail of unlikely tokens. *Chapter 2*

**Parametric knowledge** — Information encoded in a model's weights during training, as opposed to information provided in the context at inference time. Parametric knowledge is fixed after training and cannot be verified or cited; it's "what the model remembers." *Chapter 4*

**PEFT (Parameter-Efficient Fine-Tuning)** — A family of techniques — including LoRA, QLoRA, prefix tuning, and adapters — that modify only a small subset of model parameters during fine-tuning. Reduces compute, memory, and storage requirements by orders of magnitude compared to full fine-tuning. *Chapter 10*

**Prompt caching** — Storing and reusing the model's internal computation for a fixed prompt prefix across multiple requests. Reduces latency and cost for applications where many requests share the same system prompt or context. Offered by Anthropic and others as a first-party API feature. *Chapter 3*

**Prompt injection** — An attack where a user crafts input that causes the model to ignore its instructions and follow the attacker's instructions instead. The core security vulnerability in LLM applications, analogous to SQL injection in databases. *Chapter 5*

**QLoRA** — A variant of LoRA that fine-tunes quantized (4-bit) model weights, reducing hardware requirements from multiple enterprise GPUs to a single consumer GPU. Makes fine-tuning accessible to individual practitioners and small teams. *Chapter 10*

**Quantization** — Reducing the numerical precision of model weights (e.g., from 16-bit to 4-bit), making models smaller and faster at the cost of some quality degradation. Enables running large models on consumer hardware. Key formats include GPTQ, AWQ, and GGUF. *Appendix A, Chapter 10*

**RAG (Retrieval-Augmented Generation)** — An architecture that combines retrieval from an external knowledge base with language model generation. Documents are embedded and stored in a vector database; at query time, relevant documents are retrieved and included in the model's context to ground its response in verified information. *Chapter 4*

**RAGAS** — An evaluation framework for RAG pipelines that measures faithfulness (does the answer match the retrieved context?), answer relevance (does the answer address the question?), and context relevance (was the right information retrieved?). *Chapter 4*

**ReAct** — A prompting pattern that interleaves reasoning (thinking about what to do) with acting (using tools) and observing (processing tool results). The foundation of most agentic architectures. *Chapter 6*

**Reasoning model** — A model trained or prompted to generate explicit chains of thought before producing a final answer. Examples include OpenAI's o1/o3 series and Claude's extended thinking mode. Reasoning models trade latency and cost for improved performance on complex tasks. *Chapter 1*

**Re-ranking** — A retrieval refinement step where an initial set of retrieved documents is re-scored by a more accurate (but slower) model, typically a cross-encoder. Improves retrieval precision by catching cases where embedding similarity doesn't correspond to true relevance. *Chapter 4*

**RLHF (Reinforcement Learning from Human Feedback)** — The alignment technique where human raters compare model outputs and indicate preferences. These preferences train a reward model, which is used to fine-tune the LLM via reinforcement learning. RLHF is what makes models helpful, relatively honest, and somewhat safe. It's also what makes them sycophantic, verbose, and confidently wrong when miscalibrated. *Chapter 14*

**Sampling parameters** — Configuration values that control the randomness and diversity of model outputs, including temperature, top-p, top-k, and frequency/presence penalties. These parameters shape the probability distribution the model samples from, affecting output quality, consistency, and creativity. *Chapter 2*

**Scaling laws** — Empirically observed power-law relationships between model size, dataset size, compute budget, and model loss. Scaling laws predict that increasing compute produces predictable improvements in loss, though the relationship between loss and task performance is less well understood. *Chapter 1*

**Semantic caching** — Caching LLM responses based on the semantic similarity of queries rather than exact string matching. If a new query is semantically similar to a previously answered one, the cached response is returned, saving cost and latency. *Chapter 9*

**Semantic search** — Searching for documents based on meaning rather than keyword matching. Queries and documents are embedded in a shared vector space, and retrieval is based on vector similarity. More robust to vocabulary variation than keyword search but can miss exact matches. *Chapter 4*

**Streaming** — Delivering model output token by token as it's generated, rather than waiting for the complete response. Improves perceived latency for users and enables progressive rendering. Implemented via Server-Sent Events (SSE) in most APIs. *Chapter 3*

**Superposition** — A phenomenon in neural networks where individual neurons represent multiple, unrelated concepts simultaneously through overlapping distributed representations. Superposition means networks encode more features than they have dimensions, making mechanistic interpretability much harder. *Chapter 14*

**SWE-bench** — Software Engineering benchmark. Presents models with real GitHub issues from open-source projects and evaluates whether they can produce patches that pass the project's test suite. SWE-bench Verified is the curated subset with human-validated tasks. Top scores around 74% as of early 2026. *Chapter 1*

**Temperature** — A sampling parameter that controls the sharpness of the probability distribution the model samples from. Lower temperature concentrates probability on the most likely tokens (more deterministic, more repetitive). Higher temperature flattens the distribution (more diverse, more random). Temperature does not control "creativity"; it controls randomness. *Chapter 2*

**Token** — A subword unit, typically 3-4 characters of English text, drawn from a fixed vocabulary. Models process tokens, not characters or words. Tokenization affects cost (API pricing is per-token), context window usage, and the model's ability to handle different languages and formats. *Chapter 1*

**Tool use** — The capability of an LLM to invoke external functions, APIs, or services by generating structured specifications of the function call. The model doesn't execute the tool; it specifies what to call and with what arguments, and the application handles execution. *Chapter 5*

**Transformer** — The neural network architecture introduced in "Attention Is All You Need" (Vaswani et al., 2017) that underlies all modern LLMs. Built on self-attention mechanisms that allow the model to relate every position in a sequence to every other position simultaneously, enabling parallel processing and effective handling of long-range dependencies. *Chapter 1*

**Vector database** — A database optimized for storing and querying high-dimensional vectors (embeddings). Supports approximate nearest neighbor search to find vectors similar to a query vector. Used in RAG systems to store document embeddings and retrieve relevant documents at query time. Examples include Pinecone, Weaviate, Qdrant, Chroma, and pgvector. *Chapter 4*
