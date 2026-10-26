# Architecture Decisions

## AuditLog Schema Design

- **Selected**: naïve approach \[cite: 32\]  
- **How implemented**: Use existing `AuditLog` entity without modification — all 10 pre-existing columns cover every new log entry type, zero schema changes, no migration \[cite: 32\].

---

## Feature: Audit Log \- Extension to Four New Operation Types \[cite: 32\]

This prompt covers all changes needed to log four new operation types and to display all log entries correctly in the Audit History panel \[cite: 32\].

**No database migration is required.** The existing `AuditLog` entity at `src/Entity/AuditLog.php` is unchanged \[cite: 32\].

**Summary of changes:** \[cite: 32\]

- Change 1: `StoreUpdatedEvent` — add `operationType` as 5th constructor param \[cite: 32\]  
- Change 2: `OrderItemStatusUpdatedEvent` — add `operationType` as 5th constructor param \[cite: 32\]  
- Change 3: `AuditLogEventSubscriber` — read `getOperationType()` instead of hardcoded strings \[cite: 32\]  
- Change 4: `SupplierService` — update existing rename dispatch \+ add start/stop dispatch \[cite: 32\]  
- Change 5: `StoreService` — capture old field values \+ add two new dispatches \[cite: 32\]  
- Change 6: `OrderOperationService` — fix existing dispatch signature \+ add order\_status dispatch \[cite: 32\]  
- Change 7: `AuditHistoryPanel.js` — extend `assembleDescription()` with four new branches \[cite: 32\]

---

## Change 1 — StoreUpdatedEvent: add operationType parameter \[cite: 32\]

**File:** `src/Event/StoreUpdatedEvent.php` \[cite: 32\]

Replace the entire file: \[cite: 32\] \[Change 1: full StoreUpdatedEvent class with a 7-param constructor (subjectId, tenantId, userId, userEmail, operationType, oldValue, newValue), private fields and getters \- code omitted\] \[cite: 32\]

**What changed:** `string $operationType` added as 5th constructor param (between `$userEmail` and `$oldValue`), mirroring `GroupUpdatedEvent` at `src/Event/GroupUpdatedEvent.php:17`. Private field `$operationType` and getter `getOperationType()` added. All callers passing 6 args will fail until updated — see Changes 3 and 4 \[cite: 33\].

---

## Change 2 — OrderItemStatusUpdatedEvent: add operationType parameter \[cite: 33\]

**File:** `src/Event/OrderItemStatusUpdatedEvent.php` \[cite: 33\]

Replace the entire file: \[cite: 33\] \[Change 2: full OrderItemStatusUpdatedEvent class with the same 7-param constructor, private fields and getters \- code omitted\] \[cite: 33\]

**What changed:** identical structural change to Change 1 — same 7-param constructor, same new private field and getter. The caller update is in Change 6 \[cite: 33\].

---

## Change 3 — AuditLogEventSubscriber: read operationType from event \[cite: 33\]

**File:** `src/EventSubscriber/AuditLogEventSubscriber.php` \[cite: 33\]

**Change 3a** — inside `onStoreUpdated()` at line 93, replace the hardcoded string: \[cite: 33\] \[Change 3a old: persistLog call with entity type 'store' and the hardcoded operation 'updated' \- code omitted\] \[cite: 33\] **New line:** \[cite: 33\] \[Change 3a new: the same persistLog call, passing `$event->getOperationType()` instead of `'updated'` \- code omitted\] \[cite: 33\]

**Change 3b** — inside `onOrderItemStatusUpdated()` at line 111, replace the hardcoded string: \[cite: 33\] \[Change 3b old: persistLog call with entity type 'order\_item' and the hardcoded operation 'status\_updated' \- code omitted\] \[cite: 33\] **New line:** \[cite: 33\] \[Change 3b new: the same persistLog call, passing `$event->getOperationType()` instead of `'status_updated'` \- code omitted\] \[cite: 33\]

No other changes to this file. All existing try/catch wrappers with `$this->errorTracker->captureException($e)` remain in place — C8 is satisfied. The `persistLog()` private method signature is unchanged \[cite: 33\].

---

## Change 4 — SupplierService: update store rename dispatch and add start/stop dispatch \[cite: 33\]

**File:** `src/Services/SupplierService.php` \[cite: 33\]

`StoreUpdatedEvent` is already imported at line 18\. No new use statements needed \[cite: 33\].

### Change 4a — updateStore() dispatch (currently lines 493-500) \[cite: 33\]

The existing dispatch passes 6 arguments. The constructor now requires 7\. Add `'updated'` as the 5th argument \[cite: 33\]. Replace this block: \[cite: 33\] \[Change 4a old: StoreUpdatedEvent dispatch with 6 arguments \- store id, tenant id, user id, user email, old store name, new store name \- code omitted\] \[cite: 34\] With: \[cite: 34\] \[Change 4a new: the same dispatch with `'updated'` inserted as the 5th argument \- code omitted\] \[cite: 34\]

