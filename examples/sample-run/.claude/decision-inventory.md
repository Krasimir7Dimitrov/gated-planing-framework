# Decision Inventory \- Audit Log Feature (Step 3.5)

Verification pass: every line number below was obtained by physically opening the file and locating the symbol. Nothing is carried over from `scope.md` or `discrepancies.md` without re-verification.

## Sources read

- `.claude/meeting-specs.md` (BE-1..BE-18, FE-1..FE-7, References)  
- `.claude/business-logic-extract.md`  
- `.claude/scope.md`  
- `.claude/discrepancies.md`  
- Step 3 confirmed answers (4 decisions, passed verbatim by the parent agent)  
- Source files listed in Sections 1-4 below  
- `.claude/solutions.md` — **not read** (per agent rule). `.claude/solutions-research.md` — **does not exist**; Step 2.3/2.5 were not triggered for this task (no new entity, no new mechanism — see Section 1 note).

---

## Entity Fields

**No new entity is created by this task.** All four confirmed decisions are pattern-completions of the already-existing `AuditLog` mechanism. Step 2.3 (Schema Design Solution) was therefore never triggered and no `## Solution: — Schema Design` entry exists — this is correct, not a gap. The table below documents the **existing** `AuditLog` columns that every new log entry writes into, verified field-by-field against the entity file, to prove the confirmed decisions require **zero schema changes and zero migration**.

- **AuditLog**  
- Field: id  
- PHP type: int  
- Column type: integer (PK, GeneratedValue)  
- Nullable: NO  
- C9: ✅ auto PK, one value  
- Source: Confirmed existing — `src/Entity/AuditLog.php:23`  
- **AuditLog**  
- Field: subject\_id  
- PHP type: ?int  
- Column type: integer  
- Nullable: YES  
- C9: 🟨 one entity ID  
- Source: Confirmed existing — `AuditLog.php:30`  
- **AuditLog**  
- Field: entity\_type  
- PHP type: string  
- Column type: string(100)  
- Nullable: NO  
- C9: ✅ one category token ('store' / 'group' / 'order\_item')  
- Source: Confirmed existing — `AuditLog.php:37`  
- **AuditLog**  
- Field: operation\_type  
- PHP type: string  
- Column type: string(100)  
- Nullable: NO  
- C9: ✅ one operation token  
- Source: Confirmed existing — `AuditLog.php:44`  
- **AuditLog**  
- Field: old\_value  
- PHP type: ?string  
- Column type: text  
- Nullable: YES  
- C9: ✅ one label string (not composite)  
- Source: Confirmed existing — `AuditLog.php:51`  
- **AuditLog**  
- Field: new\_value  
- PHP type: ?string  
- Column type: text  
- Nullable: YES  
- C9: ✅ one label string (not composite)  
- Source: Confirmed existing — `AuditLog.php:58`  
- **AuditLog**  
- Field: user\_id  
- PHP type: ?int  
- Column type: integer  
- Nullable: YES  
- C9: ✅ one user ID  
- Source: Confirmed existing — `AuditLog.php:65`  
- **AuditLog**  
- Field: user\_email  
- PHP type: ?string  
- Column type: string(255)  
- Nullable: YES  
- C9: 🟨 one email  
- Source: Confirmed existing — `AuditLog.php:72`  
- **AuditLog**  
- Field: tenant\_id  
- PHP type: int  
- Column type: integer  
- Nullable: NO  
- C9: ✅ one tenant ID  
- Source: Confirmed existing — `AuditLog.php:79`  
- **AuditLog**  
- Field: created\_at  
- PHP type: \\DateTimeImmutable  
- Column type: datetime\_immutable  
- Nullable: NO  
- C9: ✅ one timestamp  
- Source: Confirmed existing — `AuditLog.php:86`

### Schema Decision Summary

**Verified: no new columns required.** Each confirmed decision maps entirely onto the existing columns:

