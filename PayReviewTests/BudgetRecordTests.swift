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

    /// 消費頻率 Phase 1: a weekly budget with actual weekday/month-day selections
    /// should round-trip through Codable exactly the same way the plain fields do —
    /// this is the same encode/decode path `FirestoreBudgetRepository` uses.
    @Test func budgetRecordWithFrequencyCodableRoundTrip() throws {
        let original = BudgetRecord(
            id: "b1",
            name: "健身房",
            limitMinorUnits: 1_500,
            expectedMonthlyCount: 12,
            frequency: .weekly,
            frequencyWeekdays: [2, 4, 6],
            schemaVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BudgetRecord.self, from: data)
        #expect(decoded == original)
        #expect(decoded.frequency == .weekly)
        #expect(decoded.frequencyWeekdays == [2, 4, 6])
    }

    /// 消費頻率 Phase 1: budgets saved to Firestore *before* this feature shipped
    /// have no `frequency`/`frequencyWeekdays`/`frequencyMonthDays` keys at all.
    /// `BudgetRecord`'s custom `init(from:)` must treat that as "no frequency
    /// configured" instead of throwing — otherwise every pre-existing user's
    /// `observeBudgets()` stream would break the moment this feature ships.
    @Test func decodingLegacyJSONWithoutFrequencyFieldsFallsBackToCustom() throws {
        let legacyJSON = """
        {
            "id": "b1",
            "name": "餐飲",
            "limitMinorUnits": 3000,
            "expectedMonthlyCount": 5,
            "schemaVersion": 1,
            "createdAt": 1700000000,
            "updatedAt": 1700000000
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(BudgetRecord.self, from: legacyJSON)

        #expect(decoded.frequency == .custom)
        #expect(decoded.frequencyWeekdays.isEmpty)
        #expect(decoded.frequencyMonthDays.isEmpty)
    }

    @Test func isScheduledMatchesDailyEveryDay() {
        let budget = BudgetRecord(
            id: "b1", name: "早餐", limitMinorUnits: 900, expectedMonthlyCount: 30,
            frequency: .daily,
            schemaVersion: 1, createdAt: .now, updatedAt: .now
        )
        let calendar = Calendar(identifier: .gregorian)
        let someTuesday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 28))!
        let someSunday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        #expect(budget.isScheduled(on: someTuesday, calendar: calendar))
        #expect(budget.isScheduled(on: someSunday, calendar: calendar))
    }

    @Test func isScheduledMatchesWeeklyOnlyOnSelectedWeekdays() {
        // 2026/7/28 is a Tuesday (weekday 3 in Calendar's 1=Sunday numbering).
        let calendar = Calendar(identifier: .gregorian)
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 28))!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 29))!

        let budget = BudgetRecord(
            id: "b1", name: "健身房", limitMinorUnits: 1_500, expectedMonthlyCount: 8,
            frequency: .weekly, frequencyWeekdays: [3],
            schemaVersion: 1, createdAt: .now, updatedAt: .now
        )
        #expect(budget.isScheduled(on: tuesday, calendar: calendar))
        #expect(!budget.isScheduled(on: wednesday, calendar: calendar))
    }

    @Test func isScheduledMatchesMonthlyOnlyOnSelectedDays() {
        let calendar = Calendar(identifier: .gregorian)
        let the5th = calendar.date(from: DateComponents(year: 2026, month: 7, day: 5))!
        let the6th = calendar.date(from: DateComponents(year: 2026, month: 7, day: 6))!

        let budget = BudgetRecord(
            id: "b1", name: "房租", limitMinorUnits: 12_000, expectedMonthlyCount: 1,
            frequency: .monthly, frequencyMonthDays: [5],
            schemaVersion: 1, createdAt: .now, updatedAt: .now
        )
        #expect(budget.isScheduled(on: the5th, calendar: calendar))
        #expect(!budget.isScheduled(on: the6th, calendar: calendar))
    }

    @Test func isScheduledNeverMatchesCustom() {
        let budget = BudgetRecord(
            id: "b1", name: "其他", limitMinorUnits: 1_000, expectedMonthlyCount: 3,
            frequency: .custom,
            schemaVersion: 1, createdAt: .now, updatedAt: .now
        )
        #expect(!budget.isScheduled(on: .now))
    }

    @Test func suggestedExpectedMonthlyCountMatchesApprovedDefaults() {
        #expect(BudgetRecord.suggestedExpectedMonthlyCount(frequency: .daily, weekdays: [], monthDays: []) == 30)
        #expect(BudgetRecord.suggestedExpectedMonthlyCount(frequency: .weekly, weekdays: [2, 4], monthDays: []) == 8)
        #expect(BudgetRecord.suggestedExpectedMonthlyCount(frequency: .monthly, weekdays: [], monthDays: [1, 15, 30]) == 3)
        #expect(BudgetRecord.suggestedExpectedMonthlyCount(frequency: .custom, weekdays: [1], monthDays: [1]) == nil)
    }
}
