#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
  FILE=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
fi

if [[ "$FILE" == *"discrepancies.md"* ]] || [[ "$FILE" == *"solutions.md"* ]]; then

  if [ ! -f ".claude/business-logic-extract.md" ]; then
    echo "* BLOCKED: .claude/business-logic-extract.md is missing." >&2
    echo "**" >&2
    echo "  Step 1b: call search_business_logic for every domain concept in this task" >&2
    echo "  and write the actual findings to .claude/business-logic-extract.md." >&2
    echo "  Only rules and constraints directly relevant to the feature being built." >&2
    exit 2
  fi

  CONTENT_LINES=$(grep -c "^[[:space:]]*" .claude/business-logic-extract.md 2>/dev/null || echo 0)
  if [ "$CONTENT_LINES" -lt 3 ]; then
    echo "* BLOCKED: .claude/business-logic-extract.md has only $CONTENT_LINES non-blank lines - need at least 3." >&2
    echo "**" >&2
    echo "  Call search_business_logic for every domain concept and write the actual results." >&2
    echo "  If nothing is relevant, write what was searched and why nothing applies." >&2
    exit 2
  fi

fi