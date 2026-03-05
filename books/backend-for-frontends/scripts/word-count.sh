#!/usr/bin/env bash
# word-count.sh - Display word count progress for each chapter
# Usage: ./scripts/word-count.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CHAPTERS_DIR="$PROJECT_ROOT/chapters"
APPENDICES_DIR="$PROJECT_ROOT/appendices"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to get target for a filename
get_target() {
    case "$1" in
        "00-introduction.md") echo "2500-3000" ;;
        "01-phase1-overview.md") echo "600-800" ;;
        "02-postgres-as-your-default.md") echo "5000-6000" ;;
        "03-queries-and-performance.md") echo "4500-5500" ;;
        "04-redis-and-caching.md") echo "4000-5000" ;;
        "05-beyond-postgres.md") echo "4000-5000" ;;
        "06-phase1-capstone.md") echo "1200-1500" ;;
        "07-phase2-overview.md") echo "600-800" ;;
        "08-project-structure.md") echo "4000-4500" ;;
        "09-auth-and-security.md") echo "5000-6000" ;;
        "10-background-jobs.md") echo "4500-5000" ;;
        "11-api-design.md") echo "4500-5500" ;;
        "12-testing-strategy.md") echo "4000-4500" ;;
        "13-phase2-capstone.md") echo "1200-1500" ;;
        "14-phase3-overview.md") echo "600-800" ;;
        "15-containers.md") echo "3500-4000" ;;
        "16-ci-cd.md") echo "4000-5000" ;;
        "17-cloud-infrastructure.md") echo "5000-6000" ;;
        "18-observability.md") echo "5000-6000" ;;
        "19-load-testing-reliability.md") echo "4000-4500" ;;
        "20-phase3-capstone.md") echo "1200-1500" ;;
        "21-phase4-overview.md") echo "600-800" ;;
        "22-design-pattern-drills.md") echo "6000-7000" ;;
        "23-real-world-architectures.md") echo "4000-5000" ;;
        "24-scaling-playbook.md") echo "5000-6000" ;;
        "25-phase4-capstone.md") echo "1000-1200" ;;
        "26-phase5-overview.md") echo "600-800" ;;
        "27-llm-integration.md") echo "5000-6000" ;;
        "28-rag-pipelines.md") echo "5000-6000" ;;
        "29-agent-backends.md") echo "4000-5000" ;;
        "30-ai-engineering-workflow.md") echo "3500-4000" ;;
        "31-phase5-capstone.md") echo "1500-2000" ;;
        "32-conclusion.md") echo "1500-2000" ;;
        "appendix-a-tool-recommendations.md") echo "1500-2000" ;;
        "appendix-b-further-reading.md") echo "1000-1500" ;;
        *) echo "0-0" ;;
    esac
}

