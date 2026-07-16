# 花算 PayReview Project Agent v0.2

## Instruction scope

This file is the repository-level source of truth for product and engineering agents working on PayReview. Apply it to product specifications, Swift code, tests, analytics, website copy, App Store material, and release work. If an implementation request conflicts with a financial safety, privacy, or data-integrity rule here, stop and report the conflict before changing the product.

## Product definition

**花算 PayReview** is a pre-spend personal finance decision app, not only a bookkeeping app.

Its promise is:

> 花錢前，先算清楚價格與影響。

Before a user pays, the product explains how a possible purchase changes their remaining budget, recent spending frequency, savings goal, and available lower-price options. It does not shame, block, or decide for the user.

The name combines the sound of 「划算」 with 「花」 to express that every expense is worth calculating before payment. `PayReview` means reviewing a payment against the user's current financial plan. Trademark, domain, and App Store name clearance remain required before public launch.

## Product principles

1. **Decision before recording**

   Evaluate a proposed expense before creating a confirmed transaction.

2. **No guilt, only trade-offs**

   Explain opportunity cost and recovery options without labeling a user irresponsible or telling them they cannot buy something.

3. **Minimal setup, immediate value**

   Initial setup must take two to four minutes. Do not require bank credentials, a salary slip, or a complete historical ledger.

4. **Rules calculate; language explains**

   A deterministic, testable finance engine calculates all money, dates, and thresholds. Any AI writing layer may rephrase completed calculations but must never invent a number or conclusion.

5. **Privacy by default**

   Request only the permission needed for the action the user just chose. Do not read LINE, banking, credit-card, or payment-app notifications in version one.

6. **Explain every number**

   Decision results must retain their inputs, assumptions, calculation date, and calculation-rule version.

## App information architecture

| Page | User question | Primary content |
| --- | --- | --- |
| Today | What do I need to know now? | safe-to-spend amount, next planned expense, goal status, useful observation, evaluate-spend entry point |
| Evaluate | If I buy this, what changes? | quick evaluation, manual price comparison, Decision Card, purchase or defer actions |
| Plan | What have I committed to? | income cycle, planned expenses, flexible budget, safety buffer, goals, non-negotiable items |
| Records | What actually happened? | income, expense, transfer, categories, tags, notes, price comparisons, deferred and skipped decisions |
| Settings | How is my account and data managed? | sign-in, subscription, notifications, privacy, export, account deletion, support |

The Today page must have one dominant action: **Evaluate a spend**. Do not hide it in a menu or a generic plus button.

The Today page is financial navigation, not a chart-heavy dashboard. Order content as safe-to-spend amount, today's expected expense with completion actions, the dominant evaluation action, one goal status, and one useful observation. Keep pie charts and broad reporting out of the first release.

## Launch and sign-in flow

1. Draw the icon transition for no more than 0.8 seconds and respect Reduce Motion.
2. Open Today immediately when a usable local financial plan exists.
3. Otherwise show the welcome screen with the title `付錢前，先看影響。`
4. Offer Sign in with Apple, Google Sign-In, and `先試用看看`, in that order.
5. Create local guest data for trial use. Request sign-in only for backup, device migration, cross-device sync, or an account-only feature.

Never combine sign-in with notification permission, financial-account permission, or marketing consent.

## Brand and interface direction

Keep the product calm, practical, and gently encouraging. It should feel like a clear-minded friend who explains trade-offs, not a bank back office or a judge.

- Use deep ink green or dark blue-green for trust and focus.
- Use soft mint or teal for safe-to-spend and on-track states.
- Use warm amber for trade-offs. Reserve red for actual risk.
- Prefer large monetary values, generous space, and one primary action per screen.
- Use an icon based on a coin boundary opening into a forward path. Do not use currency symbols, piggy banks, rising charts, mascots, or text in the app icon.
- Animate the path, onboarding progress, Decision Card sequence, and confirmed amount movement without celebrating spending.
- Respect the system Reduce Motion setting in every animation.

## Onboarding and interactive teaching

### Required first-run flow

The onboarding flow should feel like a guided conversation rather than a long form. It must collect the minimum financial model in this order:

1. **Goal**

   Ask what the user wants to protect or reach. Collect a name, target amount, current saved amount, target date, and priority: `protected`, `important`, or `adjustable`. If the user cannot name a goal, create an editable `Safety Buffer` goal.

2. **Income cycle**

   Collect income cadence, next income date, and estimated disposable income after mandatory deductions. Do not ask for employer, bank account, or salary detail.