- **\#1a — group Order Approval**  
- entity\_type: `group`  
- operation\_type: `order_approval_updated`  
- old\_value: `Automatically` / `Manually` / `Auto-approve on Tag`  
- new\_value: same set  
- subject\_id: CustomerGroup id  
- New column needed?: NO  
- **\#1b — group Receiving Orders**  
- entity\_type: `group`  
- operation\_type: `receiving_orders_updated`  
- old\_value: `On` / `Off`  
- new\_value: `On` / `Off`  
- subject\_id: CustomerGroup id  
- New column needed?: NO  
- **\#2 — order status**  
- entity\_type: `order_item`  
- operation\_type: `order_status_updated`  
- old\_value: `STATUS_LABELS[$orderStatus]`  
- new\_value: `STATUS_LABELS[$newOrderStatus]`  
- subject\_id: Order id  
- New column needed?: NO  
- **\#3 — shop start/stop**  
- entity\_type: `store`  
- operation\_type: `status_updated`  
- old\_value: `Started` / `Stopped`  
- new\_value: `Started` / `Stopped`  
- subject\_id: ProviderStore id  
- New column needed?: NO

All four write single primitive label strings into `old_value` / `new_value` — never concatenated or composite. **C9 holds for every new entry.**

**Label literals — source verification**

- **`Automatically` (value 1, typo `Automaticaly` corrected)**  
- Confirmed by: Step 3 answer \#1  
- Physically verified against: `public/ui/app/view/orders/windows/EditCustomerGroup.js:328` — `boxLabel: 'Automatically', inputValue: 1`  
- **`Manually` (value 2\)**  
- Confirmed by: Step 3 answer \#1  
- Physically verified against: `EditCustomerGroup.js:334` — `boxLabel: 'Manually', inputValue: 2`  
- **`Auto-approve on Tag` (value 3\)**  
- Confirmed by: Step 3 answer \#1  
- Physically verified against: `EditCustomerGroup.js:339` — `boxLabel: 'Auto-approve on Tag', inputValue: 3`  
- **`On` / `Off`**  
- Confirmed by: Step 3 answer \#1 (shortened form of UI text)  
- Physically verified against: `EditCustomerGroup.js:283` — `Receiving is ON` / `EditCustomerGroup.js:286` — `Receiving is OFF`  
- **`pending` / `fulfilled` / `cancelled` / `in_progress`**  
- Confirmed by: Step 3 answer \#2 (`self::STATUS_LABELS`)  
- Physically verified against: `src/Services/OrderOperationService.php:37-42` — **note: actual constant values are lowercase snake\_case (`'pending'`), not `Pending`**. The new order-status dispatch reuses this exact map, so old/new values are identical in form to the already-logged item-status entries (`OrderOperationService.php:385-386`).  
- **`Started` (STORE\_START) / `Stopped` (STORE\_STOP)**  
- Confirmed by: Step 3 answer \#3 — user-approved wording, no UI source exists  
- Physically verified against: Constants verified: `src/Services/SupplierService.php:23` — `const STORE_START = 1;`, `:25` `const STORE_STOP = 0;`

**Operation type literals — uniqueness check against existing values**

Existing `operation_type` values in use: `created` (`AuditLogEventSubscriber.php:48`, `:84`), `imported` (`:57`), `deleted` (`:75`, `:102`), `updated` (`StoreService.php:871`, and `AuditLogEventSubscriber.php:93`), `order_type_updated` (`StoreService.php:888`), `status_updated` (`AuditLogEventSubscriber.php:111`).

- **`order_approval_updated`**  
- Collides with existing?: NO — not present anywhere  
- **`receiving_orders_updated`**  
- Collides with existing?: NO — not present anywhere  
- **`order_status_updated`**  
- Collides with existing?: NO — not present anywhere  
- **`status_updated` (for `entity_type='store'`)**  
- Collides with existing?: **Value already in use for `entity_type='order_item'`**. Distinguished by `entity_type`, which is correct on the BE side (the pair `entity_type` \+ `operation_type` is unique). Consequence for FE — see Section 5\.

---

### Method Calls

All methods below were located by opening the file and reading the definition.

**Existing methods — verified present**

