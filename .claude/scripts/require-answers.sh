#!/bin/bash
INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
  FILE=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
fi

if [[ "$FILE" == *"implementation-prompt.md"* ]]; then
  if [ ! -f .claude/answers-confirmed.txt ]; then
    echo "* BLOCKED: Questions from Step 3 not yet answered." >&2
    echo "Get user confirmation on all questions, then:" >&2
    echo "  echo 'confirmed' > .claude/answers-confirmed.txt" >&2
    exit 2
  fi
fi