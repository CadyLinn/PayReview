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

// v2 Phase 5: a single per-user document (not a collection) holding whole-app
// settings that aren't tied to any one transaction or budget. Today that's just
// the total monthly budget the user allocates individual BudgetRecords out of;
// more settings can be added to this same document later without a schema
// migration, since it's already a flexible "one document per user" shape.
struct ProfileRecord: Codable, Equatable, Sendable {
    let monthlyBudgetLimitMinorUnits: Int64
    let schemaVersion: Int
    let createdAt: Date
    let updatedAt: Date

    /// What a brand-new user has before they've ever set a total budget — 0, not
    /// some placeholder Optional, so the rest of the app (sliders, arithmetic) never
    /// has to unwrap a "maybe there's no profile yet" case.
    static let unset = ProfileRecord(
        monthlyBudgetLimitMinorUnits: 0,
        schemaVersion: 1,
        createdAt: .now,
        updatedAt: .now
    )
}
