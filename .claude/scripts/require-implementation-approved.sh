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

# Only enforce if implementation-prompt.md has been written
if [ ! -f ".claude/implementation-prompt.md" ]; then
    exit 0
fi

APPROVED_FILE=".claude/implementation-approved.txt"

if [ ! -f "$APPROVED_FILE" ]; then
    echo "X BLOCKED: Implementation not yet approved by the user." >&2
    echo "" >&2
    echo "The implementation prompt is ready at .claude/implementation-prompt.md" >&2
    echo "Present it to the user and wait for explicit approval to start coding." >&2
    echo "" >&2
    echo "When the user approves: touch .claude/implementation-approved.txt" >&2
    exit 2
fi