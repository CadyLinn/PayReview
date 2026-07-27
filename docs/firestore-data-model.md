# Firestore data model (v1 — pure ledger)

Cloud Firestore is PayReview's authoritative financial-data store. Every user-owned document is scoped below `users/{uid}`. Money is stored as integer minor units, never as `Double` or `Float`.

This v1 scope covers pure bookkeeping only: transactions and a derived balance. Category is not a managed entity in v1 — there is no `categories` collection, no `Category` domain model, and no category CRUD screen. Each transaction instead carries a free-text `categoryLabel` for lightweight grouping, aggregated client-side when needed. Everything else that was previously planned here (financial plans, income cycles, goals, planned expenses, flexible budgets, tags, transfers, decision snapshots, deferred purchases, structured categories, and the account-deletion job queue) has been deferred, not deleted. See `docs/deferred-v2-scope.md` for what was cut and why, and when to bring each piece back.

## Ownership and access

```text
users/{uid}/profile/main               User profile and preferences
users/{uid}/transactions/{transactionId} Confirmed income and expense records
```

Firebase Authentication is the v1 access boundary. Firestore Rules allow a user to access only documents under their authenticated `users/{uid}` path. The rules already in `firebase/firestore.rules` cover this and do not need to change for v1.

## Shared document fields

All user-owned documents include:

| Field | Type | Purpose |
| --- | --- | --- |
| `schemaVersion` | integer | Enables future migrations. |
| `createdAt` | Firestore timestamp | Creation time. |
| `updatedAt` | Firestore timestamp | Last update time. |
| `source` | string enum | `manual` for v1. Kept from the original model so `import`/`shareText`/`screenshot` can be added later without a schema migration. |

## Financial representations

| Field pattern | Firestore type | Rule |
| --- | --- | --- |
| `amountMinorUnits` | integer, signed | Currency amount in the smallest unit. Positive = income, negative = expense. Never `Double`/`Float`. |
| `currencyCode` | string | ISO 4217 currency code, initially `TWD`. |
| `occurredAt` | timestamp | Stored in UTC; views format using the user's calendar and time zone. |
| `categoryLabel` | string, optional | Free-text label for grouping. No cross-collection reference — this is intentional, see below. |

## `Transaction`

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | Firestore document ID |
| `amountMinorUnits` | integer, signed | Positive = income, negative = expense. No separate `kind` field — the sign carries that information. |
| `currencyCode` | string | |
| `categoryLabel` | string, optional | Free text, not a reference. See below for why. |
| `occurredAt` | timestamp | |
| `note` | string, optional | |
| `source` | string enum | `manual` for v1 |
| `schemaVersion` | integer | |
| `createdAt` / `updatedAt` | timestamp | |

There is no `plannedExpenseOccurrenceID` or transfer linkage in v1 — those depended on collections that are deferred.

## Why `categoryLabel` instead of a `Category` collection

A structured `Category` entity was in the original plan but was dropped for v1: it adds a whole collection, a repository, and a create/select/rename/delete UI for something a free-text field on `Transaction` already covers. The tradeoff was checked against Firestore's read-based billing model — as long as category totals are computed by grouping the transactions you already fetched for the ledger view (e.g. `Dictionary(grouping:)` in Swift), there is no extra read cost. Extra cost would only appear if the app queried Firestore once per category instead of aggregating locally, or if it fetched unbounded history instead of a date-scoped range. Neither is necessary here.

If v2 later needs managed categories (rename across historical transactions, merge, delete-with-reassignment), that is the point to introduce a real `Category` collection — not before.

## Balance

Balance is not a stored field. It is a derived value computed on the client as `sum(transaction.amountMinorUnits)` across the relevant transactions — no filtering by kind is needed since the sign already encodes income vs. expense.

## Data access pattern

`transactions` is exposed through a single repository with one real-time stream, scoped to whatever date range the current view needs (e.g. current month). Category breakdowns are computed client-side by grouping that same in-memory data by `categoryLabel` — no second query per category.

## Required records for the first test screen

A minimal fixture for manual/UI testing should include three transactions (one income, two expense) using free-text `categoryLabel` values (e.g. `"薪資"`, `"餐飲"`, `"交通"`), with no merchant names, real user IDs, or live Firebase data.

## Delivery sequence

1. Keep the existing Firebase Authentication UID-scoped Firestore rules (`firebase/firestore.rules`) — no change needed for v1.
2. Implement the `Transaction` domain model and Firestore DTOs that map minor units and timestamps to the domain model.
3. Enable repository reads after Firebase Authentication resolves an authenticated session.
4. Add offline rollback handling and Emulator tests before enabling writes.