- **`StoreService`**  
- Method: `updateGroup()`  
- Verified file;line: `src/Services/StoreService.php:776`  
- **`CustomerGroup`**  
- Method: `getOrderApprovalMode()`  
- Verified file;line: `src/Entity/CustomerGroup.php:197`  
- **`CustomerGroup`**  
- Method: `setOrderApprovalMode()`  
- Verified file;line: `src/Entity/CustomerGroup.php:202`  
- **`CustomerGroup`**  
- Method: `getAcceptOrders()`  
- Verified file;line: `src/Entity/CustomerGroup.php:142`  
- **`CustomerGroup`**  
- Method: `setAcceptOrders()`  
- Verified file;line: `src/Entity/CustomerGroup.php:147`  
- **`CustomerGroup`**  
- Method: `getId()`  
- Verified file;line: `src/Entity/CustomerGroup.php:113`  
- **`CustomerGroup`**  
- Method: `getGroupName()`  
- Verified file;line: `src/Entity/CustomerGroup.php:166`  
- **`CustomerGroup`**  
- Method: `getAllowedOrderType()`  
- Verified file;line: `src/Entity/CustomerGroup.php:209`  
- **`GroupUpdatedEvent`**  
- Method: `__construct()` — already carries `string $operationType` (5th arg)  
- Verified file;line: `src/Event/GroupUpdatedEvent.php:17`  
- **`GroupUpdatedEvent`**  
- Method: `getOperationType()`  
- Verified file;line: `src/Event/GroupUpdatedEvent.php:32`  
- **`AuditLogEventSubscriber`**  
- Method: `onGroupUpdated()` — already reads `$event->getOperationType()`  
- Verified file;line: `src/EventSubscriber/AuditLogEventSubscriber.php:63` (delegation at :66)  
- **`AuditLogEventSubscriber`**  
- Method: `onStoreUpdated()` — currently hardcodes `'updated'` at :93  
- Verified file;line: `src/EventSubscriber/AuditLogEventSubscriber.php:90`  
- **`AuditLogEventSubscriber`**  
- Method: `onOrderItemStatusUpdated()` — currently hardcodes `'status_updated'` at :111  
- Verified file;line: `src/EventSubscriber/AuditLogEventSubscriber.php:108`  
- **`AuditLogEventSubscriber`**  
- Method: `persistLog()`  
- Verified file;line: `src/EventSubscriber/AuditLogEventSubscriber.php:117`  
- **`AuditLogEventSubscriber`**  
- Method: `getSubscribedEvents()`  
- Verified file;line: `src/EventSubscriber/AuditLogEventSubscriber.php:31`  
- **`OrderOperationService`**  
- Method: `updateOrderItemStatus()`  
- Verified file;line: `src/Services/OrderOperationService.php:228`  
- **`OrderOperationService`**  
- Method: `self::STATUS_LABELS` (const, not a method)  
- Verified file;line: `src/Services/OrderOperationService.php:37-42`  
- **`Order`**  
- Method: `getStatus()` — source of `$orderStatus`  
- Verified file;line: `src/Entity/Order.php:302`  
- **`Order`**  
- Method: `setStatus()` — applies `$newOrderStatus`  
- Verified file;line: `src/Entity/Order.php:307`  
- **`Order`**  
- Method: `getCustomerGroup()` — used for tenantId resolution  
- Verified file;line: `src/Entity/Order.php:262`  
- **`OrderItemStatusUpdatedEvent`**  
- Method: `__construct()` — currently 6 params, **no** operationType  
- Verified file;line: `src/Event/OrderItemStatusUpdatedEvent.php:16`  
- **`SupplierService`**  
- Method: `startStopStore()`  
- Verified file;line: `src/Services/SupplierService.php:516`  
- **`SupplierService`**  
- Method: `updateStore()` — existing rename path, dispatch at :493  
- Verified file;line: `src/Services/SupplierService.php:493` (dispatch call site)  
- **`ProviderStore`**  
- Method: `getStoreStatus()`  
- Verified file;line: `src/Entity/ProviderStore.php:262`  
- **`ProviderStore`**  
- Method: `setStoreStatus()`  
- Verified file;line: `src/Entity/ProviderStore.php:267`  
- **`ProviderStore`**  
- Method: `getId()`  
- Verified file;line: `src/Entity/ProviderStore.php:161`  
- **`ProviderStore`**  
- Method: `getStoreName()`  
- Verified file;line: `src/Entity/ProviderStore.php:202`  
- **StoreUpdatedEvent**  
- Method: `__construct()` — currently 6 params, **no** operationType  
- Verified file;line: `src/Event/StoreUpdatedEvent.php:16`  
- **AuditLog**  
- Method: `setOperationType()`  
- Verified file;line: `src/Entity/AuditLog.php:120`  
- **AuditLog**  
- Method: `setOldValue()` / `setNewValue()`  
- Verified file;line: `src/Entity/AuditLog.php:131` / `:142`  
- **AuditHistoryController**  
- Method: `getAuditHistory()` — returns `operation_type`, `entity_type`, `old_value`, `new_value`, `subject_id` unchanged  
- Verified file;line: `src/Controller/AuditHistoryController.php:32` (payload at :55-64)  
- **AuditHistoryPanel**  
- Method: `assembleDescription()` (static)  
- Verified file;line: `public/ui/app/view/audithistory/AuditHistoryPanel.js:74`  
- **OrdersController**  
- Method: `openAuditHistoryPanel()`  
- Verified file;line: `public/ui/app/view/orders/OrdersController.js:1368`  
- **Renderers**  
- Method: `getOrdersTools()`  
- Verified file;line: `public/ui/app/utils/Renderers.js:190`

