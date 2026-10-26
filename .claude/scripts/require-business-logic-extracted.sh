#!/bin/bash
set -u
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [ -z "$FILE" ]; then
    FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

case "$FILE" in
    *discrepancies.md*|*solutions.md*) ;;
    *) exit 0 ;;
esac

if [ ! -f ".claude/business-logic-extract.md" ]; then
    echo "BLOCKED: .claude/business-logic-extract.md is missing." >&2
    echo "Search the business logic and record relevant findings before writing discrepancies.md or solutions.md." >&2
    exit 2
fi

CONTENT_LINES=$(grep -c '^[^[:space:]]' .claude/business-logic-extract.md 2>/dev/null || true)
CONTENT_LINES=${CONTENT_LINES:-0}
if [ "$CONTENT_LINES" -lt 3 ]; then
    echo "BLOCKED: .claude/business-logic-extract.md has fewer than 3 non-blank lines." >&2
    exit 2
fi
