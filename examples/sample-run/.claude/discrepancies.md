# Discrepancies \- Audit Log Feature

Sources read before writing this file:

- `.CLAUDE.md` (C1-C9 constraints)  
- `.claude/meeting-specs.md` (BE-1 through BE-10 \+ References)  
- `.claude/business-logic-extract.md` (domain rules)  
- `.claude/scope.md` (file:line references)  
- Actual source files: `AuditLogEventSubscriber.php`, `AuditLog.php`, `AuditHistoryController.php`, `SupplierService.php` (lines 485-630), `StoreService.php` (lines 615-940), `OrderOperationService.php` (lines 228-318), `AuditHistoryPanel.js`, `AuditHistoryStore.js`, `OrdersController.js`, `Renderers.js`  
- reference-app files: `AuditHistory.php`, `AuditHistoryService.php`

---

## Category A — BE-\* Requirements

---

### Rule: BE-1

**Log shop/store creation — store operation type, entity reference, and relevant field values**

- Code location: `src/Services/SupplierService.php:422` (dispatch) \-\> `src/EventSubscriber/AuditLogEventSubscriber.php:81` (handler) \-\> `:117` (persistLog)  
- Happy path: After `flush()` in line 420 the code dispatches `StoreCreatedEvent($store->getId(), $tenantId, $userId, $userEmail, null, $store->getStoreName())`. `persistLog` stores `entity_type='store'`, `operation_type='created'`, `subject_id=store.id`, `old_value=null`, `new_value=store name`, `user_id`, `user_email`, `tenant_id`, `created_at`. All required primitives are stored.  
- Edge cases: If the payment provider API call fails or the initial `persist`/`flush` throws, the dispatch is never reached — no speculative log is written, which is correct per BE-10. `subject_id` is read from the already-flushed `$store->getId()`, so the auto-generated PK is available.  
- Failure path: `onStoreCreated` wraps the `persistLog` call in try/catch with `$this->errorTracker->captureException($e)` — exceptions inside `persistLog` (including a second-flush failure) are caught and reported without propagating.  
- Missing cases: none found.  
- Verdict: COMPLIANT

---

### Rule: BE-2

**Log shop/store update — store operation type, entity reference, old value, new value**

- Code location: `src/Services/SupplierService.php:493` (dispatch) \-\> `src/EventSubscriber/AuditLogEventSubscriber.php:90` (handler)  
- Happy path: After `flush()` at Line 491, the code dispatches `StoreUpdatedEvent($store->getId(), $tenantId, $userId, $userEmail, $oldStoreName, $store->getStoreName())`, `old_value=old store name`, `new_value=new store name`. All required fields stored correctly.  
- Edge cases: If the payment provider API patch returns `success=false`, the method returns early at Line 486 before reaching `flush()` and the dispatch never fires — correct, no log for a failed update.  
- Failure path: `onStoreUpdated` wraps `persistLog` in try/catch \+ error tracker.  
- Missing cases: `SupplierService::startStopStore()` (lines 516-578) changes `storeStatus` (`STORE_START` / `STORE_STOP`) and calls `flush()` but dispatches no event. Whether a start/stop/restart action constitutes a "shop/store update" that must be logged is not addressed in the meeting specs — the meeting's "Shops section" context at `[03:30]` is consistent with name edits via the Edit Shop form, not lifecycle commands. This sub-operation is not explicitly included or excluded by the meeting.  
- Verdict: UNDOCUMENTED — `updateStore()` (name change) is correctly logged; `startStopStore()` (status change) is not logged and the meeting does not clarify whether it should be.

---

### Rule: BE-3

**Log shop/store deletion — store operation type and entity reference**