**Methods/params that DO NOT yet exist and must be created** (explicitly mandated by the Step 3 confirmed answers — listed separately so nothing above is falsely claimed as existing)

- **`OrderItemStatusUpdatedEvent`**  
- Member to add: `string $operationType` constructor param \+ `$operationType` property \+ `getOperationType()`  
- Current state — verified: `Confirmed absent` — constructor is `(int $subjectId, int tenantId, ?int $userId, ?string $userEmail, ?string $oldValue, ?string $newValue)` at `OrderItemStatusUpdatedEvent.php:16`; no operationType anywhere in the 33-line file  
- Pattern to mirror: `GroupUpdatedEvent.php:13` (property), `:17` (5th ctor arg), `:32` (getter)  
- **`StoreUpdatedEvent`**  
- Member to add: `string $operationType` constructor param \+ `$operationType` property \+ `getOperationType()`  
- Current state — verified: `Confirmed absent` — constructor is `(int $subjectId, int tenantId, ?int $userId, ?string $userEmail, ?string $oldValue, ?string $newValue)` at `StoreUpdatedEvent.php:16`; no operationType anywhere in the 33-line file  
- Pattern to mirror: `GroupUpdatedEvent.php:13` / `:17` / `:32`

**Call sites that must be updated to preserve current behaviour** (verified — each currently passes 6 args and will break on signature change unless amended)

- **`new StoreUpdatedEvent(...)`** — store rename  
- Verified file;line: `src/Services/SupplierService.php:493`  
- Required change: pass `'updated'` explicitly  
- **`new OrderItemStatusUpdatedEvent(...)`** — item status  
- Verified file;line: `src/Services/OrderOperationService.php:300`  
- Required change: pass `'status_updated'` explicitly  
- **`onStoreUpdated()`** hardcoded `'updated'`  
- Verified file;line: `src/EventSubscriber/AuditLogEventSubscriber.php:93`  
- Required change: replace with `$event->getOperationType()`  
- **`onOrderItemStatusUpdated()`** hardcoded `'status_updated'`  
- Verified file;line: `src/EventSubscriber/AuditLogEventSubscriber.php:111`  
- Required change: replace with `$event->getOperationType()`

**Dispatch / anchor points — verified exact lines**

- **\#1 capture old values before the field loop**  
- Anchor: `$oldGroupName` / `$oldAllowedOrderType` captured here today  
- Verified file;line: `StoreService.php:799` / `:800` (field loop at :882-809; `$fields` array at :798-794)  
- **\#1 new dispatches go after the existing pair**  
- Anchor: existing `GroupUpdatedEvent` dispatches  
- Verified file;line: `StoreService.php:866` (`'updated'`, guard at :865) and `:883` (`'order_type_updated'`, guard at :877) — both after `flush()` at :863  
- **\#2 order-status branch**  
- Anchor: `if ($oldOrderStatus !== $newOrderStatus) { $order->setStatus(...) }`  
- Verified file;line: `OrderOperationService.php:270-273`; `$orderStatus` read at :256; `flush()` at :285; existing dispatch at :300-307  
- **\#3 start/stop flush**  
- Anchor: `if ($this->entityManager->flush();` inside `if (!is_null($status))`  
- Verified file;line: `SupplierService.php:567` (status computed at :560, `setStoreStatus()` at :563, block :562-568)  
- **BE-10 timing — re-verified for all three new dispatches:** every new dispatch site **after** its originating `flush()` (`:863`, `:285`, `:567`). Old values are captured **before** mutation in all three cases (`StoreService.php` before the `802` loop; `$orderStatus` at `OrderOperationService.php:256` before `:271`; `ProviderStore::getStoreStatus()` before `setStoreStatus()` at `SupplierService.php:563`). No speculative logging.

