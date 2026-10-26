# Display Data Trace \- Audit Log

## Sources checked

- meeting-specs.md \#\# Explicit Examples \+ \#\# Format Specifications  
- decision-inventory.md (entity fields, method calls)  
- scope.md (dispatch points, available data per method)  
- business-logic-extract.md (domain rules)  
- discrepancies.md (critical notes affecting data availability)

## Trace

### Rows from \#\# Explicit Examples

- **"`discount-10` was added" — store creation entry**  
  - Data needed to construct it: entity label (`'shop'`), store name (`new_value`), verb `'created'`  
  - Where that data comes from: `StoreCreatedEvent`: `$store->getStoreName()` passed as `$newValue`; dispatched at `SupplierService.php:422` after flush \[cite: 29\]  
  - Entity field that stores it: `AuditLog.entity_type` \= `'store'`, `AuditLog.operation_type` \= `'created'`, `AuditLog.new_value` \= store name \[cite: 29\]  
  - Verdict: COVERED \[cite: 29\]  
- **"`was deleted` — deletion entry"**  
  - Data needed to construct it: entity label (`'shop'`/`'group'`), entity name (`old_value`), verb `'deleted'` \[cite: 29\]  
  - Where that data comes from: `StoreDeletedEvent` / `GroupDeletedEvent`: subject name captured before `remove()` and passed as `$oldValue`; dispatch sites at `SupplierService.php:620` and `StoreService.php:930` \[cite: 29\]  
  - Entity field that stores it: `AuditLog.entity_type`, `AuditLog.operation_type` \= `'deleted'`, `AuditLog.old_value` \= entity name \[cite: 29\]  
  - Verdict: COVERED \[cite: 29\]  
- **"`the status of an item on some order was updated, and, say, the status changed from 'on hold' to 'pending' or something like that`" — spoken approximation of status change sentence**  
  - Data needed to construct it: entity label (`'order item'`), subject reference (`subject_id = order id`), old status label, new status label \[cite: 29\]  
  - Where that data comes from: `OrderItemStatusUpdatedEvent`: `$order->getId()` as `subject_id`, `STATUS_LABELS[$oldStatus]` as `old_value`, `STATUS_LABELS[new status]` as `new_value`; dispatch at `OrderOperationService.php:300` \[cite: 29\]  
  - Entity field that stores it: `AuditLog.entity_type` \= `'order_item'`, `AuditLog.operation_type` \= `'status_updated'`, `AuditLog.subject_id`, `AuditLog.old_value`, `AuditLog.new_value` \[cite: 29\]  
  - Verdict: COVERED — `STATUS_LABELS` values are lowercase snake\_case (`'pending'`, `'cancelled'`, etc.); FE prettify map (`'pending'` \-\> `'Pending'`) is a frontend formatting decision, not a missing stored field \[cite: 29\]  
- **"`Status changed from 'pending' to 'cancelled'` — Cancel button demo"**  
  - Data needed to construct it: old status label, new status label \[cite: 29\]  
  - Where that data comes from: Same as row above — item-level `OrderItem` dispatch \[cite: 29\]  
  - Entity field that stores it: `AuditLog.old_value`, `AuditLog.new_value` \[cite: 29\]  
  - Verdict: COVERED \[cite: 29\]  
- **"`Status changed from 'cancelled' back to 'pending'` — Restore button demo"**  
  - Data needed to construct it: old status label, new status label \[cite: 29\]  
  - Where that data comes from: Same dispatch path — oldStatus \= `'cancelled'`, new \= `'pending'` \[cite: 29\]  
  - Entity field that stores it: `AuditLog.old_value`, `AuditLog.new_value` \[cite: 29\]  
  - Verdict: COVERED \[cite: 29\]  
