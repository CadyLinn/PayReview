//
//  BudgetListViewModelTests.swift
//  PayReviewTests
//

import Testing
@testable import PayReview
import Foundation

@MainActor
struct BudgetListViewModelTests {
    @Test func addingBudgetUpdatesState() async throws {
        let viewModel = makeViewModel()

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.addBudget(name: "餐飲", limitMinorUnits: 3_000, expectedMonthlyCount: 5)
        try await Task.sleep(for: .milliseconds(50))

        guard case .loaded(let budgets) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            observation.cancel()
            return
        }

        #expect(budgets.count == 1)
        #expect(budgets.first?.name == "餐飲")
        #expect(budgets.first?.limitMinorUnits == 3_000)
        #expect(budgets.first?.expectedMonthlyCount == 5)

        observation.cancel()
    }

    /// Phase 5: editing an existing budget should overwrite it in place (same id,
    /// same createdAt) rather than appending a second one.
    @Test func updatingBudgetOverwritesInPlace() async throws {
        let now = Date()
        let budget = BudgetRecord(
            id: "b1",
            name: "餐飲",
            limitMinorUnits: 3_000,
            expectedMonthlyCount: 5,
            schemaVersion: 1,
            createdAt: now,
            updatedAt: now
        )
        let viewModel = makeViewModel(budgets: [budget])

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.updateBudget(budget, name: "外食", limitMinorUnits: 4_000, expectedMonthlyCount: 6)
        try await Task.sleep(for: .milliseconds(50))

        guard case .loaded(let budgets) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            observation.cancel()
            return
        }

        #expect(budgets.count == 1)
        #expect(budgets.first?.id == "b1")
        #expect(budgets.first?.name == "外食")
        #expect(budgets.first?.limitMinorUnits == 4_000)
        #expect(budgets.first?.expectedMonthlyCount == 6)
        #expect(budgets.first?.createdAt == now)

        observation.cancel()
    }

    /// Phase 5: the centered total-budget field should persist through
    /// `updateMonthlyBudgetLimit` and show up in `viewModel.profile`.
    @Test func updatingMonthlyBudgetLimitUpdatesProfile() async throws {
        let viewModel = makeViewModel()

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.updateMonthlyBudgetLimit(minorUnits: 20_000)
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.profile.monthlyBudgetLimitMinorUnits == 20_000)

        observation.cancel()
    }

    /// Phase 5: `remainingAllocatableMinorUnits` should be total minus every existing
    /// budget's limit, and `excluding:` should add a budget's own allocation back in
    /// (so editing it doesn't count its current value against itself).
    @Test func remainingAllocatableMinorUnitsAccountsForExistingBudgets() async throws {
        let now = Date()
        let dining = BudgetRecord(
            id: "b1", name: "餐飲", limitMinorUnits: 3_000, expectedMonthlyCount: 5,
            schemaVersion: 1, createdAt: now, updatedAt: now
        )
        let transport = BudgetRecord(
            id: "b2", name: "交通", limitMinorUnits: 1_200, expectedMonthlyCount: 8,
            schemaVersion: 1, createdAt: now, updatedAt: now
        )
        let viewModel = makeViewModel(budgets: [dining, transport], profileLimitMinorUnits: 10_000)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        // total 10,000 - (3,000 + 1,200) = 5,800 left for a brand-new budget
        #expect(viewModel.remainingAllocatableMinorUnits() == 5_800)
        // editing 餐飲: exclude its own 3,000, so 10,000 - 1,200 = 8,800 is the max
        // it could be raised to
        #expect(viewModel.remainingAllocatableMinorUnits(excluding: "b1") == 8_800)

        observation.cancel()
    }

    /// Phase 5: if existing budgets already add up to more than the (possibly since
    /// shrunk) total budget, remaining should clamp at 0 instead of going negative —
    /// a negative value would make for an invalid Slider range in AddBudgetView.
    @Test func remainingAllocatableMinorUnitsClampsAtZeroWhenOverAllocated() async throws {
        let now = Date()
        let dining = BudgetRecord(
            id: "b1", name: "餐飲", limitMinorUnits: 8_000, expectedMonthlyCount: 5,
            schemaVersion: 1, createdAt: now, updatedAt: now
        )
        let viewModel = makeViewModel(budgets: [dining], profileLimitMinorUnits: 5_000)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.remainingAllocatableMinorUnits() == 0)

        observation.cancel()
    }

    /// Phase 3: normal case — some spend this month, still under budget. Verifies the
    /// core formula: remaining = limit - spent, suggested next = remaining / max(expected - used, 1).
    @Test func progressComputesRemainingBudgetAndSuggestedNextAmount() async throws {
        let now = Date()
        let budget = BudgetRecord(
            id: "b1",
            name: "餐飲",
            limitMinorUnits: 3_000,
            expectedMonthlyCount: 5,
            schemaVersion: 1,
            createdAt: now,
            updatedAt: now
        )
        let transactions = [
            makeTransaction(id: "t1", minorUnits: -1_000, budgetId: "b1", occurredAt: now),
            makeTransaction(id: "t2", minorUnits: -500, budgetId: "b1", occurredAt: now)
        ]
        let viewModel = makeViewModel(budgets: [budget], transactions: transactions)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        let progress = viewModel.progress(for: budget, month: now)
        #expect(progress.spentMinorUnits == 1_500)
        #expect(progress.remainingMinorUnits == 1_500)
        #expect(progress.usedCount == 2)
        #expect(progress.expectedCount == 5)
        // remaining 1,500 ÷ max(5 - 2, 1) = 1,500 ÷ 3 = 500
        #expect(progress.suggestedNextAmountMinorUnits == 500)

        observation.cancel()
    }

    /// Phase 3: over-budget case — spent more than the limit. Suggested amount should
    /// be nil (the view shows "已超出預算" instead of a number), and remaining is negative.
    @Test func progressReturnsNilSuggestionWhenOverBudget() async throws {
        let now = Date()
        let budget = BudgetRecord(
            id: "b1",
            name: "交通",
            limitMinorUnits: 1_200,
            expectedMonthlyCount: 8,
            schemaVersion: 1,
            createdAt: now,
            updatedAt: now
        )
        let transactions = [
            makeTransaction(id: "t1", minorUnits: -1_500, budgetId: "b1", occurredAt: now)
        ]
        let viewModel = makeViewModel(budgets: [budget], transactions: transactions)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        let progress = viewModel.progress(for: budget, month: now)
        #expect(progress.remainingMinorUnits == -300)
        #expect(progress.suggestedNextAmountMinorUnits == nil)

        observation.cancel()
    }

    /// Phase 3: transactions from a different budget, a different month, or that are
    /// income (positive amount) should all be excluded from the calculation.
    @Test func progressExcludesOtherBudgetsOtherMonthsAndIncome() async throws {
        let now = Date()
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        let budget = BudgetRecord(
            id: "b1",
            name: "餐飲",
            limitMinorUnits: 3_000,
            expectedMonthlyCount: 5,
            schemaVersion: 1,
            createdAt: now,
            updatedAt: now
        )
        let transactions = [
            makeTransaction(id: "t1", minorUnits: -1_000, budgetId: "b1", occurredAt: now),
            makeTransaction(id: "t2", minorUnits: -9_999, budgetId: "b2", occurredAt: now), // 別的類別
            makeTransaction(id: "t3", minorUnits: -9_999, budgetId: "b1", occurredAt: lastMonth), // 上個月
            makeTransaction(id: "t4", minorUnits: 30_000, budgetId: "b1", occurredAt: now) // 收入，不算消費
        ]
        let viewModel = makeViewModel(budgets: [budget], transactions: transactions)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        let progress = viewModel.progress(for: budget, month: now)
        #expect(progress.spentMinorUnits == 1_000)
        #expect(progress.usedCount == 1)

        observation.cancel()
    }

    /// Phase 4: the disclosure list should show only this budget's expenses for the
    /// given month, newest first — same filter as `progress(for:)` (see the test above
    /// verifying that filter), plus the sort order.
    @Test func transactionsForBudgetReturnsThisMonthsExpensesNewestFirst() async throws {
        let now = Date()
        let earlier = now.addingTimeInterval(-3_600) // 1 小時前
        let earliest = now.addingTimeInterval(-7_200) // 2 小時前
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        let budget = BudgetRecord(
            id: "b1",
            name: "餐飲",
            limitMinorUnits: 3_000,
            expectedMonthlyCount: 5,
            schemaVersion: 1,
            createdAt: now,
            updatedAt: now
        )
        let transactions = [
            makeTransaction(id: "t1", minorUnits: -500, budgetId: "b1", occurredAt: earliest),
            makeTransaction(id: "t2", minorUnits: -300, budgetId: "b1", occurredAt: now),
            makeTransaction(id: "t3", minorUnits: -400, budgetId: "b1", occurredAt: earlier),
            makeTransaction(id: "t4", minorUnits: -999, budgetId: "b2", occurredAt: now), // 別的類別
            makeTransaction(id: "t5", minorUnits: -999, budgetId: "b1", occurredAt: lastMonth) // 上個月
        ]
        let viewModel = makeViewModel(budgets: [budget], transactions: transactions)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        let result = viewModel.monthlyTransactions(for: budget, month: now)

        #expect(result.map(\.id) == ["t2", "t3", "t1"])

        observation.cancel()
    }

    /// Small factory so every test doesn't have to spell out all three repositories
    /// (budgets, transactions, profile) by hand — Phase 5 added the third one
    /// (`ProfileRepository`), and most tests here don't care about it at all.
    private func makeViewModel(
        budgets: [BudgetRecord] = [],
        transactions: [TransactionRecord] = [],
        profileLimitMinorUnits: Int64 = 0
    ) -> BudgetListViewModel {
        BudgetListViewModel(
            repository: InMemoryBudgetRepository(seed: budgets),
            transactionRepository: InMemoryFinancialRepository(seed: transactions),
            profileRepository: InMemoryProfileRepository(seed: ProfileRecord(
                monthlyBudgetLimitMinorUnits: profileLimitMinorUnits,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            ))
        )
    }

    private func makeTransaction(
        id: String,
        minorUnits: Int64,
        budgetId: String?,
        occurredAt: Date
    ) -> TransactionRecord {
        TransactionRecord(
            id: id,
            amount: Money(minorUnits: minorUnits, currencyCode: "TWD"),
            budgetId: budgetId,
            occurredAt: occurredAt,
            note: nil,
            source: .manual,
            schemaVersion: 1,
            createdAt: occurredAt,
            updatedAt: occurredAt
        )
    }
}
