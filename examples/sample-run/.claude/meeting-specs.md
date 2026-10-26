# Meeting Specs \- Audit Log Feature

## Decisions

- **\[00:45\]**  
  - Decision: Build an Audit History feature in the Back Office modeled on the existing reference-app product history \[cite: 39\]  
  - Screen context: reference-app (Demo Lamp) tab switched to, product history modal open showing rows with date, user, and text \[cite: 39\]  
- **\[01:01\]**  
  - Decision: Log entries must be human-readable — understandable to an ordinary user, not in technical codes \[cite: 39\]  
  - Screen context: reference-app history modal open; presenter highlights specific log text rows ("discount-10 was added", "was deleted") \[cite: 39\]  
- **\[01:46\]**  
  - Decision: Log only specific, explicitly defined operations — NOT every user action \[cite: 39\]  
  - Screen context: Back Office order-detail sidebar open (Order, Status, Type, Date, User fields visible) \[cite: 39\]  
- **\[02:10\]**  
  - Decision: Log order item status updates on orders — both order-level and per-item status changes \[cite: 39\]  
  - Screen context: Back Office order-detail sidebar; Cancel and Restore buttons visible; status cycling between "pending" and "cancelled" \[cite: 39\]  
- **\[02:46\]**  
  - Decision: Log customer group creation \[cite: 39\]  
  - Screen context: Back Office Customer Groups section; Create Customer Group modal open with name field and member list \[cite: 39\]  
- **\[02:46\]**  
  - Decision: Log importing external groups (separate from standard group creation) \[cite: 39\]  
  - Screen context: Back Office Customer Groups modal still open \[cite: 39\]  
- **\[03:11\]**  
  - Decision: Log customer group updates (example: order type change) \[cite: 39\]  
  - Screen context: Back Office Customer Groups modal; Order Type checkboxes (Retail, Wholesale, Retail & Wholesale) hovered \[cite: 39, 41\]  
- **\[03:11\]**  
  - Decision: Log customer group deletion \[cite: 39\]  
  - Screen context: Back Office Customer Groups section \[cite: 39\]  
- **\[03:30\]**  
  - Decision: Log shop/store creation \[cite: 39\]  
  - Screen context: Back Office Shops section; Create Shop modal open with one text field and Cancel/Save buttons \[cite: 39\]  
- **\[03:30\]**  
  - Decision: Log shop/store deletion \[cite: 39\]  
  - Screen context: Back Office Shops section; Create Shop modal visible as context \[cite: 39\]  
- **\[03:30\]**  
  - Decision: Log shop/store updates \[cite: 39\]  
  - Screen context: Back Office Shops section \[cite: 39\]  
- **\[03:51\]**  
  - Decision: Log entry must be written only after the database write is confirmed — not speculatively before \[cite: 39\]  
  - Screen context: Static orders table view (no modal open; backend logic being discussed) \[cite: 39\]

## Format Specifications

- **\[01:01\]**  
  - Format / Label / Example: Human-readable log text format — "discount-10 was added", "was deleted" \[cite: 39\]  
  - Screen context: reference-app history modal; presenter selects these text strings on screen to demonstrate the expected format \[cite: 39\]  
- **\[01:01\]**  
  - Format / Label / Example: Order item status example: "the status of an item on some order was updated, and, say, the status changed from 'on hold' to 'pending' or something like that" \[cite: 40\]  
  - Screen context: reference-app history modal; spoken while pointing at the format of existing entries \[cite: 40\]  
- **\[05:23\]**  
  - Format / Label / Example: Each log entry shows three pieces of information: human-readable description of what happened, the date, and the user who made the change \[cite: 40\]  
  - Screen context: reference-app product history modal re-opened; cursor hovering over "Extend all" area in upper right of log table \[cite: 40\]  
- **\[05:23\]**  
  - Format / Label / Example: The middle column/field visible in reference-app's history panel is excluded from the Back Office — "the middle field here doesn't concern us, because it's specific to reference-app" \[cite: 40\]  
  - Screen context: reference-app history modal; all three columns visible on screen \[cite: 40\]

## Constraints

- **\[01:46\]**  
  - Constraint: Log only the specific listed operations — not every user action \[cite: 40\]  
  - Screen context: Back Office order-detail sidebar open \[cite: 40\]  
- **\[03:51\]**  
  - Constraint: Log must be written ONLY after it is certain the database record was created, updated, or deleted — "the log has to happen on a clear manipulation in the database, not log something in advance and then it's not clear whether something will go wrong and it won't reach the database" \[cite: 40\]  
  - Screen context: Static orders table; no modal open \[cite: 40\]  
- **\[04:38\]**  
  - Constraint: Avoid unnecessary extra database connections — no excessive opening and closing of connections — "we have to avoid unnecessary connections to the database, constant opening and closing of connections" \[cite: 40\]  
  - Screen context: Static orders table; backend/Doctrine discussion \[cite: 40\]

