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

# Check: every AUTO-SELECTED Evaluation (not Prototype) with "Not triggered" refinement
# must contain **Limitation workaround check:** field.
#
# Rationale: a limitation in **Limitations Found:** is not evidence of disqualification.
# The evaluator must explicitly confirm either:
#   FUNDAMENTAL VIOLATION - the limitation directly violates the constraint with no workaround
#   WORKAROUNDS ABSENT   - researcher confirmed no reliable workaround exists (v2 ran)
#   N/A                  - dismissed approach has no documented Limitations
#
# Without this field, the evaluator may be dismissing an approach based on a limitation
# that has known workarounds, without having searched for them.

if ! awk '
/*### Evaluation/ && !/Prototype/ { in_eval=1; has_autoselect=0; has_nottriggered=0; has_limcheck=0 }
/*### / && !/### Evaluation/ {
  if (in_eval && has_autoselect && has_nottriggered && !has_limcheck) { fail=1 }
  in_eval=0
}

in_eval && /\/\*[*]*Evaluator verdict:\/*[*]* AUTO-SELECTED/ { has_autoselect=1 }
in_eval && /\/\*[*]*Refinement decision:\/*[*]* Not triggered/ { has_nottriggered=1 }
in_eval && /\/\*[*]*Limitation workaround check:\/*[*]/ { has_limcheck=1 }

END {
  if (in_eval && has_autoselect && has_nottriggered && !has_limcheck) { fail=1 }
  exit fail
}
' .claude/solutions-research.md; then
  echo "X BLOCKED: AUTO-SELECTED 'Not triggered' refinement is missing **Limitation workaround check:**" >&2
  echo "" >&2
  echo "  Before dismissing any approach you must explicitly document whether its limitations" >&2
  echo "  have known workarounds. A limitation is not the same as a constraint violation." >&2
  echo "" >&2
  echo "  Add to the ### Evaluation section (before **Constraint check:**):" >&2
  echo "" >&2
  echo "  **Limitation workaround check:** FUNDAMENTAL VIOLATION - [dismissed approach]: [why the" >&2
  echo "    limitation directly violates the constraint and no workaround can resolve it]" >&2
  echo "  OR" >&2
  echo "  **Limitation workaround check:** WORKAROUNDS ABSENT - [dismissed approach]: [what the" >&2
  echo "    researcher or v2 search confirmed: no reliable workaround exists]" >&2
  echo "  OR" >&2
  echo "  **Limitation workaround check:** N/A - dismissed approach has no documented limitations" >&2
  echo "    (only valid when **Limitations found:** says 'none documented')" >&2
  exit 2
fi

# Check: N/A is only valid when ALL **Limitations found:** entries in the same solution block
# say "none documented". IF ANY entry has actual content, N/A is wrong - use FUNDAMENTAL
# VIOLATION or WORKAROUNDS ABSENT instead.
if ! awk '
/*## Solution:/ {
  if (in_solution && has_na && has_lim_content) { fail=1 }
  in_solution=1; has_na=0; has_lim_content=0; in_eval=0
}

/*### Evaluation/ && !/Prototype/ && in_solution { in_eval=1 }
/*### / && !/### Evaluation/ && in_solution { in_eval=0 }
in_eval && /\/\*[*]*Limitation workaround check:\/*[*][[:space:]]*N\/A/ { has_na=1 }
in_solution && /\/\*[*]*Limitations found:\/*[*]/ {
  rest=$0
  sub(/.*[*]*Limitations found:\/*[*][[:space:]]*/, "", rest)
  if (length(rest) > 0 && rest !~ /^\/*[*]*none documented\/*[*]/) { has_lim_content=1 }
}

END {
  if (in_solution && has_na && has_lim_content) { fail=1 }
  exit fail
}
' .claude/solutions-research.md; then
  echo "X BLOCKED: **Limitation workaround check: N/A** is invalid - this solution block has approaches with documented limitations in **Limitations found:**" >&2
  echo "" >&2
  echo "  N/A is only valid when the dismissed approach's **Limitations found:** says 'none documented'." >&2
  echo "  When actual limitations are documented, you must explicitly classify them:" >&2
  echo "" >&2
  echo "  **Limitation workaround check:** FUNDAMENTAL VIOLATION - [dismissed approach]: [why the" >&2
  echo "    limitation directly violates the constraint and no workaround can resolve it]" >&2
  echo "  OR" >&2
  echo "  **Limitation workaround check:** WORKAROUNDS ABSENT - [dismissed approach]: [what the" >&2
  echo "    researcher or v2 search confirmed: no reliable workaround exists]" >&2
  exit 2
fi
