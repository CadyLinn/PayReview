import Combine
import Foundation

enum IncomeCadence: String, CaseIterable, Identifiable {
    case daily = "每日"
    case monthly = "每月"
    case biweekly = "每兩週"
    case weekly = "每週"
    case irregular = "不固定"

    var id: Self { self }
}

struct PlannedExpenseDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var amount: Decimal
    var isEssential: Bool

    init(id: UUID = UUID(), name: String, amount: Decimal, isEssential: Bool = true) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isEssential = isEssential
    }
}

@MainActor
final class SetupStore: ObservableObject {
    @Published var goalName = "自訂目標"
    @Published var goalAmount: Decimal = 50_000
    @Published var savedAmount: Decimal = 21_000
    @Published var targetDate = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2027, month: 6, day: 1)
    ) ?? Date()

    @Published var incomeCadence: IncomeCadence = .monthly
    @Published var nextIncomeDate = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2026, month: 7, day: 25)
    ) ?? Date()
    @Published var availableIncome: Decimal = 38_000
    @Published var plannedExpenses = [
        PlannedExpenseDraft(name: "房租", amount: 12_000),
        PlannedExpenseDraft(name: "電信費", amount: 699)
    ]
    @Published var flexibleBudget: Decimal = 3_400

    var plannedExpenseTotal: Decimal {
        plannedExpenses.reduce(Decimal.zero) { $0 + $1.amount }
    }

    func updatePlannedExpenseTotal(to total: Decimal) {
        guard !plannedExpenses.isEmpty else {
            plannedExpenses = [PlannedExpenseDraft(name: "必要支出", amount: max(0, total))]
            return
        }

        let otherExpenses = plannedExpenses.dropFirst().reduce(Decimal.zero) { $0 + $1.amount }
        plannedExpenses[0].amount = max(0, total - otherExpenses)
    }

    func adjustIncome(by amount: Decimal) {
        availableIncome = max(0, availableIncome + amount)
    }

    func updateFlexibleBudget(sliderPosition: Double) {
        let step = Decimal(Int(sliderPosition.rounded()))
        flexibleBudget = 1_000 + step * 100
    }

    var flexibleBudgetSliderPosition: Double {
        let steps = (flexibleBudget - 1_000) / 100
        return NSDecimalNumber(decimal: steps).doubleValue
    }
}

extension Decimal {
    var twdFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TWD"
        formatter.currencySymbol = "NT$"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "NT$0"
    }
}

extension FormatStyle where Self == Decimal.FormatStyle.Currency {
    static var payReviewTWD: Decimal.FormatStyle.Currency {
        .currency(code: "TWD")
            .locale(Locale(identifier: "en_US"))
            .precision(.fractionLength(0))
    }
}