3. **Planned fixed expenses**

   Offer templates for rent, transit, lunch, subscriptions, bills, and other. Each expense has an estimated amount or range, frequency or remaining occurrences, date, and essential flag. Support daily and monthly occurrences.

4. **Flexible budget**

   Ask how much the user wants to reserve each week or month for discretionary choices, interests, entertainment, and planned-expense overage. Let them choose gentle or direct reminder tone.

5. **Ready state**

   Show a transparent estimate such as: “Before the next income date, about NT$680 is available after planned expenses and goals.”

Do not add an onboarding step that asks a user to define “impulse spending.” It is a decision-time state, not financial setup input. Offer optional intent labels when evaluating a purchase: `necessary`, `planned`, or `unplanned`.

### Interactive tutorial content

Before setup, show a short, skippable teaching sequence:

1. **Plan what matters**: goals, fixed expenses, and flexible budget form a usable plan.
2. **Evaluate before paying**: enter an amount to see budget and goal effects before recording the purchase.
3. **Compare real offers**: enter prices and promotions seen in different stores; the app calculates final payment and unit price.
4. **Keep control of data**: no bank login is required; data export and account deletion are always available.

Use the same approved explanation in the app, official website, App Store listing, privacy policy, and support FAQ. Maintain a single reviewed source of product copy; changes to data collection, permissions, pricing, or core functionality must update every public surface in the same release.

### Permission education

- Explain a permission in an in-app screen immediately before the system prompt.
- Request notification permission only after the user enables an app reminder. Explain that it is used for deferred purchases, planned expenses, and goal reminders.
- Do not request financial-account, contact, location, camera, or photo-library access during onboarding.
- If screenshot import is added later, explain that the image is used only to extract a price for confirmation and request photo access only at that moment.

## Account, storage, and privacy

### Authentication

- Support **Sign in with Apple** and **Google Sign-In** through Firebase Authentication.
- Keep **Try without an account** available. Trial data stays on the device until the user chooses backup, cross-device sync, or an account-only feature.
- Do not request notification permission, marketing consent, or financial data as a condition of sign-in.

### Storage model

- Use **Cloud Firestore** as the cloud source of truth for signed-in financial data.
- Use Firestore offline persistence and a local `FinanceEngine` so the core evaluation remains usable without a network connection.
- Keep temporary `SpendScenario` calculations local until the user confirms an action.
- Use local storage for anonymous trial data and offer an explicit, confirmed migration after account creation.
- iCloud device backup may preserve local app data where the user has enabled iCloud Backup. Do not use CloudKit as a second synchronization source alongside Firestore; it would create conflicting sources of truth.

### Data control

- Provide in-app data export.
- Provide an in-app **Delete account** entry point. A secure webpage may complete the confirmed deletion flow, but an email-only or contact-form-only request is insufficient.
- Deletion must remove Firebase Authentication identity, Firestore documents, and user files in Firebase Storage within the stated retention period.
- Show the privacy policy, terms, data-export action, deletion action, and support contact in Settings.

## Subscription model

Use StoreKit 2 for App Store subscription purchase, entitlement status, restoration, and subscription-management links.

| Plan | Price | Trial | Rule |
| --- | ---: | --- | --- |
| Annual | NT$800 per year | Seven days | Trial is available only to eligible users and renews annually after the trial unless cancelled. |
| Monthly | NT$120 per month | No trial by default | Renews monthly unless cancelled. |

Before purchase, clearly show the plan, price, billing period, trial eligibility, renewal behavior, cancellation path, and what paid access unlocks. Do not present a trial as free when it converts to a paid subscription without this disclosure.

## Financial model and decision rules

### Four layers

| Layer | Contains | Main question |
| --- | --- | --- |
| Personal Financial Model | income cycle, accounts, fixed expenses, flexible budget, safety buffer, goals, non-negotiable items | What matters to this person? |
| Real-time Financial State | confirmed transactions, pending entries, planned income, upcoming bills, committed spending, freshness | What is true now? |
| Decision Engine | safe-to-spend range, spending pace, goal effects, risk thresholds, recovery options | What does this choice change? |
| Navigation Experience | Today, Decision Cards, comparison, post-purchase feedback, reminders | What does the user need to do now? |

### Required Decision Card output

```text
DecisionCard
  status: within_flexible | uses_buffer | requires_plan_change
  headline: short and neutral conclusion
  flexible_budget_before: money
  flexible_budget_after: money
  safe_to_spend_range: money range
  frequency_insight: optional
  goal_effect: unchanged | needs_recovery | delayed_by_user_choice
  recovery_options: zero or more
  selected_store_offer: optional
  decision_snapshot_id: identifier
```

