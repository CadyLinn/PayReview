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

    private let repository: TransactionRepository

    init(repository: TransactionRepository) {
        self.repository = repository
    }

    var balanceMinorUnits: Int64 {
        guard case .loaded(let records) = state else { return 0 }
        return records.reduce(0) { $0 + $1.amount.minorUnits }
    }

    /// Subscribes to the repository's transaction stream and keeps `state` in sync.
    /// This runs until the underlying stream finishes (which we treat as a failure,
    /// since `observeTransactions()` only finishes early when the Firestore listener
    /// hit an error).
    func start() async {
        for await latest in await repository.observeTransactions() {
            state = .loaded(latest)
        }
        state = .error
    }

    /// Creates and persists a new transaction. `amountMinorUnits` should already carry
    /// the correct sign: positive for income, negative for expense.
    func addTransaction(
        amountMinorUnits: Int64,
        categoryLabel: String?,
        note: String?
    ) async {
        let id = repository.newTransactionID()
        let now = Date()
        let transaction = TransactionRecord(
            id: id,
            amount: Money(minorUnits: amountMinorUnits, currencyCode: "TWD"),
            categoryLabel: categoryLabel,
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
