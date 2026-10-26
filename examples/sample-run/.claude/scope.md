# Scope \- Audit Log Feature

## MCP Calls Made

- **`get_lessons`**  
  - Input: "audit log audit history logging shops stores customer groups order item status"  
  - Key findings: 3 lessons returned, all just written by meeting-extractor: post-flush timing, review reference-app pattern first, use Doctrine lifecycle events / avoid extra DB connections  
- **`search_business_logic`**  
  - Input: "shop store"  
  - Key findings: Shop (UI) \== Store (backend/payment provider). New store saved as `ProviderStore`, status Pending verification. Close \= shop menu \-\> confirm \-\> real removal.  
- **`search_business_logic`**  
  - Input: "customer group"  
  - Key findings: Two add paths: Create New vs Import Existing. Editable fields: name, members, `CustomerGroup.allowed_order_type`, Receiving Orders, Order Approval.  
- **`search_business_logic`**  
  - Input: "external group"  
  - Key findings: "Import Existing" \= importing an existing payment provider customer segment \= the "external group" path from the meeting.  
- **`search_business_logic`**  
  - Input: "order item status"  
  - Key findings: Statuses: Pending / Fulfilled / Cancelled. Constant `ORDER_ITEM_STATUS_PENDING`. Manual actions on Pending: Fulfil, Cancel.  
- **`search_business_logic`**  
  - Input: "audit history log"  
  - Key findings: No results — product history/audit log is not documented in the primary project's BUSINESS\_LOGIC.md (it's the separate reference-app project).  
- **`search_business_logic`**  
  - Input: "reference-app"  
  - Key findings: No relevant results in the primary project's BUSINESS\_LOGIC.md.  
- **`search_business_logic`**  
  - Input: "Cancel Restore order item status constants"  
  - Key findings: Confirms Pending/Fulfilled/Cancelled statuses and `ORDER_ITEM_STATUS_PENDING` constant; manual actions on Pending: Fulfil, Cancel.  
- **`get_project_context`**  
  - Input: project: primary  
  - Key findings: Entities include existing `AuditLog`; controllers include existing `AuditHistoryController`; repositories include existing `AuditLogRepository`. Feature is already partially pre-built (earlier WIP).  
- **`get_routes`**  
  - Input: project: primary, filter: "audit"  
  - Key findings: Existing route `GET /audit-history` \-\> `src/Controller/AuditHistoryController.php`  
- **`get_entity_schema`**  
  - Input: "AuditLog" / "CustomerGroup" / "ProviderStore"  
  - Key findings: Parser returned empty/incomplete field lists (annotation style not parsed by this MCP tool) — read directly via search\_code/Read instead, see below  
- **`get_entity_schema`**  
  - Input: "OrderItem"  
  - Key findings: Fields: id, type, status, has\_required\_fields, data (array, JSON)  
- **`get_entity_schema`**  
  - Input: "Order"  
  - Key findings: Fields: id, customerId, source, requestPayload, responsePayload, responseStatus, validFlag, errorFlag, status (int, nullable \- the "order" status), itemType, groupId, groupName  
- **`search_code`**  
  - Input: "`ProviderStore` / `CustomerGroup` (primary, \*.php)"  
  - Key findings: Relations confirmed: CustomerGroup ManyToOne \-\> ProviderStore  
- **`search_code`**  
  - Input: "class AuditLog" (primary)  
  - Key findings: Full entity found (see Reference Files Read)  
- **`search_code`**  
  - Input: "class AuditHistoryController" (primary)  
  - Key findings: Full controller found: `GET /audit-history`, `@IsGranted("ROLE_STORE_ADMIN")`, paginated by tenant, returns raw fields only (no assembled description — correctly BE-only)  
- **`search_code`**  
  - Input: Event classes (Store\*/Group\*/OrderItemStatusUpdated)  
  - Key findings: All share shape: subjectId, tenantId, userId, userEmail, oldValue, newValue; `GroupUpdatedEvent` additionally carries operationType  
- **`search_code`**  
  - Input: "`new ...Event` dispatch call sites"  
  - Key findings: Found all 9 dispatch call sites across SupplierService, StoreService, OrderOperationService — see Requirement Coverage  