# Total targets
TOTAL_MIN=60000
TOTAL_MAX=80000

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Backend for Senior Frontend Engineers - Word Count Progress${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Print header
printf "%-45s │ %7s │ %11s │ %s\n" "Chapter" "Current" "Target" "Status"
printf "%-45s─┼─%7s─┼─%11s─┼─%s\n" "─────────────────────────────────────────────" "───────" "───────────" "────────"

total_words=0
chapters_complete=0
chapters_started=0
total_chapters=0

# Chapter files in order
CHAPTER_FILES=(
    "00-introduction.md"
    "01-phase1-overview.md"
    "02-postgres-as-your-default.md"
    "03-queries-and-performance.md"
    "04-redis-and-caching.md"
    "05-beyond-postgres.md"
    "06-phase1-capstone.md"
    "07-phase2-overview.md"
    "08-project-structure.md"
    "09-auth-and-security.md"
    "10-background-jobs.md"
    "11-api-design.md"
    "12-testing-strategy.md"
    "13-phase2-capstone.md"
    "14-phase3-overview.md"
    "15-containers.md"
    "16-ci-cd.md"
    "17-cloud-infrastructure.md"
    "18-observability.md"
    "19-load-testing-reliability.md"
    "20-phase3-capstone.md"
    "21-phase4-overview.md"
    "22-design-pattern-drills.md"
    "23-real-world-architectures.md"
    "24-scaling-playbook.md"
    "25-phase4-capstone.md"
    "26-phase5-overview.md"
    "27-llm-integration.md"
    "28-rag-pipelines.md"
    "29-agent-backends.md"
    "30-ai-engineering-workflow.md"
    "31-phase5-capstone.md"
    "32-conclusion.md"
)

APPENDIX_FILES=(
    "appendix-a-tool-recommendations.md"
    "appendix-b-further-reading.md"
)

# Function to check status
print_status() {
    local count=$1
    local target=$2
    local min=$(echo "$target" | cut -d'-' -f1)
    local max=$(echo "$target" | cut -d'-' -f2)

    if [ "$count" -eq 0 ]; then
        echo -e "${RED}○ Not started${NC}"
    elif [ "$count" -lt "$min" ]; then
        local pct=$((count * 100 / min))
        echo -e "${YELLOW}◐ ${pct}%${NC}"
    elif [ "$count" -le "$max" ]; then
        echo -e "${GREEN}● Complete${NC}"
    else
        echo -e "${GREEN}● Complete (+$(($count - $max)))${NC}"
    fi
}

update_counters() {
    local count=$1
    local target=$2
    local min=$(echo "$target" | cut -d'-' -f1)

    if [ "$count" -gt 0 ]; then
        chapters_started=$((chapters_started + 1))
        if [ "$count" -ge "$min" ]; then
            chapters_complete=$((chapters_complete + 1))
        fi
    fi
}

# Process chapters
echo -e "${YELLOW}CHAPTERS${NC}"
echo ""

for filename in "${CHAPTER_FILES[@]}"; do
    filepath="$CHAPTERS_DIR/$filename"
    target=$(get_target "$filename")
    total_chapters=$((total_chapters + 1))

    if [ -f "$filepath" ]; then
        word_count=$(wc -w < "$filepath" | tr -d ' ')
    else
        word_count=0
    fi

    total_words=$((total_words + word_count))
    update_counters "$word_count" "$target"
    status=$(print_status "$word_count" "$target")

    display_name="${filename%.md}"
    printf "%-45s │ %7d │ %11s │ %b\n" "$display_name" "$word_count" "$target" "$status"
done

echo ""
printf "%-45s─┼─%7s─┼─%11s─┼─%s\n" "─────────────────────────────────────────────" "───────" "───────────" "────────"
echo ""

# Process appendices
echo -e "${YELLOW}APPENDICES${NC}"
echo ""

for filename in "${APPENDIX_FILES[@]}"; do
    filepath="$APPENDICES_DIR/$filename"
    target=$(get_target "$filename")
    total_chapters=$((total_chapters + 1))

    if [ -f "$filepath" ]; then
        word_count=$(wc -w < "$filepath" | tr -d ' ')
    else
        word_count=0
    fi

    total_words=$((total_words + word_count))
    update_counters "$word_count" "$target"
    status=$(print_status "$word_count" "$target")

    display_name="${filename%.md}"
    printf "%-45s │ %7d │ %11s │ %b\n" "$display_name" "$word_count" "$target" "$status"
done

echo ""
printf "%-45s─┼─%7s─┼─%11s─┼─%s\n" "─────────────────────────────────────────────" "───────" "───────────" "────────"
echo ""

# Summary
echo -e "${CYAN}SUMMARY${NC}"
echo ""

# Calculate percentage
if [ $total_words -gt 0 ]; then
    pct_of_min=$((total_words * 100 / TOTAL_MIN))
    pct_of_max=$((total_words * 100 / TOTAL_MAX))
else
    pct_of_min=0
    pct_of_max=0
fi

printf "%-30s %d words\n" "Total words:" "$total_words"
printf "%-30s %d-%d words\n" "Target range:" "$TOTAL_MIN" "$TOTAL_MAX"
printf "%-30s %d%% of minimum, %d%% of maximum\n" "Progress:" "$pct_of_min" "$pct_of_max"
printf "%-30s %d/%d\n" "Chapters complete:" "$chapters_complete" "$total_chapters"
printf "%-30s %d/%d\n" "Chapters started:" "$chapters_started" "$total_chapters"

echo ""

# Progress bar
echo -n "["
bar_width=50
filled=$((pct_of_min * bar_width / 100))
if [ $filled -gt $bar_width ]; then
    filled=$bar_width
fi

for ((i=0; i<filled; i++)); do
    echo -n "█"
done
for ((i=filled; i<bar_width; i++)); do
    echo -n "░"
done
echo -n "] $pct_of_min%"
echo ""
echo ""
