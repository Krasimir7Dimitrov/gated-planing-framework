TASK: Add an Audit Log feature to the Back Office, modeled on the
existing reference-app product history: log create/update/delete of shops
(stores), customer groups (including importing external groups), and updates
to an order item's status - only after the database write is
confirmed, not speculatively before it. Expose it in the frontend as a
button next to "Extend all" that opens a panel showing a human-readable
description, the date, and the user who made the change, matching the
reference-app UI pattern.

The meeting documents are in the project root:
- MEETING_TRANSCRIPT.md
- MEETING_SCREEN_SUMMARY.json

Execute the Pre-Implementation Protocol defined in CLAUDE.md in full, from
Step 1 onwards. Do not skip steps and do not collapse them. Wait for each
agent to complete before proceeding to the next step.

STEP 1 - MAP SCOPE
1a. Spawn the meeting-extractor agent to produce .claude/meeting-specs.md.
    After it completes, write a lesson for every row in
    "## General Rules & Architecture Decisions", then add a
    "## Requirements by Layer" section classifying every requirement as
    BACKEND (BE-*) or FRONTEND (FE-*).
    Apply the display-language rule strictly: anything described with
    "show", "display", "the user sees", "human-readable", "description",
    or "as a sentence" is FRONTEND. Split mixed requirements into one BE
    row (raw primitives stored) and one FE row (assembled display string).

1b. Call get_lessons FIRST, before anything else. Read every lesson and
    flag the ones relevant to this task. Then call search_business_logic
    for every domain concept named in the meeting. Never read
    docs/BUSINESS_LOGIC.md in full. Write the applicable rules to
    .claude/business-logic-extract.md.

1c. Map what EXISTS in the codebase using the MCP tools -
    get_project_context, get_entity_schema, get_routes, search_code.
    Use the Read tool only where no MCP tool can answer. Read every file
    listed under "## References to Existing Functionality" in
    meeting-specs.md before writing anything.
    Write .claude/scope.md with all four required sections, one
    Requirement Coverage row per BE-* requirement - including the ones
    with no implementing code, marked "not yet implemented".

STEP 2 - GAP ANALYSIS
Spawn the gap-analyzer agent. It compares BE-* requirements and domain
rules against the actual source files and writes .claude/discrepancies.md
with a COMPLIANT / DISCREPANCY / UNDOCUMENTED verdict for each.
Route every finding: new entity or table goes to Step 2.3; anything
touching Doctrine, Symfony wiring, or more than two files goes to
Step 2.5; every UNDOCUMENTED verdict becomes a Step 3 question.
UNDOCUMENTED is not a pass.

STEP 2.3 - FOUNDATIONAL DESIGN (only if a new entity, table, or endpoint)
Add the Schema Design Solution as the FIRST entry in solutions.md, before
any mechanism Solution. Define every field: name, PHP type, column type,
nullability, and the C9 check. Where a reference entity exists, complete
the Reference field coverage table - every field marked INCLUDE or
EXCLUDE, and every EXCLUDE justified with a verbatim meeting quote.
A Solution that names a column not yet defined by a Schema Solution is
invalid.

STEP 2.5 - SOLUTION DESIGN REVIEW
Write .claude/research-problems.md first, before any naive approach.
State each problem in plain language: no class names, no PHP syntax, no
framework constructs, no pattern names. Describe the outcome required,
not the mechanism.

Then write .claude/solutions.md. For each Solution, assess extensibility
explicitly - logging, audit, status machines, and CRUD operation sets are
inherently extensible, so "must be extendable without modifying existing
service code" becomes part of the constraint even if the meeting did not
say it.

Answer the evidence checklist honestly. If your own Cons contradict any
part of the constraint, the checklist item is NO regardless of citations.
If the meeting named a reference implementation, item 3 is automatically
NO. Self-select only when all three are YES.

Spawn solution-researcher agents in parallel for every Solution where
Self-select is NO, passing the problem statement verbatim. Then spawn
constraint-evaluator agents in parallel. The evaluators must not read
solutions.md. Handle REFINEMENT_REQUESTED and PROTOTYPE_REQUESTED
verdicts as specified - each at most once per Solution.

Finish with the Post-Evaluation Impact Review and the Architecture
Decisions table.

STEP 3 - CLARIFYING QUESTIONS
Re-read scope.md before forming each question; if the answer is already
documented there, it is not a question.
Ask every question whose answer materially changes the implementation -
do not limit the count artificially. For each question you decide not to
ask, state it and explain why it does not affect the output.
Use the required format: Rule / Current code (file:line) / Options with
consequences / the option you lean toward and why.
After the answers, call write_lesson for anything that generalises beyond
this task.

STEP 3.5 - DECISION INVENTORY
Spawn the decision-verifier agent. Every entity field must trace to its
Schema Design Solution, every method call must be verified at a real
file:line, all of C1-C9 must appear explicitly, and the frontend
framework must be confirmed against an actual source file - not assumed
from scope.md. Anything unverifiable becomes a new Step 3 question.

STEP 3.7 - DISPLAY DATA TRACE AND PROMPT
Spawn the prompt-writer agent. It traces every meeting example sentence
to an entity field available at its dispatch point. If any verdict is
MISSING, it stops and reports a Step 3 question instead of writing the
prompt.

RULES FOR THE WHOLE RUN
- Prefer MCP tools over reading files directly. If an MCP tool returns
  zero results for an indexed project, that is a real "not found"; for an
  external project it means unindexed - use Read with the absolute path.
- Make no decision without code evidence. A citation is file:line.
- Never write TBD, TODO, "confirm with user", or any placeholder into
  implementation-prompt.md. Stop and ask instead.
- When evidence is insufficient, escalate to a Step 3 question. Do not
  guess, and do not fill a gap with a plausible default.
- Report honestly if a step cannot be completed, and say which one.

Present the finished implementation prompt and wait for my explicit
approval. Write no production code before that approval.