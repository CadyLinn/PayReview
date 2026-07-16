import Foundation

struct InMemoryFinancialDataRepository: FinancialDataRepository {
    func loadSnapshot() async throws -> FinancialDataSnapshot {
        TestFinancialDataset.snapshot
    }
}

enum TestFinancialDataset {
    static let snapshot = FinancialDataSnapshot(
        plan: FinancialPlanRecord(
            id: "test-plan-july",
            name: "測試用七月計畫",
            currencyCode: "TWD"
        ),
        incomeCycle: IncomeCycleRecord(
            id: "test-cycle-july",
            planID: "test-plan-july",
            startsAt: date(year: 2026, month: 7, day: 1),
            endsAt: date(year: 2026, month: 7, day: 31),
            expectedIncome: Money(minorUnits: 78_000)
        ),
        flexibleBudget: FlexibleBudgetRecord(
            id: "test-flexible-july",
            planID: "test-plan-july",
            cycleID: "test-cycle-july",
            allocation: Money(minorUnits: 18_000)
        ),
        categories: [
            CategoryRecord(id: "test-category-salary", name: "收入", kind: .income),
            CategoryRecord(id: "test-category-food", name: "餐飲", kind: .expense),
            CategoryRecord(id: "test-category-home", name: "居住", kind: .expense),
            CategoryRecord(id: "test-category-transport", name: "交通", kind: .expense)
        ],
        goals: [
            GoalRecord(
                id: "test-goal-emergency",
                name: "緊急預備金",
                targetAmount: Money(minorUnits: 120_000),
                savedAmount: Money(minorUnits: 42_000),
                targetDate: date(year: 2026, month: 12, day: 31)
            )
        ],
        plannedExpenses: [
            PlannedExpenseRecord(
                id: "test-planned-rent",
                name: "房租",
                expectedAmount: Money(minorUnits: 15_000),
                dueDate: date(year: 2026, month: 7, day: 5),
                isEssential: true,
                isCompleted: true
            ),
            PlannedExpenseRecord(
                id: "test-planned-utilities",
                name: "水電費",
                expectedAmount: Money(minorUnits: 2_000),
                dueDate: date(year: 2026, month: 7, day: 20),
                isEssential: true,
                isCompleted: false
            )
        ],
        transactions: [
            TransactionRecord(
                id: "test-transaction-income",
                kind: .income,
                amount: Money(minorUnits: 78_000),
                categoryID: "test-category-salary",
                occurredAt: date(year: 2026, month: 7, day: 1),
                plannedExpenseOccurrenceID: nil
            ),
            TransactionRecord(
                id: "test-transaction-rent",
                kind: .expense,
                amount: Money(minorUnits: 15_000),
                categoryID: "test-category-home",
                occurredAt: date(year: 2026, month: 7, day: 5),
                plannedExpenseOccurrenceID: "test-planned-rent"
            ),
            TransactionRecord(
                id: "test-transaction-food",
                kind: .expense,
                amount: Money(minorUnits: 320),
                categoryID: "test-category-food",
                occurredAt: date(year: 2026, month: 7, day: 14),
                plannedExpenseOccurrenceID: nil
            )
        ],
        transfers: [
            TransferRecord(
                id: "test-transfer-savings",
                amount: Money(minorUnits: 5_000),
                occurredAt: date(year: 2026, month: 7, day: 2)
            )
        ]
    )

    private static func date(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei") ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}
