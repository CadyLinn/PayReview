import Foundation

protocol TransactionRepository {
    func observeTransactions() async -> AsyncStream<[TransactionRecord]>
    
    func newTransactionID() -> String
    
    func addTransaction(_ transaction: TransactionRecord) async throws
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