- **`search_code`**  
  - Input: "Extend All|Extend all|extend-all|ExtendAll" (primary, all files)  
  - Key findings: **Zero matches anywhere in the primary project.** No literal "Extend All" Button exists in this codebase.  
- **`search_code`**  
  - Input: "ExtendStore|extend\_store" (primary)  
  - Key findings: Found: per-store single "Extend" action (`POST /extend/{storeId}`, `ExtendStore` window) — no bulk "Extend All" UI button exists  
- **`search_code`**  
  - Input: "status" in OrderOperationService.php  
  - Key findings: Confirms both an "order" status (`Order.status`, aggregate) and an "item" status (`OrderItem.status`, per item) exist and are both mutated in the same method — see Method Traces  
- **`search_code`**  
  - Input: "updateGroup" in StoreService.php  
  - Key findings: Confirms which group fields are editable: `groupName`, `allowedOrderType`, `orderApprovalMode`, `acceptOrders` — only 2 of 4 trigger a logged event

## Reference Files Read

- **reference-app backend logging pattern (meeting ref `[05:05]`)**  
  - Path read: `../reference-app/backend/src/Entity/AuditEvent.php` (or `AuditHistory.php`)  
  - Key pattern found: Generic field-diff log entity: columns `unique_id`, `product_id`, `table`, `field`, `old_value`, `new_value`, `action`, `source`, `date`, `user_id`. Raw primitives only (table/field/old/new), no assembled description column — same BE-raw/FE-assemble split as our AuditLog, but implemented as a *generic per-field diff row* (any entity/field), not per-operation domain events.  
- **reference-app backend logging pattern (meeting ref `[05:05]`)**  
  - Path read: `../reference-app/backend/src/Service/AuditHistoryService.php`  
  - Key pattern found: `formatData()` resolves `field` \+ human label via a `FieldsMapping` lookup (not literal sentence assembly, but structurally similar: BE returns old/new \+ field label, FE builds the sentence). Also supports `revert from history` (`revertDataFromHistory`) — not required by the meeting/RUN\_PROMPT, not in scope.  
- **reference-app frontend UI (`Extend all` button \+ history panel) (meeting ref `[00:45]`, `[05:23]`)**  
  - Path read: Searched entire reference-app repo (`ui/app`, all `.js`, excluding vendor/build dirs) for "Extend all", "extend-all", "ExtendAll", "product history"  
  - Key pattern found: **Zero matches.** No literal "Extend All" button or dedicated product-history frontend view exists in this checked-out reference-app repo — it is likely rendered by a micro-frontend module not present in this checkout, or the meeting's spoken "extend all" does not map to a literal component name here. This is a genuine unresolved reference — see Step 3 question.  
- **Back Office existing frontend scaffold (pre-existing WIP, not from meeting refs)**  
  - Path read: `public/ui/app/store/AuditHistoryStore.js`, `public/ui/app/view/audithistory/AuditHistoryPanel.js`, `public/ui/app/utils/Renderers.js`, `public/ui/app/view/orders/OrdersController.js`  
  - Key pattern found: A full Audit History panel \+ "Audit History" button already exist, placed next to "Expand All" (`Renderers.getOrdersTools`). See discrepancy candidate below.

## Requirement Coverage

- **BE-1**  
  - Requirement: Log shop/store creation  
  - Implementing code: `SupplierService.php:422` dispatches `StoreCreatedEvent` after `flush()` at line \~415  
  - Callers: `AuditLogEventSubscriber::onStoreCreated` \-\> `persistLog()`  
  - Return value traced: YES — persists `AuditLog(entity_type='store', operation_type='created')`  
- **BE-2**  
  - Requirement: Log shop/store update  
  - Implementing code: `SupplierService.php:493` dispatches `StoreUpdatedEvent` after `flush()`  
  - Callers: `AuditLogEventSubscriber::onStoreUpdated`  
  - Return value traced: YES  
