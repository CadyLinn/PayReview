import SwiftUI

struct ExpensesSetupView: View {
    @ObservedObject var store: SetupStore
    let continueAction: () -> Void
    @State private var isAddingExpense = false

    var body: some View {
        List {
            Section {
                SetupProgressHeader(completedSteps: 3)
                    .listRowBackground(Color.clear)

                VStack(alignment: .leading, spacing: 8) {
                    Text("哪些支出要先替你留起來？")
                        .font(.title2.weight(.bold))
                    Text("先放現在記得的必要支出，其他項目之後都能補上")
                        .font(.subheadline)
                        .foregroundStyle(PayReviewTheme.secondaryText)
                }
                .listRowBackground(Color.clear)

                MascotSpeechView(message: "先放記得的就好，這不是一次定案")
                    .listRowBackground(Color.clear)
            }

            Section("固定支出") {
                ForEach(store.plannedExpenses) { expense in
                    LabeledContent(expense.name, value: expense.amount.twdFormatted)
                }
                .onDelete { offsets in
                    store.plannedExpenses.remove(atOffsets: offsets)
                }

                Button("新增支出", systemImage: "plus") {
                    isAddingExpense = true
                }
            }

            Section("每月固定支出") {
                LabeledContent(
                    "\(store.plannedExpenses.count) 個項目",
                    value: store.plannedExpenseTotal.twdFormatted
                )
                .font(.headline)
            }

            Section {
                Button("確認固定支出，繼續", action: continueAction)
                    .buttonStyle(PayReviewPrimaryButtonStyle())

                Text("想起其他項目時，隨時都能回來加上")
                    .font(.footnote)
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
        .payReviewSetupBackground()
        .navigationTitle("固定支出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingExpense) {
            AddPlannedExpenseView(store: store)
        }
    }
}

private struct AddPlannedExpenseView: View {
    @ObservedObject var store: SetupStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var isEssential = true

    var body: some View {
        NavigationStack {
            Form {
                Section("支出內容") {
                    TextField("名稱", text: $name)
                    TextField("金額", text: $amountText)
                        .keyboardType(.decimalPad)
                    Toggle("必要支出", isOn: $isEssential)
                }
            }
            .navigationTitle("新增固定支出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入", systemImage: "checkmark") {
                        guard let amount = Decimal(string: amountText), amount >= 0 else { return }
                        store.plannedExpenses.append(
                            PlannedExpenseDraft(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                amount: amount,
                                isEssential: isEssential
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Decimal(string: amountText) == nil)
                }
            }
        }
    }
}
