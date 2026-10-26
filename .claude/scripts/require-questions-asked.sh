#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')

# Do not block if the hook is already active (prevents infinite loop)
if echo "$INPUT" | grep -q '"stop_hook_active"[:space:]]*:[:space:]]*true'; then
    exit 0
fi

QUESTIONS_FILE=".claude/questions-asked.txt"

# If file doesn't exist, create it with N/A and allow - Claude will populate it explicitly when doing analysis
if [ ! -f "$QUESTIONS_FILE" ]; then
    echo "N/A" > "$QUESTIONS_FILE"
    exit 0
fi

# If file exists but is empty, block - it was created but never filled
if [ ! -s "$QUESTIONS_FILE" ]; then
    echo "X BLOCKED: questions-asked.txt exists but is empty." >&2
    echo "Run: echo 'N/A' > .claude/questions-asked.txt (or document actual questions)" >&2
    exit 2
fi