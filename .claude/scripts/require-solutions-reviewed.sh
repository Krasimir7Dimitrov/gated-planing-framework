#!/bin/bash
# Gate implementation-prompt.md until solution research has been reviewed.
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [ -z "$FILE" ]; then
    FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
[[ "$FILE" == *implementation-prompt.md* ]] || exit 0

for required in .claude/solutions-reviewed.txt .claude/solutions.md .claude/solutions-research.md; do
    if [ ! -f "$required" ]; then
        echo "BLOCKED: required review artifact is missing: $required" >&2
        exit 2
    fi
done

if grep -q '\[PENDING\]' .claude/solutions-research.md; then
    echo "BLOCKED: solutions-research.md still contains [PENDING] sections." >&2
    exit 2
fi
DRAFT_TITLES=$(grep '^## Solution:' .claude/solutions.md | sort)
RESEARCH_TITLES=$(grep '^## Solution:' .claude/solutions-research.md | sort)
if [ "$DRAFT_TITLES" != "$RESEARCH_TITLES" ]; then
    echo "BLOCKED: solution titles differ between solutions.md and solutions-research.md." >&2
    exit 2
fi
exit 0
