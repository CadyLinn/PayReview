//
//  ProfileRecordTests.swift
//  PayReviewTests
//

import Testing
@testable import PayReview
import Foundation

struct ProfileRecordTests {
    @Test func profileRecordCodableRoundTrip() throws {
        let original = ProfileRecord(
            monthlyBudgetLimitMinorUnits: 20_000,
            schemaVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProfileRecord.self, from: data)
        #expect(decoded == original)
    }

    /// `.unset` is what a brand-new user's profile looks like before they've ever
    /// typed anything into the total-budget field — should be 0, not some sentinel
    /// that the rest of the app has to special-case.
    @Test func unsetDefaultsToZeroMonthlyBudget() {
        #expect(ProfileRecord.unset.monthlyBudgetLimitMinorUnits == 0)
    }
}
