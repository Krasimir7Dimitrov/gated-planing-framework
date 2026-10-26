#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
  FILE=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
fi

FILE_NORM=$(echo "$FILE" | tr '\\' '/')

if [[ "$FILE_NORM" != *"solutions-research.md"* ]]; then
  exit 0
fi

if [ ! -f ".claude/solutions-research.md" ]; then
  exit 0
fi

# Check: If ANY approach in a solution block has **Workaround found:** with actual content
# (not "none found") AND the AQC section contains X for any approach - the AQC section
# must mention "Workaround" at least once.
#
# Rationale: A X that ignores a documented workaround is an incomplete evaluation.
# The evaluator must explicitly address why the workaround does not resolve the issue.

if ! awk '
/^## Solution:/ {
  if (in_solution && has_workaround && has_aqc_fail && !aqc_mentions_workaround) { fail=1 }
  in_solution=1; has_workaround=0; has_aqc_fail=0; aqc_mentions_workaround=0
  in_research=0; in_aqc=0
}

/^### Research/ && in_solution               { in_research=1; in_aqc=0 }
/^### Architecture Quality Check/ && in_solution { in_aqc=1; in_research=0 }
/^### / && !/Research/ && !/Architecture Quality Check/ && in_solution { in_research=0; in_aqc=0 }

in_research && /^\* \*Workaround found:\*/ {
  rest=$0
  sub(/.*\*Workaround found:\*[[:space:]]*/, "", rest)
  if (length(rest) > 4 && rest !~ /^(\[n|N]one/ ) { has_workaround=1 }
}

in_research && /^\* \*Alternative workaround found:\*/ {
  rest=$0
  sub(/.*\*Alternative workaround found:\*[[:space:]]*/, "", rest)
  if (length(rest) > 4 && rest !~ /^(\[n|N]ot found/ && rest !~ /^(\[n|N]one/) { has_workaround=1 }
}

in_aqc && /- X/ { has_aqc_fail=1 }
in_aqc && /[Ww]orkaround/ { aqc_mentions_workaround=1 }

END {
  if (in_solution && has_workaround && has_aqc_fail && !aqc_mentions_workaround) { fail=1 }
  exit fail
}
' .claude/solutions-research.md; then
  echo "* BLOCKED: AQC has X for an approach that has a documented **Workaround found:** or **Alternative workaround found:** in Research, but the AQC section never mentions the workaround." >&2
  echo "**" >&2
  echo "  A X score that ignores a documented workaround is incomplete." >&2
  echo "  For each X on an approach with a Workaround found:" >&2
  echo "  1. State what the workaround is." >&2
  echo "  2. Explain why it does NOT resolve the issue for this specific dimension." >&2
  echo "  3. If the workaround DOES resolve the issue - change the score to [check] or A." >&2
  exit 2
fi