#!/bin/bash
set -u
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [ -z "$FILE" ]; then
    FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
FILE_NORM=$(printf '%s' "$FILE" | tr '\\' '/')
[[ "$FILE_NORM" == *discrepancies.md* ]] || exit 0
[ -f .claude/meeting-specs.md ] || exit 0

REFS=$(awk -F'|' '
    /## References to Existing Functionality/ { in_section=1; next }
    in_section && /^#/ { in_section=0 }
    in_section && NF >= 5 && index($4, "Path:") > 0 {
        cell=$4
        sub(/^.*Path:[[:space:]]*/, "", cell)
        gsub(/^[[:space:]`\047"]+|[[:space:]`\047"]+$/, "", cell)
        if (cell != "") print cell
    }
' .claude/meeting-specs.md)
[ -n "$REFS" ] || exit 0
[ -f .claude/read-log.txt ] || {
    echo "BLOCKED: Reference project files listed in meeting-specs.md have not been read." >&2
    exit 2
}

MISSING=()
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    ref_norm=$(printf '%s' "$ref" | tr '\\' '/')
    if ! grep -qF "$ref_norm" .claude/read-log.txt 2>/dev/null && ! grep -qF "$ref" .claude/read-log.txt 2>/dev/null; then
        MISSING+=("$ref")
    fi
done <<< "$REFS"

if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "BLOCKED: No reference files read for:" >&2
    printf ' - %s\n' "${MISSING[@]}" >&2
    exit 2
fi
