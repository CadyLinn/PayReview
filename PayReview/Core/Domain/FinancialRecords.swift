import Foundation

struct Money: Codable, Hashable, Sendable {
    let minorUnits: Int64 // pos = income; neg = expenses
    let currencyCode: String
}

enum TransactionSource: String, Codable, Sendable {
    case manual
}

struct TransactionRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let amount: Money
    // v2 Phase 2: was a free-text `categoryLabel`; now points at a `BudgetRecord.id`
    // so the UI can offer a fixed Picker of existing budgets instead of typed text,
    // and so Phase 3/4 can group transactions by budget without string-matching.
    // nil means "uncategorized" (the "請選擇類別" default).
    let budgetId: String?
    let occurredAt: Date
    let note: String?
    let source: TransactionSource
    let schemaVersion: Int
    let createdAt: Date
    let updatedAt: Date
}

// v2: a Budget doubles as a category — creating one gives users something to file
// transactions under (Phase 2) and something to track monthly spend against
// (Phase 3/4). There is deliberately no separate structured Category type.
struct BudgetRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let limitMinorUnits: Int64
    let expectedMonthlyCount: Int
    let schemaVersion: Int
    let createdAt: Date
    let updatedAt: Date
}