### Change 4b — startStopStore() `if (is_null($status))` block (currently lines 562-568) \[cite: 34\]

The current block: \[cite: 34\] \[Change 4b old: the block that sets the store status, updates the timestamp, persists and flushes \- code omitted\] \[cite: 34\] Replace with: \[cite: 34\] \[Change 4b new: capture the old store status before setStoreStatus(), persist and flush, map both statuses through a `STORE_START -> 'Started' / STORE_STOP -> 'Stopped'` label map, resolve user id/email with a null guard, and dispatch StoreUpdatedEvent with 'status\_updated' \- code omitted\] \[cite: 34\]

**Notes:** \[cite: 34\]

- `$oldStatus` is captured before `setStoreStatus($status)` so the pre-mutation value is logged (BE-10) \[cite: 34, 35\].  
- The dispatch sits after `flush()` so it fires only on confirmed persistence (BE-10) \[cite: 35\].  
- `$this->user` is declared `@var User|null` — the null guard is required \[cite: 35\].  
- Tenant ID comes from the store's project chain (`getProject()->getTenantId()`) rather than from `$this->user`, because `$this->user` may be null. This is the same pattern used in `OrderOperationService.php:287-291` \[cite: 35\].  
- `STORE_START = 1` and `STORE_STOP = 0` are already declared as class constants at lines 23 and 25 \[cite: 35\].

---

## Change 5 — StoreService::updateGroup(): capture old values and add two new dispatches \[cite: 35\]

**File:** `src/Services/StoreService.php` \[cite: 35\]

`GroupUpdatedEvent` is already imported at line 27\. No new use statements needed \[cite: 35\].

### Change 5a — capture old field values before the field loop (currently Lines 799-800) \[cite: 35\]

The current code after `$store = $group->getStore();` at line 797: \[cite: 35\] \[Change 5a old: the two existing captures of the old group name and the old allowed order type \- code omitted\] \[cite: 35\] Replace with: \[cite: 35\] \[Change 5a new: the same two captures plus `$oldOrderApprovalMode` and `$oldAcceptOrders` \- code omitted\] \[cite: 35\] These two captures must be placed before the `foreach ($fields as $field)` loop at Line 802, which iterates `allowedOrderType`, `orderApprovalMode`, and `acceptOrders` via dynamic setters. After the loop any of these fields may have been mutated \[cite: 35\].

### Change 5b — add two dispatch blocks after the existing order\_type\_updated dispatch (after Line 892, before the return) \[cite: 35\]

The current end of `updateGroup()` — the block after the `allowedOrderType` dispatch closing brace (Line 892\) through to the return: \[cite: 35\] \[Change 5b old: the closing brace of the order-type dispatch and the existing success response return \- code omitted\] \[cite: 35\] Replace with: \[cite: 35\] \[Change 5b new: if the order approval mode changed, dispatch GroupUpdatedEvent with `order_approval_updated` and labels `1 -> 'Automatically', 2 -> 'Manually', 3 -> 'Auto-approve on Tag'`; if acceptOrders changed, dispatch GroupUpdatedEvent with `receiving_orders_updated` and `'On'/'Off'`; then the unchanged success response return \- code omitted\] \[cite: 35\]

**Notes:** \[cite: 35\]

- Both dispatches sit after `$this->entityManager->flush()` at line 863 (BE-10) \[cite: 35\].  
- Old values were captured before the field loop in Change 5a \[cite: 35, 36\].  
- Label map keys: `1 -> 'Automatically'`, `2 -> 'Manually'`, `3 -> 'Auto-approve on Tag'` — verified against `public/ui/app/view/orders/windows/EditCustomerGroup.js:328, 334, 339` (decision-inventory.md, Label literals table) \[cite: 35, 36\].  
- `$oldAcceptOrders` and `$group->getAcceptOrders()` return `?int` (verified at `CustomerGroup.php:142`). Falsy values (null, 0\) map to `'Off'`; truthy (1) maps to `'On'` — verified against `EditCustomerGroup.js:283, 286` \[cite: 36\].  
- `$this->user` access pattern here follows the existing dispatches at lines 866-874 and 883-892, which also access `$this->user` without null guard. No change to that pattern \[cite: 36\].

---

## Change 6 — OrderOperationService: fix existing dispatch \+ add order\_status dispatch \[cite: 36\]

**File:** `src/Services/OrderOperationService.php` \[cite: 36\]

`OrderItemStatusUpdatedEvent` is already imported at line 21\. No new use statements needed \[cite: 36\].

### Change 6a — existing dispatch (currently lines 300-307): add 'status\_updated' as 5th argument \[cite: 36\]

The existing dispatch: \[cite: 36\] \[Change 6a old: OrderItemStatusUpdatedEvent dispatch with 6 arguments \- order id, tenant id, log user id, log user email, old and new item status labels from STATUS\_LABELS \- code omitted\] \[cite: 36\] Replace with: \[cite: 36\] \[Change 6a new: the same dispatch with `'status_updated'` as the 5th argument, followed by a second OrderItemStatusUpdatedEvent dispatch with `'order_status_updated'` and the old/new order status labels, guarded by `$newOrderStatus !== $orderStatus` \- code omitted\] \[cite: 36\]