- Code location: `src/Services/SupplierService.php:599-629` \+ dispatch at line 620 \-\> `src/EventSubscriber/AuditLogEventSubscriber.php:99`  
- Happy path: `$storeSubjectId = $store->getId()` and `$storeName = $store->getStoreName()` are captured before `remove()`/`flush()` (Lines 599-601). After flush at Line 618, dispatches `StoreDeletedEvent(storeSubjectId, storeTenantId, userId, userEmail, storeName, null)`, `entity_type='store'`, `operation_type='deleted'`, `old_value=store name (for display)`, `new_value=null`. Entity reference and name correctly preserved.  
- Edge cases: If the payment provider delete API returns `success=false`, returns early at Line 611 before removal/flush/dispatch — no log for a failed deletion. Correct.  
- Failure path: `onStoreDeleted` wraps `persistLog` in try/catch \+ error tracker.  
- Missing cases: none found.  
- Verdict: COMPLIANT

---

### Rule: BE-4

**Log customer group creation — store operation type, entity reference, and relevant field values**

- Code location: `src/Services/StoreService.php:636` (dispatch) \-\> `src/EventSubscriber/AuditLogEventSubscriber.php:45`  
- Happy path: After `flush()` at line 634, dispatches `GroupCreatedEvent($group->getId(), $tenantId, $userId, $userEmail, null, $group->getGroupName())`. entity\_type=`group`, operation\_type=`created`, `new_value=group name`. Required fields stored.  
- Edge cases: If the payment provider create-segment API fails, returns early before flush/dispatch — no speculative log. Correct.  
- Failure path: `onGroupCreated` wraps `persistLog` in try/catch \+ error tracker.  
- Missing cases: none found.  
- Verdict: COMPLIANT

---

### Rule: BE-5

**Log customer group update (e.g. order type change) — store operation type, entity reference, old value, new value**

- Code location: `src/Services/StoreService.php:865-892` (two conditional dispatches) \-\> `AuditLogEventSubscriber.php:62`  
- Happy path: After `flush()` at line 863:  
  - If group name changed (line 865): dispatches `GroupUpdatedEvent` with `operation_type='updated'`, `old_value=oldGroupName`, `new_value=new group name`. Correctly logged.  
  - If allowedOrderType changed (line 877): dispatches `GroupUpdatedEvent` with `operation_type='order_type_updated'`, `old_value=label string (e.g. 'Retail')`, `new_value=label string (e.g. 'Retail & Wholesale')`. Correctly logged.  
- Edge cases: If no watched field changed, no event fires — correct, only actual changes produce log entries.  
- Failure path: `onGroupUpdated` wraps `persistLog` in try/catch \+ error tracker.  
- Missing cases: The `updateGroup()` method also applies changes to three fields via a loop (lines 790-808): `allowedOrderType`, `orderApprovalMode`, and `acceptOrders`. Changes to `orderApprovalMode` and `acceptOrders` are persisted and flushed at line 863 but **NO event is dispatched for either**. These are editable group-level settings (Order Approval mode and Receiving Orders toggle) that the user can change in the Edit Customer Group form. The meeting requirement at `[03:11]` says "Log customer group updates (example: order type change)" — the "(example:)" phrasing implies that order type is one instance of a general "group update" category, not the exhaustive list. `orderApprovalMode` and `acceptOrders` changes are silently unlogged but never produce a log entry. The meeting's use of "(example: order type change)" indicates general group update logging is required, not only order type changes.  
- Verdict: DISCREPANCY — `orderApprovalMode` and `acceptOrders` changes are persisted and flushed but never produce a log entry. The meeting's use of "(example: order type change)" indicates general group update logging is required, not only order type changes.

---

### Rule: BE-6

**Log customer group deletion — store operation type and entity reference**

- Code location: `src/Services/StoreService.php:928-937` \+ dispatch at line 930 \-\> `AuditLogEventSubscriber.php:71`  
- Happy path: `$groupSubjectId = $group->getId()` and `$groupName = $group->getGroupName()` captured before `remove()`/`flush()` (lines 923-924). After flush at line 928, dispatches `GroupDeletedEvent(groupSubjectId, groupTenantId, userId, userEmail, groupName, null)`, `entity_type='group'`, `operation_type='deleted'`, `old_value=group name (correctly carries the name of the deleted entity)`, `new_value=null`.  
- Edge cases: deletion data captured before removal — ID and name are available. Correct.  
- Failure path: `onGroupDeleted` wraps `persistLog` in try/catch \+ error tracker.  
- Missing cases: none found.  
- Verdict: COMPLIANT

