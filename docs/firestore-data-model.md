# Firestore data model

Cloud Firestore is PayReview's authoritative financial-data store. Every user-owned document is scoped below `users/{uid}`. Money is stored as integer minor units, never as `Double` or `Float`.

## Ownership and access

```text
deletionRequests/{requestId}           Server-owned deletion status
users/{uid}/profile/main               User profile and preferences
users/{uid}/financialPlans/{planId}    Calculation assumptions
users/{uid}/incomeCycles/{cycleId}     Income-cycle dates and amount
users/{uid}/goals/{goalId}             Protected savings goals
users/{uid}/plannedExpenses/{expenseId} Expected essential expenses
users/{uid}/flexibleBudgets/{budgetId} Flexible allocation per cycle
users/{uid}/categories/{categoryId}    Income and expense categories
users/{uid}/tags/{tagId}               User-defined labels
users/{uid}/transactions/{transactionId} Confirmed income and expense records
users/{uid}/transfers/{transferId}     Transfers, excluded from income and expense totals
users/{uid}/decisionSnapshots/{snapshotId} Confirmed calculation evidence
users/{uid}/deferredPurchases/{purchaseId} Preserved deferred decisions
```

Firebase Authentication is the MVP access boundary. Firestore Rules allow a user to access only documents under their authenticated `users/{uid}` path. `deletionRequests` is reserved for a future server-managed account-deletion workflow.

## Shared document fields

All user-owned documents include:

| Field | Type | Purpose |
| --- | --- | --- |
| `schemaVersion` | integer | Enables future migrations. |
| `createdAt` | Firestore timestamp | Creation time. |
| `updatedAt` | Firestore timestamp | Last update time. |
| `source` | string enum | `manual`, `import`, `shareText`, or `screenshot`. |

## Financial representations

| Field pattern | Firestore type | Rule |
| --- | --- | --- |
| `amountMinorUnits` | integer | Currency amount in the smallest unit. |
| `currencyCode` | string | ISO 4217 currency code, initially `TWD`. |
| `occurredAt`, `targetDate` | timestamp | Stored in UTC; views format using the user's calendar and time zone. |
| `categoryId`, `tagIDs` | string, string array | References remain within the same user scope. |

`Transaction` documents have `kind` of `income` or `expense`. Transfers use the separate `transfers` collection and are never included in income, expense, frequency, or safe-to-spend calculations. A transaction can contain `plannedExpenseOccurrenceID`; the confirmation transaction must atomically mark that occurrence complete so it cannot be deducted twice.

## Required records for the first test screen

The synthetic test snapshot includes one financial plan, one income cycle, one flexible budget, four categories, one goal, two planned expenses, two confirmed expense transactions, one confirmed income transaction, and one transfer. It intentionally contains no merchant names, real user IDs, notes, or live Firebase data.

## Delivery sequence

1. Deploy the included Firebase Authentication UID-scoped Firestore rules.
2. Implement Firestore DTOs that map minor units and timestamps to the domain models.
3. Enable repository reads after Firebase Authentication resolves an authenticated session.
4. Add idempotent transaction confirmation, planned-expense completion, offline rollback, and Emulator tests before enabling writes.