**Notes:** \[cite: 36\]

- `$orderStatus` is captured at line 256 (`$orderStatus = $order->getStatus()`), before any mutation \[cite: 36\].  
- `$newOrderStatus` is computed by the loop ending at line 268 and is not modified after that point \[cite: 36\].  
- The `$newOrderStatus !== $orderStatus` condition matches the guard already used at line 270 (`if ($newOrderStatus !== $orderStatus) { $order->setStatus($newOrderStatus); }`) \[cite: 36\].  
- `$logUserId` and `$logUserEmail` are set in the if-block at lines 293-298 and are already null-safe \[cite: 36\].  
- `$tenantId` is resolved from the entity chain at lines 287-291 and is already cast to `int` \[cite: 36\].  
- `self::STATUS_LABELS` maps: `1 -> 'pending'`, `2 -> 'fulfilled'`, `3 -> 'cancelled'`, `4 -> 'in_progress'`. If `$orderStatus` is null (not yet computed), the null coalescing gives `(string) null == ''`, which is acceptable \[cite: 36\].  
- Both dispatches sit after `$this->em->flush()` at line 285 (BE-10) \[cite: 36\].

---

## Change 7 — AuditHistoryPanel.js: extend assembleDescription() \[cite: 36\]

**File:** `public/ui/app/view/audithistory/AuditHistoryPanel.js` \[cite: 36\]

Replace the entire `assembleDescription()` function body inside the `statics` block (lines 74-104). The surrounding structure (`statics: { ... }`) is unchanged \[cite: 36\]. Replace: \[cite: 36\] \[Change 7 old: the current assembleDescription() \- entity label map (group \-\> 'group', store \-\> 'shop', order\_item \-\> 'order item') and branches for created, imported, updated, order\_type\_updated, deleted and status\_updated, with a generic fallback \- code omitted\] \[cite: 36\] With: \[cite: 37\] \[Change 7 new: the same function with a `statusPrettify` map, an `entityType`\-aware `status_updated` branch, and new branches for order\_approval\_updated, receiving\_orders\_updated, and order\_status\_updated \- code omitted\] \[cite: 37\]

**What changed:** \[cite: 37\]

1. `'statusPrettify'` map added — converts stored lowercase snake\_case values (`'pending'`, `'fulfilled'`, `'cancelled'`, `'in_progress'`) to human-readable labels (`'Pending'`, `'Fulfilled'`, `'Cancelled'`, `'In Progress'`) \[cite: 37\].  
2. `'status_updated'` branch made entity-type-aware: \[cite: 37\]  
   - `entityType === 'store'`: renders `shop status changed from "Stopped" to "Started"` (stored values `'Started'` / `'Stopped'` are already human-readable — no prettify needed) \[cite: 37\].  
   - Otherwise (`entity_type === 'order_item'`): retains original order-ref format with `statusPrettify` applied to old/new values \[cite: 37\].  
3. New `'order_approval_updated'` branch: renders `group order approval changed from "Automatically" to "Manually"` (stored values are already human-readable — no prettify needed) \[cite: 37\].  
4. New `'receiving_orders_updated'` branch: renders `group receiving orders changed from "On" to "Off"` (stored values are already human-readable) \[cite: 37\].  
5. New `'order_status_updated'` branch: renders `order [#N] status changed from "Pending" to "Fulfilled"` with `statusPrettify` applied (stored values are lowercase snake\_case from `STATUS_LABELS`) \[cite: 37\].

---

## Constraint Checklist \[cite: 37\]

- **`C4`** \[cite: 37\]  
  - How satisfied: No parameters added to services.yaml — no config file changes required; all modified classes are either plain value objects or already-registered services with unchanged DI wiring \[cite: 37\]  
- **`C6`** \[cite: 37\]  
  - How satisfied: No `dd()`, `var_dump()`, or `dump()` calls introduced in any changed file \[cite: 37\]  
- **`C7`** \[cite: 37\]  
  - How satisfied: No LoggerInterface added — `ErrorTrackerInterface` already present in `AuditLogEventSubscriber.php:25` and unchanged \[cite: 37\]  
- **`C8`** \[cite: 37\]  
  - How satisfied: `onStoreUpdated()` and `onOrderItemStatusUpdated()` in `AuditLogEventSubscriber` remain fully wrapped in existing try-catch with `$this->errorTracker->captureException($e)`; both changes (3a, 3b) only alter the string argument passed to `persistLog()` inside the existing try body — the guard is preserved and no new unguarded handler is added \[cite: 37\]  
- **`C9`** \[cite: 37\]  
  - How satisfied: No new columns — all 10 existing `AuditLog` columns are unchanged; each new log entry writes exactly one primitive token per column (one `entity_type`, one `operation_type`, one label string in `old_value`, one label string in `new_value`, one `subject_id`); the order\_status dispatch is a second separate event rather than packing two values into one column \[cite: 37\]