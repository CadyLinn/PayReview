//
//  TodayViewModelTests.swift
//  PayReviewTests
//

import Testing
@testable import PayReview
import Foundation

@MainActor
struct TodayViewModelTests {
    private func makeViewModel(
        budgets: [BudgetRecord],
        transactions: [TransactionRecord] = [],
        profileLimitMinorUnits: Int64 = 0
    ) -> TodayViewModel {
        TodayViewModel(
            budgetRepository: InMemoryBudgetRepository(seed: budgets),
            transactionRepository: InMemoryFinancialRepository(seed: transactions),
            profileRepository: InMemoryProfileRepository(seed: ProfileRecord(
                monthlyBudgetLimitMinorUnits: profileLimitMinorUnits,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            ))
        )
    }

    private func makeBudget(
        id: String,
        name: String,
        frequency: BudgetFrequency,
        weekdays: Set<Int> = [],
        monthDays: Set<Int> = []
    ) -> BudgetRecord {
        BudgetRecord(
            id: id,
            name: name,
            limitMinorUnits: 1_000,
            expectedMonthlyCount: 1,
            frequency: frequency,
            frequencyWeekdays: weekdays,
            frequencyMonthDays: monthDays,
            schemaVersion: 1,
            createdAt: .now,
            updatedAt: .now
        )
    }

