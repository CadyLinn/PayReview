//
//  TransactionListView.swift
//  PayReview
//

import SwiftUI

struct TransactionListView: View {
    @State private var viewModel: TransactionListViewModel
    @State private var showsAddTransaction = false

    init(uid: String) {
        _viewModel = State(
            initialValue: TransactionListViewModel(
                repository: FirestoreTransactionRepository(uid: uid)
            )
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
                AddTransactionView(viewModel: viewModel)
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

    private func transactionRow(_ transaction: TransactionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transaction.categoryLabel ?? "未分類")
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
    @Environment(\.dismiss) private var dismiss

    @State private var kind: Kind = .expense
    @State private var amountText = ""
    @State private var categoryLabel = ""
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
                Section("類別（選填）") {
                    TextField("例如：餐飲、交通、薪資", text: $categoryLabel)
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
        let trimmedCategory = categoryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await viewModel.addTransaction(
                amountMinorUnits: signedAmount,
                categoryLabel: trimmedCategory.isEmpty ? nil : trimmedCategory,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            isSaving = false
            dismiss()
        }
    }
}