- **BE-3**  
  - Requirement: Log shop/store deletion  
  - Implementing code: `SupplierService.php:620` dispatches `StoreDeletedEvent` after `flush()` (subjectId/name captured before `remove()`)  
  - Callers: `AuditLogEventSubscriber::onStoreDeleted`  
  - Return value traced: YES  
- **BE-4**  
  - Requirement: Log customer group creation  
  - Implementing code: `StoreService.php:636` dispatches `GroupCreatedEvent` after `flush()`  
  - Callers: `AuditLogEventSubscriber::onGroupCreated`  
  - Return value traced: YES  
- **BE-5**  
  - Requirement: Log customer group update  
  - Implementing code: `StoreService.php:866` (name change) and `:883` (order-type change) dispatch `GroupUpdatedEvent`. **`updateGroup()` also allows changing `orderApprovalMode` and `acceptOrders` (lines \~798-810) — neither change dispatches any event.**  
  - Callers: `AuditLogEventSubscriber::onGroupUpdated`  
  - Return value traced: PARTIAL — only 2 of 4 editable group fields are logged  
- **BE-6**  
  - Requirement: Log customer group deletion  
  - Implementing code: `StoreService.php:930` dispatches `GroupDeletedEvent` after `flush()` (id/name captured before `remove()`)  
  - Callers: `AuditLogEventSubscriber::onGroupDeleted`  
  - Return value traced: YES  
- **BE-7**  
  - Requirement: Log external group import (distinct from standard creation)  
  - Implementing code: `StoreService.php:728` dispatches `GroupImportedEvent` after `flush()`, inside `updateGroup()`'s "Import Existing" branch  
  - Callers: `AuditLogEventSubscriber::onGroupImported` \-\> `persistLog($event, 'group', 'imported')`  
  - Return value traced: YES — distinct `operation_type='imported'` vs `'created'`  
- **BE-8**  
  - Requirement: Log order item status updates  
  - Implementing code: `OrderOperationService.php:300` dispatches `OrderItemStatusUpdatedEvent` after `flush()` at line \~285. **Only the item-level `OrderItem.status` old/new is logged. The same method also conditionally updates the order-level `Order.status` (line \~275, `$newOrderStatus`) when it differs — that change is NOT logged.**  
  - Callers: `AuditLogEventSubscriber::onOrderItemStatusUpdated`  
  - Return value traced: PARTIAL — order status change is silently unlogged (matches the flagged meeting ambiguity)  
- **BE-9**  
  - Requirement: Store user and timestamp per log entry  
  - Implementing code: `AuditLog` entity: `user_id`, `user_email`, `created_at` (`DateTimeImmutable`, set via `persistLog()`)  
  - Callers: `AuditLogEventSubscriber::persistLog()`  
  - Return value traced: YES  
- **BE-10**  
  - Requirement: Log entry persisted only after DB write confirmed  
  - Implementing code: Confirmed for all 9 dispatch sites: each occurs after the originating `$this->entityManager->flush()` in the same method, and subject id/name for deletions is captured before `remove()`. `persistLog()` itself does its own `persist()` \+ `flush()`, persisting the AuditLog row (a second flush per operation — not a new DB connection, same EntityManager, but worth noting against the "avoid extra round-trips" lesson).  
  - Callers: n/a  
  - Return value traced: YES (timing), NOTE (extra flush)

## Method Traces

### AuditLogEventSubscriber — `src/EventSubscriber/AuditLogEventSubscriber.php:20`

- Subscribes to: `GroupCreatedEvent`, `GroupImportedEvent`, `GroupUpdatedEvent`, `GroupDeletedEvent`, `StoreCreatedEvent`, `StoreUpdatedEvent`, `StoreDeletedEvent`, `OrderItemStatusUpdatedEvent`  
- Every handler wrapped in try/catch \-\> `$this->errorTracker->captureException($e)` (C8 compliant)  
- `persistLog(object $event, string $entityType, string $operationType)` (line 117): builds `AuditLog` from `$event->getSubjectId()/getOldValue()/getNewValue()/getUserId()/getUserEmail()/getTenantId()`, sets `created_at` to `now()`, `persist()` \+ `flush()`.  
- Callers: Symfony EventDispatcher (via the 8 `dispatch(new ...Event(...))` call sites in scope.md Requirement Coverage)  
- Design note: This is a **decoupled event-subscriber pattern**, not the reference-app's generic Doctrine-changeset-diff pattern. New operation types require (a) a new Event class, (b) a new dispatch call site in the originating service, (c) a new `getSubscribedEvents()` entry \+ handler method — i.e., it is extendable without modifying *other* services' code, but each new loggable field/action inside an *existing* service still requires a manual dispatch call to be added at that call site. Not a mechanism that logs "for free."

