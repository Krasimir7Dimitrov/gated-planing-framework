# Business Logic - [Your Project Name]

> Template. Copy to `docs/BUSINESS_LOGIC.md` (or the path set in `businessLogicPath`
> in `framework.config.json`) and replace the example content with your own domain.
>
> The `search_business_logic` MCP tool splits this file by Markdown headings and
> scores each section by keyword matches, so:
> - keep one rule or concept per '##' / '###' section;
> - put the words people will search for in the heading;
> - prefer short, concrete statements over long prose.
>
> Everything below is a fictional example (a small online shop).

## System Overview

The shop sells physical products. Customers place **Orders**; each Order contains one or more **OrderItems**. Staff manage products, discounts and order statuses in the primary project (back office). The secondary project is a public API used by the storefront.

## Orders

### Order statuses

An Order moves through these statuses, in this order only:

| Status | Meaning |
| --- | --- |
| `new` | Created by the customer, not yet paid |
| `paid` | Payment confirmed by the payment provider |
| `shipped` | Handed over to the courier |
| `cancelled` | Cancelled by the customer or staff - terminal |

- An Order can be cancelled only while it is `new` or `paid`.
- A `shipped` Order can never return to an earlier status.

### Order totals

- The Order total is the sum of all OrderItem line totals minus applied discounts.
- Totals are stored in minor units (cents) as integers - never as floats.

## Order Items

- An OrderItem references exactly one product and stores the unit price **at the time of purchase**. Later product price changes never affect existing items.
- Quantity must be a positive integer.

## Discounts

### Discount codes

- A discount code (e.g. `discount-10`) gives a fixed percentage off the Order total.
- Only one discount code can be applied per Order.
- An expired or disabled code is rejected with a validation error - it is never silently ignored.

### Discount audit log

Every change to a discount code (created, enabled, disabled, percentage changed) is recorded in the audit log with: operation type, discount ID, old value, new value, the staff user who made the change, and a timestamp. The human-readable sentence shown in the UI (e.g. "discount-10 was added") is built by the frontend from these fields - it is not stored.

## Integrations

### Payment provider

- Payment confirmation arrives via webhook. The webhook handler must be idempotent: receiving the same event twice must not change the Order twice.

### Courier notifications

- When an Order becomes `shipped`, the courier API is notified. If the courier host parameter is empty, no request is sent (no-op).