- **"`Group update example: order type changed from 'retail' to 'retail and wholesale'`"**  
  - Data needed to construct it: old allowed order type label, new allowed order type label \[cite: 29\]  
  - Where that data comes from: `GroupUpdatedEvent` dispatched at `StoreService.php:883` with `operation_type='order_type_updated'`; old/new values resolved via `$allowedOrderTypeLabels` map \[cite: 29\]  
  - Entity field that stores it: `AuditLog.operation_type` \= `'order_type_updated'`, `AuditLog.old_value` \= e.g. `'Retail'`, `AuditLog.new_value` \= e.g. `'Retail & Wholesale'` \[cite: 29\]  
  - Verdict: COVERED \[cite: 29\]

### Rows from \#\# Format Specifications

- **"`Human-readable log text format — 'discount-10 was added', 'was deleted'` — format pattern: `[subject] was added` / `[subject] was deleted`"**  
  - Data needed to construct it: entity label (derived from `entity_type` at FE), entity name from `old_value` or `new_value`, verb from `operation_type` \[cite: 30\]  
  - Where that data comes from: `entity_type` and `operation_type` returned by `AuditHistoryController.php:55-64`; `new_value` carries name for `'created'`, `old_value` for `'deleted'` \[cite: 30\]  
  - Entity field that stores it: `AuditLog.entity_type`, `AuditLog.operation_type`, `AuditLog.old_value`, `AuditLog.new_value` \[cite: 30\]  
  - Verdict: COVERED — all four fields already in API response \[cite: 30\]  
- **"`order item status example — status changed from 'on hold' to 'pending'` — spoken description of the assembled sentence format"**  
  - Data needed to construct it: entity\_type label, order `subject_id`, old status, new status \[cite: 30\]  
  - Where that data comes from: Same as item-level `status_updated` dispatch above \[cite: 30\]  
  - Entity field that stores it: `AuditLog.entity_type`, `AuditLog.subject_id`, `AuditLog.old_value`, `AuditLog.new_value` \[cite: 30\]  
  - Verdict: COVERED \[cite: 30\]  
- **"`Each log entry shows three pieces of information: human-readable description, the date, and the user who made the change` — three-column layout"**  
  - Data needed to construct it: (1) assembled description from `entity_type`/`operation_type`/`old_value`/`new_value`/`subject_id`; (2) timestamp; (3) user email \[cite: 30\]  
  - Where that data comes from: description assembled FE-side; `AuditLog.created_at` for date; `AuditLog.user_email` for user \[cite: 30\]  
  - Entity field that stores it: `AuditLog.created_at`, `AuditLog.user_email`, plus the five fields used for description \[cite: 30\]  
  - Verdict: COVERED — all fields returned by `AuditHistoryController.php:55-64` and declared in `AuditHistoryStore.js:20` \[cite: 30\]  
- **"`The middle column/field visible in reference-app's history panel is excluded from the Back Office` — display exclusion"**  
  - Data needed to construct it: No data required; this means the existing `AuditHistoryPanel.js` grid must NOT include a third reference-app-specific column \[cite: 30\]  
  - Where that data comes from: N/A — exclusion rule; existing `AuditHistoryPanel.js` grid already has only Date, User, Description columns \[cite: 30\]  
  - Entity field that stores it: N/A \[cite: 30\]  
  - Verdict: COVERED — existing panel has exactly the three required columns; no reference-app middle column is present \[cite: 30\]

### New operation types from four confirmed decisions

- **`Display for 'order_approval_updated' (group) — e.g. 'group order approval changed from "Automatically" to "Manually"'`**  
  - Data needed to construct it: `entity_type = 'group'`, `operation_type = 'order_approval_updated'`, `old_value = approval mode label`, `new_value = approval mode label` \[cite: 30\]  
  - Where that data comes from: `StoreService.updateGroup()`: `$oldOrderApprovalMode` captured before field loop; `$group->getOrderApprovalMode()` read after loop; mapped via `$orderApprovalLabels` (1 \-\> `'Automatically'`, 2 \-\> `'Manually'`, 3 \-\> `'Auto-approve on Tag'`); dispatched as `GroupUpdatedEvent` after flush at line 863 \[cite: 30, 31\]  
  - Entity field that stores it: `AuditLog.entity_type` \= `'group'`, `AuditLog.operation_type` \= `'order_approval_updated'`, `AuditLog.old_value`, `AuditLog.new_value` \[cite: 31\]  
  - Verdict: COVERED \[cite: 31\]  
