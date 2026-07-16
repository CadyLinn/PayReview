# PayReview Repository Agent Rules

This file defines the mandatory rules for AI agents and contributors working in this repository.

## 1. Instruction priority

Use the following sources in order:

1. The user's current explicit request.
2. This `AGENT.md` file.
3. [PRODUCT_PLAN_V0.2.md](PRODUCT_PLAN_V0.2.md) for product behavior, scope, copy, and brand direction.
4. [PRODUCT_LAUNCH_PLAN_V0.2.md](PRODUCT_LAUNCH_PLAN_V0.2.md) for onboarding, subscriptions, analytics, App Store preparation, and release operations.
5. [TECH_STACK.md](TECH_STACK.md) for technical direction after unresolved architecture decisions have been approved.
6. Feature specifications and tests.

Do not silently resolve a conflict between these sources. Report the conflict, identify the affected files, and request a product or architecture decision before implementing behavior that depends on it.

## 2. Product mission

Build PayReview as a pre-spend personal finance decision product, not merely a bookkeeping app.

The product must help the user understand before payment:

1. What changes if this purchase happens now.
2. Whether similar confirmed purchases have happened frequently.
3. How to make the purchase with the least disruption to the existing plan.
4. What recovery action can preserve the budget or goal.

Use the product promise:

> 花錢前，先算價格與影響。

Never shame the user, celebrate spending, block a purchase, or present the product as making the final decision for them.

## 3. Language and repository standards

- Write all source-code comments in English.
- Do not use emoji in source code, comments, identifiers, commit messages, release notes, or project documentation.
- Write user-facing Traditional Chinese copy in a calm, concise, and non-judgmental tone.
- Use consistent product terms from the product plan. Do not invent synonyms for financial states without updating the specification.
- Use Markdown for product and engineering documentation.
- Keep files focused. Link to the source document instead of duplicating long product specifications.
- Do not commit `.DS_Store`, secrets, generated credentials, local build output, or personal test data.
- Never log authentication tokens, exact financial content, private notes, merchant names, or personally identifiable information.

## 4. Product experience rules

### Today

- Make Today a financial navigation page, not a chart-heavy dashboard.
- Show safe-to-spend guidance, the next planned expense, one clear evaluation action, one goal state, and one useful observation.
- Keep `評估一筆消費` as the single dominant action. Do not hide it in a generic plus button or overflow menu.

### Evaluate

- Ask for the amount first. Keep category optional for quick evaluation.
- Show a clear conclusion before detailed cards.
- Answer price, budget, frequency, and goal impact when data is available.
- State that data is insufficient when a reliable result cannot be calculated.
- Offer `購買並記錄`, `晚點決定`, `略過`, and `調整計畫` after evaluation.

### Plan

- Treat income cycle, planned expenses, flexible budget, safety buffer, goals, and non-negotiable items as calculation assumptions.
- Show assumptions and allow the user to review or update them.

### Records

- Store confirmed transactions separately from evaluated scenarios.
- Support income, expense, transfer, category, date, note, and tags.
- Do not count a transfer as income or expense.
- When a transaction fulfills a planned expense occurrence, complete that occurrence and prevent duplicate deduction.

## 5. Financial calculation rules

- Implement all monetary and date calculations in a deterministic, testable `FinanceEngine` module.
- Keep `FinanceEngine` independent of SwiftUI, authentication, analytics, and cloud persistence.
- Use `Decimal` for currency. Never use `Double` or `Float` for money.
- Use `Calendar` with an explicit time zone for financial periods and target dates.
- Reserve essential and expected expenses before calculating flexible spending.
- Reserve the minimum contribution for protected goals before calculating safe-to-spend guidance.
- Present safe-to-spend as an estimate or range when inputs are uncertain. Never present it as a guarantee.
- Preserve calculation inputs, assumptions, data freshness, evaluation time, time zone, and rule version in `DecisionSnapshot`.
- Let AI explain calculated results only. Never let generated text invent, change, round independently, or override a financial result.

### Decision status

Use the following internal states unless the product specification is formally changed:

- `within_flexible`: the purchase fits the remaining flexible allocation.
- `uses_buffer`: the purchase exceeds flexible allocation but fits a buffer explicitly approved for this scenario.
- `requires_plan_change`: the purchase requires an explicit change to future discretionary spending, a contribution, or a goal date.
- `insufficient_data`: required inputs are unavailable or too stale for a reliable result.

Do not automatically label a purchase as impulsive because it exceeds the flexible budget. Use `規劃外` or `超出預算` in user-facing copy unless the user explicitly classifies their intent.

### Goal impact

- Keep the goal date unchanged when flexible funds cover the purchase.
- Show a recovery amount when future discretionary spending can preserve the goal.
- Calculate use of goal funds only after the user actively selects that scenario.
- Show a delayed goal date only when the user uses protected goal funds or the minimum savings pace can no longer reach the target date.
- Never mutate a goal contribution or target date without explicit confirmation.

### Spending frequency