### AuditLog entity — `src/Entity/AuditLog.php:14`

- Columns: `id`, `subject_id` (int, nullable), `entity_type` (string 100), `operation_type` (string 100), `old_value` (text, nullable), `new_value` (text, nullable), `user_id` (int, nullable), `user_email` (string 255, nullable), `tenant_id` (int), `created_at` (datetime\_immutable)  
- Every column stores exactly one primitive fact — C9 compliant. No assembled description column exists (FE assembles it — matches the display-language rule split).  
- Table created by `migrations/Version20250527120000.php` — schema matches entity exactly.

### AuditHistoryController::getAuditHistory() — `src/Controller/AuditHistoryController.php:20`

- Route: `GET /audit-history` (name `get_audit_history`), `@IsGranted("ROLE_STORE_ADMIN")`, `@RequiresAccessCheck`  
- Reads tenant from `$this->getUser()->getTenant()->getId()`, paginates via `AuditLogRepository::getByTenantId()`  
- Returns raw fields: `id`, `subject_id`, `entity_type`, `operation_type`, `old_value`, `new_value`, `user_email`, `created_at` — **no `user_id`** in the response (present in entity/DB but not serialized) — not needed by FE since `user_email` is what's displayed.  
- Callers (frontend): `AuditHistoryStore.js` (`proxy.url: '/api/audit-history'`)

### AuditHistoryPanel — `public/ui/app/view/audithistory/AuditHistoryPanel.js:1`

- Ext window, grid with columns `Date` / `User` / `Description`  
- `statics.assembleDescription(entityType, operationType, oldValue, newValue, subjectId)` — client-side sentence assembly exactly matching the display-language rule (FE-1): handles `created`/`imported`/`updated`/`order_type_updated`/`deleted`/`status_updated` operation types with entity-label lookup (`group` \-\> `'group'`, `store` \-\> `'shop'`, `order_item` \-\> `'order item'`)  
- Opened via `OrdersController::openAuditHistoryPanel()`, wired to an "Audit History" button in `Renderers.getOrdersTools()` — **placed immediately after the "Expand All" button, not any "Extend All" button (none exists in the Back Office).**

### OrderOperationService::updateOrderItemStatus() — `src/Services/OrderOperationService.php:228`

- Input: `{id, status}` (`id` \= OrderItem id)  
- Loads the item record, captures `$oldStatus` (item-level).  
- Recomputes `$newOrderStatus` from all sibling `OrderItem` rows via `CALCULATE_ORDER_STATUS` map; if different from current `Order.status`, updates the Order (order status) too — but this is a silent side effect, not logged.  
- Persists \+ flushes both the item status and (conditionally) the order.  
- Dispatches `OrderItemStatusUpdatedEvent` with only the **item-level** old/new status labels.  
- Unused/unlogged: `$newOrderStatus` change A (matches meeting's flagged "order vs item" ambiguity — user said "both" will change; only the item status is logged today)

## Reference-app reference notes

For the meeting's explicit requirement, `../reference-app` was read directly (not via MCP \- external, unindexed project). The backend `AuditHistoryService`/`AuditHistory` entity confirms the same raw-primitive-storage / FE-assembles-description architecture already used by our `Auditlog`. However, no literal "Extend All" button or a locatable product-history frontend view exists anywhere in this reference-app checkout (exhaustive grep across `ui/app`, all `.js`, excluding vendored/build directories, returned zero matches) — this UI reference could not be physically verified and is flagged as a Step 3 question rather than assumed.