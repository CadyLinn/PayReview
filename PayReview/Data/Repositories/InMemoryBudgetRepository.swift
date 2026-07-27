import Foundation

actor InMemoryBudgetRepository: BudgetRepository {
    private var budgets: [BudgetRecord]
    private var continuations: [UUID: AsyncStream<[BudgetRecord]>.Continuation] = [:]

    /// `seed` lets callers (mainly SwiftUI #Preview) start this fake repository
    /// pre-populated, so a preview can show a realistic "already has budgets" state
    /// without going through async addBudget() calls first.
    init(seed: [BudgetRecord] = []) {
        budgets = seed
    }

    func observeBudgets() async -> AsyncStream<[BudgetRecord]> {
        let id = UUID()
        return AsyncStream<[BudgetRecord]> { continuation in
            continuation.yield(budgets)
            self.continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    nonisolated func newBudgetID() -> String {
        UUID().uuidString
    }

    func addBudget(_ budget: BudgetRecord) async throws {
        budgets.append(budget)
        for continuation in continuations.values {
            continuation.yield(budgets)
        }
    }
}
