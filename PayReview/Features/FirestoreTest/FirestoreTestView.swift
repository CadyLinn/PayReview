import SwiftUI

struct FirestoreTestView: View {
    @StateObject private var viewModel = FirestoreTestViewModel()

    var body: some View {
        List {
            if let snapshot = viewModel.snapshot {
                Section {
                    Text("這是裝置內的合成測試資料，不會寫入 Firestore。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("財務計畫") {
                    LabeledContent("計畫", value: snapshot.plan.name)
                    LabeledContent("收入週期", value: dateRange(snapshot.incomeCycle.startsAt, snapshot.incomeCycle.endsAt))
                    LabeledContent("預期收入", value: money(snapshot.incomeCycle.expectedIncome))
                    LabeledContent("彈性預算", value: money(snapshot.flexibleBudget.allocation))
                }

                Section("目標") {
                    ForEach(snapshot.goals) { goal in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.name)
                            Text("已累積 \(money(goal.savedAmount))／目標 \(money(goal.targetAmount))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("預期支出") {
                    ForEach(snapshot.plannedExpenses) { expense in
                        LabeledContent(expense.name, value: money(expense.expectedAmount))
                    }
                }

                Section("已確認交易") {
                    ForEach(snapshot.transactions) { transaction in
                        LabeledContent(transaction.kind == .income ? "收入" : "支出", value: money(transaction.amount))
                    }
                }

                Section("轉帳") {
                    ForEach(snapshot.transfers) { transfer in
                        LabeledContent("不計入收入或支出", value: money(transfer.amount))
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
            } else {
                ContentUnavailableView("無法載入測試資料", systemImage: "tray")
            }
        }
        .navigationTitle("資料測試")
        .task {
            await viewModel.load()
        }
        .alert("資料問題", isPresented: errorBinding) {
            Button("好", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }

    private func money(_ money: Money) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = money.currencyCode
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: NSNumber(value: money.minorUnits)) ?? "-"
    }

    private func dateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: start, to: end)
    }
}

#Preview {
    NavigationStack {
        FirestoreTestView()
    }
}