- Count only confirmed expense transactions in the configured category and time window.
- Exclude transfers, evaluations, deferred purchases, skipped decisions, reversed transactions, and deleted transactions.
- Show `資料不足，尚未計算頻率。` when the category or history is insufficient.
- Do not hard-code a rolling window until the product owner confirms whether to use 30 days, the income cycle, or a user-configurable period.

### Price comparison

- Treat offers as manual, user-entered information. Do not claim an automatic market-wide lowest price.
- Compare final payment only for equivalent specifications and quantities.
- Compare unit price only when units are compatible.
- Flag different variants or missing units as non-comparable.
- Allow the user to review and override the final checkout amount.
- Do not assign automatic monetary value to points, cashback, gifts, installment benefits, or complex promotion conditions.

Use:

```text
merchandiseSubtotal = basePrice * quantity
discountedSubtotal = merchandiseSubtotal * (1 - percentageDiscountRate) - fixedDiscount
finalPayment = max(0, discountedSubtotal - couponAmount) + shipping + requiredFees
unitPrice = finalPayment / comparableQuantity
```

## 6. Scenario and transaction integrity

- Keep `SpendScenario` temporary and local until the user confirms an action.
- Never change the real budget, goal balance, or transaction history during evaluation.
- Create a `Transaction` only after `購買並記錄` confirmation.
- Save a deferred or skipped decision only after the user chooses to preserve it.
- Make confirmation operations idempotent so repeated taps or retries cannot create duplicate transactions.
- Store the selected `PriceOption` identifier in the scenario snapshot when comparison is used.
- Treat confirmed transactions as the source of truth for actual spending history.

## 7. iOS architecture rules

- Build the UI with SwiftUI and support the minimum iOS version approved by the team.
- Keep views declarative and free of financial calculations and direct database access.
- Use a feature state or view model layer for presentation behavior.
- Use repository protocols between features and persistence implementations.
- Isolate authentication, subscriptions, notifications, analytics, and storage behind service protocols.
- Use Swift Concurrency for asynchronous work and maintain actor isolation for mutable shared state.
- Respect the system Reduce Motion setting for launch, onboarding, Decision Card, and transaction animations.
- Support Dynamic Type, VoiceOver labels, sufficient contrast, and localized currency and dates.
- Do not add a third-party dependency when the platform API is sufficient.
- Document why a dependency is needed before adding it.

Recommended boundaries:

```text
App
Features
  Onboarding
  Today
  Evaluate
  PriceComparison
  Plan
  Records
  Settings
Core
  FinanceEngine
  Domain
  DesignSystem
Data
  Repositories
  LocalStore
  CloudStore
Services
  Authentication
  Subscription
  Notifications
  Analytics
Tests
```

## 8. Persistence and synchronization rules

- Keep anonymous trial data on device.
- Ask for explicit confirmation before migrating local trial data into an account.
- Maintain one authoritative synchronization source for signed-in financial data.
- Do not implement simultaneous CloudKit and Firestore bidirectional synchronization.
- Define conflict resolution, deletion propagation, retry behavior, and offline recovery before enabling cross-device sync.
- Keep unconfirmed scenarios local even when account sync is enabled.

### Architecture decision required

The current v0.2 documents do not yet establish one final cloud direction:

- `PRODUCT_PLAN_V0.2.md` describes SwiftData first and CloudKit later.
- `TECH_STACK.md` proposes Firestore for signed-in synchronization.

Do not start cloud synchronization implementation until the team records one decision: CloudKit, Firestore, or local-only for MVP. Update all affected documents in the same PR after the decision.

## 9. Authentication, privacy, and permissions

- Keep `先試用看看` available unless the product owner explicitly changes the requirement.
- Offer Sign in with Apple when third-party sign-in such as Google is offered on iOS.
- Do not request notification, financial account, photo, contact, location, camera, or marketing permission during sign-in.
- Explain a permission immediately before showing the system prompt.
- Request notification permission only after the user enables a reminder.
- Request photo access only when the user actively chooses a future screenshot-import feature.
- Keep core MVP evaluation usable without bank or payment-account connections.
- Provide privacy policy, terms, support, data export, and account deletion in Settings.
- If accounts can be created, let users initiate deletion of the complete account and associated data from inside the App.
- Do not use an email-only or generic form-only flow as account deletion.
- Tell subscribed users that deleting an account does not automatically cancel an Apple-managed subscription, and provide subscription management access.
- Keep App, website, App Store metadata, privacy labels, policies, and FAQ consistent in the same release.

## 10. Subscription rules

Use StoreKit 2 as the source of App Store entitlement state.

Current proposed plans:

| Plan | Price | Trial |
| --- | ---: | --- |
| Annual | NT$800 per year | Seven days for eligible users |
| Monthly | NT$120 per month | No trial by default |

- Treat these as proposed configuration until the product owner confirms the paid feature boundary.
- Display the localized StoreKit price rather than hard-coding display prices in production UI.
- Before purchase, show the product value, billing period, trial eligibility, conversion price, renewal behavior, and cancellation path.
- Support purchase restoration and entitlement refresh.
- Do not unlock access from a local purchase-success flag alone.
- Do not claim that every user is eligible for a free trial.

