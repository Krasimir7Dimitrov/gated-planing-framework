#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
    FILE=$(echo "$INPUT" | grep -o '"path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
fi

# Only check implementation-prompt.md
if [[ "$FILE" != "implementation-prompt.md" ]]; then
    exit 0
fi

# Check 1: decision-inventory.md must exist
if [ ! -f ".claude/decision-inventory.md" ]; then
    echo "X BLOCKED: .claude/decision-inventory.md is missing." >&2
    echo "" >&2
    echo "Step 2.9 - Decision Inventory must be completed before writing the prompt." >&2
    echo "Required sections:" >&2
    echo "  ### Entity Fields      - every new entity field, type, C9 check, source" >&2
    echo "  ### Method Calls        - every method called in the prompt, verified file:line" >&2
    echo "  ### Constraints Applied - all C1-C9 explicitly stated (N/A allowed)" >&2
    echo "  ### Frontend Framework  - framework verified against a real source file" >&2
    exit 2
fi

# Check 2: required sections must exist
MISSING_SECTIONS=""
for section in "Entity Fields" "Method Calls" "Constraints Applied" "Frontend Framework"; do
    if ! grep -q "### $section" .claude/decision-inventory.md; then
        MISSING_SECTIONS="${MISSING_SECTIONS}\n  - ### $section"
    fi
done

if [ -n "$MISSING_SECTIONS" ]; then
    echo "X BLOCKED: decision-inventory.md is missing required sections:" >&2
    printf "$MISSING_SECTIONS\n" >&2
    exit 2
fi

# Check 3: no placeholder phrases
PLACEHOLDERS=$(grep -niE '\bTBD\b|assumed|not verified|not checked|\bTODO\b|to be confirmed' .claude/decision-inventory.md 2>/dev/null)
if [ -n "$PLACEHOLDERS" ]; then
    echo "X BLOCKED: decision-inventory.md contains unresolved placeholders." >&2
    echo "" >&2
    echo "$PLACEHOLDERS" >&2
    echo "" >&2
    echo "Every entry must be explicitly verified. If a method or field cannot be verified - step," >&2
    echo "add it to Step 3, wait for the answer, then resume." >&2
    exit 2
fi

# Check 4: all C1-C9 must appear in the inventory
MISSING_CONSTRAINTS=""
for i in 1 2 3 4 5 6 7 8 9; do
    if ! grep -qE "\bC${i}\b" .claude/decision-inventory.md; then
        MISSING_CONSTRAINTS="$MISSING_CONSTRAINTS C${i}"
    fi
done

if [ -n "$MISSING_CONSTRAINTS" ]; then
    echo "X BLOCKED: decision-inventory.md is missing constraints: $MISSING_CONSTRAINTS" >&2
    echo "" >&2
    echo "ALL C1-C9 constraints must appear in '### Constraints Applied'." >&2
    echo "Write 'N/A - not applicable' explicitly for constraints that don't affect this task." >&2
    exit 2
fi

# Check 5: Source values in Entity Fields must match actual ## Solution: titles in solutions-research.md
# Skip if solutions-research.md does not exist (no formal solutions needed for this task)
if [ -f ".claude/solutions-research.md" ]; then
    INVALID_SOURCES=""
    while IFS= read -r source; do
        [ -z "$source" ] && continue
        # Allow Q&A-derived sources: "Q1 answer", "Step 3", "confirmed answer", etc.
        if echo "$source" | grep -qiE "Q[0-9]|step 3|answer|confirmed"; then
            continue
        fi
        if ! grep -qF "## Solution: $source" .claude/solutions-research.md; then
            INVALID_SOURCES="${INVALID_SOURCES}\n  - \"$source\""
        fi
    done < <(awk '
        /### Entity Fields/ { in_section=1; next }
        /^#/ && !/Entity Fields/ { in_section=0 }
        in_section && /^\/|/ {
            if ($0 ~ /^\|---/) next
            line = $0
            gsub(/^\|[[:space:]]*|\|[[:space:]]*$/, "", line)
            n = split(line, cols, "|")
            source = cols[n]
            gsub(/^[[:space:]]*|[[:space:]]*$/, "", source)
            if (length(source) > 0 && source != "Source") print source
        }
    ' .claude/decision-inventory.md)

    if [ -n "$INVALID_SOURCES" ]; then
        echo "X BLOCKED: decision-inventory.md Source column contains values that don't match any '## Solution:' in solutions-research.md." >&2
        echo "" >&2
        echo "Unmatched sources:" >&2
        printf "$INVALID_SOURCES\n" >&2
        echo "" >&2
        echo "Every entity field must trace to an actual Schema Design Solution." >&2
        echo "Fix: correct the Source value to match exactly the '## Solution: ...' title," >&2
        echo "or mark it as 'Q[n] answer' if it was decided in Step 3 Q&A." >&2
        exit 2
    fi
fi