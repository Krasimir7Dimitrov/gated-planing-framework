# Application - Claude Instructions

## Project Documentation

Before starting any task, read `docs/BUSINESS_LOGIC.md` - it contains the domain rules, business logic, and system overview. Always apply this knowledge when writing, reviewing, or analyzing code.

This file is loaded automatically at the start of every session. Read it before making any changes.

---

# Pre-Implementation Protocol

The checklist hook WILL block all writes until you complete 3 steps:

## Available MCP tools - use these instead of reading files directly

| Tool | When to use |
|---|---|
| `get_lessons` | ALWAYS call first at the start of every task - reads lessons_learned.md for past mistakes |
| `search_business_logic` | Search docs/BUSINESS_LOGIC.md by keyword - never read the whole file |
| `get_project_context` | Structural overview of admin or middleware (controllers, services, entities) |
| `get_entity_schema` | Parse a Doctrine entity - fields, types, relations, constants |
| `get_routes` | Symfony route table for admin/middleware |
| `search_code` | ripgrep search in source code |
| `write_lesson` | After any task with a non-trivial problem - record what was learned |

**Rule: Never read source files directly when an MCP tool can provide the same information.**

**Fallback rule: If an MCP tool returns 0 results for a file or project - do NOT conclude "not accessible". Use the `Read` tool with the absolute path directly. MCP tools are scoped to indexed projects only (admin, middleware).**
External projects (e.g. reference project at `C:\\path\\to\\sample-project`) must be read via `Read` with absolute paths or `Bash` with `find`/`ls`.

## Step 1 - Map scope

### 1a - Extract meeting documents (mandatory if present)

If `MEETING_TRANSCRIPT.md` or `MEETING_SCREEN_SUMMARY.json` exist in the project root:

Agent(
  subagent_type: "meeting-extractor",
  prompt: "Extract all specs from the meeting documents into .claude/meeting-specs.md"
)

Wait for the agent to complete before proceeding. The agent writes `.claude/meeting-specs.md`.

After the agent completes, read the `## General Rules & Architecture Decisions` section of `meeting-specs.md`, if it contains any rows:
- Call `write_lesson` for each row - one lesson per rule, including the timestamp and scope
- Then run: `echo 'processed' > .claude/meeting-rules-processed.txt`

If the section is empty or missing, skip this step entirely.

After writing lessons (or if the section is empty), read `meeting-specs.md` and add a `## Requirements by Layer` section classifying every extracted requirement as BACKEND or FRONTEND:

- **BACKEND** - affects data model, database schema, API contract, service logic, or system behavior
- **FRONTEND** - affects display format, UI labels, text shown to the user, column layout, or visual presentation

**Display language rule (mandatory - read before classifying each requirement):** If a meeting requirement uses display verbs - "show", "display", "the user sees", "visible as", "shown as", "appears as" - or describes what text or label the user reads

**Display-adjective trigger (mandatory extension):** A requirement that describes data as **human-readable**, **description**, **description text**, **in plain language**, **as a sentence**, or **formatted text** also triggers this rule.

Example: "show human-readable description like 'private.com was added'" splits into:
- **BE**: store the raw data needed to construct the description (operation type, subject ID, old value, new value)
- **FE**: display an assembled human-readable sentence per log row

A requirement classified as BE because "we need to store it" is only valid if the raw value is a primitive fact - an ID, a timestamp, a status code, a name - not a pre-assembled display string. A display sentence (or any text that would need to be assembled)

A requirement that has both aspects must be split into two rows: one BE row (what the system stores/computes) and one FE row (how it is displayed). Write directly into meeting-specs.md:

## Requirements by Layer

### Backend
| ID | Requirement | Source |
|---|---|---|
| BE-1 | [requirement text] | [timestamp] |

### Frontend
| ID | Requirement | Source |
|---|---|---|
| FE-1 | [requirement text] | [timestamp] |

**Step 2 three-way comparison uses `meeting-specs.md` as the "Meeting says:" source - not the raw transcript.**
If meeting-specs.md does not exist when you reach Step 2, spawn the meeting-extractor agent first.

### 1b - Call get_lessons first (mandatory)
Call `get_lessons` before anything else.
Read every lesson. Flag any that are relevant to the current task.

