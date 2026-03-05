#!/bin/bash
# build-book.sh - Build the book in multiple formats (PDF, HTML, EPUB, mdBook)
# Usage: ./scripts/build-book.sh [pdf|html|epub|mdbook|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
CHAPTERS_DIR="$PROJECT_ROOT/chapters"
APPENDICES_DIR="$PROJECT_ROOT/appendices"

BOOK_NAME="backend-for-frontends"
OUTPUT_MD="$BUILD_DIR/$BOOK_NAME.md"
OUTPUT_PDF="$BUILD_DIR/$BOOK_NAME.pdf"
OUTPUT_HTML="$BUILD_DIR/$BOOK_NAME.html"
OUTPUT_EPUB="$BUILD_DIR/$BOOK_NAME.epub"

FORMAT="${1:-all}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building: Backend for Senior Frontend Engineers${NC}"
echo ""

# Ensure build directory exists
mkdir -p "$BUILD_DIR"

# Create combined markdown with YAML front matter
create_combined_markdown() {
    cat > "$OUTPUT_MD" << 'FRONTMATTER'
---
title: "Backend for Senior Frontend Engineers"
subtitle: "Building Taste"
author: "A practical guide to backend architecture, infrastructure, and AI-native engineering"
documentclass: book
classoption:
  - oneside
  - 11pt
geometry:
  - margin=1in
  - includehead
  - includefoot
toc: true
toc-depth: 2
numbersections: false
highlight-style: tango
linkcolor: blue
urlcolor: blue
colorlinks: true
---

\newpage

FRONTMATTER

    local chapter_count=0
    local appendix_count=0

    # Process chapters in order
    echo -e "${YELLOW}Processing chapters...${NC}"
    for chapter_file in $(ls -1 "$CHAPTERS_DIR"/*.md 2>/dev/null | sort); do
        if [ -f "$chapter_file" ]; then
            filename=$(basename "$chapter_file")
            echo "  Adding: $filename"

            if [ $chapter_count -gt 0 ]; then
                echo -e "\n\\\\newpage\n" >> "$OUTPUT_MD"
            fi

            cat "$chapter_file" >> "$OUTPUT_MD"
            echo "" >> "$OUTPUT_MD"
            ((chapter_count++))
        fi
    done

    # Process appendices
    echo -e "${YELLOW}Processing appendices...${NC}"
    for appendix_file in $(ls -1 "$APPENDICES_DIR"/*.md 2>/dev/null | sort); do
        if [ -f "$appendix_file" ]; then
            filename=$(basename "$appendix_file")
            echo "  Adding: $filename"

            echo -e "\n\\\\newpage\n" >> "$OUTPUT_MD"
            cat "$appendix_file" >> "$OUTPUT_MD"
            echo "" >> "$OUTPUT_MD"
            ((appendix_count++))
        fi
    done

    echo ""
    echo -e "${GREEN}Combined markdown:${NC} $OUTPUT_MD"
    echo "  Chapters: $chapter_count"
    echo "  Appendices: $appendix_count"
}

# Build PDF
build_pdf() {
    if ! command -v lualatex &> /dev/null; then
        echo -e "${RED}Error: lualatex not found. Install with: brew install texlive${NC}"
        return 1
    fi

    echo ""
    echo -e "${YELLOW}Generating PDF...${NC}"

    # Create a header file for emoji support and code formatting
    HEADER_FILE="$BUILD_DIR/header.tex"
    cat > "$HEADER_FILE" << 'TEXHEADER'
% Font setup with emoji fallback
\directlua{
  luaotfload.add_fallback("emojifallback", {
    "Apple Color Emoji:mode=harf",
    "Apple Symbols:mode=harf",
    "Menlo:mode=harf"
  })
}
\setmainfont{Helvetica Neue}[RawFeature={fallback=emojifallback}]
\setmonofont{Menlo}[Scale=0.85,RawFeature={fallback=emojifallback}]

% Code block formatting - prevent overflow
\usepackage{fvextra}
\DefineVerbatimEnvironment{Highlighting}{Verbatim}{
  breaklines=true,
  breakanywhere=true,
  commandchars=\\\{\},
  fontsize=\small
}

% Better typography
\usepackage{microtype}

% Reduce chapter title size
\usepackage{titlesec}
\titleformat{\chapter}[display]
  {\normalfont\huge\bfseries}
  {}
  {0pt}
  {\Huge}
\titlespacing*{\chapter}{0pt}{-20pt}{20pt}

% No "Chapter X" prefix
\renewcommand{\chaptername}{}
\renewcommand{\thechapter}{}
TEXHEADER

    pandoc "$OUTPUT_MD" \
        -o "$OUTPUT_PDF" \
        --toc \
        --toc-depth=2 \
        --highlight-style=tango \
        -V geometry:margin=1in \
        -V fontsize=11pt \
        -V linkcolor=blue \
        -V urlcolor=blue \
        -V documentclass=book \
        -H "$HEADER_FILE" \
        --pdf-engine=lualatex \
        2>&1 | grep -v "^$" | head -30

    rm -f "$HEADER_FILE"

    if [ -f "$OUTPUT_PDF" ]; then
        pdf_size=$(du -h "$OUTPUT_PDF" | cut -f1)
        echo -e "${GREEN}PDF generated:${NC} $OUTPUT_PDF ($pdf_size)"
    else
        echo -e "${RED}PDF generation failed.${NC}"
        return 1
    fi
}

# Build HTML
build_html() {
    echo ""
    echo -e "${YELLOW}Generating HTML...${NC}"

    # Create HTML with embedded styles
    pandoc "$OUTPUT_MD" \
        -o "$OUTPUT_HTML" \
        --standalone \
        --toc \
        --toc-depth=2 \
        --highlight-style=tango \
        --metadata title="Backend for Senior Frontend Engineers: Building Taste" \
        -V lang=en \
        --css="data:text/css,$(cat << 'STYLES'
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    line-height: 1.6;
    max-width: 42em;
    margin: 0 auto;
    padding: 2em;
    color: #1a1a1a;
    background: #fafafa;
}
h1, h2, h3, h4 {
    font-weight: 600;
    line-height: 1.25;
    margin-top: 2em;
    margin-bottom: 0.5em;
}
h1 { font-size: 2em; border-bottom: 1px solid #ddd; padding-bottom: 0.3em; }
h2 { font-size: 1.5em; }
h3 { font-size: 1.25em; }
code {
    font-family: "SF Mono", Menlo, Monaco, monospace;
    font-size: 0.9em;
    background: #f0f0f0;
    padding: 0.15em 0.3em;
    border-radius: 3px;
}
pre {
    background: #2d2d2d;
    color: #f8f8f2;
    padding: 1em;
    border-radius: 6px;
    overflow-x: auto;
    line-height: 1.4;
}
pre code {
    background: none;
    padding: 0;
    color: inherit;
}
blockquote {
    border-left: 4px solid #ddd;
    margin-left: 0;
    padding-left: 1em;
    color: #555;
    font-style: italic;
}
a { color: #0066cc; text-decoration: none; }
a:hover { text-decoration: underline; }
#TOC {
    background: #f5f5f5;
    padding: 1.5em;
    border-radius: 8px;
    margin-bottom: 3em;
}
#TOC ul { list-style: none; padding-left: 1em; }
#TOC > ul { padding-left: 0; }
#TOC a { color: #333; }
hr { border: none; border-top: 1px solid #ddd; margin: 3em 0; }
em { font-style: italic; }
strong { font-weight: 600; }
.title { font-size: 2.5em; margin-bottom: 0.25em; }
.subtitle { font-size: 1.25em; color: #666; margin-bottom: 2em; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; }
th, td { border: 1px solid #ddd; padding: 0.5em; text-align: left; }
th { background: #f5f5f5; }
STYLES
)"

    if [ -f "$OUTPUT_HTML" ]; then
        html_size=$(du -h "$OUTPUT_HTML" | cut -f1)
        echo -e "${GREEN}HTML generated:${NC} $OUTPUT_HTML ($html_size)"
    else
        echo -e "${RED}HTML generation failed.${NC}"
        return 1
    fi
}

# Build EPUB
build_epub() {
    echo ""
    echo -e "${YELLOW}Generating EPUB...${NC}"

    pandoc "$OUTPUT_MD" \
        -o "$OUTPUT_EPUB" \
        --toc \
        --toc-depth=2 \
        --highlight-style=tango \
        --metadata title="Backend for Senior Frontend Engineers: Building Taste" \
        --metadata author="A practical guide to backend architecture, infrastructure, and AI-native engineering" \
        --metadata lang="en" \
        --split-level=1

    if [ -f "$OUTPUT_EPUB" ]; then
        epub_size=$(du -h "$OUTPUT_EPUB" | cut -f1)
        echo -e "${GREEN}EPUB generated:${NC} $OUTPUT_EPUB ($epub_size)"
    else
        echo -e "${RED}EPUB generation failed.${NC}"
        return 1
    fi
}

# Build mdBook (multi-page HTML with navigation)
build_mdbook() {
    if ! command -v mdbook &> /dev/null; then
        echo -e "${RED}Error: mdbook not found. Install with: brew install mdbook${NC}"
        return 1
    fi

    echo ""
    echo -e "${YELLOW}Generating mdBook HTML...${NC}"

    mdbook build "$PROJECT_ROOT" 2>&1

    if [ -d "$BUILD_DIR/html" ] && [ -f "$BUILD_DIR/html/index.html" ]; then
        html_count=$(ls -1 "$BUILD_DIR/html"/*.html 2>/dev/null | wc -l | tr -d ' ')
        echo -e "${GREEN}mdBook generated:${NC} $BUILD_DIR/html/ ($html_count HTML files)"
        echo "  Open with: open $BUILD_DIR/html/index.html"
    else
        echo -e "${RED}mdBook generation failed.${NC}"
        return 1
    fi
}

# Main
# Skip combined markdown for mdbook-only builds (mdbook reads from src/ directly)
if [ "$FORMAT" != "mdbook" ]; then
    create_combined_markdown
fi

case "$FORMAT" in
    pdf)
        build_pdf
        ;;
    html)
        build_html
        ;;
    epub)
        build_epub
        ;;
    mdbook)
        build_mdbook
        ;;
    all)
        build_html
        build_epub
        build_pdf
        build_mdbook
        ;;
    *)
        echo -e "${RED}Unknown format: $FORMAT${NC}"
        echo "Usage: $0 [pdf|html|epub|mdbook|all]"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Build complete!${NC}"
