# Sample Run

> Artifacts from a real run. Domain renamed, business rules replaced with fictional ones, source code removed.

## What this run was

A team meeting asked for an **audit log** in a back-office app: record who created, updated or deleted stores and customer groups, and every order-item status change, and show the entries in an "Audit History" panel. The task was given to Claude Code with `RUN_PROMPT.md` (...), and the framework ran Steps 1 -> 3.7 up to the implementation prompt.

Names of people, the company, its products and its domain have been replaced. The original business rules were replaced with fictional ones that keep the same structure and count, so every verdict in the analysis still follows from the rules it cites. Code blocks in `implementation-prompt.md` were replaced with one-line descriptions. Metrics (cost, time, tokens, tool calls) are unchanged.

## Files, in the order the framework produced them

| File | Step | What to look at |
|---|---|---|
| `MEETING_TRANSCRIPT.md` (...) , `MEETING_SCREEN_SUMMARY.json` (...) | input | Spoken meeting + what was on screen, by timestamp |
| `RUN_PROMPT.md` (...) | input | The task prompt given to Claude Code |
| `.claude/meeting-specs.md` (...) | 1a | Decisions, examples, flags, and the BE/FE split |
| `.claude/business-logic-extract.md` (...) | 1c | Only the domain rules that apply to this task |
| `.claude/scope.md` (...) | 1d | What already exists: MCP calls, reference files, requirement coverage, method traces |
| `.claude/discrepancies.md` (...) | 2 | COMPLIANT / DISCREPANCY / UNDOCUMENTED per requirement and constraint |
| `.claude/solutions.md` (...), `.claude/solutions-research.md` (...) | 2.3 / 2.5 | One self-selected schema solution |
| `.claude/decision-inventory.md` (...) | 3.5 | Every field, method and line number physically re-verified |
| `.claude/display-data-trace.md` (...) | 3.7 | Every meeting example traced to a stored field |
| `.claude/implementation-prompt.md` (...) | 3.7 | The hand-off prompt (code omitted) |
| `.claude/metrics/runs/` (...) | metrics | `run-report.mjs` output for the planning cycle and a later session |
| `.claude/metrics/mcp-queries.json` (...) | metrics | Every MCP retrieval call, with result counts |