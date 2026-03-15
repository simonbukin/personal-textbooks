# Appendix B: Recommended Reading & Sources

This appendix collects the papers, documentation, tools, and communities referenced throughout the book, organized by category with brief annotations explaining why each is worth your time.

## Foundational Papers

These are the papers that shaped the field. You don't need to understand every equation, but you should be able to explain the core contribution of each.

**"Attention Is All You Need"** — Vaswani et al., 2017. The transformer paper. Introduced the self-attention mechanism that replaced recurrent architectures and made modern LLMs possible. Read the architecture section and understand why self-attention enables parallelization and captures long-range dependencies. Everything in this book traces back to this paper. [arxiv.org/abs/1706.03762](https://arxiv.org/abs/1706.03762)

**"Scaling Laws for Neural Language Models"** — Kaplan et al., 2020. Established predictable power-law relationships between model size, dataset size, compute budget, and loss. These curves guided billions of dollars in training decisions and remain the best framework for understanding why bigger models are better models, and where that trend might break. [arxiv.org/abs/2001.08361](https://arxiv.org/abs/2001.08361)

**"Training Compute-Optimal Large Language Models" (Chinchilla)** — Hoffmann et al., 2022. Demonstrated that most models were undertrained relative to their size. You get better performance per compute dollar by training a smaller model on more data than by training a larger model on less data. Reshaped the training strategies of every major lab. [arxiv.org/abs/2203.15556](https://arxiv.org/abs/2203.15556)

**"Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks"** — Lewis et al., 2020. The original RAG paper. Introduced the architecture of combining retrieval from an external knowledge base with language model generation. The core idea, grounding model outputs in retrieved evidence, is now the default approach for any application requiring factual accuracy. [arxiv.org/abs/2005.11401](https://arxiv.org/abs/2005.11401)

**"ReAct: Synergizing Reasoning and Acting in Language Models"** — Yao et al., 2022. Showed that interleaving reasoning traces with actions (tool calls) produces better outcomes than either reasoning or acting alone. The ReAct pattern (think, act, observe, repeat) is the foundation of modern agentic systems. [arxiv.org/abs/2210.03629](https://arxiv.org/abs/2210.03629)

**"Constitutional AI: Harmlessness from AI Feedback"** — Bai et al., 2022. Anthropic's approach to alignment through written principles rather than pure human preference optimization. Important for understanding how models are steered toward safe behavior and what the limitations of that steering are. [arxiv.org/abs/2212.08073](https://arxiv.org/abs/2212.08073)

**"Lost in the Middle: How Language Models Use Long Contexts"** — Liu et al., 2023. Empirically demonstrated that LLMs attend more to information at the beginning and end of their context window, with reduced attention to information in the middle. This directly affects how you should structure prompts and order retrieved documents. [arxiv.org/abs/2307.03172](https://arxiv.org/abs/2307.03172)

**"QLoRA: Efficient Finetuning of Quantized Language Models"** — Dettmers et al., 2023. Made fine-tuning accessible by showing that you can fine-tune a quantized model with minimal quality loss, reducing hardware requirements from multiple enterprise GPUs to a single consumer GPU. If you're fine-tuning on a budget, this is the paper. [arxiv.org/abs/2305.14314](https://arxiv.org/abs/2305.14314)

**"Direct Preference Optimization: Your Language Model is Secretly a Reward Model"** — Rafailov et al., 2023. Simplified RLHF by eliminating the separate reward model, showing that preference data can be used to directly optimize the language model. DPO has become the default alignment technique for many open-source models due to its simplicity and stability. [arxiv.org/abs/2305.18290](https://arxiv.org/abs/2305.18290)

## Essential Practical Reading

These are the resources you'll return to repeatedly as you build.

**Simon Willison's blog** — [simonwillison.net](https://simonwillison.net). The single most valuable source for practical AI engineering insight. Willison approaches AI tools with a builder's curiosity and a journalist's skepticism, testing claims empirically and documenting what works. His coverage of prompt injection, local models, and AI tool design is ahead of the industry consensus by months. Subscribe to the newsletter.

**Anthropic Prompt Engineering Documentation** — [docs.anthropic.com/en/docs/build-with-claude/prompt-engineering](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering). Thorough and honest first-party documentation on prompt design. Unlike blog posts that present prompt engineering as a collection of tricks, Anthropic's docs explain *why* techniques work and when they don't. Updated regularly as models evolve.

**Anthropic Agent Building Guide** — [docs.anthropic.com/en/docs/build-with-claude/agentic](https://docs.anthropic.com/en/docs/build-with-claude/agentic). Practical guidance on building agentic systems with Claude, including patterns for tool use, planning, and self-correction. Less theoretical than academic papers on agents, more architecturally substantive than typical tutorials.

**MCP Documentation** — [modelcontextprotocol.io](https://modelcontextprotocol.io). The specification and documentation for the Model Context Protocol. Essential reading if you're building tool integrations for AI agents. The specification is well-written and the examples are practical. Understand the transport layer, tool definitions, and resource model.

**MCP 2026 Roadmap** — Available on the MCP documentation site and GitHub. Outlines planned extensions to the protocol including streamable HTTP transport, enhanced authentication, and remote server support. Important for understanding where the ecosystem is heading and making architectural decisions that won't need immediate rework.

## Benchmarks

Understanding benchmarks is understanding what the field actually measures, and what it doesn't.

**GAIA** — General AI Assistants benchmark. Tests multi-step reasoning, web browsing, and tool use on real-world tasks. Top scores near 90% as of early 2026. Useful for evaluating end-to-end agent capability. [arxiv.org/abs/2311.12983](https://arxiv.org/abs/2311.12983)

**SWE-bench** — Software Engineering benchmark. Presents models with real GitHub issues and asks them to produce patches. SWE-bench Verified is the curated, human-validated subset. The most relevant benchmark for evaluating coding agent capability. Top scores around 74% as of early 2026. [swe-bench.github.io](https://swe-bench.github.io)

**BFCL** — Berkeley Function-Calling Leaderboard. Evaluates models' ability to correctly invoke functions with proper arguments — the core capability underlying all tool use. Important for selecting models for agentic applications. [gorilla.cs.berkeley.edu/leaderboard.html](https://gorilla.cs.berkeley.edu/leaderboard.html)

**MTEB** — Massive Text Embedding Benchmark. The standard benchmark for evaluating embedding models across retrieval, classification, clustering, and other tasks. Essential for selecting embedding models for RAG systems. [huggingface.co/spaces/mteb/leaderboard](https://huggingface.co/spaces/mteb/leaderboard)

**Chatbot Arena / LMSYS** — [chat.lmsys.org](https://chat.lmsys.org). Crowdsourced evaluation where users compare model outputs head-to-head. The Elo rating system provides a relative ranking that captures dimensions benchmarks miss: fluency, helpfulness, instruction-following quality. The closest thing to a consensus ranking of model quality for general-purpose use.

## Evaluation Frameworks

Tools for building your own eval infrastructure.

**RAGAS** — [docs.ragas.io](https://docs.ragas.io). A framework for evaluating RAG pipelines with metrics for faithfulness (does the answer match the retrieved context?), answer relevance (does the answer address the question?), and context relevance (is the retrieved context useful?). The go-to tool for RAG evaluation. Referenced in Chapters 4 and 9.

**LangSmith** — [smith.langchain.com](https://smith.langchain.com). LangChain's observability and evaluation platform. Useful for tracing multi-step agent execution, logging LLM calls, and running eval suites. Tightly integrated with LangChain but usable independently. Tracing is especially valuable for debugging agentic systems.

**OpenAI Evals** — [github.com/openai/evals](https://github.com/openai/evals). Open-source framework for evaluating LLM outputs. Provides a structured approach to defining eval criteria and running them systematically. The framework is model-agnostic despite the name. Useful for building custom eval suites.

**Braintrust** — [braintrust.dev](https://braintrust.dev). A newer eval platform with strong support for LLM-as-judge evaluations, A/B comparison, and dataset management. Worth evaluating if you're building a production eval pipeline and want a managed solution.

## Key Blogs & Newsletters

Stay current without drowning in noise.

**Simon Willison** — [simonwillison.net](https://simonwillison.net). Already listed above but worth repeating: the single most valuable individual voice in practical AI engineering. Read everything he writes.

**Anthropic Research Blog** — [anthropic.com/research](https://anthropic.com/research). Primary source for interpretability research, Constitutional AI updates, and model capability analysis. Less frequent than other blogs but higher signal-to-noise ratio. Read their research publications when they drop; they shape the field.

**The Batch** — Andrew Ng's weekly newsletter. Curated AI news with brief, technically informed commentary. Good for maintaining breadth without spending hours on Twitter. Accessible to both technical and non-technical readers.

**Latent Space Podcast** — [latent.space](https://latent.space). The best technical AI podcast. Long-form interviews with researchers and practitioners covering both theory and practice. Episodes on agents, evaluations, and production AI engineering are particularly relevant to this book's scope.

**Interconnects** — Nathan Lambert's newsletter on RLHF, alignment, and model training. Accessible writing on alignment training techniques, written by someone who does the work. Essential if you're interested in the topics from Chapter 14.

**Ahead of AI** — Sebastian Raschka's newsletter. Practical coverage of model training, fine-tuning techniques, and ML engineering. More technically detailed than most newsletters, with code examples and empirical comparisons.

## AI Safety Resources

**Anthropic Core Views on AI Safety** — [anthropic.com/news/core-views-on-ai-safety](https://anthropic.com/news/core-views-on-ai-safety). Anthropic's institutional position on AI safety risks and their approach to addressing them. Honest about uncertainties and openly discusses what they don't know how to solve.

**"Toy Models of Superposition"** — Elhage et al., 2022. The key paper on why neural network interpretability is harder than it looks. Demonstrates that networks encode more features than they have dimensions through superposition. [transformer-circuits.pub/2022/toy_model/index.html](https://transformer-circuits.pub/2022/toy_model/index.html)

**Anthropic's Interpretability Research** — [transformer-circuits.pub](https://transformer-circuits.pub). Collected interpretability research from Anthropic's team. The thread on dictionary learning and sparse autoencoders is worth following for understanding the current state of mechanistic interpretability.

## Infrastructure & Tooling

**vLLM** — [vllm.ai](https://vllm.ai). The most widely used open-source LLM inference server. Implements PagedAttention for efficient KV cache management and continuous batching for high throughput. Essential if you're self-hosting models.

**Ollama** — [ollama.com](https://ollama.com). The simplest way to run open-weight models locally. Handles model downloading, quantization, and serving with minimal configuration. Useful for development, testing, and privacy-sensitive applications.

**LiteLLM** — [litellm.ai](https://litellm.ai). A unified API wrapper that provides a consistent interface across 100+ LLM providers. Useful for model routing, fallback chains, and avoiding vendor lock-in in application code.
