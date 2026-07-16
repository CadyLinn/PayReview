import SwiftUI

enum SetupRoute: Hashable {
    case income
    case expenses
    case budget
    case complete
    case buildingPlan
}

struct SetupFlowView: View {
    @StateObject private var store: SetupStore
    @State private var path: [SetupRoute] = []
    let completion: () -> Void

    init(store: SetupStore, completion: @escaping () -> Void = {}) {
        _store = StateObject(wrappedValue: store)
        self.completion = completion
    }

    var body: some View {
        // Uses native SwiftUI NavigationStack so system spacing, back behavior,
        // Dynamic Type, and accessibility remain consistent with iOS.
        NavigationStack(path: $path) {
            GoalSetupView(store: store) {
                path.append(.income)
            }
            .navigationDestination(for: SetupRoute.self) { route in
                switch route {
                case .income:
                    IncomeSetupView(store: store) {
                        path.append(.expenses)
                    }
                case .expenses:
                    ExpensesSetupView(store: store) {
                        path.append(.budget)
                    }
                case .budget:
                    BudgetSetupView(store: store) {
                        path.append(.complete)
                    }
                case .complete:
                    SetupCompleteView(store: store) {
                        path.append(.buildingPlan)
                    }
                case .buildingPlan:
                    BuildingPlanView(store: store, completion: completion)
                }
            }
        }
        .tint(PayReviewTheme.primary)
    }
}

#Preview {
    SetupFlowView(store: SetupStore())
}
