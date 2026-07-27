//
//  BudgetRecordTests.swift
//  PayReviewTests
//

import Testing
@testable import PayReview
import Foundation

struct BudgetRecordTests {
    @Test func budgetRecordCodableRoundTrip() throws {
        let original = BudgetRecord(
            id: "b1",
            name: "餐飲",
            limitMinorUnits: 3_000,
            expectedMonthlyCount: 5,
            schemaVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BudgetRecord.self, from: data)
        #expect(decoded == original)
    }
}
