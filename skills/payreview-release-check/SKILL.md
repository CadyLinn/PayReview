---
name: payreview-release-check
description: Run the release-readiness process for 花算 PayReview before a TestFlight build, App Store submission, preorder, or production release. Use when preparing a version, auditing store requirements, checking subscriptions and privacy disclosures, validating support and legal links, or producing a go/no-go release report.
---

# PayReview Release Check

Run this skill before every TestFlight distribution, App Store submission, preorder update, and production release. Produce a clear release report; do not submit or publish anything unless the product owner explicitly asks.

## Required release input

Gather or mark as missing:

- Version and build number.
- Release type: TestFlight, App Store review, preorder update, or production release.
- Release date and public availability date.
- What changed in this version.
- Subscription products and pricing affected by the release.
- Required reviewer account and review steps, if sign-in is needed.

If an input is missing, mark it `block` or `not applicable`. Do not infer a date, subscription configuration, or test account.

## Checklist

### 1. Product and data integrity

- Confirm the onboarding flow completes in two to four minutes with a goal, income cycle, planned expenses, and flexible budget.
- Confirm a `SpendScenario` does not change budgets or records before the user confirms a purchase.
- Test `within_flexible`, `uses_buffer`, and `requires_plan_change` decisions.
- Confirm goal delay appears only after goal-reserve use or an infeasible recovery plan.
- Confirm a transaction that fulfils a planned expense is not deducted twice.
- Test manual price comparison with same-size and different-size offers.
- Verify income, expense, transfer, categories, date, note, and tags in daily bookkeeping.

### 2. Privacy, account, and permissions

- Verify the privacy policy, terms, and in-app privacy explanation match the website and App Store listing.
- Verify Sign in with Apple and Google Sign-In work through Firebase Authentication.
- Verify guest-mode data behavior and the explicit migration path after account creation.
- Verify data export is reachable in the app.
- Verify account deletion starts in the app and completes through a secure authenticated flow; do not accept an email-only or contact-form-only process.
- Confirm Firestore rules isolate data by authenticated user ID.
- Confirm notification permission is requested only after the user enables a reminder and sees a purpose explanation.
- Confirm no unsupported access to banking, payment, LINE, contacts, location, camera, or photos is requested.

### 3. Subscription and commerce

- Confirm the Annual plan is NT$800 per year with a seven-day trial for eligible users.
- Confirm the Monthly plan is NT$120 per month and does not show an unintended trial.
- Confirm price, billing period, trial conditions, renewal terms, cancellation path, and paid features are shown before purchase.
- Test purchase, cancellation state refresh, Restore Purchases, and StoreKit entitlement changes.
- Verify paywall copy matches App Store Connect product metadata.

### 4. App Store materials and review readiness

- Check app name, subtitle, description, keywords, category, age rating, privacy labels, screenshots, and App Preview assets.
- Prepare reviewer credentials, test data, and precise review notes when a login or paid feature is required to evaluate the app.
- Verify the support URL, privacy-policy URL, terms URL, FAQ, and contact channel are live.
- Verify account-deletion instructions are easy for both users and reviewers to find.
- Check current App Store policy and App Store Connect requirements before submission; requirements can change between releases.
- For preorders, verify public date, release date, and product availability are valid before enabling preorder.

### 5. Legal, support, and communications

- Generate open-source notices with LicensePlist and expose them in the Settings bundle.
- Include required license text exactly, including MIT notices where applicable.
- Verify customer-support email or form receives a test submission.
- Confirm Traditional Chinese and English press-kit assets, product description, screenshots, and contact details are current.
- Confirm the website contains official product information, download or preorder link, terms, privacy policy, support, and FAQ.

### 6. Quality and observability

- Run automated tests for FinanceEngine money rounding, dates, budget allocation, goal timing, and duplicate deduction.
- Test offline evaluation and recovery after reconnecting to Firestore.
- Check Firebase Analytics event naming and ensure no raw financial or free-text personal data is sent.
- Check Crashlytics has no known release-blocking crash or non-fatal error.
- Verify all source-code comments and project documentation are in English where code standards require it, and contain no emoji.

### 7. Submission and release actions

- Confirm build signing, version, build number, and archive are correct.
- Use App Store Connect tooling only after all blocking checks are resolved.
- Upload metadata, build, and review notes with a dry run or human review where possible.
- Do not publish automatically. Require explicit owner approval for TestFlight external testing, App Store submission, preorder activation, and production release.

## Release report format

Return a concise report in this format:

```text
PayReview Release Report
Version: <version> (<build>)
Release type: <type>
Target date: <date or missing>

Pass
- <verified item>

Block
- <missing or failed item, owner, next action>

Not applicable
- <item and reason>

Decision: GO | NO-GO
Owner approval required: yes | no
```

Set `Decision: NO-GO` if any privacy, account deletion, subscription disclosure, security, critical finance-calculation, or App Store review requirement is blocked.
