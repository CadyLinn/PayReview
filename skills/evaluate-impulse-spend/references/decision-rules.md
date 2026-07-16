# PayReview decision rules

## Terms

- `availableFunds`: funds available before the next income date after confirmed transactions but before remaining planned expenses and protected goal contributions, excluding unconfirmed future income and any separately approved safety buffer.
- `flexibleBefore`: flexible allocation minus confirmed flexible spending in the active period.
- `proposedAmount`: the final verified payment for the evaluated purchase.
- `flexibleAfter`: `flexibleBefore - proposedAmount`.
- `protectedReserveLow`: planned-expense minimums plus minimum protected goal contributions before the next income date.
- `protectedReserveHigh`: planned-expense maximums plus minimum protected goal contributions before the next income date.
- `availableBuffer`: a safety-buffer amount that the user has explicitly allowed for this scenario and that does not overlap available funds, planned expenses, protected goal contributions, or goal funds.

When planned expenses are ranges, calculate both conservative and optimistic outcomes:

```text
safeToSpendLow = max(0, availableFunds - protectedReserveHigh)
safeToSpendHigh = max(0, availableFunds - protectedReserveLow)
classifiedSpendableBefore = min(max(0, flexibleBefore), safeToSpendLow)
classifiedSpendableAfter = classifiedSpendableBefore - proposedAmount
```

Display the safe-to-spend result as an estimate or range and retain the inputs. Use `classifiedSpendableBefore` for status classification so the conclusion never exceeds either the remaining flexible allocation or the conservative funds left after protected obligations. Do not present either bound as a guarantee.

## Status classification

```text
if required inputs are missing, stale, or internally inconsistent:
    status = insufficient_data
else if proposedAmount <= classifiedSpendableBefore:
    status = within_flexible
else if proposedAmount <= classifiedSpendableBefore + availableBuffer:
    status = uses_buffer
else:
    status = requires_plan_change
```

The middle status is valid only when the buffer is explicitly available to the scenario and is not already counted elsewhere. Do not infer permission to use a buffer or goal fund. Do not upgrade a conservative result using `safeToSpendHigh`; uncertainty must not produce a more permissive status.

## Required scenarios

### Pay from flexible budget

Show the remaining flexible allocation and safe-to-spend range. A negative `flexibleAfter` represents a shortfall, not spendable money.

### Protect the goal date

Keep the protected goal contribution unchanged. Calculate the exact discretionary reduction or later-period shift needed to cover any shortfall. Offer the recovery action; do not apply it.

### Use goal funds

Calculate this only after the user actively selects the scenario. Recalculate the savings pace from the reduced goal balance or contribution. Show a delay only when the target date actually changes.

Never state that every unplanned expense delays a goal. If `classifiedSpendableBefore` covers the purchase, the goal remains unchanged.

## Frequency

Count only confirmed expense transactions in the configured window and category. Exclude transfers, scenarios, deferred purchases, skipped decisions, and deleted or reversed transactions.

If the category is absent or the history does not meet the product's configured sufficiency threshold, return:

```text
資料不足，尚未計算頻率。
```

The rolling-window choice remains a product configuration. Do not hard-code 30 days until the owner resolves that decision.

## Output contract

```text
DecisionCard
  status: within_flexible | uses_buffer | requires_plan_change | insufficient_data
  headline: neutral localized text
  flexible_budget_before: money
  flexible_budget_after: money
  classified_spendable_before: money
  classified_spendable_after: money
  safe_to_spend_range: money range
  frequency_insight: count and window | insufficient data
  goal_effect: unchanged | needs_recovery | delayed_by_user_choice
  recovery_options: zero or more explicit actions
  assumptions: values, dates, freshness, and uncertainty
  rule_version: identifier
  decision_snapshot_id: identifier
```

## Example

Given `flexibleBefore = NT$680`, `safeToSpendLow = NT$680`, and `proposedAmount = NT$600`, return `within_flexible` with `flexibleAfter = NT$80`. If `safeToSpendLow` is only NT$500, classify the same purchase as `requires_plan_change` unless a separate, explicitly approved buffer covers the NT$100 shortfall. If protected goal contributions remain fully reserved, return `goal_effect = unchanged`. A valid optional recovery explanation is that preserving the original NT$680 of flexibility would require reducing other discretionary spending by NT$600 over a stated period; do not confuse that preference with a required goal recovery.