    /// 2026/7/28 is a Tuesday — Calendar's weekday numbering (1=Sunday) makes that
    /// weekday 3. Used across these tests as a fixed "today" so the weekly/monthly
    /// matching isn't at the mercy of whatever day the test actually runs on.
    private var referenceTuesday: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 28))!
    }

    @Test func todaysScheduledBudgetsIncludesDailyWeeklyOnMatchingDayAndMonthlyOnMatchingDay() async throws {
        let daily = makeBudget(id: "b1", name: "早餐", frequency: .daily)
        let weeklyMatch = makeBudget(id: "b2", name: "健身房", frequency: .weekly, weekdays: [3])
        let weeklyMiss = makeBudget(id: "b3", name: "瑜珈", frequency: .weekly, weekdays: [2])
        let monthlyMatch = makeBudget(id: "b4", name: "房租", frequency: .monthly, monthDays: [28])
        let custom = makeBudget(id: "b5", name: "其他", frequency: .custom)

        let viewModel = makeViewModel(budgets: [daily, weeklyMatch, weeklyMiss, monthlyMatch, custom])
        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        let scheduled = viewModel.todaysScheduledBudgets(referenceDate: referenceTuesday)
        let scheduledIDs = Set(scheduled.map(\.id))

        #expect(scheduledIDs == ["b1", "b2", "b4"])
        observation.cancel()
    }

    @Test func loggedTransactionTodayFindsExpenseRecordedTodayForThatBudget() async throws {
        let budget = makeBudget(id: "b1", name: "早餐", frequency: .daily)
        let todaysExpense = TransactionRecord(
            id: "t1",
            amount: Money(minorUnits: -80, currencyCode: "TWD"),
            budgetId: "b1",
            occurredAt: referenceTuesday,
            note: "早餐",
            source: .manual,
            schemaVersion: 1,
            createdAt: referenceTuesday,
            updatedAt: referenceTuesday
        )
        let viewModel = makeViewModel(budgets: [budget], transactions: [todaysExpense])
        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        let found = viewModel.loggedTransactionToday(for: budget, referenceDate: referenceTuesday)
        #expect(found?.id == "t1")
        observation.cancel()
    }

    @Test func loggedTransactionTodayIgnoresTransactionsFromOtherDaysOrOtherBudgets() async throws {
        let budget = makeBudget(id: "b1", name: "早餐", frequency: .daily)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: referenceTuesday)!
        let wrongDay = TransactionRecord(
            id: "t1", amount: Money(minorUnits: -80, currencyCode: "TWD"), budgetId: "b1",
            occurredAt: yesterday, note: "早餐", source: .manual, schemaVersion: 1,
            createdAt: yesterday, updatedAt: yesterday
        )
        let wrongBudget = TransactionRecord(
            id: "t2", amount: Money(minorUnits: -80, currencyCode: "TWD"), budgetId: "b2",
            occurredAt: referenceTuesday, note: "午餐", source: .manual, schemaVersion: 1,
            createdAt: referenceTuesday, updatedAt: referenceTuesday
        )
        let viewModel = makeViewModel(budgets: [budget], transactions: [wrongDay, wrongBudget])
        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.loggedTransactionToday(for: budget, referenceDate: referenceTuesday) == nil)
        observation.cancel()
    }

    /// Phase 3: typing an amount into a "今日固定支出" row creates a real expense
    /// transaction — negative amount, tagged with the category's id, noted with the
    /// category's own name (there's no separate name field in this flow).
    @Test func addTodayExpenseCreatesNegativeTransactionTaggedWithBudget() async throws {
        let budget = makeBudget(id: "b1", name: "早餐", frequency: .daily)
        let viewModel = makeViewModel(budgets: [budget])
        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.addTodayExpense(for: budget, amountMinorUnits: 80)
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.transactions.count == 1)
        #expect(viewModel.transactions.first?.amount.minorUnits == -80)
        #expect(viewModel.transactions.first?.budgetId == "b1")
        #expect(viewModel.transactions.first?.note == "早餐")
        observation.cancel()
    }

    /// 新增: re-opening an already-logged row and entering a new amount should
    /// overwrite the existing transaction in place (same id), not create a second
    /// one — the "tap a completed row to re-enter it" flow.
    @Test func updateTodayExpenseOverwritesInPlace() async throws {
        let budget = makeBudget(id: "b1", name: "早餐", frequency: .daily)
        let viewModel = makeViewModel(budgets: [budget])
        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.addTodayExpense(for: budget, amountMinorUnits: 80)
        try await Task.sleep(for: .milliseconds(50))
        guard let logged = viewModel.loggedTransactionToday(for: budget) else {
            Issue.record("Expected a logged transaction after adding one")
            observation.cancel()
            return
        }

        await viewModel.updateTodayExpense(logged, amountMinorUnits: 120)
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.transactions.count == 1)
        #expect(viewModel.transactions.first?.id == logged.id)
        #expect(viewModel.transactions.first?.amount.minorUnits == -120)
        observation.cancel()
    }

    /// 新增: clearing a completed row's amount back to nothing should delete the
    /// underlying transaction — verified here at the view model level (the row's
    /// "empty expression = delete" decision lives in `TodayFixedExpenseRow`, but
    /// the actual deletion goes through this method).
    @Test func deleteTodayExpenseRemovesTheTransaction() async throws {
        let budget = makeBudget(id: "b1", name: "早餐", frequency: .daily)
        let viewModel = makeViewModel(budgets: [budget])
        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.addTodayExpense(for: budget, amountMinorUnits: 80)
        try await Task.sleep(for: .milliseconds(50))
        guard let logged = viewModel.loggedTransactionToday(for: budget) else {
            Issue.record("Expected a logged transaction after adding one")
            observation.cancel()
            return
        }

        await viewModel.deleteTodayExpense(logged)
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.transactions.isEmpty)
        #expect(viewModel.loggedTransactionToday(for: budget) == nil)
        observation.cancel()
    }

    /// 新增: the Today tab's "預算剩餘總額" hero number — total monthly budget minus
    /// everything spent this month across every category, not just today's
    /// scheduled ones. Income transactions and other months' expenses shouldn't
    /// count against it.
    @Test func remainingBudgetSubtractsThisMonthsExpensesAcrossAllBudgets() async throws {
        let daily = makeBudget(id: "b1", name: "早餐", frequency: .daily)
        let weekly = makeBudget(id: "b2", name: "健身房", frequency: .weekly, weekdays: [1])

        let thisMonthExpense1 = TransactionRecord(
            id: "t1", amount: Money(minorUnits: -300, currencyCode: "TWD"), budgetId: "b1",
            occurredAt: referenceTuesday, note: "早餐", source: .manual, schemaVersion: 1,
            createdAt: referenceTuesday, updatedAt: referenceTuesday
        )
        let thisMonthExpense2 = TransactionRecord(
            id: "t2", amount: Money(minorUnits: -500, currencyCode: "TWD"), budgetId: "b2",
            occurredAt: referenceTuesday, note: "健身房", source: .manual, schemaVersion: 1,
            createdAt: referenceTuesday, updatedAt: referenceTuesday
        )
        let lastMonthExpense = TransactionRecord(
            id: "t3", amount: Money(minorUnits: -9_999, currencyCode: "TWD"), budgetId: "b1",
            occurredAt: Calendar.current.date(byAdding: .month, value: -1, to: referenceTuesday)!,
            note: "上個月", source: .manual, schemaVersion: 1,
            createdAt: referenceTuesday, updatedAt: referenceTuesday
        )
        let thisMonthIncome = TransactionRecord(
            id: "t4", amount: Money(minorUnits: 30_000, currencyCode: "TWD"), budgetId: nil,
            occurredAt: referenceTuesday, note: "薪水", source: .manual, schemaVersion: 1,
            createdAt: referenceTuesday, updatedAt: referenceTuesday
        )

        let viewModel = makeViewModel(
            budgets: [daily, weekly],
            transactions: [thisMonthExpense1, thisMonthExpense2, lastMonthExpense, thisMonthIncome],
            profileLimitMinorUnits: 10_000
        )
        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        // 10,000 total budget − (300 + 500) this month's expenses = 9,200.
        #expect(viewModel.remainingBudgetMinorUnits(referenceDate: referenceTuesday) == 9_200)
        observation.cancel()
    }

    @Test func remainingBudgetCanGoNegativeWhenOverspent() async throws {
        let daily = makeBudget(id: "b1", name: "早餐", frequency: .daily)
        let overspend = TransactionRecord(
            id: "t1", amount: Money(minorUnits: -12_000, currencyCode: "TWD"), budgetId: "b1",
            occurredAt: referenceTuesday, note: "早餐", source: .manual, schemaVersion: 1,
            createdAt: referenceTuesday, updatedAt: referenceTuesday
        )
        let viewModel = makeViewModel(budgets: [daily], transactions: [overspend], profileLimitMinorUnits: 10_000)
        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.remainingBudgetMinorUnits(referenceDate: referenceTuesday) == -2_000)
        observation.cancel()
    }

    @Test func addTodayExpenseIgnoresZeroOrNegativeAmounts() async throws {
        let budget = makeBudget(id: "b1", name: "早餐", frequency: .daily)
        let viewModel = makeViewModel(budgets: [budget])
        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.addTodayExpense(for: budget, amountMinorUnits: 0)
        await viewModel.addTodayExpense(for: budget, amountMinorUnits: -50)
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.transactions.isEmpty)
        observation.cancel()
    }
}
