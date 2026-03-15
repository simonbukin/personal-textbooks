#!/bin/bash
# build-book.sh - Build the book in multiple formats (PDF, HTML, EPUB, mdBook)
# Usage: ./scripts/build-book.sh [pdf|html|epub|mdbook|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
CHAPTERS_DIR="$PROJECT_ROOT/chapters"
APPENDICES_DIR="$PROJECT_ROOT/appendices"

BOOK_NAME="modern-ai"
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

echo -e "${GREEN}Building: Modern AI — From Vibe Coder to Practical SME${NC}"
echo ""

# Ensure build directory exists
mkdir -p "$BUILD_DIR"

# Create combined markdown with YAML front matter
create_combined_markdown() {
    cat > "$OUTPUT_MD" << 'FRONTMATTER'
---
title: "Modern AI"
subtitle: "From Vibe Coder to Practical SME"
author: "A practical guide to building, auditing, and advising on production AI systems"
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
case "$FORMAT" in
    mdbook)
        build_mdbook
        ;;
    all)
        create_combined_markdown
        build_mdbook
        ;;
    *)
        echo -e "${RED}Unknown format: $FORMAT${NC}"
        echo "Usage: $0 [mdbook|all]"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Build complete!${NC}"
