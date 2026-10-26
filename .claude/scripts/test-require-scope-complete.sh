#!/bin/bash
# Tests for require-scope-complete.sh
# Usage: bash .claude/scripts/test-require-scope-complete.sh

HOOK_ABS="$(cd "$(dirname "$0")" && pwd)/require-scope-complete.sh"
PASS=0
FAIL=0
TMPDIR_ROOT=$(mktemp -d)

# Helper: run hook against a fake file write to discrepancies.md
run_hook() {
    local scope="$1"
    local meeting="$2"
    local label="$3"
    local expect="$4" # "block" or "pass"

    local tmpdir="$TMPDIR_ROOT/case_${echo $PASS$FAIL}"
    mkdir -p "$tmpdir/.claude"

    [ -n "$scope" ] && printf '%s' "$scope" > "$tmpdir/.claude/scope.md"
    [ -n "$meeting" ] && printf '%s' "$meeting" > "$tmpdir/.claude/meeting-specs.md"

    local input='{"tool_name":"Write","tool_input":{"file_path":"'"$tmpdir"'/.claude/discrepancies.md","content":"x"}}'
    local result
    result=$(cd "$tmpdir" && echo "$input" | bash "$HOOK_ABS" 2>&1)
    local exit_code=$?

    if [ "$expect" = "block" ] && [ $exit_code -ne 0 ]; then
        echo "  ■ BLOCK  $label"
        PASS=$((PASS+1))
    elif [ "$expect" = "pass" ] && [ $exit_code -eq 0 ]; then
        echo "  ■ PASS   $label"
        PASS=$((PASS+1))
    else
        echo "  X WRONG  $label (expected $expect, got exit=$exit_code)"
        [ -n "$result" ] && echo "    -> $result" | head -3
        FAIL=$((FAIL+1))
    fi
}

# Minimal valid scope.md (used in multiple tests)
VALID_SCOPE="# Scope

## MCP Calls Made
| Tool | Input | Key findings |
|---|---|---|
| get_lessons | - | none |

## Requirement Coverage
| BE-ID | Requirement | Implementing code | Callers | Return value traced |
|---|---|---|---|---|
| BE-1 | log channel create | src/Service/Foo.php:10 | src/Controller/Bar.php:5 | YES |

## Method Traces
### Foo::create() - src/Service/Foo.php:10
- Returns: {id: int}
- id - passed to response
- Callers: src/Controller/Bar.php:5"

# Tests -------------------------------------------------------------------
echo ""
echo "=== require-scope-complete.sh tests ==="
echo ""

echo "1. Missing scope.md"
run_hook "" "" "scope.md missing" "block"

echo ""
echo "2. Missing required sections"
run_hook "# Scope
Some text but no sections." "" "no sections at all" "block"

run_hook "# Scope
## MCP Calls Made
| Tool | Input |
|---|---|
| get_lessons | - |" "" "missing Requirement Coverage and Method Traces" "block"

run_hook "# Scope
## MCP Calls Made
some content
## Requirement Coverage
header only - no table
## Method Traces
content" "" "Requirement Coverage has no table rows" "block"

echo ""
echo "3. Requirement Coverage - empty / minimal rows"
run_hook "# Scope
## MCP Calls Made
| Tool | Input | Key findings |
|---|---|---|
| get_lessons | - | none |

## Requirement Coverage
| BE-ID | Requirement | Implementing code | Callers | Return value traced |
|---|---|---|---|---|

## Method Traces
### Foo::bar()" "" "Requirement Coverage header+separator but no data rows" "block"

run_hook "# Scope
## MCP Calls Made
| Tool | Input | Key findings |
|---|---|---|
| get_lessons | - | none |

## Requirement Coverage
| BE-ID | Requirement | Implementing code | Callers | Return value traced |
|---|---|---|---|---|
| | | | | |

## Method Traces
### Foo::bar()" "" "Requirement Coverage with empty data row (bypass attempt)" "pass"
# NOTE: this is a gap - empty row passes

echo ""
echo "4. Case sensitivity"
run_hook "# Scope
## mcp calls made
## requirement coverage
| BE-ID | x |
|---|---|
| BE-1 | y |
## method traces" "" "Lowercase section names (bypass attempt)" "block"

echo ""
echo "5. Valid scope.md - should pass"
run_hook "$VALID_SCOPE" "" "valid scope.md, no meeting references" "pass"

echo ""
echo "6. Reference Files Read - meeting with references"
MEETING_WITH_REFS='# Reference to Existing Functionality
| Timestamp | Reference | What to Look at |
|---|---|---|
| 01:00 | Shipping module | reference project write-side |'

run_hook "$VALID_SCOPE" "$MEETING_WITH_REFS"   "meeting has references but scope.md missing Reference Files Read" "block"

SCOPE_WITH_REFS="$VALID_SCOPE

## Reference Files Read
| File | Path read | Key pattern found |
|---|---|---|
| Shipping module | src/Entity/ShipInfo.php:1 | direct persist |"

run_hook "$SCOPE_WITH_REFS" "$MEETING_WITH_REFS"   "meeting has references and scope.md has Reference Files Read" "pass"

echo ""
echo "7. Non-discrepancies.md write - hook should be silent"
INPUT_OTHER='{"tool_name":"Write","tool_input":{"file_path":"/tmp/solutions.md","content":"x"}}'
result=$(echo "$INPUT_OTHER" | bash "$HOOK_ABS" 2>&1)
exit_code=$?
if [ $exit_code -eq 0 ]; then
    echo "  ■ PASS   non-discrepancies write is ignored"
    PASS=$((PASS+1))
else
    echo "  X WRONG  non-discrepancies write triggered block (exit=$exit_code)"
    FAIL=$((FAIL+1))
fi

echo ""
echo "---------------------------------------------------"
echo "  Passed: $PASS   Failed: $FAIL"
echo "---------------------------------------------------"
if [ $FAIL -gt 0 ]; then
    echo ""
    echo "  X Gaps found - see X lines above"
fi
echo ""

rm -rf "$TMPDIR_ROOT"