### 1c - Map business logic
For every domain concept mentioned in the meeting or task:
- Call `search_business_logic` with the relevant keyword
- Do NOT read docs/BUSINESS_LOGIC.md in full - search only

After all `search_business_logic` calls, write the relevant findings to `.claude/business-logic-extract.md` - only the domain rules and constraints that directly apply to the feature being built.

### 1d - Map codebase scope
- Call `get_project_context` for structural overview
- For every entity involved: call `get_entity_schema` instead of reading the file
- For every route involved: call `get_routes`
- For any specific code pattern or usage: call `search_code`
- Only call Read on a file if no MCP tool can provide the needed information
- Reference files listed in `meeting-specs.md` must be read with the Read tool during Step 1, before writing any data flow, hook points, or implementation notes to `scope.md`. **`scope.md` documents what EXISTS in the codebase - not what will be built.** Any architectural decision that depends on a reference implementation (e.g. Shipping module) is invalid until that reference has been read.

Write `.claude/scope.md` using the required structure below. A hook blocks writing `discrepancies.md` if any section is missing or `## Requirement Coverage` has no data rows.

# Scope - [Feature name]

## MCP Calls Made
| Tool | Input | Key findings |
|---|---|---|
| get_lessons | - | [relevant lessons flagged] |
| search_business_logic | "[keyword]" | [rules found] |
| get_entity_schema | "[Entity]" | [fields returned] |
| get_routes | - | [relevant routes] |
| search_code | "[pattern]" | [matches found] |

## Reference Files Read
| File | Path read | Key pattern found |
|---|---|---|
| [name from meeting-specs.md References] | [file:line] | [write-side pattern] |

## Requirement Coverage
| BE-ID | Requirement | Implementing code | Callers | Return value traced |
|---|---|---|---|---|
| BE-1 | [summary] | src/Service/Foo.php:45 | src/Controller/Bar.php:12 | YES |

## Method Traces
### ClassName::methodName() - src/Service/Foo.php:45
- Returns: {key1: type, key2: type}
- key1 -> passed to: [next destination]
- key2 -> unused
- Callers: src/Controller/Bar.php:12, src/Command/Baz.php:34

Rules:
- `## Reference Files Read` is required only when `meeting-specs.md ## References to Existing Functionality` has rows
- `## Requirement Coverage` must have one row per BE-* requirement - never skip one even if implementing code is missing (write "not yet implemented")
- `## Method Traces` must include every method whose return value is used downstream in the feature - trace every key, flag unused ones

## Step 2 - Systematic conflict analysis

Spawn the gap-analyzer agent. It reads meeting-specs.md (BE-* requirements only), business-logic-extract.md, scope.md, and actual source files, then writes discrepancies.md with COMPLIANT / DISCREPANCY / UNDOCUMENTED verdicts for every rule and requirement.

Agent(
  subagent_type: "gap-analyzer",
  prompt: "
    Working directory: C:/Projects/sample-application

    Read these files in order:
    1. CLAUDE.md - specifically ## Analysis principles for C1-C9 constraints
    2. .claude/meeting-specs.md - BE-* requirements and ## References to Existing Functionality
    3. .claude/business-logic-extract.md - domain rules
    4. .claude/scope.md - file:line references for existing code

    Read the actual source files referenced in scope.md before writing analysis.
    Read every file listed in meeting-specs.md ## References to Existing Functionality.

    Write: .claude/discrepancies.md
  "
)

Wait for the agent to complete before proceeding.

After the agent completes, read discrepancies.md and route each finding:
- DISCREPANCY that mentions "entity does not exist", "new entity", "migration required", "does not exist yet" -> **Step 2.3** (schema design first)
- DISCREPANCY involving Doctrine, Symfony integration, or touching more than two files -> **Step 2.5** (solution design)
- Any UNDOCUMENTED verdict -> **Step 3** (clarifying question required)

A verdict of UNDOCUMENTED is not a pass - ask the user before concluding.

## Step 2.3 - Foundational Design

Insert this step after discrepancies.md is complete and before Step 2.5.

**Mandatory trigger** - Step 2.3 is required when discrepancies.md contains any new entity, table, or API contract to be created (keywords: "entity does not exist", "new entity", "migration required", "does not exist yet").

