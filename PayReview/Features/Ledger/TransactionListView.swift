//
//  TransactionListView.swift
//  PayReview
//

import SwiftUI

struct TransactionListView: View {
    @State private var viewModel: TransactionListViewModel
    // Phase 5: one piece of state for "which sheet, in which mode" instead of a
    // separate Bool for "show add" plus something else for "show edit" — this way
    // the two modes can never both be active, and there's only one `.sheet` to reason
    // about. Same pattern as `BudgetListView.BudgetSheetMode`.
    @State private var transactionSheetMode: TransactionSheetMode?

    private enum TransactionSheetMode: Identifiable {
        case new
        case edit(TransactionRecord)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let transaction): return transaction.id
            }
        }

        var editingTransaction: TransactionRecord? {
            if case .edit(let transaction) = self { return transaction }
            return nil
        }
    }

    /// Designated initializer: takes both abstract repositories so previews/tests can
    /// pass in-memory fakes instead of always hitting real Firestore.
    init(repository: TransactionRepository, budgetRepository: BudgetRepository) {
        _viewModel = State(
            initialValue: TransactionListViewModel(
                repository: repository,
                budgetRepository: budgetRepository
            )
        )
    }

    /// Convenience initializer used by the real app — wires up the Firestore-backed
    /// repositories for the given signed-in user.
    init(uid: String) {
        self.init(
            repository: FirestoreTransactionRepository(uid: uid),
            budgetRepository: FirestoreBudgetRepository(uid: uid)
        )
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("紀錄")
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
                "無法載入交易",
                systemImage: "exclamationmark.triangle",
                description: Text("請確認網路連線，稍後再試一次。")
            )
        case .loaded(let transactions):
            List {
                Section {
                    balanceHeader
                }
                Section("交易") {
                    if transactions.isEmpty {
                        Text("還沒有任何交易")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(transactions.sorted { $0.occurredAt > $1.occurredAt }) { transaction in
                            transactionRow(transaction)
                                // Phase 5: tapping a row opens it in AddTransactionView's
                                // edit mode. `.contentShape` extends the tappable area to
                                // the whole row (including empty space), not just the text.
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    transactionSheetMode = .edit(transaction)
                                }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        transactionSheetMode = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增交易")
                }
            }
            .sheet(item: $transactionSheetMode) { mode in
                AddTransactionView(
                    viewModel: viewModel,
                    budgets: viewModel.budgets,
                    editingTransaction: mode.editingTransaction
                )
            }
        }
    }

    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("目前餘額")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amountText(forMinorUnits: viewModel.balanceMinorUnits))
                .font(.system(size: 34, weight: .bold, design: .rounded))
        }
        .padding(.vertical, 4)
    }

    /// Looks up the budget name for a transaction's `budgetId`. Falls back to "未分類"
    /// both when `budgetId` is nil (user picked "請選擇類別") and when the id doesn't
    /// match any currently-loaded budget (e.g. it was deleted after this transaction
    /// was recorded — v2 has no budget deletion yet, but this keeps the row safe either way).
    private func budgetName(for transaction: TransactionRecord) -> String {
        guard let budgetId = transaction.budgetId else { return "未分類" }
        return viewModel.budgets.first { $0.id == budgetId }?.name ?? "未分類"
    }

    /// The row's title — per request, this is now the transaction's own name
    /// (`note`, labeled "消費名稱" in AddTransactionView), not its category. Falls
    /// back to a placeholder since `note` is still an optional field under the hood.
    private func transactionName(for transaction: TransactionRecord) -> String {
        guard let note = transaction.note, !note.isEmpty else { return "未命名交易" }
        return note
    }

    private func transactionRow(_ transaction: TransactionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transactionName(for: transaction))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(amountText(forMinorUnits: transaction.amount.minorUnits))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(transaction.amount.minorUnits >= 0 ? .green : .red)
            }
            // Category now sits below the title, unconditionally — it was the title
            // before (budgetName was never optional-guarded), so nothing is lost by
            // always showing it here.
            Text(budgetName(for: transaction))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(transaction.occurredAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func amountText(forMinorUnits minorUnits: Int64) -> String {
        let sign = minorUnits >= 0 ? "+" : "−"
        return "\(sign)NT$\(abs(minorUnits))"
    }
}

private struct AddTransactionView: View {
    let viewModel: TransactionListViewModel
    let budgets: [BudgetRecord]
    let editingTransaction: TransactionRecord?
    @Environment(\.dismiss) private var dismiss

