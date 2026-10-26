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

# Only enforce if both files exist
if [ ! -f ".claude/discrepancies.md" ] || [ ! -f ".claude/solutions.md" ]; then
    exit 0
fi

# Detect if discrepancies.md introduces a new entity or table
NEW_ENTITY=$(grep -icE 'entity does not exist|new entity|migration required|does not exist |entity|...entity...|REQUIRED|CREATE TABLE' .claude/discrepancies.md 2>/dev/null || echo 0)

if [ "$NEW_ENTITY" -gt 0 ]; then
    if ! grep -qIZ "## Solution:.*Scheme Design" .claude/solutions.md; then
        echo "X BLOCKED: discrepancies.md introduces a new entity but solutions.md has no Schema Design solution." >&2
        echo "" >&2
        echo "Step 2.5 - Foundational Design is required before execution solutions." >&2
        echo "Add as the FIRST solution in solutions.md:" >&2
        echo "" >&2
        echo "  ## Solution: [EntityName] Schema Design" >&2
        echo "" >&2
        echo "Define every field (name, PHP type, column type, nullable) and verify self against C9." >&2
        echo "No execution solution may reference a field not defined here." >&2
        exit 2
    fi
fi