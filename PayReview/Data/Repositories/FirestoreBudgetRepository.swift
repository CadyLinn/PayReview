import FirebaseFirestore

final class FirestoreBudgetRepository: BudgetRepository {
    private let collection: CollectionReference

    init(uid: String) {
        collection = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("budgets")
    }

    func newBudgetID() -> String {
        collection.document().documentID
    }

    func observeBudgets() async -> AsyncStream<[BudgetRecord]> {
        AsyncStream<[BudgetRecord]> { continuation in
            let listener = collection.addSnapshotListener { snapshot, error in
                if let error {
                    print("Firestore listener error: \(error)")
                    continuation.finish()
                    return
                }

                let records = snapshot?.documents.compactMap { document -> BudgetRecord? in
                    try? document.data(as: BudgetRecord.self)
                } ?? []
                continuation.yield(records)
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func addBudget(_ budget: BudgetRecord) async throws {
        try collection.document(budget.id).setData(from: budget)
    }
}
