#!/bin/bash
# build-book.sh - Build the book in multiple formats (PDF, HTML, EPUB)
# Usage: ./scripts/build-book.sh [pdf|html|epub|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
CHAPTERS_DIR="$PROJECT_ROOT/chapters"
APPENDICES_DIR="$PROJECT_ROOT/appendices"
SRC_DIR="$PROJECT_ROOT/src"

BOOK_NAME="irreplaceable"
OUTPUT_MD="$BUILD_DIR/$BOOK_NAME.md"
OUTPUT_PDF="$BUILD_DIR/$BOOK_NAME.pdf"
OUTPUT_EPUB="$BUILD_DIR/$BOOK_NAME.epub"

FORMAT="${1:-all}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building: Irreplaceable - Design Taste in the Age of Machines${NC}"
echo ""

# Ensure build directory exists
mkdir -p "$BUILD_DIR"

# Create combined markdown with YAML front matter (for PDF/EPUB)
create_combined_markdown() {
    cat > "$OUTPUT_MD" << 'FRONTMATTER'
---
title: "Irreplaceable"
subtitle: "Design Taste in the Age of Machines"
author: "Claude Opus 4.6"
date: \today
documentclass: book
classoption:
  - oneside
  - 11pt
geometry:
  - margin=1in
toc: true
toc-depth: 2
numbersections: false
highlight-style: tango
linkcolor: blue
urlcolor: blue
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
    if ! command -v xelatex &> /dev/null; then
        echo -e "${RED}Error: xelatex not found. Install with: brew install texlive${NC}"
        return 1
    fi

    echo ""
    echo -e "${YELLOW}Generating PDF...${NC}"

    # Create PDF-safe version (handle special characters)
    OUTPUT_PDF_MD="$BUILD_DIR/${BOOK_NAME}-pdf.md"
    cat "$OUTPUT_MD" | \
        perl -pe 's/→/->/g' | \
        perl -pe 's/—/--/g' \
        > "$OUTPUT_PDF_MD"

    pandoc "$OUTPUT_PDF_MD" \
        -o "$OUTPUT_PDF" \
        --toc \
        --toc-depth=2 \
        --highlight-style=tango \
        -V geometry:margin=1in \
        -V fontsize=11pt \
        -V linkcolor=blue \
        -V urlcolor=blue \
        -V mainfont="Helvetica Neue" \
        -V monofont="Menlo" \
        --pdf-engine=xelatex \
        2>&1 | head -20

    rm -f "$OUTPUT_PDF_MD"

    if [ -f "$OUTPUT_PDF" ]; then
        pdf_size=$(du -h "$OUTPUT_PDF" | cut -f1)
        echo -e "${GREEN}PDF generated:${NC} $OUTPUT_PDF ($pdf_size)"
    else
        echo -e "${RED}PDF generation failed.${NC}"
        return 1
    fi
}

# Build HTML using mdbook
build_html() {
    if ! command -v mdbook &> /dev/null; then
        echo -e "${RED}Error: mdbook not found. Install with: cargo install mdbook${NC}"
        return 1
    fi

    echo ""
    echo -e "${YELLOW}Generating HTML with mdbook...${NC}"

    cd "$PROJECT_ROOT"
    mdbook build

    if [ -d "$BUILD_DIR/html" ]; then
        html_files=$(find "$BUILD_DIR/html" -name "*.html" | wc -l | tr -d ' ')
        echo -e "${GREEN}HTML generated:${NC} $BUILD_DIR/html/ ($html_files pages)"
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
        --metadata title="Irreplaceable: Design Taste in the Age of Machines" \
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

# Main
case "$FORMAT" in
    pdf)
        create_combined_markdown
        build_pdf
        ;;
    html)
        build_html
        ;;
    epub)
        create_combined_markdown
        build_epub
        ;;
    all)
        create_combined_markdown
        build_html
        build_epub
        build_pdf
        ;;
    *)
        echo -e "${RED}Unknown format: $FORMAT${NC}"
        echo "Usage: $0 [pdf|html|epub|all]"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Build complete!${NC}"
