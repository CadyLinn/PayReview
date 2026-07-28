//
//  CalculatorKeypadViewTests.swift
//  PayReviewTests
//

import Testing
@testable import PayReview

struct CalculatorKeypadViewTests {
    @Test func evaluatesPlainInteger() {
        #expect(CalculatorKeypadView.evaluatedAmount(from: "80") == 80)
    }

    @Test func evaluatesAddition() {
        #expect(CalculatorKeypadView.evaluatedAmount(from: "120+35") == 155)
    }

    @Test func evaluatesMultiplicationBeforeAdditionLikeAnyCalculator() {
        // NSExpression respects standard operator precedence, so this should be
        // 10 + (2*3) = 16, not (10+2)*3 = 36.
        #expect(CalculatorKeypadView.evaluatedAmount(from: "10+2*3") == 16)
    }

    @Test func roundsNonIntegerDivisionToNearestWholeNumber() {
        // 100/3 = 33.33... — amounts are always whole NT$, so this rounds.
        #expect(CalculatorKeypadView.evaluatedAmount(from: "100/3") == 33)
    }

    @Test func trimsATrailingOperatorInsteadOfFailing() {
        // User tapped "=" right after "120+" without finishing the second number.
        #expect(CalculatorKeypadView.evaluatedAmount(from: "120+") == 120)
    }

    @Test func returnsNilForEmptyExpression() {
        #expect(CalculatorKeypadView.evaluatedAmount(from: "") == nil)
    }

    @Test func returnsNilForZeroOrNegativeResults() {
        #expect(CalculatorKeypadView.evaluatedAmount(from: "0") == nil)
        #expect(CalculatorKeypadView.evaluatedAmount(from: "5-10") == nil)
    }
}
