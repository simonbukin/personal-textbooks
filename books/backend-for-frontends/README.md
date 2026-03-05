# Backend for Senior Frontend Engineers: Building Taste

A practical guide to backend architecture, infrastructure, and AI-native engineering for experienced frontend developers.

## Project Structure

```
backend-for-frontends-book/
├── chapters/                    # All 33 chapter markdown files (00-32)
├── appendices/                  # Appendix A and B
├── build/                       # Generated output (gitignored)
│   ├── backend-for-frontends.md   # Combined markdown
│   └── backend-for-frontends.pdf  # Final PDF
├── scripts/
│   ├── build-book.sh           # Concatenate + generate PDF
│   └── word-count.sh           # Progress tracker
├── TEXTBOOK_SPEC.md            # Voice, tone, formatting spec
├── CHAPTER_GUIDE.md            # Detailed chapter-by-chapter brief
└── README.md                   # This file
```

## Quick Start

### Check Progress

```bash
./scripts/word-count.sh
```

Shows word count for each chapter against targets, completion status, and overall progress.

### Build the Book

```bash
./scripts/build-book.sh
```

Concatenates all chapters into a single markdown file and generates a PDF.

### Prerequisites for PDF Generation

```bash
# Install pandoc
brew install pandoc

# Install LaTeX (for PDF generation)
brew install --cask basictex

# After installing basictex, restart terminal then install additional packages
sudo tlmgr update --self
sudo tlmgr install collection-latexrecommended
```

## Writing Workflow

### Batch Generation

The book is generated in 15 batches. Each batch should be:

1. Written following the specs in `TEXTBOOK_SPEC.md` and `CHAPTER_GUIDE.md`
2. Verified with `./scripts/word-count.sh` to check word targets
3. Built with `./scripts/build-book.sh` to verify formatting

### Batch Schedule

| Batch | Phase | Chapters | Word Target |
|-------|-------|----------|-------------|
| 1 | 1 - Data Layer | 00-02 | ~6,000 |
| 2 | 1 - Data Layer | 03-04 | ~9,000 |
| 3 | 1 - Data Layer | 05-06 | ~5,500 |
| 4 | 2 - Server Architecture | 07-08 | ~5,000 |
| 5 | 2 - Server Architecture | 09-10 | ~10,000 |
| 6 | 2 - Server Architecture | 11-13 | ~10,000 |
| 7 | 3 - Infrastructure | 14-16 | ~8,000 |
| 8 | 3 - Infrastructure | 17-18 | ~11,000 |
| 9 | 3 - Infrastructure | 19-20 | ~5,500 |
| 10 | 4 - System Design | 21-22 | ~7,500 |
| 11 | 4 - System Design | 23-25 | ~10,000 |
| 12 | 5 - AI-Native | 26-27 | ~6,000 |
| 13 | 5 - AI-Native | 28-29 | ~10,000 |
| 14 | 5 - AI-Native | 30-32 | ~7,000 |
| 15 | Appendices | A-B | ~3,000 |

**Total Target:** 60,000-80,000 words

## Chapter File Naming

```
00-introduction.md
01-phase1-overview.md
02-postgres-as-your-default.md
...
32-conclusion.md
appendix-a-tool-recommendations.md
appendix-b-further-reading.md
```

## Chapter Template

Each chapter follows this structure:

```markdown
# Chapter N: [Title]

## Why This Matters
[1-3 paragraphs on the problem and value]

## [Core Content Sections]
[3-6 sections with code, explanations, taste moments]

## The Taste Test
[3-5 scenarios with brief explanations]

## Practical Exercise
[2-6 hour exercise with acceptance criteria]

## Checkpoint
[5-8 "I can..." statements]
```

## Style Guide Quick Reference

- **Voice:** Opinionated peer, not professor
- **Person:** Second person ("you") throughout
- **Code:** TypeScript (Node.js) primary, complete runnable examples
- **Framework:** Hono or Fastify (not Express)
- **ORM:** Drizzle (with raw SQL alongside)
- **Database:** PostgreSQL + Redis

### Callout Markers

- 🔒 Security callout
- 💸 Startup cost callout
- 🤔 Taste moment
- ⚡ AI shortcut

See `TEXTBOOK_SPEC.md` for complete style guide.

## License

[Your license here]
