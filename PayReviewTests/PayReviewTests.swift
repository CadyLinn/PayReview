//
//  PayReviewTests.swift
//  PayReviewTests
//
//  Created by 廖為 on 2026/7/26.
//

import Testing
@testable import PayReview
import Foundation

struct FinancialRecordsTest {
    @Test func moneyCodableRoundTrip() throws {
        let original = Money(minorUnits: -1500, currencyCode: "TWD")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Money.self, from: data)
        #expect(decoded == original)
    }
    
    @Test func transactionRecordCodableRoundTripWithOptionals() throws {
        let original = TransactionRecord(
            id: "t1",
            amount: Money(minorUnits: 30000, currencyCode: "TWD"),
            categoryLabel: "薪資",
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            note: "七月薪水",
            source: .manual,
            schemaVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransactionRecord.self, from: data)
        #expect(decoded == original)
    }
    
    @Test func transactionRecordCodableRoundTripWithNilOptionals() throws {
        let original = TransactionRecord(
            id: "t1",
            amount: Money(minorUnits: 30000, currencyCode: "TWD"),
            categoryLabel: nil,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            note: nil,
            source: .manual,
            schemaVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransactionRecord.self, from: data)
        #expect(decoded == original)
    }
    
    @Test func transactionSourceDecodesFromRawValue() throws {
        let json = Data("\"manual\"".utf8)
        let decoded = try JSONDecoder().decode(TransactionSource.self, from: json)
        #expect(decoded == .manual)
    }
}