## UI Requirements

- **\[05:23\]**  
  - Requirement: Add a new small button to the right of the existing "Extend all" button — "next to 'extend all', on the right side, one small button just like this one needs to be added" \[cite: 40\]  
  - Screen context: reference-app product history modal; cursor hovering over "Extend all" text/button in upper right corner of log table \[cite: 40\]  
- **\[05:23\]**  
  - Requirement: Clicking the button opens a panel/window — same behavior as the reference-app "Product history" button \[cite: 40\]  
  - Screen context: reference-app product history modal open as the visual reference \[cite: 40\]  
- **\[05:23\]**  
  - Requirement: The panel displays: (1) human-readable description of the action, (2) date, (3) user who made the change \[cite: 40, 41\]  
  - Screen context: reference-app history panel columns visible \[cite: 41\]  
- **\[05:23\]**  
  - Requirement: The middle column present in reference-app's history panel is NOT included in the Back Office audit panel \[cite: 41\]  
  - Screen context: reference-app history panel with all three columns visible on screen \[cite: 41\]  
- **\[05:23\]**  
  - Requirement: Follow the reference-app UI design as the standard — "in general this has to be followed as the standard in the frontend" \[cite: 41\]  
  - Screen context: reference-app history modal is the reference template \[cite: 41\]

## Explicit Examples

- **\[01:01\]**  
  - Example: "discount-10 was added" — exact wording of a human-readable log entry (shown in reference-app) \[cite: 41\]  
  - Screen context: reference-app history modal; presenter highlights this text on screen \[cite: 41\]  
- **\[01:01\]**  
  - Example: "was deleted" — example of a deletion log entry wording (shown in reference-app) \[cite: 41, 42\]  
  - Screen context: reference-app history modal; presenter highlights this text \[cite: 42\]  
- **\[01:01\]**  
  - Example: "the status of an item on some order was updated, and, say, the status changed from 'on hold' to 'pending' or something like that" — spoken example of what an order item status log entry should say \[cite: 42\]  
  - Screen context: reference-app history modal; spoken as the most complex expected log entry \[cite: 42\]  
- **\[02:10\]**  
  - Example: Status changed from "pending" to "cancelled" — demonstrated live by clicking Cancel \[cite: 42\]  
  - Screen context: Back Office order-detail sidebar; Cancel button clicked, status visibly changed \[cite: 42\]  
- **\[02:10\]**  
  - Example: Status changed from "cancelled" back to "pending" — demonstrated live by clicking Restore \[cite: 42\]  
  - Screen context: Back Office order-detail sidebar; Restore button clicked immediately after \[cite: 42\]  
- **\[03:11\]**  
  - Example: Group update example: order type changed from "retail" to "retail and wholesale" (Retail & Wholesale) — "if we change, for example, the order type here from retail... to retail and wholesale" \[cite: 42\]  
  - Screen context: Back Office Customer Groups modal; Order Type checkboxes (Retail, Wholesale, Retail & Wholesale) visible \[cite: 42\]

## References to Existing Functionality

- **\[00:45\]**  
  - Reference: reference-app product history UI (Demo Lamp tab) — reference for the panel layout, button placement, and log entry format \[cite: 42\]  
  - What to look at: reference-app frontend: the "Product history" button and the modal it opens; columns: description, date, user \[cite: 42\]  
- **\[05:05\]**  
  - Reference: reference-app backend logging pattern — "we should look at reference-app for roughly the logging principle. So the code there needs to be reviewed" — must review reference-app source code before implementing \[cite: 42\]  
  - What to look at: reference-app backend codebase (`../reference-app`); write-side log implementation \[cite: 42\]

## Flags — Ambiguous or Contradictory

- **\[01:01\]**  
  - Issue: "they have to be understandable to an ordinary user, meaning in plain language" — log entries must be in human-readable language \[cite: 42\]  
  - Why flagged: Needs BE/FE split: describes display text format, not raw storage. BE stores raw primitives (operation type, entity ID, old value, new value); FE assembles the human-readable sentence \[cite: 42\]  
- **\[01:01\]**  
  - Issue: "the status of an item on some order was updated, and, say, the status changed from 'on hold' to 'pending' or something like that" — spoken as the expected log description text \[cite: 42, 43\]  
  - Why flagged: Needs BE/FE split: describes display text format, not raw storage. This is the assembled sentence the user sees — BE must store old/new status values and operation type; FE constructs the sentence \[cite: 43\]  
- **\[02:10\]**  
  - Issue: "both the order status and the status of that specific item will change" — two statuses mentioned: an order-level one and a per-item one \[cite: 43\]  
  - Why flagged: Vague: the distinction between the "order" status and the "item" status is not explained further. It is unclear whether both must be logged as separate entries or as one combined entry \[cite: 43\]  
