# PayReview decision rules

## Terms

- `flexibleBefore`: flexible allocation minus confirmed flexible spending in the active period.
- `proposedAmount`: the final verified payment for the evaluated purchase.
- `flexibleAfter`: `flexibleBefore - proposedAmount`.
- `protectedReserve`: essential planned expenses plus minimum protected goal contributions before the next income date.
- `availableBuffer`: the safety buffer amount that the user has explicitly allowed for this scenario.

When planned expenses are ranges, calculate both conservative and optimistic outcomes:

```text
safeToSpendLow = max(0, availableFunds - plannedExpenseMaximum - protectedGoalContribution)
safeToSpendHigh = max(0, availableFunds - plannedExpenseMinimum - protectedGoalContribution)
```

Display the result as an estimate or range and retain the inputs. Do not present it as a guarantee.

## Status classification

```text
if proposedAmount <= flexibleBefore:
    status = within_flexible
else if proposedAmount <= flexibleBefore + availableBuffer:
    status = uses_buffer
else:
    status = requires_plan_change
```

The middle status is valid only when the buffer is explicitly available to the scenario. Do not infer permission to use a buffer or goal fund.

## Required scenarios

### Pay from flexible budget

Show the remaining flexible allocation and safe-to-spend range. A negative `flexibleAfter` represents a shortfall, not spendable money.

### Protect the goal date

Keep the protected goal contribution unchanged. Calculate the exact discretionary reduction or later-period shift needed to cover any shortfall. Offer the recovery action; do not apply it.

### Use goal funds

Calculate this only after the user actively selects the scenario. Recalculate the savings pace from the reduced goal balance or contribution. Show a delay only when the target date actually changes.

Never state that every unplanned expense delays a goal. If flexible funds cover the purchase, the goal remains unchanged.

## Frequency

Count only confirmed expense transactions in the configured window and category. Exclude transfers, scenarios, deferred purchases, skipped decisions, and deleted or reversed transactions.

If the category is absent or the history does not meet the product's configured sufficiency threshold, return:

```text
資料不足，尚未計算頻率。
```

The rolling-window choice remains a product configuration. Do not hard-code 30 days until the owner resolves that decision.

## Price option

```text
merchandiseSubtotal = basePrice * quantity
discountedSubtotal = merchandiseSubtotal * (1 - percentageDiscountRate) - fixedDiscount
finalPayment = max(0, discountedSubtotal - couponAmount) + shipping + requiredFees
unitPrice = finalPayment / comparableQuantity
```

Allow the user to override and confirm `finalPayment`. Compare final payment only for the same quantity and specification. Compare unit price for different sizes with the same unit. Treat different variants or missing units as non-comparable.

Do not assign automatic value to points, cashback, gifts, installment benefits, membership conditions, or complex thresholds. Preserve these as notes unless the user supplies a verified final payment.

## Output contract

```text
DecisionCard
  status: within_flexible | uses_buffer | requires_plan_change | insufficient_data
  headline: neutral localized text
  flexible_budget_before: money
  flexible_budget_after: money
  safe_to_spend_range: money range
  price_action: optional verified comparison
  frequency_insight: count and window | insufficient data
  goal_effect: unchanged | needs_recovery | delayed_by_user_choice
  recovery_options: zero or more explicit actions
  assumptions: values, dates, freshness, and uncertainty
  rule_version: identifier
  decision_snapshot_id: identifier
```

## Example

Given `flexibleBefore = NT$680` and `proposedAmount = NT$600`, return `within_flexible` with `flexibleAfter = NT$80`. If protected goal contributions remain fully reserved, return `goal_effect = unchanged`. A valid optional recovery explanation is that preserving the original NT$680 of flexibility would require reducing other discretionary spending by NT$600 over a stated period; do not confuse that preference with a required goal recovery.
