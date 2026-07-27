import Foundation

actor InMemoryProfileRepository: ProfileRepository {
    private var profile: ProfileRecord
    private var continuations: [UUID: AsyncStream<ProfileRecord>.Continuation] = [:]

    /// `seed` lets previews/tests start with a total budget already set, same
    /// reasoning as the `seed:` inits on `InMemoryBudgetRepository` and
    /// `InMemoryFinancialRepository`.
    init(seed: ProfileRecord = .unset) {
        profile = seed
    }

    func observeProfile() async -> AsyncStream<ProfileRecord> {
        let id = UUID()
        return AsyncStream<ProfileRecord> { continuation in
            continuation.yield(profile)
            self.continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    func setMonthlyBudgetLimit(minorUnits: Int64) async throws {
        // Preserve the original createdAt instead of resetting it on every edit —
        // this is still "the same profile document", just with an updated field.
        profile = ProfileRecord(
            monthlyBudgetLimitMinorUnits: minorUnits,
            schemaVersion: profile.schemaVersion,
            createdAt: profile.createdAt,
            updatedAt: Date()
        )
        for continuation in continuations.values {
            continuation.yield(profile)
        }
    }
}