- **\[03:11\]**  
  - Issue: "updating a group" — group update must be logged \[cite: 43\]  
  - Why flagged: Vague: only the order type change was demonstrated on screen. It is not stated whether all group fields (name, members, etc.) trigger a log entry or only the order type field \[cite: 43\]  
- **\[05:23\]**  
  - Issue: "the middle field here doesn't concern us, because it's specific to reference-app" — the middle field of reference-app's history panel is excluded \[cite: 43\]  
  - Why flagged: Vague: the exact name or content of the excluded "middle field" is not stated. Requires inspecting the reference-app source to identify which column to omit \[cite: 43\]

## General Rules & Architecture Decisions

- **\[03:51\]**  
  - Rule / Principle: Log entries must always be written after confirmed database persistence — never speculatively before the write is committed. "The log has to happen on a clear manipulation in the database, not log something in advance and then it's not clear whether something will go wrong and it won't reach the database" \[cite: 43\]  
  - Scope: Any logging, audit trail, or history feature in the primary or secondary project \[cite: 43\]  
- **\[04:38\]**  
  - Rule / Principle: When implementing logging with Doctrine, use Doctrine's own features and avoid extra unnecessary database connections (no repeated open/close of connections) \[cite: 44\]  
  - Scope: Any Doctrine-based logging or audit system in the primary or secondary project \[cite: 44\]  
- **\[05:05\]**  
  - Rule / Principle: Before implementing any logging/history feature, review the reference-app reference implementation and follow its pattern \[cite: 44\]  
  - Scope: Logging, history, and audit features across the primary project; reference project: `../reference-app` \[cite: 44\]

## Requirements by Layer

### Backend

- **BE-1**  
  - Requirement: Log shop/store creation — store operation type, entity reference, and relevant field values \[cite: 44\]  
  - Source: \[03:30\] \[cite: 44\]  
- **BE-2**  
  - Requirement: Log shop/store update — store operation type, entity reference, old value, new value \[cite: 44\]  
  - Source: \[03:30\] \[cite: 44\]  
- **BE-3**  
  - Requirement: Log shop/store deletion — store operation type and entity reference \[cite: 44\]  
  - Source: \[03:30\] \[cite: 44\]  
- **BE-4**  
  - Requirement: Log customer group creation — store operation type, entity reference, and relevant field values \[cite: 44\]  
  - Source: \[02:46\] \[cite: 44\]  
- **BE-5**  
  - Requirement: Log customer group update (e.g. order type change) — store operation type, entity reference, old value, new value \[cite: 44\]  
  - Source: \[03:11\] \[cite: 44\]  
- **BE-6**  
  - Requirement: Log customer group deletion — store operation type and entity reference \[cite: 44\]  
  - Source: \[03:11\] \[cite: 44\]  
- **BE-7**  
  - Requirement: Log external group import as an operation distinct from standard group creation — store operation type and entity reference \[cite: 44\]  
  - Source: \[02:46\] \[cite: 44\]  
- **BE-8**  
  - Requirement: Log order item status updates — store operation type, order reference, old status value, new status value \[cite: 44\]  
  - Source: \[02:10\] \[cite: 44\]  
- **BE-9**  
  - Requirement: Every log entry must store the user who made the change and the timestamp of the change \[cite: 44\]  
  - Source: \[05:23\] \[cite: 44\]  
- **BE-10**  
  - Requirement: A log entry must be persisted only after the corresponding database write (create/update/delete) is confirmed — never written speculatively before the write is committed \[cite: 44\]  
  - Source: \[03:51\] \[cite: 44\]

### Frontend

- **FE-1**  
  - Requirement: Display a human-readable description of what happened for each log entry, assembled from the stored raw data (e.g. "discount-10 was added", "was deleted", "status changed from 'on hold' to 'pending'") \[cite: 44\]  
  - Source: \[01:01\], \[05:23\] \[cite: 44\]  
- **FE-2**  
  - Requirement: Display the date of the change, formatted for the panel, for each log entry \[cite: 44\]  
  - Source: \[05:23\] \[cite: 44\]  
- **FE-3**  
  - Requirement: Display the user who made the change for each log entry \[cite: 44\]  
  - Source: \[05:23\] \[cite: 44\]  
- **FE-4**  
  - Requirement: Add a small button to the right of the existing "Extend all" button that opens the audit panel \[cite: 44\]  
  - Source: \[05:23\] \[cite: 44\]  
- **FE-5**  
  - Requirement: Clicking the button opens a panel, matching the behavior of the reference-app "Product history" button \[cite: 44\]  
  - Source: \[05:23\] \[cite: 44\]  
- **FE-6**  
  - Requirement: Exclude the middle column present in reference-app's history panel from the Back Office audit panel \[cite: 44\]  
  - Source: \[05:23\] \[cite: 44\]  
- **FE-7**  
  - Requirement: Follow the reference-app UI design as the standard for layout and styling of the audit panel \[cite: 44\]  
  - Source: \[05:23\] \[cite: 44\]