For each new entity/table: add `## Solution: [EntityName] Schema Design` as the **first** entry in solutions.md, before any mechanism Solutions.

## Solution: [EntityName] Schema Design

### Draft (Claude)
**Constraint:** Each column must store exactly one piece of information (C9). Define all fields - name, PHP type, column type, nullable - before any mechanism Solution references them.
**Extensibility assessment:** NO - schema is a one-time structural decision.
**Naive approach:** [list all fields and their types]
**Evidence checklist:**
- Every aspect of the naive approach has a specific file:line citation: YES / NO
- The citations cover ALL fields and behaviors - not just part of the constraint: YES / NO
- No aspect relies on general framework knowledge without project-specific proof: YES / NO
**Self-select:** YES (all three YES) / NO (any NO -> spawn researcher)
**Options:**
- A: [schema option A] - pros/cons
- B: [schema option B] - pros/cons
**Reference field coverage:** (mandatory when scope.md documents a reference entity with named fields)
| Reference field | Decision | Excluded because |
|---|---|---|
| [field] | INCLUDE as `[local field name]` | - |
| [field] | EXCLUDE | [meeting timestamp]: "[exact quote]" |
**Project files relevant to this constraint:** [entity files from the same bundle, migration examples, reference entity schemas from reference project if relevant]

**Ordering rule:** schema Solutions are evaluated (Step 2.5c) first. A mechanism Solution draft that names a specific column or field not yet defined in a Schema Solution is invalid - return it to Step 2.3.

**New API endpoint:** document the response contract (fields, types, format) as `## Solution: [Endpoint] API Contract` before any controller Solution.

## Step 2.5 - Solution Design Review

Insert this step after discrepancies.md is complete and before Step 3.

**Mandatory triggers - Step 2.5 is required when any discrepancy or requirement involves:**
- Performance or DB efficiency ("efficient", "no extra", "minimal", "round-trip", "connection")
- Any new Doctrine operation (persist, flush, event, subscriber, computeChangeSet)
- Any new Symfony integration (service, listener, event subscriber, controller)
- Any architectural decision that touches more than two files

If none of the above apply, skip to Step 3.

### 2.5a - Draft

**Step 1 - Write problem statements FIRST (before any naive approach)**

For every triggered decision, write `.claude/research-problems.md` with one entry per decision:

## Problem: [short name matching the ## Solution: title that will be created]

[2-4 sentences in plain language describing what outcome is needed and what constraints it operates under.
Rules:
- No class names, method names, or interface names
- No PHP syntax ($, ->, ::, ())
- No framework-specific constructs (do not name EventDispatcher, EntityManager, Listener, Subscriber, etc.)
- No pattern names (do not write "event-based", "observer pattern", "pub/sub", "decoupled via events")
- Describe WHAT must happen, not HOW]

**Self-check before writing each Problem entry (mandatory):**
Read your draft and ask: *"Would a developer who has never used Symfony or Doctrine understand what business outcome is needed from this description?"*
- If YES - write it.
- If NO, or if the description names a mechanism (event, listener, dispatcher, decouple, subscribe, observer) - rewrite it until the answer is YES.

A hook checks this file after every write - it will block if it contains PHP syntax, class names, or pattern-hint language.

**Step 2 - Assess extensibility, then write solutions.md**

**Before writing any option, assess extensibility:**
Some feature domains are inherently likely to grow - new operations added, new entity types tracked, new rules enforced. If the feature belongs to one of these domains, extensibility is an implicit constraint even if the meeting did not state it:
- Logging / audit / history systems
- Status machines and workflow engines
- CRUD operation sets (if 5 operations are logged today, a 6th will come)
- Event tracking and notification systems
- Any feature where the meeting says "these specific X things" - because X will grow

**Two files are used for solution design. Keep them strictly separate:**

| File | Owner | Contents | Evaluator sees it? |
|---|---|---|---|
| `.claude/solutions.md` | Claude | Draft, Options, Evidence checklist, Project files | **NO** |
| `.claude/solutions-research.md` | Researcher + Evaluator | Research findings, Pre-eval context, Evaluation | YES |

For each triggered decision, write an entry in `.claude/solutions.md`:

## Solution: [Problem name]

