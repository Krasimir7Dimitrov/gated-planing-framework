#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
    FILE=$(echo "$INPUT" | grep -o '"path"[:space:]]*:[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[:space:]]*:[:space:]]*"\([^"]*\)"/\1/')
fi

FILE_NORM=$(echo "$FILE" | tr '\\' '/')

# Only enforce when writing discrepancies.md
if [[ "$FILE_NORM" != *"discrepancies.md" ]]; then
    exit 0
fi

# Check 1: if meeting documents exist, meeting-specs.md must exist first
MEETING_DOCS_EXIST=0
if [ -f ".claude/MEETING_TRANSCRIPT.md" ] || [ -f "MEETING_SCREEN_SUMMARY.json" ]; then
    MEETING_DOCS_EXIST=1
fi

if [ "$MEETING_DOCS_EXIST" -eq 1 ] && [ ! -f ".claude/meeting-specs.md" ]; then
    echo "X BLOCKED: meeting-specs.md does not exist." >&2
    echo "" >&2
    echo "MEETING_TRANSCRIPT.md / MEETING_SCREEN_SUMMARY.json are present." >&2
    echo "Spawn the meeting-extractor agent before writing discrepancies.md:" >&2
    echo "" >&2
    echo "  Agent(subagent_type: 'meeting-extractor', prompt: 'Extract all specs from the meeting documents into .claude/meeting-specs.md')" >&2
    echo "" >&2
    echo "Step 2 three-way comparison uses meeting-specs.md as the 'Meeting says:' source." >&2
    exit 2
fi

# Check 2: if meeting-specs.md has General Rules rows, they must have been processed as lessons
if [ -f ".claude/meeting-specs.md" ]; then
    # Count data rows in the General Rules section (lines starting with | that are not header or separator)
    GENERAL_RULES_ROWS=$(awk '
        /## General Rules/ { in_section=1; next }
        in_section && /^#/ { in_section=0 }
        in_section && /^\|[^-]/ { count++ }
        END { print count+0 }
    ' .claude/meeting-specs.md)

    # Subtract header row
    GENERAL_RULES_ROWS=$((GENERAL_RULES_ROWS - 1))

    if [ "$GENERAL_RULES_ROWS" -gt 0 ] && [ ! -f ".claude/meeting-rules-processed.txt" ]; then
        echo "X BLOCKED: meeting-specs.md contains $GENERAL_RULES_ROWS general rule(s) that have not been written as lessons." >&2
        echo "" >&2
        echo "For each row in '## General Rules & Architecture Decisions':" >&2
        echo "  Call write_lesson with the rule, its timestamp, and the scope it applies to." >&2
        echo "" >&2
        echo "When done: echo 'processed' > .claude/meeting-rules-processed.txt" >&2
        exit 2
    fi
fi