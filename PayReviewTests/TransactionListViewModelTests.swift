//
//  TransactionListViewModelTests.swift
//  PayReviewTests
//
//  Created by 廖為 on 2026/7/27.
//

import Testing
@testable import PayReview
import Foundation

@MainActor
struct TransactionListViewModelTests {
    @Test func addingTransactionUpdatesStateAndBalance() async throws {
        let repository = InMemoryFinancialRepository()
        let budgetRepository = InMemoryBudgetRepository()
        let viewModel = TransactionListViewModel(repository: repository, budgetRepository: budgetRepository)

        let observation = Task { await viewModel.start() }
        // Give the stream a moment to deliver the initial (empty) snapshot before we
        // add anything. A fixed sleep is a simplification for now, not a robust
        // synchronization mechanism.
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.addTransaction(
            amountMinorUnits: 30_000,
            budgetId: "b1",
            note: nil
        )
        try await Task.sleep(for: .milliseconds(50))

        guard case .loaded(let records) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            observation.cancel()
            return
        }

        #expect(records.count == 1)
        #expect(records.first?.budgetId == "b1")
        #expect(viewModel.balanceMinorUnits == 30_000)

        observation.cancel()
    }

    @Test func balanceSumsSignedAmountsAcrossMultipleTransactions() async throws {
        let repository = InMemoryFinancialRepository()
        let budgetRepository = InMemoryBudgetRepository()
        let viewModel = TransactionListViewModel(repository: repository, budgetRepository: budgetRepository)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.addTransaction(amountMinorUnits: 30_000, budgetId: "b1", note: nil)
        await viewModel.addTransaction(amountMinorUnits: -1_200, budgetId: "b2", note: nil)
        await viewModel.addTransaction(amountMinorUnits: -800, budgetId: "b3", note: nil)
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.balanceMinorUnits == 28_000)

        observation.cancel()
    }

    /// Phase 5: editing a transaction should overwrite it in place (same id,
    /// same occurredAt/createdAt) rather than appending a second one, and the
    /// balance should reflect the new amount, not the old one.
    @Test func updatingTransactionOverwritesInPlaceAndUpdatesBalance() async throws {
        let repository = InMemoryFinancialRepository()
        let budgetRepository = InMemoryBudgetRepository()
        let viewModel = TransactionListViewModel(repository: repository, budgetRepository: budgetRepository)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.addTransaction(amountMinorUnits: -500, budgetId: "b1", note: "午餐")
        try await Task.sleep(for: .milliseconds(50))

        guard case .loaded(let recordsBeforeEdit) = viewModel.state, let original = recordsBeforeEdit.first else {
            Issue.record("Expected one transaction after adding it")
            observation.cancel()
            return
        }

        await viewModel.updateTransaction(
            original,
            amountMinorUnits: -800,
            budgetId: "b2",
            note: "晚餐"
        )
        try await Task.sleep(for: .milliseconds(50))

        guard case .loaded(let recordsAfterEdit) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            observation.cancel()
            return
        }

        #expect(recordsAfterEdit.count == 1)
        #expect(recordsAfterEdit.first?.id == original.id)
        #expect(recordsAfterEdit.first?.amount.minorUnits == -800)
        #expect(recordsAfterEdit.first?.budgetId == "b2")
        #expect(recordsAfterEdit.first?.note == "晚餐")
        #expect(recordsAfterEdit.first?.occurredAt == original.occurredAt)
        #expect(viewModel.balanceMinorUnits == -800)

        observation.cancel()
    }

    /// Phase 6: deleting a transaction should remove it from state (and its amount
    /// should stop counting toward the balance) — the red "刪除這筆資料" button flow.
    @Test func deletingTransactionRemovesItAndUpdatesBalance() async throws {
        let repository = InMemoryFinancialRepository()
        let budgetRepository = InMemoryBudgetRepository()
        let viewModel = TransactionListViewModel(repository: repository, budgetRepository: budgetRepository)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        await viewModel.addTransaction(amountMinorUnits: -500, budgetId: "b1", note: "午餐")
        await viewModel.addTransaction(amountMinorUnits: 30_000, budgetId: nil, note: "薪水")
        try await Task.sleep(for: .milliseconds(50))

        guard case .loaded(let records) = viewModel.state, let toDelete = records.first(where: { $0.note == "午餐" }) else {
            Issue.record("Expected to find the 午餐 transaction after adding it")
            observation.cancel()
            return
        }

        await viewModel.deleteTransaction(toDelete)
        try await Task.sleep(for: .milliseconds(50))

        guard case .loaded(let remaining) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            observation.cancel()
            return
        }

        #expect(remaining.count == 1)
        #expect(remaining.first?.note == "薪水")
        #expect(viewModel.balanceMinorUnits == 30_000)

        observation.cancel()
    }

    /// 新增: `AddTransactionView`'s new date picker passes an explicit `occurredAt`
    /// through to `addTransaction` — confirms it's actually used instead of being
    /// silently ignored in favor of "now".
    @Test func addingTransactionWithExplicitOccurredAtUsesThatDate() async throws {
        let repository = InMemoryFinancialRepository()
        let budgetRepository = InMemoryBudgetRepository()
        let viewModel = TransactionListViewModel(repository: repository, budgetRepository: budgetRepository)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        let pickedDate = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        await viewModel.addTransaction(amountMinorUnits: -500, budgetId: "b1", note: "早餐", occurredAt: pickedDate)
        try await Task.sleep(for: .milliseconds(50))

        guard case .loaded(let records) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            observation.cancel()
            return
        }
        #expect(records.first?.occurredAt == pickedDate)
        observation.cancel()
    }

    /// 新增: editing a transaction's date should change `occurredAt` when a new one
    /// is passed, but leave it alone (falls back to `original.occurredAt`) when the
    /// caller doesn't supply one — the same backward-compatible default every
    /// other Phase 5 call site already relies on.
    @Test func updatingTransactionCanChangeOrPreserveOccurredAt() async throws {
        let repository = InMemoryFinancialRepository()
        let budgetRepository = InMemoryBudgetRepository()
        let viewModel = TransactionListViewModel(repository: repository, budgetRepository: budgetRepository)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        let originalDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        await viewModel.addTransaction(amountMinorUnits: -500, budgetId: "b1", note: "午餐", occurredAt: originalDate)
        try await Task.sleep(for: .milliseconds(50))

        guard case .loaded(let recordsBeforeEdit) = viewModel.state, let original = recordsBeforeEdit.first else {
            Issue.record("Expected one transaction after adding it")
            observation.cancel()
            return
        }

        // No `occurredAt:` supplied — should preserve the original date.
        await viewModel.updateTransaction(original, amountMinorUnits: -600, budgetId: "b1", note: "午餐")
        try await Task.sleep(for: .milliseconds(50))
        if case .loaded(let afterFirstEdit) = viewModel.state {
            #expect(afterFirstEdit.first?.occurredAt == originalDate)
        } else {
            Issue.record("Expected .loaded state")
        }

        // Explicit `occurredAt:` supplied — should overwrite it.
        let newDate = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        await viewModel.updateTransaction(original, amountMinorUnits: -600, budgetId: "b1", note: "午餐", occurredAt: newDate)
        try await Task.sleep(for: .milliseconds(50))
        if case .loaded(let afterSecondEdit) = viewModel.state {
            #expect(afterSecondEdit.first?.occurredAt == newDate)
        } else {
            Issue.record("Expected .loaded state")
        }

        observation.cancel()
    }

    @Test func budgetsPropertyReflectsBudgetRepositoryStream() async throws {
        let repository = InMemoryFinancialRepository()
        let budgetRepository = InMemoryBudgetRepository(seed: [
            BudgetRecord(
                id: "b1",
                name: "餐飲",
                limitMinorUnits: 3_000,
                expectedMonthlyCount: 5,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            )
        ])
        let viewModel = TransactionListViewModel(repository: repository, budgetRepository: budgetRepository)

        let observation = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.budgets.count == 1)
        #expect(viewModel.budgets.first?.name == "餐飲")

        observation.cancel()
    }
}