---

### Constraints Applied

- **C1**  
- Applies: N/A  
- Applied to: No new service reads env vars or parameters. The three touched services already inject what they need; `SupplierService` already uses `ParameterBagInterface` (constructor `SupplierService.php:66`, used at `:76`) and this task adds no parameter reads. `AuditLogEventSubscriber` injects only `EntityManagerInterface` \+ `ErrorTrackerInterface` (`AuditLogEventSubscriber.php:25`). No `getenv()` / `$_ENV` / `$_SERVER` introduced.  
- Verdict: ✅  
- **C2**  
- Applies: N/A  
- Applied to: No integration parameter (host, URL, key) is introduced or consumed by or any of the four decisions. The logging path is DB-only; the payment provider host used at `SupplierService.php:76` is pre-existing and untouched.  
- Verdict: ✅  
- **C3**  
- Applies: YES  
- Applied to: No new status constants. The three new `operation_type` values (`order_approval_updated`, `receiving_orders_updated`, and `order_status_updated` store value are passed as **string literals at the dispatch call sites**, exactly matching how `'updated'` (`StoreService.php:871`) and `order_type_updated` (`:888`) are passed today. No `const` is added to `AuditLog`, the event classes, or any service. The label maps reuse existing sources: `OrderOperationService::STATUS_LABELS` (`:37-42`) and `SupplierService::STORE_START` / `STORE_STOP` (`:23` / `:25`) — both pre-existing, neither extended.  
- Verdict: ✅  
- **C4**  
- Applies: YES  
- Applied to: No parameters added to `config/services.yaml`. The two modified event classes are plain value objects (not services); `AuditLogEventSubscriber` remains autowired/autoconfigured with no DI changes — its constructor signature (`AuditLogEventSubscriber.php:25`) is unchanged by these decisions.  
- Verdict: ✅  
- **C6**  
- Applies: YES  
- Applied to: No `dd()`, `var_dump()` or `dump()` is introduced. Verified absent in every file read for this inventory: `AuditLogEventSubscriber` (133 lines), `AuditLog.php` (191), `CustomerGroup.php` (319), `ProviderStore.php` (read), `GroupUpdatedEvent.php` (35), `StoreUpdatedEvent.php` (32), `OrderItemStatusUpdatedEvent.php` (32), `AuditHistoryController.php` (72), `AuditHistoryPanel.js` (106), `AuditHistoryStore.js` (21), and the read ranges of the three services.  
- Verdict: ✅  
- **C7**  
- Applies: YES  
- Applied to: No `LoggerInterface` added. `AuditLogEventSubscriber` constructor (`AuditLogEventSubscriber.php:25`) takes only `EntityManagerInterface` \+ `ErrorTrackerInterface` and is not modified by any decision. The two event classes gain a `string $operationType` scalar only — no new service dependency anywhere.  
- Verdict: ✅  
- **C8**  
- Applies: YES  
- Applied to: The event subscriber is the sole consumer of all three new/changed events and **already** wraps every handler in `try { ... } catch (\Throwable $e) { $this->errorTracker->captureException($e); }` — on `onGroupUpdated` `AuditLogEventSubscriber.php:63-70`, `onStoreUpdated` `:90-97`, `onOrderItemStatusUpdated` `:108-115`. `ErrorTrackerInterface` injected at `:25`, stored at `:28`. The decisions change only the *argument* passed to `persistLog()` inside the existing `try` body — the protection is preserved and no new unguarded handler is added. Auxiliary log failures cannot propagate into `updateGroup()`, `startStopStore()` or `updateOrderItemStatus()`.  
- Verdict: ✅  
- **C9**  
- Applies: YES  
- Applied to: Verified per field in Section 1\. Every new log row writes one primitive token per column: one `entity_type`, one `operation_type`, one label string in `old_value`, one label string in `new_value`, one `subject_id`. No concatenation, no JSON, no composite value. Decision \#2 in particular dispatches a **second, separate** `OrderItemStatusUpdatedEvent` rather than packing order+item status into one row — which is precisely what C9 requires. No new columns, so no new JSON-column justification is needed.  
- Verdict: ✅

---

### Frontend Framework

- **Sencha Ext JS (classic toolkit, MVVM: `Ext.define` / `Ext.window.Window` / `Ext.data.Store` / `Ext.ComponentQuery`)**  
- Verified file;line: `public/ui/app/store/AuditHistoryStore.js:1` — `Ext.define('BackOfficeApp.store.AuditHistoryStore', { extend: 'Ext.data.Store'`  
- **Sencha Ext JS — window component \+ static helper**  
- Verified file;line: `public/ui/app/view/audithistory/AuditHistoryPanel.js:1-2` — `Ext.define('BackOfficeApp.view.audithistory.AuditHistoryPanel', { extend: 'Ext.window.Window'`  
- **Sencha Ext JS — ViewController handler wiring**  
- Verified file;line: `public/ui/app/view/orders/OrdersController.js:1368` — `openAuditHistoryPanel: function () { Ext.ComponentQuery.query('audit-history-panel')[0].create().show(); }`  
- **Sencha Ext JS — toolbar button config objects (`xtype: 'button'`, `handler: '<controller method name>'`)**  
- Verified file;line: `public/ui/app/utils/Renderers.js:190` (`getOrdersTools`), button at `:374-379`

No React/Vue/Angular artefacts are present in these files. Framework confirmed directly from source, not from `scope.md`.

---

### Section 5 — Required frontend changes (input for Step 3.7 prompt-writer)

Verified fact: `AuditHistoryPanel.assembleDescription()` (`public/ui/app/view/audithistory/AuditHistoryPanel.js:74-104`) branches on `operationType` only, and handles exactly six values — `'created'` (`:81`), `'imported'` (`:84`), `'updated'` (`:87`), `'order_type_updated'` (`:93`), `'deleted'` (`:96`), `'status_updated'` (`:99`). Anything else falls through to the generic fallback at **line 103**: `return entityLabel + ' ' + operationType;`.

**Consequences of. the four confirmed decisions, as they stand today:**

- **`operation_type = 'order_approval_updated'`, `entity_type = 'group'`**  
- Current FE result — verified: Falls through to `AuditHistoryPanel.js:103` — renders `group order_approval_updated` — a raw technical token, violating FE-1  
- FE change required: New branch needed  
- **`operation_type = 'receiving_orders_updated'`, `entity_type = 'group'`**  
- Current FE result — verified: Falls through to `AuditHistoryPanel.js:103` — renders `group receiving_orders_updated` — violates FE-1  
- FE change required: New branch needed  
- **`operation_type = 'order_status_updated'`, `entity_type = 'order_item'`**  
- Current FE result — verified: Falls through to `AuditHistoryPanel.js:103` — renders `order item order_status_updated` — violates FE-1  
- FE change required: New branch needed  
- **`operation_type = 'status_updated'`, `entity_type = 'store'`**  
- Current FE result — verified: **Does not fall through** — it matches the existing branch at `AuditHistoryPanel.js:99-102`, which hardcodes the string `'order item'` and an `of order #7 changed from 'Stopped' to 'Started'` — factually wrong text about the wrong entity.  
- FE change required: Existing branch at `:99` must be `entityType`\-aware (branch on `entity_type === 'store'` vs `'order_item'`)

All four rows are backend-driven and deterministic — no new stored data is needed to fix them (`entity_type`, `operation_type`, `old_value`, `new_value`, `subject_id` are all already returned by `AuditHistoryController.php:55-64` and declared in `AuditHistoryStore.js:20`). The exact display wording for the four new sentences is a Step 3.7 display-trace concern, not a storage decision.

**Decision \#4 (button placement) — verified as already satisfied, no change:** the “Audit History” button exists at `public/ui/app/utils/Renderers.js:374-379` (`text: 'Audit History'`, `role: 'audit-history'`, `handler: 'openAuditHistoryPanel'`), placed immediately after the “Expand All” button (`Renderers.js:358-373`, `role: 'expand-all'`) inside `getOrdersTools()` (`Renderers.js:190`). Its handler resolves to `OrdersController.js:1368`, which opens `AuditHistoryPanel`. Confirmed FINAL by Step 3 answer \#4 — no edit required.