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
    let categoryLabel: String?
    let occurredAt: Date
    let note: String?
    let source: TransactionSource
    let schemaVersion: Int
    let createdAt: Date
    let updatedAt: Date
}
