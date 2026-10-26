#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
    FILE=$(echo "$INPUT" | grep -o '"path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
fi

# Normalize backslashes to forward slashes (Windows path compatibility)
FILE_NORM=$(echo "$FILE" | tr '\\' '/')

# Allow writes to .claude/ working directory always
if [[ "$FILE_NORM" == *".claude/"* ]] || [[ "$FILE_NORM" == *"/.claude/"* ]]; then
    exit 0
fi

# Allow writes to CLAUDE.md (project config, not implementation code)
if [[ "$FILE_NORM" == *"/CLAUDE.md" ]] || [[ "$FILE_NORM" == "CLAUDE.md" ]]; then
    exit 0
fi

DONE_FILE=".claude/checklist-done.txt"

if [ ! -f "$DONE_FILE" ]; then
    echo "X BLOCKED: Pre-Implementation Checklist not completed." >&2
    echo "" >&2
    echo "Before writing code you MUST:" >&2
    echo "  Step 1: List all files in scope (output to .claude/scope.md)" >&2
    echo "  Step 2: Systematic conflict analysis - trace ALL paths per rule -> .claude/discrepancies.md" >&2
    echo "  Step 3: Ask user about any ambiguity. Get confirmation." >&2
    echo "" >&2
    echo "When done: run touch .claude/checklist-done.txt" >&2
    exit 2
fi