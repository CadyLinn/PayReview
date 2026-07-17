---
name: payreview-release-check
description: Run the release-readiness process for PayReview before a TestFlight build, App Store submission, preorder, or production release. Use when preparing a version, auditing store requirements, checking subscriptions and privacy disclosures, validating support and legal links, or producing a go/no-go release report.
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
- Test `within_flexible`, `uses_buffer`, `requires_plan_change`, and `insufficient_data`, including a flexible allocation above the conservative safe-to-spend bound.
- Confirm goal delay appears only after goal-reserve use or an infeasible recovery plan.
- Confirm a transaction that fulfils a planned expense is not deducted twice.
- Verify income, expense, transfer, categories, date, note, and tags in daily bookkeeping.

### 2. Privacy, account, and permissions

- Verify the privacy policy, terms, and in-app privacy explanation match the website and App Store listing.
- Verify Sign in with Apple and Google Sign-In work through Firebase Authentication.
- Verify unauthenticated users cannot enter onboarding or core financial features.
- Verify authenticated financial data reads and writes through Cloud Firestore.
- Verify data export is reachable in the app.
- Verify account deletion starts in the app and requires recent authentication; do not accept an email-only or contact-form-only process.
- For Sign in with Apple, verify reauthentication produces a fresh authorization code and `Auth.auth().revokeToken(withAuthorizationCode:)` succeeds before Firebase Authentication deletion.
- Verify new writes stop before deletion and pending writes use a cancellable 30-second maximum; test success, terminal error, cancellation, timeout, retry, cancel-deletion, and separately confirmed discard paths.
- Verify the callable function checks recent `auth_time`, persists the `deleting` state and durable job atomically, and returns an opaque receipt only after the job is safely queued.
- Verify a stable deletion request ID makes recursive Firestore and cloud-file deletion idempotent, Firebase Authentication is deleted only after cloud data, and the backend continues retrying after the client clears local data and signs out.
- Verify the `deleted` tombstone contains only minimal operational fields, remains for at least seven days after Auth deletion, is disclosed in the privacy policy, and cannot be changed by clients. Cleanup must confirm the Auth user and deletion job are absent; production must never reuse a deleted `uid`.
- Verify deletion and account switching terminate Firestore, clear persistent cache and local sensitive data, and prevent a different `uid` from reading the previous user's data.
- Verify ordinary account switching uses a cancellable 30-second pending-write maximum, cancels without data loss on timeout or failure, and blocks the next account when cache clearing fails.
- Confirm Firestore Security Rules isolate all financial data by authenticated user ID.
- Confirm user writes fail closed unless Firebase Authentication is present and the requested path belongs to the authenticated token `uid`; verify anonymous and cross-user access are rejected.
- Confirm the MVP does not implement or request notification permission.
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
- Document why cross-device financial continuity is a significant account-based feature under the current App Review Guideline 5.1.1(v). Mark submission `block` if mandatory login cannot be justified against the current rule.
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
- Test Firestore offline persistence and synchronization after reconnecting.
- Test sign-out, same-user reauthentication, cross-user cache isolation, pending-write handling during account switching, cache-clear failure, and deletion cleanup.
- Test offline optimistic writes that are later rejected by Security Rules; verify the UI rolls back, marks the operation unsaved, and offers recovery.
- Test network loss before and after deletion-job acceptance and confirm the backend continues after client sign-out without requesting another Apple authorization code.
- Check Firebase Analytics and ensure no raw financial or free-text personal data is sent.
- Check Crashlytics for release-blocking crashes or non-fatal errors.
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
