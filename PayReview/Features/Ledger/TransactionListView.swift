//
//  TransactionListView.swift
//  PayReview
//

import SwiftUI

struct TransactionListView: View {
    @State private var viewModel: TransactionListViewModel
    @State private var showsAddTransaction = false

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
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增交易")
                }
            }
            .sheet(isPresented: $showsAddTransaction) {
                AddTransactionView(viewModel: viewModel, budgets: viewModel.budgets)
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

    private func transactionRow(_ transaction: TransactionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(budgetName(for: transaction))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(amountText(forMinorUnits: transaction.amount.minorUnits))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(transaction.amount.minorUnits >= 0 ? .green : .red)
            }
            if let note = transaction.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
    @Environment(\.dismiss) private var dismiss

    @State private var kind: Kind = .expense
    @State private var amountText = ""
    // v2 Phase 2: nil is the "請選擇類別" default (uncategorized). Using String? directly
    // as the Picker's selection works because every `.tag(...)` below — including the
    // "請選擇類別" row — is tagged with an Optional<String>, so they're all the same type.
    @State private var selectedBudgetID: String?
    @State private var note = ""
    @State private var isSaving = false

    private enum Kind: String, CaseIterable, Hashable {
        case income = "收入"
        case expense = "支出"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("類型", selection: $kind) {
                        ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("金額") {
                    TextField("金額", text: $amountText)
                        .keyboardType(.numberPad)
                }
                Section("類別") {
                    Picker("類別", selection: $selectedBudgetID) {
                        Text("請選擇類別").tag(String?.none)
                        ForEach(budgets) { budget in
                            Text(budget.name).tag(Optional(budget.id))
                        }
                    }
                }
                Section("備註（選填）") {
                    TextField("備註", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(kind == .income ? "新增收入" : "新增支出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(amountValue == nil || isSaving)
                }
            }
        }
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
            await viewModel.addTransaction(
                amountMinorUnits: signedAmount,
                budgetId: selectedBudgetID,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
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
