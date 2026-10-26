#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
  FILE=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
fi

# Only check implementation-prompt.md
if [[ "$FILE" != *"implementation-prompt.md"* ]]; then
  exit 0
fi

if [ ! -f ".claude/implementation-prompt.md" ]; then
  exit 0
fi

# Check 1: explicit placeholder phrases
PHRASE_MATCHES=$(grep -niE "confirm with user|to be confirmed|to be decided|\bTBD\b|\bTBC\b|needs clarification|open question|confirm which|ask |check with |verify with user|ask which|ask about|clarify with" .claude/implementation-prompt.md)

# Check 2: question marks on lines that imply a question directed at the user
# Excludes PHP null-safe (?->), nullable types (int?), and URL optional params ({x?})
QUESTION_MATCHES=$(grep -niE "\?" .claude/implementation-prompt.md \
  | grep -ivE "\?\->" \
  | grep -ivE "\?\"" \
  | grep -ivE "\?[A-Za-z][a-zA-Z]+" \
  | grep -ivE "^\s*[-*]\s*.*\|\?\s*$" \
  | grep -iE "(user|you|confirm|ask|decide|clarify|which|should|what|how|where|when)\b")

if [ -n "$PHRASE_MATCHES" ] || [ -n "$QUESTION_MATCHES" ]; then
  echo "X BLOCKED: implementation-prompt.md contains unresolved decisions." >&2
  echo "" >&2
  if [ -n "$PHRASE_MATCHES" ]; then
    echo "Forbidden phrases found:" >&2
    echo "$PHRASE_MATCHES" >&2
    echo "" >&2
  fi
  if [ -n "$QUESTION_MATCHES" ]; then
    echo "Question marks implying open decisions found:" >&2
    echo "$QUESTION_MATCHES" >&2
    echo "" >&2
  fi
  echo "Rule: Do NOT embed unresolved decisions in the prompt body." >&2
  echo "  1. STOP writing the prompt." >&2
  echo "  2. Add the question to Step 3 in the required Q&A format." >&2
  echo "  3. Wait for the user's answer." >&2
  echo "  4. Then continue writing the prompt." >&2
  exit 2
fi