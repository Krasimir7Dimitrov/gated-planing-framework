#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
  FILE=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
fi

FILE_NORM=$(echo "$FILE" | tr '\\' '/')

# Only check solutions.md
if [[ "$FILE_NORM" != *"solutions.md"* ]]; then
  exit 0
fi

if [ ! -f ".claude/solutions.md" ]; then
  exit 0
fi

# Early self-contradiction check: Self-select: YES + extensibility constraint + cons admit modifications
awk '
/^## Solution:/ {
  if (in_solution && is_self && has_ext && has_mod) {
    print "* Self-contradiction detected in solution: '"$sol_name"'" > "/dev/stderr"
    print "**" > "/dev/stderr"
    print "  Self-select: YES but Options -> Cons document a constraint violation:" > "/dev/stderr"
    print "  Constraint requires extensibility without service modifications," > "/dev/stderr"
    print "  but Cons admit that service or constructor modifications are required." > "/dev/stderr"
    print "**" > "/dev/stderr"
    print "  Fix: Set Self-select: NO before proceeding to Step 2.5b." > "/dev/stderr"
  }
  in_solution=1; sol_name=substr($0,14)
  is_self=0; has_ext=0; has_mod=0; in_opts=0
}

/^\*   \*Constraint:\*/ {
  if ($0 ~ /without modif|without changing|extensib[^:]*=|no modif/) has_ext=1
}

/^\*   \*Self-select:\*.*YES/ { is_self=1 }
/^\*   \*Options:\*/ { in_opts=1 }
/^\*   \*/ { in_opts=0 }

  is_self=0; has_ext=0; has_mod=0; in_opts=0
}

/^\*   \*Constraint:\*/ {
  if ($0 ~ /without modif|without changing|extensib[^:]*=|no modif/) has_ext=1
}

/^\*   \*Self-select:\*.*YES/ { is_self=1 }
/^\*   \*Options:\*/ { in_opts=1 }
/^\*   \*/ { in_opts=0 }
in_opts && /constructor|must be updated|requires modif[yi]|must be modified|requires edit|service must/ {
  has_mod=1
}
END {
  if (in_solution && is_self && has_ext && has_mod) {
    print "* Self-contradiction detected in solution: '"$sol_name"'" > "/dev/stderr"
    print "**" > "/dev/stderr"
    print "  Self-select: YES but Options -> Cons document a constraint violation:" > "/dev/stderr"
    print "  Constraint requires extensibility without service modifications," > "/dev/stderr"
    print "  but Cons admit that service or constructor modifications are required." > "/dev/stderr"
    print "**" > "/dev/stderr"
    print "  Fix: Set Self-select: NO before proceeding to Step 2.5b." > "/dev/stderr"
  }
}
' .claude/solutions.md

# Frontend/backend separation check: FE-* IDs must not appear in Meeting constraints found
# Pre-evaluation Context is in solutions-research.md (not solutions.md)
if [ -f ".claude/solutions-research.md" ]; then
  if grep -qE '^\* \*Meeting constraints found:\*.*FE-[0-9]' .claude/solutions-research.md; then
    echo "* Frontend requirement cited in backend constraint: **Meeting constraints found:** contains FE-* ID." >&2
    echo "**" >&2
    echo "  Frontend requirements (FE-*) describe display rules - they are NOT backend architecture constraints." >&2
    echo "  Remove FE-* IDs from **Meeting constraints found:** and use only BE-* IDs." >&2
    fi
fi