---

### Rule: BE-7

**Log external group import as an operation distinct from standard group creation — store operation type and entity reference**

- Code location: `src/Services/StoreService.php:727-735` (`importExternalGroups()`) \-\> `AuditLogEventSubscriber.php:53`  
- Happy path: After the single `flush()` at line 725 (covering all newly created CustomerGroup rows for this import batch), the code iterates `$createdGroups` and dispatches `GroupImportedEvent` per group. `persistLog` stores `entity_type='group'`, `operation_type='imported'`. Distinct from `created`. Requirement satisfied.  
- Edge cases: If all submitted groups already exist (no new CustomerGroup rows created), `$createdGroups` is empty and no events fire — correct, no log for a no-op import. If only some are new, only those fire events.  
- Failure path: `onGroupImported` wraps `persistLog` in try/catch \+ error tracker.  
- Missing cases: none found.  
- Verdict: COMPLIANT

---

### Rule: BE-8

**Log order item status updates — store operation type, order reference, old status value, new status value**

- Code location: `src/Services/OrderOperationService.php:300-307` \-\> `AuditLogEventSubscriber.php:108`  
- Happy path: After `flush()` at line 285, dispatches `OrderItemStatusUpdatedEvent($order->getId(), $tenantId, $userId, $userEmail, STATUS_LABELS[$oldStatus], STATUS_LABELS[$data['status']])`, `entity_type='order_item'`, `operation_type='status_updated'`, `subject_id = parent Order ID`. `old_value` and `new_value` are human-readable status labels (`STATUS_LABELS['Pending'`, `'Cancelled'`). The item-level `OrderItem` status change is fully logged.  
- Edge cases: If `$this->user` is null (automated update, no authenticated user), `$logUserId` and `$logUserEmail` are set to null (lines 293-298). The `AuditLog` columns `user_id` and `user_email` are nullable — this is handled correctly.  
- Failure path: `onOrderItemStatusUpdated` wraps `persistLog` in try/catch \+ error tracker.  
- Missing cases: The same `updateOrderItemStatus()` method also conditionally updates the **order-level** `Order.status` aggregate at line 271 (`$order->setStatus($newOrderStatus)`) when it differs from the current value. This change is persisted and flushed at line 285 alongside the item status, but the event at line 300 carries only the item-level `OrderItem` old/new status — the order status change (`$orderStatus` \-\> `$newOrderStatus`) is never included in any log entry. The meeting speaker at `[02:18]` stated "both the order status and the status of that specific item will change". Whether the order status change must be logged as a separate entry or is implicitly covered by the existing per-operation entry is not clarified in the meeting.  
- Verdict: DISCREPANCY — The order-level `Order.status` aggregate change is silently unlogged when it occurs as a side effect of an item status update. Whether this requires a separate log entry or is out of scope requires a human decision (flagged in meeting-specs.md \#\# Flags as vague).

---

### Rule: BE-9

**Every log entry must store the user who made the change and the timestamp of the change**

- Code location: `src/Entity/AuditLog.php:63-86` (`user_id`, `user_email`, `created_at` columns) \-\> `AuditLogEventSubscriber.php:128-128` (persistLog sets all fields from event)  
- Happy path: `persistLog()` sets `user_id` from `$event->getUserId()`, `user_email` from `$event->getUserEmail()`, and `created_at` via `setCreatedAt()` which calls `new \DateTimeImmutable()` at the moment of log persistence. All three fields are written for every log entry.  
- Edge cases: `user_id` and `user_email` columns are nullable (Lines 63, 71). For `OrderOperationService` (automated updates with no session user), both are passed as null and stored as null. This is acceptable — the schema allows it and the controller returns `user_email` to the frontend, which renders null gracefully.  
- Failure path: If `setCreatedAt()` or `persist()`/`flush()` fails inside `persistLog`, the try/catch in the calling handler catches it \+ error tracker. The log entry is not written but the main request is unaffected.  
- Missing cases: none found.  
- Verdict: COMPLIANT

---

### Rule: BE-10

**A log entry must be persisted only after the corresponding database write (create/update/delete) is confirmed — never written speculatively before the write is committed**

- Code location: All 8 dispatch call sites verified against their originating flush() calls.  
- Happy path — all dispatch sites confirmed post-flush:  
  - Store created: `SupplierService.php:420` flush \+ `:422` dispatch  
  - Store updated: `SupplierService.php:491` flush \+ `:493` dispatch  
  - Store deleted: `SupplierService.php:618` flush \+ `:620` dispatch (subject data captured before remove at lines 599-601)  
  - Group created: `StoreService.php:634` flush \+ `:636` dispatch  
  - Group imported: `StoreService.php:725` flush \+ `:726` dispatch (loop over already-persisted entities)  
  - Group updated: `StoreService.php:863` flush \+ `:866`/`883` dispatch  
  - Group deleted: `StoreService.php:928` flush \+ `:930` dispatch (subject data captured before remove at lines 923-924)  
  - Status updated: `OrderOperationService.php:285` flush \+ `:300` dispatch  
- Edge cases: For deletions, `subject_id` and name are captured before `remove()`, ensuring the data is available for the event even though the entity is removed from DB. Correct.  
- Failure path: If `flush()` throws, the dispatch is never reached — no log is written for an uncommitted change. Correct per this requirement.  
- Missing cases: `persistLog()` itself calls `$this->em->flush()` at line 131 of `AuditLogEventSubscriber.php`. This is a second flush on the same `EntityManagerInterface` (same DB connection), not a new connection. It does produce one additional DB round-trip per logged operation. The meeting's constraint at `[04:38]` was specifically about avoiding extra DB connections ("unnecessary connections to the database, constant opening and closing of connections"). A second flush on an already-open EntityManager is not a new connection. However, it is an extra DB round-trip that could in principle be eliminated by batching the log persist into the originating service's own flush. Whether this level of optimization is required by the meeting constraint is ambiguous — the constraint text targeted connections, not flushes.  
- Verdict: COMPLIANT (all log writes are post-confirmed-flush; the extra flush in persistLog uses the same DB connection and does not violate the connection constraint)

---

## Category B — C1-C9 Constraints

---

### Rule: C1

**Always use ParameterBagInterface — never read env directly in services**

- Code location: All new Audit Log service code: `AuditLogEventSubscriber.php`, `AuditHistoryController.php`, event classes, `AuditLog.php`  
- Happy path: `AuditLogEventSubscriber` constructor injects only `EntityManagerInterface` and `ErrorTrackerInterface`. `AuditHistoryController` constructor injects only `AuditLogRepository`. No environment variables are accessed in any of these files. No `getenv()`, `$_ENV`, `$_SERVER` calls appear in the Audit Log feature code.  
- Edge cases: Not applicable — no configuration parameters are used by this feature at all.  
- Failure path: Not applicable.  
- Missing cases: none found.  
- Verdict: COMPLIANT — The Audit Log feature code reads no environment variables and requires no parameters.

---

### Rule: C2

**Optional integrations are configured only through parameters — an empty value (host, URL, key) means no-op. No separate enable/disable flags.**

- Code location: Not applicable — the Audit Log feature adds no configurable host, URL, or API endpoint parameter to any service.  
- Happy path: The subscriber writes to the local DB via `EntityManagerInterface`. The controller reads from the local DB via `AuditLogRepository`. No external HTTP calls or host configurations are involved in the logging path.  
- Edge cases: Not applicable.  
- Failure path: Not applicable.  
- Missing cases: none found.  
- Verdict: COMPLIANT — C2 does not apply to this feature; no integration parameters are introduced.

---

### Rule: C3

**Never add status constants without explicit instruction**

- Code location: `src/Entity/AuditLog.php`, `AuditLogEventSubscriber.php`, all event classes  
- Happy path: The `AuditLog` entity defines no PHP constants. Operation type strings (`'created'`, `'deleted'`, `'imported'`, `'order_type_updated'`, `'status_updated'`) are passed as string literals directly in the service dispatch calls and subscriber handler calls — they are not declared as class constants in the `AuditLog` entity or anywhere else. This matches the meeting's requirement to store operation type as a raw primitive string.  
- Edge cases: Not applicable.  
- Failure path: Not applicable.  
- Missing cases: none found.  
- Verdict: COMPLIANT — No new status constants have been added to any entity as part of this feature.

---

### Rule: C4

**Never put parameters in services.yaml**

- Code location: `config/services.yaml` (not modified by this feature based on scope.md review)  
- Happy path: `AuditLogEventSubscriber` uses Symfony's standard autowiring — it takes `EntityManagerInterface` and `ErrorTrackerInterface` which are pre-existing services. No custom parameters are declared in services.yaml for this feature. The controller uses `AuditLogRepository` which is also autowired.  
- Edge cases: Not applicable.  
- Failure path: Not applicable.  
- Missing cases: none found.  
- Verdict: COMPLIANT — No custom parameters were added to services.yaml for this feature.

---

### Rule: C6

**No dd(), var\_dump(), dump() in any file**

- Code location: All Audit Log files read during this analysis: `AuditLogEventSubscriber.php`, `AuditLog.php`, `AuditHistoryController.php`, `AuditHistoryPanel.js`, `AuditHistoryStore.js`, `OrdersController.js` (full file read, 1469 Lines), `Renderers.js` (full file read).  
- Happy path: No `dd()`, `var_dump()`, or `dump()` calls were found in any of the files read during this analysis.  
- Edge cases: Not applicable.  
- Failure path: Not applicable.  
- Missing cases: none found.  
- Verdict: COMPLIANT

---

### Rule: C7

**No LoggerInterface unless already present or explicitly requested**

- Code location: `AuditLogEventSubscriber.php:17-28` (constructor), `AuditHistoryController.php:22-27` (constructor)  
- Happy path: `AuditLogEventSubscriber` injects `'EntityManagerInterface'` and `'ErrorTrackerInterface'` — no `'LoggerInterface'`. `AuditHistoryController` injects only `'AuditLogRepository'` — no `'LoggerInterface'`. No other new classes were added by this feature.  
- Edge cases: Not applicable.  
- Failure path: Not applicable.  
- Missing cases: none found.  
- Verdict: COMPLIANT — `LoggerInterface` is not used anywhere in the Audit Log feature code.

---

### Rule: C8

**In Doctrine event subscribers and Symfony event listeners, wrap all logic in try-catch and report exceptions via the project's error tracker — auxiliary failures must never propagate to the main request**

- Code location: `AuditLogEventSubscriber.php:45-115` (all eight handler methods)  
- Happy path: Every public handler method (`onGroupCreated`, `OnGroupImported`, `onGroupUpdated`, `onGroupDeleted`, `onStoreCreated`, `onStoreUpdated`, `onStoreDeleted`, `onOrderItemStatusUpdated`) wraps its body in `try { $this->persistLog(...) } catch (\Throwable $e) { $this->errorTracker->captureException($e); }`. `ErrorTrackerInterface` is injected in the constructor (line 17-18, used at line 27). If `persistLog()` throws (e.g., the second `flush()` constructor (line 17-18, used at line 27). If `persistLog()` throws (e.g., the second `flush()` due to a DB constraint), the exception is caught and sent to the error tracker, and the main request continues unaffected.  
- Edge cases: The try/catch uses `\Throwable` (not `\Exception`), which also catches `\Error` — including type errors, fatal errors, etc. This is correct defensive programming for an auxiliary operation.  
- Failure path: Error-tracker capture is the only side effect of a `persistLog` failure — the caller gets no exception back, and the main business logic is unaffected.  
- Missing cases: none found.  
- Verdict: COMPLIANT

---

### Rule: C9

**Each database column must store exactly one piece of information — one status, one name, one ID, one flag. Never store concatenated or composite data in a single column.**

- Code location: `src/Entity/AuditLog.php:14-191`  
- Happy path: All ten columns store exactly one primitive fact:  
  - `id` (integer) — auto PK  
  - `subject_id` (integer, nullable) — single entity ID  
  - `entity_type` (string 100\) — single entity category string (`'store'`, `'group'`, `'order_item'`)  
  - `operation_type` (string 100\) — single operation string (`'created'`, `'updated'`, `'deleted'`, etc.)  
  - `old_value` (text, nullable) — single string value (store name, group name, or status label)  
  - `new_value` (text, nullable) — single string value  
  - `user_id` (integer, nullable) — single user ID  
  - `user_email` (string 255, nullable) — single email address  
  - `tenant_id` (integer) — single tenant ID  
  - `created_at` (datetime\_immutable) — single timestamp  
- No JSON columns, no concatenated values, no composite fields.  
- Edge cases: `old_value` and `new_value` are stored as plain text strings. In the `StoreService.php` `order_type_updated` path (lines 878-891), the old/new values are resolved from a label map before dispatch (e.g., `$allowedOrderTypeLabels[$oldAllowedOrderType] ?? (string) $oldAllowedOrderType`) — the resolved label string is a single value, not a composite. This is acceptable.  
- Missing cases: none found.  
- Verdict: COMPLIANT — All columns store exactly one primitive fact. No JSON or composite storage is used.

---

## Additional Finding — FE Button Placement (referenced by meeting `[05:23]` and `scope.md`)

This finding is included at the parent agent's explicit direction because it requires a human decision.

### Rule: "Add a new small button to the right of the existing 'Extend all' button"

**Meeting `[05:23]`**

- Code location: `public/ui/app/utils/Renderers.js:351-380` (`getOrdersTools` function, Audit History button added after Expand All button)  
- Happy path: The existing "Audit History" button (Lines 375-380) is placed immediately after the "Expand All" button (Lines 359-374) in the `getOrdersTools()` toolbar. Clicking it calls `openAuditHistoryPanel()` (`OrdersController.js:1368-1374`) which creates and shows an `AuditHistoryPanel` window.  
- Edge cases: The meeting presenter said "to the right of the existing 'Extend all' button" while pointing at a reference-app history panel. No "Extend all" button exists anywhere in the Back Office (exhaustive search returned zero matches per `scope.md` MCP calls). The reference-app codebase also has no locatable "Extend all" / "Extend all" button in its `vi/app` directory.  
- Failure path: Not applicable.  
- Missing cases: The meeting reference "Extend all" does not correspond to any identifiable button in the Back Office or in the reference-app checkout. The current implementation placed the Audit History button next to "Expand all" (not "Extend all"). These two buttons are different words — "Expand All" is the row-expander toggle at `Renderers.js:360` with `role:'expand-all'`. Whether the presenter meant "Expand All" (by mispronunciation or confusion in transcript), or meant a different UI element not present in this repo, or expected a new "Extend All" button to be created first, cannot be determined from the meeting text or codebase alone.  
- Verdict: UNDOCUMENTED — The meeting's placement reference ("to the right of the existing 'Extend all'") does not map to any existing element in the Back Office. The current code places the button next to "Expand All." A human must confirm whether (a) the current placement next to "Expand All" is acceptable, (b) the meeting meant a different existing button, or (c) an "Extend All" button must first be created and the Audit History button placed to its right.