### Draft (Claude)
**Constraint:** [exact constraint text from discrepancies.md - include extensibility if domain qualifies]
**Extensibility assessment:** [Is this domain inherently extensible? YES/NO - one sentence why]
**Naive approach:** [first solution that comes to mind]
**Evidence checklist:**
- Every aspect of the naive approach has a specific file:line citation: YES / NO
- The citations cover ALL fields and behaviors - not just part of the constraint: YES / NO
- No aspect relies on general framework knowledge without project-specific proof: YES / NO
**Self-select:** YES (all three YES) / NO (any NO -> spawn researcher)
**Options:**
- A: [description] - pros/cons
- B: [description] - pros/cons
**Project files relevant to this constraint:** [list every file:line from scope.md the evaluator must read - services, entities, controllers, config directly involved in this decision]

Immediately after writing solutions.md, create the matching skeleton in `.claude/solutions-research.md`:

## Solution: [same Problem name as in solutions.md]

### Research (Agent)
[PENDING - spawn solution-researcher agent]

**Evidence checklist rules:**
- Answer each checklist question as YES or NO - no partial answers, no percentages.
- If ALL three are YES -> **self-select**: skip researcher and evaluator agent, write evaluation directly (Step 2.5c self-select path).
- If ANY is NO -> **spawn researcher** (Step 2.5b) - mandatory, no exceptions.
- If `Constraint check` is NO -> Decision must be `Unresolved -> Q[n]`. Hook blocks anything else.
- If evaluator confidence is insufficient after research -> set Decision to `Unresolved -> Q[n]` and add question in Step 3.
- **Self-contradiction check (mandatory before answering checklist):** Read every component of `**Constraint:**` and check each one against your naive approach. If your own `**Options:**` -> Cons for the naive approach document a violation of ANY constraint component -> this solution violates the constraint.
- **Meeting reference check (mandatory before answering checklist):** Before answering YES to all three, read `meeting-specs.md ## References to Existing Functionality`. If any row is relevant to this solution's domain -> item 3 is automatically NO. A meeting reference means the user has explicitly pointed to an existing implementation to follow - verifying against it requires the evaluator agent. You cannot self-select when the meeting has named a reference.
Hook blocks SELF-SELECTED solutions where Pre-evaluation Context contains an implementation reference.

### 2.5b - Research (only for solutions where Self-select: NO)

For each solution in solutions.md where `**Self-select:**` is **NO**, spawn the researcher agent.
Solutions where `**Self-select:**` is YES skip the researcher entirely.

Spawn all required agents in a single message (parallel):