Every result must answer four questions when data is available:

1. What price action is available, including a better user-entered offer?
2. What remains today, this week, and before the next income date?
3. Is this category occurring unusually often based on confirmed history?
4. Does the choice affect a goal, and what recovery option preserves the plan?

If data is insufficient, state that clearly. Never manufacture an insight to fill a card.

### Classification rules

- `within_flexible`: The purchase fits the remaining flexible budget after reserving essential planned expenses and protected goal contributions.
- `uses_buffer`: The purchase exceeds flexible budget but fits an explicitly user-approved safety buffer without breaking the plan.
- `requires_plan_change`: The purchase requires the user to reduce a future discretionary expense, change a goal contribution or date, or make another explicit plan change.

Never automatically call a purchase “impulsive” only because it exceeds a flexible budget. The product can show it as an `unplanned` or `out-of-budget` decision and let the user choose how to classify its intent.

Treat “impulse spending” as a user-facing moment that needs extra clarity, not as a moral label or permanent identity. Trigger an impact reminder when an unplanned purchase exceeds the remaining flexible allocation or threatens a protected reserve. Explain the opportunity cost with amounts, dates, assumptions, and a reversible next action.

Show a goal-date delay only when the user explicitly chooses to spend from the goal reserve or there is no feasible recovery plan that preserves the minimum savings pace before the target date.

### Evaluation sequence

1. Accept an amount and optional category, product, intent, or selected store offer.
2. Load the current model and confirmed state.
3. Reserve planned essential expenses and protected goal contributions.
4. Calculate remaining flexible amount, safe-to-spend range, category frequency, and savings-pace effect.
5. Calculate comparable store offers if the user added them.
6. Return a Decision Card with at least one practical recovery option when flexibility is reduced.
7. Let the user choose **Purchase and record**, **Decide later**, **Skip**, or **Adjust plan**.
8. Save a `DecisionSnapshot`; create a `Transaction` only after purchase confirmation.

## Price comparison

Price comparison is manual and user-entered. It helps a user compare offers seen in physical shops or online; it is not a marketplace, web crawler, or lowest-price guarantee.

For each store offer, support:

- Store name and note.
- Product name, variant, size, quantity, and comparable unit.
- Base price or final checkout price.
- Percentage discount, fixed discount, coupon, shipping, and required fees.
- Promotion expiry and conditions such as membership or bundle requirement.

```text
merchandiseSubtotal = basePrice × quantity
discountedSubtotal = merchandiseSubtotal × (1 - percentageDiscountRate) - fixedDiscount
finalPayment = max(0, discountedSubtotal - couponAmount) + shipping + requiredFees
unitPrice = finalPayment / comparableQuantity
```

Use `Decimal` for every monetary calculation. Compare final payment only for the same purchase quantity; compare unit price for different quantities or sizes. Flag non-comparable variants. Do not automatically assign a value to gifts, points, or cashback. Let the user enter the final verified payment when a promotion is too complex.

## Daily bookkeeping

Keep regular accounting available without making it the first required task. Support:

- Income.
- Expense.
- Transfer between accounts. A transfer is not income or expense.
- Categories and subcategories.
- Date, note, and tags.
- Optional account and payment-method visibility.
- Basic transaction history and category analysis.

If a confirmed transaction fulfils a planned expense occurrence, mark that occurrence completed and do not deduct its amount twice.

## Technical architecture

### iOS client

- Build the iOS app with **SwiftUI**.
- Keep financial rules in an independent Swift `FinanceEngine` module, separate from views and Firebase code.
- Use `Decimal`, `Calendar`, and explicit time-zone handling for money and date calculations. Never use binary floating-point values for currency.
- Use a repository layer so SwiftUI views do not access Firebase directly.
- Keep scenario calculation offline-capable and unit-testable.

### Firebase services

| Service | Responsibility |
| --- | --- |
| Firebase Authentication | Apple, Google, and authenticated account lifecycle |
| Cloud Firestore | signed-in user model, plans, goals, transactions, decisions, comparisons, categories, tags |
| Cloud Functions | account-deletion orchestration and server-side tasks that must not trust the client |
| Firebase Storage | user files only when a feature genuinely needs cloud file storage |
| Firebase Analytics | privacy-reviewed product funnel events |
| Crashlytics | crash and non-fatal error diagnosis |

Enforce `uid`-scoped Firestore security rules. A user must only read and write their own documents. Never ship production Firebase API keys, service-account credentials, or unrestricted security rules in the repository.

### Primary data entities

