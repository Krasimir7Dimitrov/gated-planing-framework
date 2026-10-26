#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
  FILE=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
fi

FILE_NORM=$(echo "$FILE" | tr '\\' '/')

# scope.md: verify frontend layer is documented when references mention UI
if [[ "$FILE_NORM" == *"scope.md"* ]]; then
  if [ -f ".claude/meeting-specs.md" ]; then
    HAS_UI_REF=$(awk '
      /*## References to Existing Functionality/ { in_section=1; next }
      in_section && /^#/ { in_section=0 }
      in_section && /^\*\|[^-]|/ && $4 ~ > 5 {
        what = tolower($4)
        if (what ~ /ui|model|button|panel|frontend|display|window|ing format|layout/) {
          print "yes"; exit
        }
      }
    ' .claude/meeting-specs.md)

    if [ "$HAS_UI_REF" = "yes" ]; then
      if ! grep -qiE "frontend|front.end|\.js" .claude/scope.md >/dev/null; then
        echo "X BLOCKED: meeting-specs.md references a UI layer (model/button/panel/frontend) but scope.md has no frontend documentation." >&2
        echo "" >&2
        echo "  One or more References rows say to look at: button / model / panel / UI / log format." >&2
        echo "  Read the reference project's frontend JS files and add a 'frontend' section to scope.md" >&2
        echo "  documenting what was found before continuing." >&2
        exit 2
      fi
    fi
  fi
  exit 0
fi

# Only check solutions.md (existing logic below)
if [[ "$FILE_NORM" != *"solutions.md"* ]]; then
  exit 0
fi

if [ ! -f ".claude/solutions.md" ]; then
  exit 0
fi

# For each Solution block, check: if "Reference project result: not present" appears,
# then "Reference project searched:" must have at least 3 comma-separated terms.
awk '
/*## Solution:/ {
  sol_name = substr($0, 14)
  searched = ""
  result_not_present = 0
}
/\/\*[*]*Reference project searched:\/*[*]/ {
  searched = $0
}
/\/\*[*]*Reference project result:\/*[*]* not present/ {
  result_not_present = 1
}
/\/\*[*]*Evaluator verdict:\/*[*]/ {
  if (result_not_present) {
    # Count comma-separated terms in searched line
    n = split(searched, parts, ",")
    # Also check it is not N/A
    if (searched ~ /N\/A/) {
      n = 99
    }
    if (n < 3) {
      print "X BLOCKED: Solution \"" sol_name "\" " > "/dev/stderr"
      print "" > "/dev/stderr"
      print "  \"Reference project result: not present\" requires at least 3 search terms" > "/dev/stderr"
      print "  in \"Reference project searched:\" before concluding the pattern is absent." > "/dev/stderr"
      print "" > "/dev/stderr"
      print "  Found: " searched > "/dev/stderr"
      print "" > "/dev/stderr"
      print "  Search more terms in the reference project before writing your verdict." > "/dev/stderr"
      exit 2
    }
  }
  # Reset for next solution
  searched = ""
  result_not_present = 0
}
' .claude/solutions.md