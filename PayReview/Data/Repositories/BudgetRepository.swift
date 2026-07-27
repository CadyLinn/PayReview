import Foundation

protocol BudgetRepository {
    func observeBudgets() async -> AsyncStream<[BudgetRecord]>
    func newBudgetID() -> String
    func addBudget(_ budget: BudgetRecord) async throws
    /// Phase 5: overwrites an existing budget (matched by `budget.id`) in place.
    /// Kept as its own method rather than reusing `addBudget` because the two fakes
    /// behave differently — `addBudget` appends, `updateBudget` replaces — even
    /// though the real Firestore call underneath happens to be identical either way.
    func updateBudget(_ budget: BudgetRecord) async throws
}
