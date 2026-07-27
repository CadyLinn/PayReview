//
//  TransactionListViewModel.swift
//  PayReview
//
//  Created by 廖為 on 2026/7/27.
//

import Foundation
import Observation

enum TransactionListState: Equatable {
    case loading
    case loaded([TransactionRecord])
    case error
}

@MainActor
@Observable
final class TransactionListViewModel {
    private(set) var state: TransactionListState = .loading

    // v2 Phase 2: the "類別" Picker in AddTransactionView needs to know which budgets
    // exist. This is deliberately a separate property from `state` — the transaction
    // list has its own loading/loaded/error lifecycle, but the budget list is just
    // supplementary data for a form control, so it starts empty and fills in
    // whenever the stream delivers something, with no dedicated loading UI.
    private(set) var budgets: [BudgetRecord] = []

    private let repository: TransactionRepository
    private let budgetRepository: BudgetRepository

    init(repository: TransactionRepository, budgetRepository: BudgetRepository) {
        self.repository = repository
        self.budgetRepository = budgetRepository
    }

    var balanceMinorUnits: Int64 {
        guard case .loaded(let records) = state else { return 0 }
        return records.reduce(0) { $0 + $1.amount.minorUnits }
    }

    /// Subscribes to both the transaction stream and the budget stream, and keeps
    /// them running side by side for as long as this view is on screen.
    ///
    /// Why `async let` instead of two separate `.task` modifiers on the View: both
    /// loops are `for await ... in stream` loops that only return when their stream
    /// finishes, so each one individually blocks forever (until an error). `async let`
    /// starts both as child tasks that run concurrently, and the final `_ = await (...)`
    /// line waits for both to finish before `start()` itself returns. Without this,
    /// awaiting the transaction stream directly (like Phase 1 did) would never even
    /// start listening for budgets.
    func start() async {
        async let transactionsTask: Void = observeTransactions()
        async let budgetsTask: Void = observeBudgets()
        _ = await (transactionsTask, budgetsTask)
    }

    private func observeTransactions() async {
        for await latest in await repository.observeTransactions() {
            state = .loaded(latest)
        }
        state = .error
    }

    private func observeBudgets() async {
        for await latest in await budgetRepository.observeBudgets() {
            budgets = latest
        }
    }

    /// Creates and persists a new transaction. `amountMinorUnits` should already carry
    /// the correct sign: positive for income, negative for expense. `budgetId` is the
    /// id of a `BudgetRecord` the user picked, or nil for "請選擇類別" (uncategorized).
    func addTransaction(
        amountMinorUnits: Int64,
        budgetId: String?,
        note: String?
    ) async {
        let id = repository.newTransactionID()
        let now = Date()
        let transaction = TransactionRecord(
            id: id,
            amount: Money(minorUnits: amountMinorUnits, currencyCode: "TWD"),
            budgetId: budgetId,
            occurredAt: now,
            note: note,
            source: .manual,
            schemaVersion: 1,
            createdAt: now,
            updatedAt: now
        )
        do {
            try await repository.addTransaction(transaction)
        } catch {
            // v1 keeps this simple: log only, no dedicated error-presentation state yet.
            print("Failed to add transaction: \(error)")
        }
    }
}
