import FirebaseFunctions
import Foundation

protocol AccountStateServicing {
    func prepareActiveAccount() async throws -> AccountPreparation
}

struct AccountPreparation: Equatable, Sendable {
    let hasFinancialPlan: Bool
}

enum AccountStateServiceError: LocalizedError {
    case unexpectedResponse
    case inactiveAccount

    var errorDescription: String? {
        switch self {
        case .unexpectedResponse:
            return "帳號狀態服務回傳的資料無法使用。"
        case .inactiveAccount:
            return "此帳號目前無法使用。"
        }
    }
}

struct AccountStateService: AccountStateServicing {
    func prepareActiveAccount() async throws -> AccountPreparation {
        let functions = Functions.functions(region: "asia-east1")
        let result = try await functions.httpsCallable("ensureAccountState").call()

        guard let payload = result.data as? [String: Any],
              let status = payload["status"] as? String else {
            throw AccountStateServiceError.unexpectedResponse
        }

        guard status == "active" else {
            throw AccountStateServiceError.inactiveAccount
        }

        return AccountPreparation(
            hasFinancialPlan: payload["hasFinancialPlan"] as? Bool ?? false
        )
    }
}
