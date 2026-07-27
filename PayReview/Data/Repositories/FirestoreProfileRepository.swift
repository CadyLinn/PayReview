import FirebaseFirestore

final class FirestoreProfileRepository: ProfileRepository {
    private let docRef: DocumentReference

    init(uid: String) {
        docRef = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("profile")
            .document("main")
    }

    func observeProfile() async -> AsyncStream<ProfileRecord> {
        AsyncStream<ProfileRecord> { continuation in
            let listener = docRef.addSnapshotListener { snapshot, error in
                if let error {
                    print("Firestore listener error: \(error)")
                    continuation.yield(.unset)
                    return
                }
                // A brand-new user has no profile document at all yet — that's not
                // an error, it just means "no total budget set", i.e. `.unset`.
                guard let snapshot, snapshot.exists,
                      let record = try? snapshot.data(as: ProfileRecord.self) else {
                    continuation.yield(.unset)
                    return
                }
                continuation.yield(record)
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func setMonthlyBudgetLimit(minorUnits: Int64) async throws {
        // Read the existing document first (if any) purely to preserve its
        // `createdAt` — otherwise every edit would look like the profile was
        // just created, which is wrong once there's an actual first-set date.
        let existing = try? await docRef.getDocument(as: ProfileRecord.self)
        let now = Date()
        let record = ProfileRecord(
            monthlyBudgetLimitMinorUnits: minorUnits,
            schemaVersion: existing?.schemaVersion ?? 1,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
        try docRef.setData(from: record)
    }
}
