---
name: evaluate-impulse-spend
description: Evaluate a proposed or unplanned purchase for 花算 PayReview before it becomes a transaction. Use when implementing, testing, reviewing, or explaining quick spend evaluation, impulse-spend reminders, opportunity cost, safe-to-spend amounts, savings-goal timing, recovery options, Decision Cards, or purchase/defer/skip flows.
---

# Evaluate Impulse Spend

Produce a neutral, auditable pre-spend result. Never decide for the user and never create a confirmed transaction during evaluation.

## Load the rules

Read [references/decision-rules.md](references/decision-rules.md) before calculating, implementing, or testing an evaluation. Treat those rules as the domain contract.

## Gather inputs

Gather the minimum available data:

- Proposed amount, currency, evaluation time, and time zone.
- Optional category and purchase intent.
- Flexible-budget period, allocation, and confirmed spending.
- Essential planned expenses remaining before the next income date.
- Protected goal contributions and explicitly available safety buffer.
- Goal target date, current saved amount, required remaining amount, and current minimum savings pace.
- Data freshness, uncertain amounts, and rule version.

Do not require a category for quick evaluation. If required financial data is missing, return `insufficient_data` with the missing fields instead of estimating silently.

## Evaluate in order

1. Validate currency, non-negative amounts, and date boundaries.
2. Reserve essential planned expenses and protected goal contributions.
3. Calculate flexible budget before and after the proposed purchase.
4. Calculate a conservative safe-to-spend range from uncertain planned amounts.
5. Cap the classifiable spendable amount at the lower of remaining flexible allocation and the conservative safe-to-spend bound.
6. Return `insufficient_data` when required inputs are missing, stale, or inconsistent; otherwise classify the result as `within_flexible`, `uses_buffer`, or `requires_plan_change`.
7. Calculate the localized target date and time remaining for the protected goal.
8. Evaluate the three scenarios: pay from flexible budget, protect the goal date, and purchase without recovery or use goal funds.
9. For `requires_plan_change`, calculate the projected completion date and delay in whole days for the no-recovery scenario.
10. Produce practical recovery options without changing the plan automatically.
11. Preserve all inputs, assumptions, data freshness, and the calculation-rule version in a `DecisionSnapshot`.

## Write the Decision Card

Lead with one calm conclusion. Then answer:

1. Budget impact: before and after amounts for the relevant periods.
2. Goal impact: target date, time remaining, unchanged status, recovery needed, or projected delayed date and days.

When the amount exceeds `classifiedSpendableBefore`, lead with a calm `超出預算` warning. If the no-recovery scenario misses the target, show the calculated delayed date and whole-day delay as a projection.

Include at least one recovery option when the purchase reduces protected flexibility. Examples include reducing future discretionary spending by a stated amount, moving the purchase to a later income period, or explicitly changing the plan.

Use language such as `可以購買，但會壓縮本週的彈性空間`. Do not use shame, urgency, streaks, rewards for skipping, or claims such as `你不該買`.

## Keep evaluation separate from bookkeeping

- Keep `SpendScenario` temporary and local.
- Save a private defer or skip decision only after the user chooses it.
- Create a `Transaction` only after `Purchase and record` confirmation.
- When a transaction fulfills a planned expense occurrence, complete that occurrence and prevent duplicate deduction.
- Never mutate a goal date, contribution, or future budget without explicit confirmation.

## Implement safely

- Use `Decimal` for currency. Do not use `Double` or `Float`.
- Use `Calendar` with an explicit time zone for period boundaries.
- Keep calculations deterministic and independent of SwiftUI, persistence providers, and generated text.
- Keep user-facing explanations derived from typed calculation results.
- Write all source-code comments in English and use no emoji.
- Do not send raw amounts, merchant names, goal names, or notes to analytics.

## Verify

Test at minimum:

- Exact flexible-budget boundary and one currency unit above it.
- Zero, negative, very large, and fractional input behavior.
- Minimum and maximum planned-expense ranges.
- A flexible allocation above the conservative safe-to-spend bound without an affordability overstatement.
- Required goal target date, localized time remaining, goal unchanged, feasible recovery, explicit goal-fund use, and projected delay.
- An NT$1,000 over-budget scenario with a warning and a calculated delayed goal date when the no-recovery projection misses the target.
- Month end, leap day, daylight-saving change, and next-income-date boundary.
- A planned expense matched to a transaction without double deduction.
- Scenario evaluation without persistent budget mutation.

Report assumptions and failing cases. Do not weaken a rule to make a test pass.
