# Business Logic Extract — Audit Log Feature

Only rules directly applicable to logging shop/store, customer group, and order item status operations. Source: `search_business_logic` calls against `docs/BUSINESS_LOGIC.md` (full file not read).

## Shops / Stores

- UI term "Shop" \== backend term "Store" (payment provider terminology). "Add Shop" in the UI triggers a `create store` call to the payment provider.  
- A new shop/store is saved locally as a `ProviderStore` record, initial status **Pending verification** — it cannot accept payments yet.  
- Completing verification (business documents \+ payout account) is what actually activates it; status becomes **Active**.  
- Close Shop: shop menu \-\> "Close Shop" \-\> confirm \-\> record disappears from the list. Reopening requires the standard Add Shop flow again (i.e. closing is a real removal, not an archive flag).  
- Shops list displays: Name, Payout account (on hover), Status (Active/Pending verification), Edit icon.

## Customer Groups

- Two distinct ways to add a group: **Create New** (brand-new group created in the Back Office) and **Import Existing** (importing a customer segment that already exists in the payment provider account — this is the "external group" path referenced in the meeting).  
- Create New fields: Group name, Members (customer IDs), Order Type (Retail / Wholesale / Retail & Wholesale), Receiving Orders (toggle), Order Approval (Automatically / Manually / Auto-approve on Tag).  
- Import Existing: fetches segments from the connected payment provider account, admin selects one or more, then applies the same Order Type / Receiving Orders / Order Approval settings to the selection.  
- Editable group-level parameters (relevant for "update" logging): Group name, Members, Order Type (`CustomerGroup.allowed_order_type`), Receiving Orders, Order Approval. Store name and payout account are read-only.  
- `CustomerGroup.allowed_order_type` controls which order types (Retail / Wholesale / both) the Importer accepts from that group — this is the field the meeting's group-update example ("order type changed from retail to retail and wholesale") refers to.  
- No explicit delete-group business logic section was returned by the search (0 results for that specific action) — will need `search_code` in Step 1c if delete-group mechanics matter for schema/implementation.

## Order Item Status

- Three possible statuses for an order item: **Pending** (grey), **Fulfilled** (green), **Cancelled** (red).  
- Constant name confirmed in docs: `ORDER_ITEM_STATUS_PENDING` — the auto-assigned status when required fields (SKU, quantity) are missing on API insert.  
- Manual actions available on a Pending item: **Fulfil**, **Cancel**. This matches the meeting's Cancel/Restore demo (Cancel: pending \-\> cancelled; Restore: cancelled \-\> pending).  
- Automatic fulfilment (if configured and stock is available) sets status directly to **Fulfilled**; otherwise status is **Pending** awaiting manual review.

## Not found in BUSINESS\_LOGIC.md

- No section on product history / audit log / audit trail exists in `docs/BUSINESS_LOGIC.md` — the product history lives in the separate reference project (`../reference-app`), not documented here. Its pattern must be read directly from that codebase per the meeting's explicit reference requirement.