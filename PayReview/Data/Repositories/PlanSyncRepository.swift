import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

struct PlanSyncRequest: Equatable {
    let goalName: String
    let incomeCadence: IncomeCadence
    let plannedExpenseTotalMinorUnits: Int64
    let flexibleBudgetMinorUnits: Int64
}

protocol PlanSyncing {
    func synchronizePlan(_ request: PlanSyncRequest) async throws
}

enum PlanSyncError: LocalizedError {
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "請先登入後再更新計畫。"
        }
    }
}

struct FirestorePlanRepository: PlanSyncing {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func synchronizePlan(_ request: PlanSyncRequest) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw PlanSyncError.unauthenticated
        }

        let planDocument = firestore
            .collection("users")
            .document(uid)
            .collection("financialPlans")
            .document("current")

        var data: [String: Any] = [
            "name": request.goalName,
            "incomeCadence": request.incomeCadence.rawValue,
            "plannedExpenseTotalMinorUnits": request.plannedExpenseTotalMinorUnits,
            "flexibleBudgetMinorUnits": request.flexibleBudgetMinorUnits,
            "currencyCode": "TWD",
            "schemaVersion": 1,
            "source": "manual",
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let existingDocument = try await planDocument.getDocument()
        if !existingDocument.exists {
            data["createdAt"] = FieldValue.serverTimestamp()
        }

        try await planDocument.setData(data, merge: true)
    }
}

@MainActor
final class PlanSyncStore: ObservableObject {
    enum State: Equatable {
        case idle
        case synchronizing
        case synchronized
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let repository: PlanSyncing

    init(repository: PlanSyncing) {
        self.repository = repository
    }

    var isSynchronizing: Bool {
        state == .synchronizing
    }

    var errorMessage: String? {
        guard case let .failed(message) = state else { return nil }
        return message
    }

    func synchronize(_ request: PlanSyncRequest) async -> Bool {
        state = .synchronizing

        do {
            try await repository.synchronizePlan(request)
            state = .synchronized
            return true
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }

    func dismissError() {
        if case .failed = state {
            state = .idle
        }
    }
}
