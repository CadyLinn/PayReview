//
//  BudgetListView.swift
//  PayReview
//

import SwiftUI

struct BudgetListView: View {
    @State private var viewModel: BudgetListViewModel
    @State private var showsAddBudget = false
    // Phase 4: which month the whole page (every budget's summary + disclosure list)
    // is currently showing. This is page-level, shared UI state — not something the
    // view model owns, since it's purely "what is the user looking at right now" and
    // has no bearing on what data gets fetched (all of this month's transactions are
    // already loaded; we're just filtering client-side).
    @State private var selectedMonth: Date = .now

    /// Designated initializer: takes both abstract repositories so previews/tests can
    /// pass in-memory fakes instead of always hitting real Firestore. `transactionRepository`
    /// was added in Phase 3 so this screen can compute "剩餘預算/本月已消費" per budget.
    init(repository: BudgetRepository, transactionRepository: TransactionRepository) {
        _viewModel = State(
            initialValue: BudgetListViewModel(repository: repository, transactionRepository: transactionRepository)
        )
    }

    /// Convenience initializer used by the real app — wires up the Firestore-backed
    /// repositories for the given signed-in user.
    init(uid: String) {
        self.init(
            repository: FirestoreBudgetRepository(uid: uid),
            transactionRepository: FirestoreTransactionRepository(uid: uid)
        )
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("計畫")
                .task { await viewModel.start() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("載入中")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            ContentUnavailableView(
                "無法載入預算",
                systemImage: "exclamationmark.triangle",
                description: Text("請確認網路連線，稍後再試一次。")
            )
        case .loaded(let budgets):
            VStack(spacing: 0) {
                monthNavigationHeader
                List {
                    Section("每月預算") {
                        if budgets.isEmpty {
                            Text("還沒有任何預算，點右上角新增一個")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(budgets) { budget in
                                budgetRow(budget)
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showsAddBudget = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("新增預算")
                    }
                }
                .sheet(isPresented: $showsAddBudget) {
                    AddBudgetView(viewModel: viewModel)
                }
            }
        }
    }

    /// Page-level month switcher shared by every budget card below — there's one
    /// "current month" for the whole screen, not one per card, so the arrows live
    /// here instead of inside `budgetRow`.
    private var monthNavigationHeader: some View {
        HStack {
            Button {
                selectedMonth = adjacentMonth(offset: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("上個月")

            Spacer()

            Text(selectedMonth.formatted(.dateTime.year().month(.wide)))
                .font(.headline)

            Spacer()

            Button {
                selectedMonth = adjacentMonth(offset: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("下個月")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func adjacentMonth(offset: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) ?? selectedMonth
    }

    /// Phase 3's summary area, now the *label* of a Phase 4 `DisclosureGroup` — tapping
    /// it expands to that budget's transaction list for `selectedMonth` (below).
    private func budgetRow(_ budget: BudgetRecord) -> some View {
        let progress = viewModel.progress(for: budget, month: selectedMonth)
        return DisclosureGroup {
            budgetTransactionList(for: budget)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(budget.name)
                    .font(.subheadline.weight(.semibold))

                Text("剩餘 \(amountText(progress.remainingMinorUnits)) / \(amountText(budget.limitMinorUnits))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("已消費 \(progress.usedCount) / \(progress.expectedCount) 次")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let suggested = progress.suggestedNextAmountMinorUnits {
                    Text("下一筆建議消費 \(amountText(suggested))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                } else {
                    Text("已超出預算")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// The disclosure content: `selectedMonth`'s expenses under this budget, newest
    /// first — same row shape as `TransactionListView.transactionRow` so switching
    /// between "紀錄" and an expanded budget card feels like the same kind of list.
    @ViewBuilder
    private func budgetTransactionList(for budget: BudgetRecord) -> some View {
        let monthTransactions = viewModel.monthlyTransactions(for: budget, month: selectedMonth)
        if monthTransactions.isEmpty {
            Text("這個月「\(budget.name)」還沒有任何消費")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)
        } else {
            ForEach(monthTransactions) { transaction in
                transactionRow(transaction)
            }
        }
    }

    private func transactionRow(_ transaction: TransactionRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(transaction.note?.isEmpty == false ? transaction.note! : "無備註")
                    .font(.subheadline)
                Spacer()
                Text(amountText(transaction.amount.minorUnits))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
            Text(transaction.occurredAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func amountText(_ minorUnits: Int64) -> String {
        let sign = minorUnits < 0 ? "-" : ""
        return "\(sign)NT$\(abs(minorUnits))"
    }
}

private struct AddBudgetView: View {
    let viewModel: BudgetListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var limitText = ""
    @State private var expectedCountText = ""
    @State private var isSaving = false

    private var limitValue: Int64? {
        guard let value = Int64(limitText), value > 0 else { return nil }
        return value
    }

    private var expectedCountValue: Int? {
        guard let value = Int(expectedCountText), value > 0 else { return nil }
        return value
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && limitValue != nil
            && expectedCountValue != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("預算名稱") {
                    TextField("例如：餐飲、交通", text: $name)
                }
                Section("每月預算金額") {
                    TextField("金額", text: $limitText)
                        .keyboardType(.numberPad)
                }
                Section("每月預計消費次數") {
                    TextField("次數", text: $expectedCountText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("新增預算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func save() {
        guard let limit = limitValue, let expectedCount = expectedCountValue else { return }
        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await viewModel.addBudget(
                name: trimmedName,
                limitMinorUnits: limit,
                expectedMonthlyCount: expectedCount
            )
            isSaving = false
            dismiss()
        }
    }
}

#Preview("有預算與本月消費") {
    BudgetListView(
        repository: InMemoryBudgetRepository(seed: [
            BudgetRecord(
                id: "1",
                name: "餐飲",
                limitMinorUnits: 3_000,
                expectedMonthlyCount: 5,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            ),
            BudgetRecord(
                id: "2",
                name: "交通",
                limitMinorUnits: 1_200,
                expectedMonthlyCount: 8,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            )
        ]),
        transactionRepository: InMemoryFinancialRepository(seed: [
            // 餐飲：花了 1,500，還沒超支，會顯示建議下一筆金額
            TransactionRecord(
                id: "t1",
                amount: Money(minorUnits: -1_000, currencyCode: "TWD"),
                budgetId: "1",
                occurredAt: .now,
                note: "晚餐",
                source: .manual,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            ),
            TransactionRecord(
                id: "t2",
                amount: Money(minorUnits: -500, currencyCode: "TWD"),
                budgetId: "1",
                occurredAt: .now,
                note: "午餐",
                source: .manual,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            ),
            // 交通：花了 1,500，已經超過 1,200 的預算，會顯示「已超出預算」
            TransactionRecord(
                id: "t3",
                amount: Money(minorUnits: -1_500, currencyCode: "TWD"),
                budgetId: "2",
                occurredAt: .now,
                note: "計程車",
                source: .manual,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            ),
            // 上個月的餐飲消費：按左箭頭切換到上個月時應該只看到這一筆，
            // 這個月的兩筆餐飲消費則不該出現。用來驗證月份導覽有正確篩選。
            TransactionRecord(
                id: "t4",
                amount: Money(minorUnits: -800, currencyCode: "TWD"),
                budgetId: "1",
                occurredAt: Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now,
                note: "上個月的早餐",
                source: .manual,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            )
        ])
    )
}

#Preview("還沒有預算") {
    BudgetListView(
        repository: InMemoryBudgetRepository(),
        transactionRepository: InMemoryFinancialRepository()
    )
}