    @State private var kind: Kind
    @State private var amountText: String
    // v2 Phase 2: nil is the "請選擇類別" default (uncategorized). Using String? directly
    // as the Picker's selection works because every `.tag(...)` below — including the
    // "請選擇類別" row — is tagged with an Optional<String>, so they're all the same type.
    @State private var selectedBudgetID: String?
    @State private var note: String
    @State private var isSaving = false

    private enum Kind: String, CaseIterable, Hashable {
        case income = "收入"
        case expense = "支出"
    }

    /// When `editingTransaction` is provided, every field starts pre-filled from it
    /// instead of blank — same "designated init sets up the starting @State" idea used
    /// for `maxLimitMinorUnits`/`editingBudget` in `AddBudgetView`.
    init(viewModel: TransactionListViewModel, budgets: [BudgetRecord], editingTransaction: TransactionRecord?) {
        self.viewModel = viewModel
        self.budgets = budgets
        self.editingTransaction = editingTransaction
        if let editingTransaction {
            _kind = State(initialValue: editingTransaction.amount.minorUnits >= 0 ? .income : .expense)
            _amountText = State(initialValue: String(abs(editingTransaction.amount.minorUnits)))
            _selectedBudgetID = State(initialValue: editingTransaction.budgetId)
            _note = State(initialValue: editingTransaction.note ?? "")
        } else {
            _kind = State(initialValue: .expense)
            _amountText = State(initialValue: "")
            _selectedBudgetID = State(initialValue: nil)
            _note = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Order per request: 消費名稱 (was 備註, renamed + moved first) →
                // 收入/支出 → 類別 → 金額. Purely a layout/label change — still the
                // same underlying `note` field on TransactionRecord, still optional.
                Section("消費名稱") {
                    TextField("例如：午餐、計程車", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Picker("類型", selection: $kind) {
                        ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("類別") {
                    Picker("類別", selection: $selectedBudgetID) {
                        Text("請選擇類別").tag(String?.none)
                        ForEach(budgets) { budget in
                            Text(budget.name).tag(Optional(budget.id))
                        }
                    }
                }
                Section("金額") {
                    TextField("金額", text: $amountText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingTransaction == nil ? "儲存" : "修改") { save() }
                        .disabled(amountValue == nil || isSaving)
                }
            }
        }
    }

    private var navigationTitleText: String {
        if editingTransaction != nil {
            return "編輯" + (kind == .income ? "收入" : "支出")
        }
        return kind == .income ? "新增收入" : "新增支出"
    }

    private var amountValue: Int64? {
        guard let value = Int64(amountText), value > 0 else { return nil }
        return value
    }

    private func save() {
        guard let magnitude = amountValue else { return }
        isSaving = true
        let signedAmount = kind == .income ? magnitude : -magnitude
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if let editingTransaction {
                await viewModel.updateTransaction(
                    editingTransaction,
                    amountMinorUnits: signedAmount,
                    budgetId: selectedBudgetID,
                    note: trimmedNote.isEmpty ? nil : trimmedNote
                )
            } else {
                await viewModel.addTransaction(
                    amountMinorUnits: signedAmount,
                    budgetId: selectedBudgetID,
                    note: trimmedNote.isEmpty ? nil : trimmedNote
                )
            }
            isSaving = false
            dismiss()
        }
    }
}

#Preview("有交易與預算") {
    TransactionListView(
        repository: InMemoryFinancialRepository(seed: [
            TransactionRecord(
                id: "t1",
                amount: Money(minorUnits: 30_000, currencyCode: "TWD"),
                budgetId: nil,
                occurredAt: .now,
                note: "七月薪水",
                source: .manual,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            ),
            TransactionRecord(
                id: "t2",
                amount: Money(minorUnits: -120, currencyCode: "TWD"),
                budgetId: "1",
                occurredAt: .now,
                note: "午餐",
                source: .manual,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            )
        ]),
        budgetRepository: InMemoryBudgetRepository(seed: [
            BudgetRecord(
                id: "1",
                name: "餐飲",
                limitMinorUnits: 3_000,
                expectedMonthlyCount: 5,
                schemaVersion: 1,
                createdAt: .now,
                updatedAt: .now
            )
        ])
    )
}

#Preview("還沒有任何交易") {
    TransactionListView(
        repository: InMemoryFinancialRepository(),
        budgetRepository: InMemoryBudgetRepository()
    )
}
