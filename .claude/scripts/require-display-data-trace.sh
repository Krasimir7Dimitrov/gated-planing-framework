#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
    FILE=$(echo "$INPUT" | grep -o '"path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
fi

# Normalize backslashes to forward slashes (Windows path compatibility)
FILE_NORM=$(echo "$FILE" | tr '\\' '/')

# Only enforce on implementation-prompt.md
if [[ "$FILE_NORM" != *"implementation-prompt.md" ]]; then
    exit 0
fi

TRACE_FILE=".claude/display-data-trace.md"

if [ ! -f "$TRACE_FILE" ]; then
    echo "X BLOCKED: display-data-trace.md is missing." >&2
    echo "" >&2
    echo "Step 3.7 (Display Data Trace) must be completed before writing implementation-prompt.md." >&2
    echo "" >&2
    echo "The prompt-writing agent must:" >&2
    echo "  1. Read meeting-specs.md ## Explicit Examples and ## Format Specifications" >&2
    echo "  2. Trace each example sentence to an entity field" >&2
    echo "  3. Write .claude/display-data-trace.md with COVERED/MISSING verdicts" >&2
    echo "  4. Only if all verdicts are COVERED - write implementation-prompt.md" >&2
    exit 2
fi

# Check for MISSING verdicts in the trace table
# Look for | MISSING | or | MISSING at end of line (Table cell)
MISSING_COUNT=$(grep -cE '\|[[:space:]]*MISSING[[:space:]]*\|' "$TRACE_FILE" 2>/dev/null || echo 0)

if [ "$MISSING_COUNT" -gt 0 ]; then
    echo "X BLOCKED: display-data-trace.md contains $MISSING_COUNT MISSING verdict(s)." >&2
    echo "" >&2
    echo "All meeting example sentences must be COVERED before the prompt can be written." >&2
    echo "" >&2
    echo "MISSING verdicts mean data is needed but not available at dispatch time or not stored." >&2
    echo "Add Step 3 questions for each MISSING verdict and get user answers first." >&2
    grep -n "MISSING" "$TRACE_FILE" >&2
    exit 2
fi