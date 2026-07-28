//
//  TodayViewModel.swift
//  PayReview
//

import Foundation
import Observation

/// Powers the real-data parts of the Today tab: the "預算剩餘總額" hero number and
/// the "今日固定支出" section (消費頻率 Phase 2/3).
///
/// The rest of that screen ("評估眼前的消費", 比價實驗室/本週故事) still runs on
/// `SetupStore`/`PayReviewFlowStore` — a local-only mock left over from an early
/// prototype, with no connection to Firestore at all (see the doc comment on
/// `TodayPrototypeView`). This view model is different on purpose: it observes the
/// *same* `BudgetRepository`/`TransactionRepository`/`ProfileRepository` that
/// "計畫" and "紀錄" use, so the numbers shown here are real, persisted data — not
/// another local-only prototype layer.
@MainActor
@Observable
final class TodayViewModel {
    private(set) var budgets: [BudgetRecord] = []
    private(set) var transactions: [TransactionRecord] = []
    // 新增: the Today tab's hero number ("預算剩餘總額") needs the same total
    // monthly budget "計畫" sets via its centered field — same "supplementary,
    // starts at a sensible default" treatment `BudgetListViewModel.profile` uses.
    private(set) var profile: ProfileRecord = .unset

    private let budgetRepository: BudgetRepository
    private let transactionRepository: TransactionRepository
    private let profileRepository: ProfileRepository

    init(
        budgetRepository: BudgetRepository,
        transactionRepository: TransactionRepository,
        profileRepository: ProfileRepository
    ) {
        self.budgetRepository = budgetRepository
        self.transactionRepository = transactionRepository
        self.profileRepository = profileRepository
    }

    /// Same `async let` pattern used by `BudgetListViewModel.start()`/
    /// `TransactionListViewModel.start()` — all three streams need to run
    /// concurrently, not one after another, or later ones would never even start
    /// listening.
    func start() async {
        async let budgetsTask: Void = observeBudgets()
        async let transactionsTask: Void = observeTransactions()
        async let profileTask: Void = observeProfile()
        _ = await (budgetsTask, transactionsTask, profileTask)
    }

    private func observeBudgets() async {
        for await latest in await budgetRepository.observeBudgets() {
            budgets = latest
        }
    }

    private func observeTransactions() async {
        for await latest in await transactionRepository.observeTransactions() {
            transactions = latest
        }
    }

    private func observeProfile() async {
        for await latest in await profileRepository.observeProfile() {
            profile = latest
        }
    }

    /// The Today tab's hero number: this month's total budget minus everything
    /// actually spent this month, across *every* category — not just the ones
    /// scheduled for today (`todaysScheduledBudgets`). This can go negative if the
    /// user has overspent for the month; it's shown as-is rather than clamped to
    /// 0, since "you're NT$500 over" is more useful here than a bare "NT$0".
    func remainingBudgetMinorUnits(referenceDate: Date = .now, calendar: Calendar = .current) -> Int64 {
        let spentThisMonth = transactions
            .filter { $0.amount.minorUnits < 0 && calendar.isDate($0.occurredAt, equalTo: referenceDate, toGranularity: .month) }
            .reduce(Int64(0)) { $0 + (-$1.amount.minorUnits) }
        return profile.monthlyBudgetLimitMinorUnits - spentThisMonth
    }

    /// Which categories should show up as a "今日固定支出" item today: every budget
    /// whose configured frequency schedules `referenceDate` — see
    /// `BudgetRecord.isScheduled(on:)` for what that means per frequency. Sorted by
    /// name for a stable, predictable order across renders, rather than whatever
    /// order the Firestore snapshot happens to deliver documents in.
    func todaysScheduledBudgets(
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [BudgetRecord] {
        budgets
            .filter { $0.isScheduled(on: referenceDate, calendar: calendar) }
            .sorted { $0.name < $1.name }
    }

    /// If this category already has a logged expense today, returns it. Used to
    /// show the row as already-completed (struck through, amount fixed, input
    /// locked) instead of an open input box — per the chosen design, once a
    /// category has been recorded today it can't be recorded again the same day.
    func loggedTransactionToday(
        for budget: BudgetRecord,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> TransactionRecord? {
        transactions.first { transaction in
            transaction.budgetId == budget.id
                && transaction.amount.minorUnits < 0
                && calendar.isDate(transaction.occurredAt, inSameDayAs: referenceDate)
        }
    }

    /// Creates today's expense transaction for `budget`, called once the user types
    /// a positive amount into the row's input box. `amountMinorUnits` is a positive
    /// magnitude (what the user typed) — this flips the sign itself, since every
    /// "今日固定支出" item is by definition an expense, never an income.
    ///
    /// `note` is the category's own name: this flow has no separate "消費名稱" field
    /// the way `AddTransactionView` does, so the category name doubles as the
    /// transaction's note (matching how `TransactionListView.transactionName(for:)`
    /// already falls back to the category when a transaction has no note).
    func addTodayExpense(for budget: BudgetRecord, amountMinorUnits: Int64) async {
        guard amountMinorUnits > 0 else { return }
        let id = transactionRepository.newTransactionID()
        let now = Date()
        let transaction = TransactionRecord(
            id: id,
            amount: Money(minorUnits: -amountMinorUnits, currencyCode: "TWD"),
            budgetId: budget.id,
            occurredAt: now,
            note: budget.name,
            source: .manual,
            schemaVersion: 1,
            createdAt: now,
            updatedAt: now
        )
        do {
            try await transactionRepository.addTransaction(transaction)
        } catch {
            print("Failed to add today's fixed expense: \(error)")
        }
    }

    /// Overwrites an already-logged "今日固定支出" with a new amount — the "tap a
    /// completed row to re-enter it" flow. Everything except the amount and
    /// `updatedAt` carries over from `transaction` unchanged, same idea as
    /// `TransactionListViewModel.updateTransaction`.
    func updateTodayExpense(_ transaction: TransactionRecord, amountMinorUnits: Int64) async {
        guard amountMinorUnits > 0 else { return }
        let updated = TransactionRecord(
            id: transaction.id,
            amount: Money(minorUnits: -amountMinorUnits, currencyCode: transaction.amount.currencyCode),
            budgetId: transaction.budgetId,
            occurredAt: transaction.occurredAt,
            note: transaction.note,
            source: transaction.source,
            schemaVersion: transaction.schemaVersion,
            createdAt: transaction.createdAt,
            updatedAt: Date()
        )
        do {
            try await transactionRepository.updateTransaction(updated)
        } catch {
            print("Failed to update today's fixed expense: \(error)")
        }
    }

    /// Removes an already-logged "今日固定支出" entirely — called when the user
    /// re-opens a completed row and clears the amount instead of typing a new one.
    /// Once this succeeds, `transactions` (and therefore `loggedTransactionToday`)
    /// updates on its own through the observation stream, which is what flips the
    /// row back to its pre-input appearance — there's nothing else to reset here.
    func deleteTodayExpense(_ transaction: TransactionRecord) async {
        do {
            try await transactionRepository.deleteTransaction(id: transaction.id)
        } catch {
            print("Failed to delete today's fixed expense: \(error)")
        }
    }
}
