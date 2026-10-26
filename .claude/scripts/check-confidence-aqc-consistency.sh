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

# Check: AUTO-SELECTED verdict with Confidence < 90% must have at least one A entry
# in the Architecture Quality Check section that precedes the Evaluation.
#
# Rationale: uncertainty that lowers confidence belongs in the AQC as A, not hidden
# in the confidence number. A A in R1/R3/R4 triggers Trigger A -> REFINEMENT or PROTOTYPE.

if ! awk '
/*## Solution:/ {
  in_solution=1; aqc_has_warning=0; in_aqc=0; in_eval=0; is_auto=0; low_conf=0
}

/*### Architecture Quality Check/ && in_solution {
  aqc_has_warning=0; in_aqc=1
}

/*#/ && !/Architecture Quality Check/ && in_solution { in_aqc=0 }
in_aqc && /A/ { aqc_has_warning=1 }

/*### Evaluation/ && !/Prototype/ && in_solution {
  in_eval=1; is_auto=0; low_conf=0
}

/*#/ && !/### Evaluation/ && !/Architecture Quality Check/ && in_solution { in_eval=0 }
in_eval && /\/\*[*]*Confidence after research:\/*[*]/ {
  if (match($0, /[0-9]+/)) {
    num = substr($0, RSTART, RLENGTH)
    if (num+0 < 90) { low_conf=1 }
  }
}

in_eval && /\/\*[*]*Evaluator verdict:\/*[*]/ {
  if ($0 ~ /AUTO-SELECTED/) { is_auto=1 }
  if (low_conf && is_auto && !aqc_has_warning) { fail=1 }
}

END { exit fail }
' .claude/solutions-research.md; then
  echo "X BLOCKED: AUTO-SELECTED verdict with Confidence < 90% but Architecture Quality Check has no A entry." >&2
  echo "" >&2
  echo "  A confidence below 90% on an AUTO-SELECTED verdict means there is unresolved uncertainty." >&2
  echo "  That uncertainty must be reflected as A in the AQC dimension where it lives:" >&2
  echo "  * Cannot answer: [what specific information is missing] *" >&2
  echo "" >&2
  echo "  You cannot put uncertainty only in the Confidence number while scoring ■/X in AQC." >&2
  echo "  A in R1, R3, or R4 -> Trigger A -> REFINEMENT_REQUESTED or PROTOTYPE_REQUESTED." >&2
  exit 2
fi
