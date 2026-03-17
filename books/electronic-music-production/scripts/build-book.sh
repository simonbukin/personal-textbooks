#!/bin/bash
# build-book.sh - Build the book in multiple formats (EPUB, mdBook)
# Usage: ./scripts/build-book.sh [epub|mdbook|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
SRC_DIR="$PROJECT_ROOT/src"

BOOK_NAME="electronic-music-production"
OUTPUT_MD="$BUILD_DIR/$BOOK_NAME.md"
OUTPUT_EPUB="$BUILD_DIR/$BOOK_NAME.epub"

FORMAT="${1:-all}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Building: From Zero to Album — Electronic Music Production${NC}"
echo ""

mkdir -p "$BUILD_DIR"

create_combined_markdown() {
    cat > "$OUTPUT_MD" << 'FRONTMATTER'
---
title: "From Zero to Album"
subtitle: "A Complete Guide to Electronic Music Production"
author: "Claude Opus 4.6"
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

    if [ -f "$SRC_DIR/preamble.md" ]; then
        echo "  Adding: preamble.md"
        cat "$SRC_DIR/preamble.md" >> "$OUTPUT_MD"
        echo "" >> "$OUTPUT_MD"
    fi

    echo -e "${YELLOW}Processing chapters...${NC}"
    for chapter_file in $(ls -1 "$SRC_DIR"/chapter-*.md 2>/dev/null | sort); do
        if [ -f "$chapter_file" ]; then
            filename=$(basename "$chapter_file")
            echo "  Adding: $filename"
            echo -e "\n\\\\newpage\n" >> "$OUTPUT_MD"
            cat "$chapter_file" >> "$OUTPUT_MD"
            echo "" >> "$OUTPUT_MD"
            ((chapter_count++))
        fi
    done

    echo -e "${YELLOW}Processing appendices...${NC}"
    for appendix_file in $(ls -1 "$SRC_DIR"/appendix-*.md 2>/dev/null | sort); do
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

build_epub() {
    echo ""
    echo -e "${YELLOW}Generating EPUB...${NC}"

    pandoc "$OUTPUT_MD" \
        -o "$OUTPUT_EPUB" \
        --toc \
        --toc-depth=2 \
        --highlight-style=tango \
        --metadata title="From Zero to Album" \
        --metadata author="Claude Opus 4.6" \
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

case "$FORMAT" in
    epub)
        create_combined_markdown
        build_epub
        ;;
    mdbook)
        build_mdbook
        ;;
    all)
        create_combined_markdown
        build_epub
        build_mdbook
        ;;
    *)
        echo -e "${RED}Unknown format: $FORMAT${NC}"
        echo "Usage: $0 [epub|mdbook|all]"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Build complete!${NC}"
