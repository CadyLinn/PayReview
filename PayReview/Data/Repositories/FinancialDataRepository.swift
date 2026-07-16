import Foundation

protocol FinancialDataRepository {
    func loadSnapshot() async throws -> FinancialDataSnapshot
}

enum FinancialDataRepositoryError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "目前無法載入財務資料。"
        }
    }
}
