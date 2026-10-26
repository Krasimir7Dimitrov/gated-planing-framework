#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
    FILE=$(echo "$INPUT" | grep -o '"path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
fi

# Only check when writing discrepancies.md
if [[ "$FILE" != *"discrepancies.md"* ]]; then
    exit 0
fi

# Check 1: scope.md must exist
if [ ! -f ".claude/scope.md" ]; then
    echo "X BLOCKED: .claude/scope.md is missing." >&2
    echo "" >&2
    echo "scope.md must be written in Step 1 before gap analysis begins." >&2
    exit 2
fi

# Check 2: required sections must be present
MISSING_SECTIONS=""
for section in "MCP Calls Made" "Requirement Coverage" "Method Traces"; do
    if ! grep -q "## $section" .claude/scope.md; then
        MISSING_SECTIONS="${MISSING_SECTIONS}\n  - ## $section"
    fi
done

if [ -n "$MISSING_SECTIONS" ]; then
    echo "X BLOCKED: scope.md is missing required sections:" >&2
    printf "$MISSING_SECTIONS\n" >&2
    echo "" >&2
    echo "scope.md must have structured sections as the gap-analyzer has" >&2
    echo "complete, navigable information for every requirement." >&2
    echo "" >&2
    echo "Required structure:" >&2
    echo "  ## MCP Calls Made      - every MCP tool call + key result" >&2
    echo "  ## Requirement Coverage - one row per BE-* requirement" >&2
    echo "  ## Method Traces       - full return value + callers per method" >&2
    exit 2
fi

# Check 3: ## Requirement Coverage must have at least one data row (header alone is not enough)
COVERAGE_ROW_COUNT=$(awk '
    /## Requirement Coverage/ { in_section=1; next }
    /## / && !/Requirement Coverage/ { in_section=0 }
    in_section && /^\|/ && !/[:space:]]*\|[[:space:]]*[-]+/ { count++ }
    END { print count+0 }
' .claude/scope.md)

if [ "$COVERAGE_ROW_COUNT" -lt 2 ]; then
    echo "X BLOCKED: scope.md ## Requirement Coverage has no data rows." >&2
    echo "" >&2
    echo "Every BE-* requirement from meeting-specs.md must have a row:" >&2
    echo "  | BE-ID | Requirement | Implementing code | Callers | Return value traced |" >&2
    echo "" >&2
    echo "The gap-analyzer uses this table to know which code to examine." >&2
    exit 2
fi

# Check 4: ## Reference Files Read required when meeting-specs.md lists references
if [ -f ".claude/meeting-specs.md" ]; then
    if grep -q "## References to Existing Functionality" .claude/meeting-specs.md; then
        REF_ROWS=$(awk '
            /## References to Existing Functionality/ { in_section=1; next }
            /## / && !/References to Existing Functionality/ { in_section=0 }
            in_section && /^\|/ && !/[:space:]]*\|[[:space:]]*[-]+/ { count++ }
            END { print count+0 }
        ' .claude/meeting-specs.md)

        if [ "$REF_ROWS" -gt 1 ] && ! grep -q "## Reference Files Read" .claude/scope.md; then
            echo "X BLOCKED: scope.md is missing ## Reference Files Read." >&2
            echo "" >&2
            echo "meeting-specs.md ## References to Existing Functionality has entries." >&2
            echo "Every referenced file must be read and documented before gap analysis." >&2
            echo "" >&2
            echo "Add to scope.md:" >&2
            echo "  ## Reference Files Read" >&2
            echo "  | File | Path read | Key pattern found |" >&2
            exit 2
        fi
    fi
fi