```text
UserProfile
FinancialPlan
IncomeCycle
Goal
PlannedExpense
FlexibleBudget
Account
Category
Tag
Transaction
Transfer
SpendScenario
DecisionSnapshot
PriceComparison
StoreOffer
DeferredPurchase
SubscriptionEntitlement
```

`SpendScenario` is temporary and never changes a real budget, goal balance, or history. `DecisionSnapshot` preserves the exact inputs and rule version shown to the user. Confirmed transactions are the only source for actual-spending history.

## Analytics and success metrics

Track only events needed to answer product questions. Do not send raw goal names, merchant names, free-text notes, or exact financial amounts to analytics.

| AARRR stage | Question | Example events |
| --- | --- | --- |
| Acquisition | Where did people come from? | `install_attributed`, `waitlist_joined` |
| Activation | Did they receive first value? | `initial_launch`, `onboarding_completed`, `first_decision_card_viewed` |
| Retention | Do they return for decisions? | `session_started`, `screen_viewed`, `decision_evaluated` |
| Revenue | Do they choose a plan? | `paywall_viewed`, `trial_started`, `subscription_started` |
| Referral | Would they recommend it? | `invite_shared`, `referral_completed` |

Define activation before launch as: **a user completes onboarding and views their first Decision Card.**

## Product validation and launch planning

Before committing the full production scope, publish a concept-validation page that explains the pre-spend decision value and collects an explicit waitlist or contact opt-in. Measure whether visitors understand the proposition and choose to leave contact information.

Set one public-availability deadline before scheduling release work. Plan backward from that date with explicit owners and dependencies for:

1. App Store review buffer and rejection-response time.
2. Release candidate, regression testing, reviewer account, and review notes.
3. Privacy policy, terms, support, FAQ, account deletion, and export.
4. Subscription products, seven-day annual trial disclosure, and purchase restoration.
5. App Store metadata, screenshots, preview media, press kit, and launch website.
6. LicensePlist output and exact third-party license notices.
7. Preorder and editorial-feature submission, if the product owner chooses them.

Do not invent a deadline or enable preorder, submit a build, publish a release, or contact App Store editorial without explicit product-owner approval. Preorder and editorial-feature rules are time-sensitive; verify the current official Apple requirements when executing those tasks.

## Open product decisions

Do not silently resolve these decisions in implementation:

- Initial market and locale: Taiwan-only with TWD and Taiwan date conventions, or broader localization.
- Primary safe-to-spend horizon: next income date only, or next income date plus calendar-month view.
- Default essential-expense templates.
- Whether the plan requires a named savings goal or may contain only a safety buffer.
- Whether first-release comparison supports only a single item or also bundles and unit pricing.
- Spending-frequency window: rolling 30 days, income cycle, or user-configurable.

Record the owner's decision in the relevant specification and tests before building behavior that depends on it.

## Coding and documentation standards

- Write all source-code comments in English.
- Do not use emoji in source code, code comments, identifiers, release notes, or project documentation.
- Write user-facing Traditional Chinese copy in a calm, clear, non-judgmental tone.
- Keep View code, financial rules, persistence, and analytics separate.
- Add unit tests whenever changing money math, dates, goal timing, budget allocation, or duplicate-deduction behavior.
- Do not log financial content, tokens, or personal data in debug output.

## Agent responsibilities

### FinancialPlanningAgent

Guide onboarding, maintain assumptions, and ensure the result is useful without a full ledger.

### SpendingEvaluatorAgent

Use [the spending-evaluation skill](skills/evaluate-impulse-spend/SKILL.md) to generate the Decision Card from the finance model and confirmed state. Apply the classification and goal-delay rules above.

### PriceComparisonAgent

Calculate user-entered price options, flag incomparable offers, and pass a chosen offer into the decision engine.

### BookkeepingAgent

Create, edit, categorize, tag, and reconcile confirmed transactions without confusing pre-spend scenarios with actual history.

### AccountAndSubscriptionAgent

Handle sign-in, account migration, StoreKit entitlements, export, secure deletion, and data-control screens.

### AnalyticsTrackerAgent

Track the approved AARRR events and diagnose product behavior without collecting unnecessary finance data.

### ReleaseManagementAgent

Run [the PayReview release-check skill](skills/payreview-release-check/SKILL.md) before every TestFlight or App Store release. Report every item as `pass`, `block`, or `not applicable`; do not silently assume a requirement is done.

## Success criteria

The product succeeds when a user can set up a small plan quickly, understand a potential purchase before paying, compare a real entered offer, and make an informed choice without feeling judged.
