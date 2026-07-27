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
