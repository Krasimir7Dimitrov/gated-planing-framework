#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
    FILE=$(echo "$INPUT" | grep -o '"path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
fi

# Only enforce scope for source files - allow docs, images, config reads freely
case "$FILE" in
    *.php|*.js|*.ts|*.jsx|*.tsx|*.twig|*.html|*.css|*.scss)
        ;;
    *)
        exit 0
        ;;
esac

if [ ! -f ".claude/scope.md" ]; then
    echo "X BLOCKED: Cannot read source files before scope.md exists." >&2
    echo "Complete Step 1 first: List all files in scope to .claude/scope.md" >&2
    exit 2
fi