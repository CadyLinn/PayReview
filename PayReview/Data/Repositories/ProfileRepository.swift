import Foundation

/// Unlike `TransactionRepository`/`BudgetRepository`, this isn't backed by a
/// collection of many documents — there's exactly one profile per user. So instead
/// of `newID()`/`add()`, there's just one upsert method: `setMonthlyBudgetLimit`.
protocol ProfileRepository {
    /// Always yields a `ProfileRecord` (never nil/optional) — see `ProfileRecord.unset`
    /// for why: a user who has never set a total budget just gets 0, not a special case.
    func observeProfile() async -> AsyncStream<ProfileRecord>

    func setMonthlyBudgetLimit(minorUnits: Int64) async throws
}
