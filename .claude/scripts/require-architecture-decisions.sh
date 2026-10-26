#!/bin/bash
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [ -z "$FILE" ]; then
    FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

if [[ "$FILE" != *"implementation-prompt.md"* ]]; then
exit 0
fi

if [ ! -f ".claude/implementation-prompt.md" ]; then
exit 0
fi

if [ ! -f ".claude/solutions.md" ]; then
exit 0
fi

SOLUTION_COUNT=$(grep -c "## Solution:" .claude/solutions.md 2>/dev/null || echo 0)

if [ "$SOLUTION_COUNT" -eq 0 ]; then
exit 0
fi

# Check 1: ## Architecture Decisions section must exist
if ! grep -q "## Architecture Decisions" .claude/implementation-prompt.md; then
echo "❌ BLOCKED: implementation-prompt.md is missing '## Architecture Decisions' section." >&2
echo "" >&2
echo "solutions.md has $SOLUTION_COUNT solution(s) with evaluator verdicts." >&2
echo "Before writing the prompt body, add this table at the top:" >&2
echo "" >&2
echo "## Architecture Decisions" >&2
echo "| Solution | Selected | How implemented |" >&2
echo "|---|---|---|" >&2
echo "| [exact Solution title] | naive approach / researcher finding: [pattern name] | [one sentence] |" >&2
echo "" >&2
echo "Selected column must match the Evaluator verdict in solutions-research.md." >&2
exit 2
fi

# Check 2: table must have at least as many data rows as solutions
DECISION_ROWS=$(awk '
/^\#\# Architecture Decisions/ { in_section=1; next }
in_section && /^#/ { in_section=0 }
in_section && /^\|[^-]/ { count++ }
END { print count+0 }
' .claude/implementation-prompt.md)

# Subtract 1 for the header row
DECISION_ROWS=$((DECISION_ROWS - 1))

if [ "$DECISION_ROWS" -lt "$SOLUTION_COUNT" ]; then
echo "❌ BLOCKED: Architecture Decisions table has $DECISION_ROWS row(s) but solutions.md has $SOLUTION_COUNT solution(s)." >&2
echo "Every solution must have a corresponding row in the Architecture Decisions table." >&2
exit 2
fi

# Check 3: Architecture Decisions table counts must match Evaluator verdicts in solutions-research.md
# ALL verdicts (SELF-SELECTED and AUTO-SELECTED) are in solutions-research.md.

if [ ! -f ".claude/solutions-research.md" ]; then
echo "❌ BLOCKED: .claude/solutions-research.md is missing - cannot verify Architecture Decisions match evaluator verdicts." >&2
exit 2
fi

# Count verdicts in solutions-research.md (both SELF-SELECTED and AUTO-SELECTED)
VERDICT_RESEARCHER=$(grep -c "\*\|\*Evaluator verdict:\*\|\*.researcher finding" .claude/solutions-research.md 2>/dev/null || echo 0)
VERDICT_NAIVE=$(grep -c "\*\|\*Evaluator verdict:\*\|\*.naive approach" .claude/solutions-research.md 2>/dev/null || echo 0)

# Count entries in Architecture Decisions table
TABLE_RESEARCHER=$(awk '
/^\#\# Architecture Decisions/ { in_section=1; next }
in_section && /^#/ { in_section=0 }
in_section && /researcher finding/ { count++ }
END { print count+0 }
' .claude/implementation-prompt.md)

TABLE_NAIVE=$(awk '
/^\#\# Architecture Decisions/ { in_section=1; next }
in_section && /^#/ { in_section=0 }
in_section && /naive approach/ { count++ }
END { print count+0 }
' .claude/implementation-prompt.md)

if [ "$TABLE_RESEARCHER" -ne "$VERDICT_RESEARCHER" ]; then
echo "❌ BLOCKED: Architecture Decisions table has $TABLE_RESEARCHER 'researcher finding' row(s) but solutions-research.md has $VERDICT_RESEARCHER such verdict(s)." >&2
echo "" >&2
echo "Read Evaluator verdicts from solutions-research.md for each solution and update the table." >&2
exit 2
fi

if [ "$TABLE_NAIVE" -ne "$VERDICT_NAIVE" ]; then
echo "❌ BLOCKED: Architecture Decisions table has $TABLE_NAIVE 'naive approach' row(s) but solutions-research.md has $VERDICT_NAIVE such verdict(s)." >&2
echo "" >&2
echo "Read Evaluator verdicts from solutions-research.md for each solution and update the table." >&2
exit 2
fi

# Check 4: Post-Evaluation Impact Review must exist in solutions-research.md
if ! grep -q "## Post-Evaluation Impact Review" .claude/solutions-research.md; then
echo "❌ BLOCKED: solutions-research.md is missing '## Post-Evaluation Impact Review' section." >&2
echo "" >&2
echo "Step 2.5d: after all evaluators complete, read every verdict and check for cross-impacts." >&2
echo "Write findings to solutions-research.md under '## Post-Evaluation Impact Review'." >&2
echo "One entry per solution - even if cross-impacts are none." >&2
exit 2
fi

# Check 5: every solution must have an entry in the impact review
IMPACT_ENTRIES=$(grep -c "^### " .claude/solutions-research.md 2>/dev/null || echo 0)
# Only count entries under the impact review section
IMPACT_ENTRIES=$(awk '
/^\#\# Post-Evaluation Impact Review/ { in_section=1; next }
in_section && /^## / { in_section=0 }
in_section && /^### / { count++ }
END { print count+0 }
' .claude/solutions-research.md)

if [ "$IMPACT_ENTRIES" -lt "$SOLUTION_COUNT" ]; then
echo "❌ BLOCKED: Post-Evaluation Impact Review has $IMPACT_ENTRIES entry/entries but solutions.md has $SOLUTION_COUNT solution(s)." >&2
echo "Add one '### [Solution title]' entry per solution - even if cross-impacts are none." >&2
exit 2
fi
