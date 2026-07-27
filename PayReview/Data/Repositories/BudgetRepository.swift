import Foundation

protocol BudgetRepository {
    func observeBudgets() async -> AsyncStream<[BudgetRecord]>
    func newBudgetID() -> String
    func addBudget(_ budget: BudgetRecord) async throws
}