## 11. Analytics and diagnostics

Define every event by the product question it answers. Do not add events merely because a screen or button exists.

Use this Activation definition unless formally changed:

> The user completes initial financial setup and views the first Decision Card.

Approved event families include:

- Acquisition: concept-page and waitlist conversion.
- Activation: onboarding completion and first Decision Card.
- Retention: sessions, repeated evaluations, and plan maintenance.
- Revenue: paywall, trial, subscription, restoration, and entitlement state.
- Referral: voluntary sharing, recommendation intent, and rating prompts.

- Do not send exact financial amounts to analytics.
- Do not send merchant names, goal names, notes, custom tag text, email addresses, or full snapshots.
- Use reviewed ranges, enums, and booleans instead of raw financial values.
- Choose one primary product analytics SDK and one primary crash-reporting SDK for MVP.
- Scrub financial and authentication data from errors, breadcrumbs, and logs.
- Update privacy disclosures before shipping a new SDK or event payload.

## 12. Testing requirements

Add or update tests whenever changing money, dates, goals, allocation, persistence, or transaction confirmation.

FinanceEngine tests must cover:

- Zero, negative, fractional, and very large amounts.
- Exact flexible-budget boundary and the smallest supported unit above it.
- Planned-expense minimum and maximum ranges.
- `within_flexible`, `uses_buffer`, `requires_plan_change`, and `insufficient_data`.
- Goal unchanged, feasible recovery, explicit goal-fund use, and actual delay.
- Month end, year end, leap day, time-zone change, and next-income-date boundaries.
- Comparable and non-comparable price options.
- Insufficient and sufficient frequency history.
- Planned-expense matching without double deduction.
- Repeated confirmation without duplicate transaction creation.

Feature and integration tests must cover:

- Guest onboarding and first Decision Card.
- Sign-in and explicit local-data migration.
- Offline evaluation and recovery after reconnecting.
- Purchase, defer, skip, and adjust-plan flows.
- Data export and account deletion entry points.
- Subscription purchase, restore, expiry, and entitlement refresh.
- Reduce Motion and critical accessibility paths.

Do not weaken a product rule to make a test pass. Fix the implementation or update the approved specification first.

## 13. Git and pull request rules

- Create a feature branch for changes unless the user explicitly requests a direct `main` update.
- Never merge, rebase, force-push, submit, publish, or delete a branch without explicit authorization.
- Keep commits focused and use clear imperative commit messages.
- Do not include unrelated local files or user changes in a commit.
- Run `git diff --check` before committing.
- Run relevant tests and report what was not run.
- Use a pull request to expose product decisions, architecture conflicts, migrations, privacy changes, and release risk.
- Require review before merging changes to financial rules, authentication, synchronization, subscriptions, privacy, analytics, or release automation.
- Prefer Squash and merge after required approvals and blocking comments are resolved.

## 14. Release rules

Use [skills/payreview-release-check/SKILL.md](skills/payreview-release-check/SKILL.md) before TestFlight external testing, App Store submission, preorder activation, or production release.

- Report each release item as `pass`, `block`, or `not applicable`.
- Set the release decision to `NO-GO` when financial integrity, privacy, account deletion, security, subscription disclosure, review access, or a critical crash is blocked.
- Provide a working review account with representative test data when full functionality requires login, or an approved full-feature demo mode.
- Keep support, privacy policy, terms, FAQ, and account-deletion URLs live before submission.
- Generate and review third-party notices after dependency changes.
- Preserve required license and copyright text, including complete MIT notices.
- Treat preorder and App Store featuring as optional launch tactics, not guaranteed ranking or exposure.
- Require explicit product-owner approval before uploading a build, submitting for review, enabling preorder, nominating for featuring, or releasing publicly.
- Verify current official Apple requirements at execution time because App Store rules change.

## 15. Agent workflow

For every implementation task:

1. Read the relevant source documents and nearby code before editing.
2. Identify whether the task depends on an unresolved product or architecture decision.
3. State assumptions when they affect behavior, data, privacy, or scope.
4. Make the smallest coherent change that satisfies the approved requirement.
5. Keep calculation, UI, persistence, and analytics responsibilities separated.
6. Add or update tests proportional to risk.
7. Run formatting, static checks, tests, and `git diff --check` when available.
8. Review the final diff for unrelated files, secrets, financial data, and accidental behavior changes.
9. Report the outcome, files changed, verification performed, and any remaining decision or risk.

Stop and ask for direction when a missing decision would materially change financial behavior, cloud architecture, paid access, collected data, account deletion, or release scope.

## 16. Specialized skills

- Use [skills/evaluate-impulse-spend/SKILL.md](skills/evaluate-impulse-spend/SKILL.md) for implementing, testing, or reviewing pre-spend evaluation and Decision Cards.
- Use [skills/payreview-release-check/SKILL.md](skills/payreview-release-check/SKILL.md) for TestFlight and App Store release readiness.

These Skills provide workflows. They do not override this file or the approved product documents.
