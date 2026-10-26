#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)"//')
if [ -z "$FILE" ]; then
  FILE=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"//')
fi

FILE_NORM=$(echo "$FILE" | tr '\\' '/')

if [[ "$FILE_NORM" != *"solutions-research.md"* ]]; then
  exit 0
fi

if [ ! -f ".claude/solutions-research.md" ]; then
  exit 0
fi

# Check: **Leading approach after AQC:** and **Decision: Adopted:** must name the same approach.
# IF they differ, **Reasoning:** must contain "AQC winner overruled".
#
# Rationale: the decision must derive from the AQC comparison table, not from prior intuition
# or from finding existing code. Finding an existing implementation is evidence, not a mandate.

if ! awk '
/*## Solution:/ {
  if (in_solution && mismatch && !has_override) { fail=1 }
  in_solution=1; mismatch=0; has_override=0
  leading=""; adopted=""
  in_eval=0; in_reasoning=0; in_aqc=0
}

/*### Architecture Quality Check/ && in_solution { in_aqc=1; in_eval=0; in_reasoning=0 }
/*### Evaluation/ && !/Prototype/ && in_solution { in_eval=1; in_aqc=0; in_reasoning=0 }
/*### / && !/### Evaluation/ && !/Architecture Quality Check/ && in_solution { in_eval=0; in_aqc=0; in_reasoning=0 }

in_aqc && /\/\*[*]*Leading approach after AQC:\/*[*]/ {
  rest=$0
  sub(/.*[*]*Leading approach after AQC:\/*[*][[:space:]]*/, "", rest)
  sub(/[[:space:]]*[--].*/, "", rest)
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", rest)
  leading=tolower(rest)
}

in_eval && /\/\*[*]*Decision:\/*[*][[:space:]]*Adopted:/ {
  rest=$0
  sub(/.*[*]*Decision:\/*[*][[:space:]]*Adopted:[[:space:]]*/, "", rest)
  sub(/[[:space:]]*[--].*/, "", rest)
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", rest)
  adopted=tolower(rest)
  if (leading != "" && adopted != "") {
    if (index(leading, adopted) == 0 && index(adopted, leading) == 0) {
      mismatch=1
    }
  }
}

in_eval && /\/\*[*]*Reasoning:\/*[*]/ { in_reasoning=1 }
in_reasoning && /[Aa][Qq][Cc] winner overruled/ { has_override=1 }

END {
  if (in_solution && mismatch && !has_override) { fail=1 }
  exit fail
}
' .claude/solutions-research.md; then
  echo "X BLOCKED: **Decision:** names a different approach than **Leading approach after AQC:**" >&2
  echo "" >&2
  echo "  The decision must derive from the AQC comparison table - not from prior intuition" >&2
  echo "  or from finding existing code in the project." >&2
  echo "" >&2
  echo "  If the AQC winner fails the constraint and you must select a different approach," >&2
  echo "  add to **Reasoning:** explicitly:" >&2
  echo '  "AQC winner overruled - [approach name] fails the constraint because: [reason]"' >&2
  exit 2
fi