Agent(
  subagent_type: "solution-researcher",
  prompt: "
    Solution: [exact ## Solution: title from solutions.md]
    Problem: [paste the exact ## Problem: text from .claude/research-problems.md for this solution - verbatim, do not modify a single word]
    Extensibility: [YES - domain is inherently extensible, prefer automatic/decoupled patterns | NO]
    Technology: Symfony 5, Doctrine ORM, PHP 8.1
    Write your findings to: .claude/solutions-research.md under the matching ## Solution: header, replacing [PENDING]
  "
)

Wait for all agents to complete before proceeding to 2.5c.

After all researchers complete, scan every `### Research (Agent)` section in `solutions-research.md` for `**Design questions flagged:**` entries. For each `DQ[n]` found, add it to Step 3 as a clarifying question in the required Q&A format - these are mandatory.

### 2.5c - Evaluate (only for solutions where Self-select: NO)

**Solutions where `Self-select: YES`:** Claude writes the evaluation directly to `solutions-research.md` - no evaluator agent needed. Append after the Research section:

### Pre-evaluation Context (Evaluator)
**Meeting constraints found:** N/A - self-selected, evaluator agent not spawned
**Business logic rules found:** N/A - self-selected, evaluator agent not spawned
**Reference files searched:** N/A - self-selected, evaluator agent not spawned

### Evaluation
**Constraint check:** YES - [exact file:line citation from Draft in solutions.md]
**Decision:** [option] - [one sentence]
**Reasoning:** [why the citation proves this option satisfies the constraint]
**Confidence after research:** self-selected - all checklist items YES, citation sufficient
**Evaluator verdict:** SELF-SELECTED [naive approach | researcher finding] - [file:line]

**Solutions where `Self-select: NO`:** spawn one constraint-evaluator agent per solution. Spawn all in a single message (parallel):

Agent(
  subagent_type: "constraint-evaluator",
  prompt: "
    Solution: [exact ## Solution: title]
    Constraint: [exact constraint text from solutions.md Draft]
    Approaches found by researcher: [full **Approaches found:** section from solutions-research.md Research section - all approaches, not a summary]
    Technology: Symfony 5, Doctrine ORM, PHP 8.1

    Pre-extracted context (read these before deciding):
    - .claude/meeting-specs.md - meeting requirements and rules
    - .claude/business-logic-extract.md - relevant business logic for this task

    Project files to read independently (read ALL of these before deciding):
    [paste the full **Project files relevant to this constraint:** list from solutions.md Draft]

    Reference projects (read write-side implementation in each before deciding):
    - C:\\path\\to\\sample-project
    [include ALL entries from meeting-specs.md ## References to Existing Functionality]

    Write your findings to: .claude/solutions-research.md under the matching ## Solution: header.
    Append these three sections after the existing Research section:

    ### Pre-evaluation Context (Evaluator)
    **Meeting constraints found:** [cite BACKEND BE-* IDs only - no FE-* IDs]
    **Business logic rules found:** [exact relevant output, or 'none relevant']
    **Reference files searched:** [each reference project path + what write-side pattern was found; if reference mentions UI/frontend, also list the frontend source files read and what display pattern was found]
    **Reference field coverage:** (Schema Design solutions only) table - for each field in the reference entity: INCLUDE as `[local name]` or EXCLUDE with meeting quote; write N/A for non-schema solutions

    ### Architecture Quality Check
    **Solution type:** [Backend / Frontend / Full-stack / Trivial]
    [B1-B6 for Backend/Full-stack; F1-F5 for Frontend/Full-stack; omit irrelevant sets]
    [Each question answered per approach - one paragraph per approach, then a winner line]
    [AQC comparison table at the end - leading approach determined from the table, not from prior intuition]
    **Quality verdict:** PASS / CONCERNS
    **Impact on decision:** [only if CONCERNS - list each X/A and its effect]

    ### Evaluation v2
    **Reference project searched:** [terms used] / N/A
    **Reference project result:** [file:line] / not present
    **Self-check leading (approach name):** depth YES/NO | limits YES/NO | stack YES/NO | compare YES/NO
    **Self-check non-leading (approach name):** depth YES/NO | limits YES/NO | stack YES/NO | compare YES/NO
    **Refinement decision:** Not triggered - [why] / Triggered (1A/B3) -> REFINEMENT_REQUESTED / Skipped: [reason]
    **Prototype decision:** Not triggered - [why] / Triggered (1B1/B3/B4) -> PROTOTYPE_REQUESTED
    **Constraint check:** YES / NO
    **Decision:** ...
    **Reasoning:** ...
    **Confidence after research:** ...%
    **Evaluator verdict:** AUTO-SELECTED [option] | UNRESOLVED | REFINEMENT_REQUESTED | PROTOTYPE_REQUESTED

    RULES:
    - Do NOT read solutions.md - Claude's draft analysis must not influence your decision
    - Read the listed project files and reference projects directly and independently
    - Base your decision solely on code evidence and the researcher findings
    - For each reference project: search specifically for the WRITE-SIDE implementation
    - For Schema Design solutions: read ALL fields of the reference entity file (not just the field matching the naive approach) - document every field in reference field coverage or list in excluded
    - When a reference project is listed and meeting-specs.md references UI/frontend files: read the frontend source files and document what display pattern was found in reference field coverage
    - A decision made without reading the listed project files is invalid

    Wait for all agents to complete. The evaluator writes directly to `solutions-research.md`.

    **Claude does not fill in the Evaluation section for < 90% solutions. The evaluator does.**

    The only outcomes are:
    - **Evaluator verdict:** AUTO-SELECTED [option] - decision made automatically from code evidence, no action needed from Claude
    - **Evaluator verdict:** UNRESOLVED - evaluator could not decide; Decision is 'Unresolved -> Q[n]'; Claude must add that question to Step 3
    - **Evaluator verdict:** REFINEMENT_REQUESTED - research exists but one approach is superficially covered; evaluator needs deeper findings before it can decide; trigger the refinement pass below
    - **Evaluator verdict:** PROTOTYPE_REQUESTED - even with research, AQC B1/B3/B4 questions cannot be answered without seeing actual code structure; trigger the prototype pass below
  "
)

### Refinement pass (only if REFINEMENT_REQUESTED verdicts exist)

After the first evaluator pass, scan `solutions-research.md` for `**Evaluator verdict:** REFINEMENT_REQUESTED`. For each, the evaluator has already appended a `### Research v2 ([PENDING])` block. Spawn researcher v2 agents (single parallel message):

Agent(
  subagent_type: "solution-researcher",
  prompt: "
    Solution: [exact ## Solution: title]
    Problem: [paste exact ## Problem: text from .claude/research-problems.md - verbatim]
    Refinement query: [exact **Refinement query:** text from the evaluator's REFINEMENT_REQUESTED block]
    Refinement target: [exact **Refinement target:** text from the evaluator's REFINEMENT_REQUESTED block]
    Extensibility: [YES/NO - same as first pass]
    Technology: Symfony 5, Doctrine ORM, PHP 8.1
    Write to: .claude/solutions-research.md - ### Research v2 (Agent) block, replacing [PENDING].
  "
)

Wait for all v2 researchers to complete. Then re-spawn constraint-evaluator for each refined solution (single parallel message):

Agent(
  subagent_type: "constraint-evaluator",
  prompt: "
    Solution: [exact ## Solution: title]
    Constraint: [exact constraint text from solutions.md Draft]
    Approaches found by researcher: [full **Approaches found:** from ### Research (Agent) AND full content of ### Research v2 (Agent) - combine both]
    Technology: Symfony 5, Doctrine ORM, PHP 8.1

    Pre-extracted context (read these before deciding):
    - .claude/meeting-specs.md - meeting requirements and rules
    - .claude/business-logic-extract.md - relevant business logic for this task

    Project files to read independently (read ALL of these before deciding):
    [paste the full **Project files relevant to this constraint:** list from solutions.md Draft]

    Reference projects (read write-side implementation in each before deciding):
    - C:\\path\\to\\sample-project
    [include ALL entries from meeting-specs.md ## References to Existing Functionality]

    Write your findings to: .claude/solutions-research.md under the matching ## Solution: header.
    Append after the existing ### Research v2 (Agent) block:

    ### Architecture Quality Check
    **Solution type:** [Backend / Frontend / Full-stack / Trivial]
    [B1-B6 for Backend/Full-stack; F1-F5 for Frontend/Full-stack; omit irrelevant sets]
    [Each question answered per approach - one paragraph per approach, then a winner line]
    [AQC comparison table at the end - leading approach determined from the table, not from prior intuition]
    **Quality verdict:** PASS / CONCERNS
    **Impact on decision:** [only if CONCERNS - list each X/A and its effect]

    ### Evaluation v2
    **Reference project searched:** [terms used] / N/A
    **Reference project result:** [file:line] / not present
    **Self-check leading (approach name):** depth YES/NO | limits YES/NO | stack YES/NO | compare YES/NO
    **Self-check non-leading (approach name):** depth YES/NO | limits YES/NO | stack YES/NO | compare YES/NO
    **Refinement decision:** Not triggered - [why] / Triggered (1A/B3) - skipped: v2 exists
    **Prototype decision:** Not triggered - [why] / Triggered (1B1/B3/B4) -> PROTOTYPE_REQUESTED
    **Constraint check:** YES / NO
    **Decision:** ...
    **Reasoning:** ...
    **Confidence after research:** ...%
    **Evaluator verdict:** AUTO-SELECTED [option] | UNRESOLVED | PROTOTYPE_REQUESTED

    RULES:
    - This is a second-pass evaluation. REFINEMENT_REQUESTED is NOT a valid outcome here - decide or UNRESOLVED.
    - Read both ### Research (Agent) and ### Research v2 (Agent) before deciding
    - Do NOT read solutions.md
    - All other rules from the first-pass evaluator apply
  "
)

Wait for all v2 evaluators to complete. They write `### Evaluation v2` sections.

### Prototype pass (only if PROTOTYPE_REQUESTED verdicts exist)

Scan `solutions-research.md` for `**Evaluator verdict:** PROTOTYPE_REQUESTED` - this may appear in `### Evaluation` (first pass) or `### Evaluation v2` (after refinement). For each:

1. Read the `**Prototype approaches:**` list and `**Prototype context files:**` from the `PROTOTYPE_REQUESTED` block.
2. For EACH approach - spawn prototypers **sequentially** (one at a time, wait for each before spawning the next):

Agent(
  subagent_type: "solution-prototyper",
  worktree: "...",
  prompt: "
    Solution: [exact ## Solution: title]
    Approach name: [approach name from Prototype approaches list]
    Skeleton description: [the one-sentence skeleton description from Prototype approaches list]
    Constraint: [exact constraint text from solutions.md Draft]
    Context files: [paste the full Prototype context files list]
    Technology: Symfony 5, Doctrine ORM, PHP 8.1
  "
)

After each prototyper completes:
- Read the agent result - it contains a `### Files written:` section with absolute paths
- Read each listed file using the Read tool
- Store the file path + content (you will pass this to the evaluator)
- The worktree stays alive until you clean it up - do NOT delete it yet

3. After ALL approaches for this solution are prototyped and their files are read, clean up the worktrees (they are temporary - run `git worktree remove --force [worktree path]` for each)

4. Spawn the evaluator with the prototype code:

Agent(
  subagent_type: "constraint-evaluator",
  prompt: "
    Solution: [exact ## Solution: title]
    Constraint: [exact constraint text from solutions.md Draft]
    Approaches found by researcher: [full **Approaches found:** from ### Research (Agent) - and ### Research v2 if present]
    Technology: Symfony 5, Doctrine ORM, PHP 8.1

    Pre-extracted context (read these before deciding):
    - .claude/meeting-specs.md - meeting requirements and rules
    - .claude/business-logic-extract.md - relevant business logic for this task

    Project files to read independently (read ALL of these before deciding):
    [paste the full **Project files relevant to this constraint:** list from solutions.md Draft]

    Reference projects (read write-side implementation in each before deciding):
    - C:\\path\\to\\sample-project
    [include ALL entries from meeting-specs.md ## References to Existing Functionality]

    PROTOTYPE CODE - read and use this as the primary evidence for AQC questions:

    ### Approach A: [approach name]
    [for each file written by prototyper A - paste: file path, then full file content]

    ### Approach B: [approach name]
    [for each file written by prototyper B - paste: file path, then full file content]

    Write your findings to: .claude/solutions-research.md under the matching ## Solution: header.
    Replace the [PENDING] in ### Prototype Evaluation with:

    ### Prototype Evaluation

    **Prototype approaches compared:**
    - A: [approach name] - [files given]
    - B: [approach name] - [files given]

    ### Architecture Quality Check (code-based)
    **Solution type:** [Backend / Frontend / Full-stack]
    [Answer B1-B6 / F1-F5 citing specific class names, constructors, and wiring from the prototype code]
    **Quality verdict:** PASS / CONCERNS
    **Impact on decision:** [only if CONCERNS]

    **Self-check leading (approach name):** N/A - code-based evaluation
    **Self-check non-leading (approach name):** N/A - code-based evaluation
    **Refinement decision:** Not applicable - this is Prototype Evaluation
    **Prototype decision:** Not triggered - this is Prototype Evaluation
    **Constraint check:** YES / NO
    **Decision:** ...
    **Reasoning:** [cite specific structural patterns from the prototype code]
    **Confidence after research:** ...%
    **Evaluator verdict:** AUTO-SELECTED [option] | UNRESOLVED

    RULES:
    - PROTOTYPE_REQUESTED is NOT valid here - decide or UNRESOLVED
    - REFINEMENT_REQUESTED is NOT valid here - decide or UNRESOLVED
    - Answer AQC questions by referencing actual class names, constructors, and structural patterns in the given code - not documentation
    - Requirement ambiguity -> UNRESOLVED (a prototype cannot answer 'what does the user want?')
    - Do NOT read solutions.md
    - All other evaluator rules apply
  "
)

Wait for all prototype evaluators to complete. They write `### Prototype Evaluation` sections.

After all evaluators, self-selections, refinement passes, and prototype passes are complete, mark the step complete:

```bash
echo 'reviewed' > .claude/solutions-reviewed.txt