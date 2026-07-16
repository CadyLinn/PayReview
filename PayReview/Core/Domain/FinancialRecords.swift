import Foundation

struct Money: Codable, Equatable, Hashable, Sendable {
    let minorUnits: Int64
    let currencyCode: String

    init(minorUnits: Int64, currencyCode: String = "TWD") {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }
}

struct FinancialPlanRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let currencyCode: String
}

struct IncomeCycleRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let planID: String
    let startsAt: Date
    let endsAt: Date
    let expectedIncome: Money
}

struct FlexibleBudgetRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let planID: String
    let cycleID: String
    let allocation: Money
}

struct GoalRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let targetAmount: Money
    let savedAmount: Money
    let targetDate: Date
}

struct PlannedExpenseRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let expectedAmount: Money
    let dueDate: Date
    let isEssential: Bool
    let isCompleted: Bool
}

enum TransactionKind: String, Codable, Sendable {
    case income
    case expense
}

struct TransactionRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let kind: TransactionKind
    let amount: Money
    let categoryID: String
    let occurredAt: Date
    let plannedExpenseOccurrenceID: String?
}

struct CategoryRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: TransactionKind
}

struct TransferRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let amount: Money
    let occurredAt: Date
}

struct FinancialDataSnapshot: Equatable, Sendable {
    let plan: FinancialPlanRecord
    let incomeCycle: IncomeCycleRecord
    let flexibleBudget: FlexibleBudgetRecord
    let categories: [CategoryRecord]
    let goals: [GoalRecord]
    let plannedExpenses: [PlannedExpenseRecord]
    let transactions: [TransactionRecord]
    let transfers: [TransferRecord]
}
