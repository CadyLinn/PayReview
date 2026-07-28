import Foundation

protocol TransactionRepository {
    func observeTransactions() async -> AsyncStream<[TransactionRecord]>

    func newTransactionID() -> String

    func addTransaction(_ transaction: TransactionRecord) async throws

    /// Phase 5: overwrites an existing transaction (matched by `transaction.id`) in
    /// place, for the "tap a row in 紀錄 to edit it" flow.
    func updateTransaction(_ transaction: TransactionRecord) async throws

    /// Permanently removes a transaction, for the delete button in the edit sheet.
    func deleteTransaction(id: String) async throws
}

enum FinancialDataRepositoryError: LocalizedError, Sendable {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "目前無法載入財務資料。"
        }
    }
}