- **`Display for 'receiving_orders_updated' (group) — e.g. 'group receiving orders changed from "On" to "Off"'`**  
  - Data needed to construct it: `entity_type = 'group'`, `operation_type = 'receiving_orders_updated'`, `old_value = 'On'/'Off'`, `new_value = 'On'/'Off'` \[cite: 31\]  
  - Where that data comes from: `StoreService.updateGroup()`: `$oldAcceptOrders` captured before field loop; `$group->getAcceptOrders()` read after loop; truthy \-\> `'On'`, falsy \-\> `'Off'`; dispatched as `GroupUpdatedEvent` after flush at line 863 \[cite: 31\]  
  - Entity field that stores it: `AuditLog.entity_type` \= `'group'`, `AuditLog.operation_type` \= `'receiving_orders_updated'`, `AuditLog.old_value`, `AuditLog.new_value` \[cite: 31\]  
  - Verdict: COVERED \[cite: 31\]  
- **`Display for 'order_status_updated' (order_item) — e.g. 'order #5 status changed from "Pending" to "Fulfilled"'`**  
  - Data needed to construct it: `entity_type = 'order_item'`, `operation_type = 'order_status_updated'`, `old_value = STATUS_LABELS[$orderStatus]`, `new_value = STATUS_LABELS[$newOrderStatus]`, `subject_id = order.id` \[cite: 31\]  
  - Where that data comes from: `OrderOperationService.updateOrderItemStatus()`: `$orderStatus` already captured at line 256; `$newOrderStatus` already computed; both are ints keyed into `STATUS_LABELS`; conditional dispatch added after existing dispatch at line 307, only when `$newOrderStatus !== $orderStatus` \[cite: 31\]  
  - Entity field that stores it: `AuditLog.entity_type` \= `'order_item'`, `AuditLog.operation_type` \= `'order_status_updated'`, `AuditLog.subject_id`, `AuditLog.old_value`, `AuditLog.new_value` \[cite: 31\]  
  - Verdict: COVERED — stored as lowercase snake\_case (`'pending'`, `'fulfilled'`, etc.); FE prettify map (`'pending'` \-\> `'Pending'`) is a frontend formatting decision, not a missing stored field \[cite: 31\]  
- **`Display for 'status_updated' (store) — e.g. 'shop status changed from "Stopped" to "Started"'`**  
  - Data needed to construct it: `entity_type = 'store'`, `operation_type = 'status_updated'`, `old_value = 'Started'/'Stopped'`, `new_value = 'Started'/'Stopped'`, `subject_id = store.id` \[cite: 31\]  
  - Where that data comes from: `SupplierService.startStopStore()`: `$store->getStoreStatus()` read before `setStoreStatus()` at line 563; mapped via `$storeStatusLabels` (STORE\_START \-\> `'Started'`, STORE\_STOP \-\> `'Stopped'`); `$status` (the new value) mapped same way; dispatch added after flush at line 567 \[cite: 31\]  
  - Entity field that stores it: `AuditLog.entity_type` \= `'store'`, `AuditLog.operation_type` \= `'status_updated'`, `AuditLog.subject_id`, `AuditLog.old_value`, `AuditLog.new_value` \[cite: 31\]  
  - Verdict: COVERED — `entity_type = 'store'` distinguishes this from the existing `order_item` `status_updated` entries; FE branch must check `entity_type` to route correctly (no new stored field needed) \[cite: 31\]

## Collision note — status\_updated \+ store vs order\_item

The `operation_type = 'status_updated'` is already used for `entity_type = 'order_item'`. `entity_type = 'store'` uses the same token. This is correct on the backend (the pair `entity_type + operation_type` is unique), and the `AuditHistoryController` already returns `entity_type` in the response payload. The FE fix (making the `status_updated` branch `entity_type`\-aware) is a display change only — no new stored data is required \[cite: 31\].

## All verdicts: COVERED — proceeding to write implementation-prompt.md \[cite: 31\]