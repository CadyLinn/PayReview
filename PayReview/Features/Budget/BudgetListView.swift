//
//  BudgetListView.swift
//  PayReview
//

import SwiftUI

struct BudgetListView: View {
    @State private var viewModel: BudgetListViewModel
    // Phase 5: which sheet (if any) is showing, and in which mode. One piece of
    // state instead of two separate Bools/optionals so "add" and "edit" can never
    // both be true at once, and so there's only one `.sheet` modifier to reason about.
    @State private var budgetSheetMode: BudgetSheetMode?
    // Phase 5: which budget cards are currently expanded to show their monthly
    // transaction list. A Set of ids (not one Bool per card) because the number of
    // budgets is dynamic.
    @State private var expandedBudgetIDs: Set<String> = []
    // Phase 4: which month the whole page (every budget's summary + disclosure list)
    // is currently showing. This is page-level, shared UI state — not something the
    // view model owns, since it's purely "what is the user looking at right now" and
    // has no bearing on what data gets fetched (all of this month's transactions are
    // already loaded; we're just filtering client-side).
    @State private var selectedMonth: Date = .now
    // Phase 5: the text in the centered total-budget field under the title. Kept as
    // its own @State (not read directly from the view model on every redraw) so the
    // user can type freely without each keystroke round-tripping through Int64
    // parsing; see `totalBudgetInputHeader` for how this stays in sync with the
    // view model's `profile.monthlyBudgetLimitMinorUnits`.
    @State private var totalBudgetText: String = "0"
    @FocusState private var isEditingTotalBudget: Bool

    private enum BudgetSheetMode: Identifiable {
        case new
        case edit(BudgetRecord)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let budget): return budget.id
            }
        }

        var editingBudget: BudgetRecord? {
            if case .edit(let budget) = self { return budget }
            return nil
        }
    }

    /// Designated initializer: takes all three abstract repositories so previews/tests
    /// can pass in-memory fakes instead of always hitting real Firestore.
    /// `profileRepository` was added in Phase 5 for the total monthly budget.
    init(
        repository: BudgetRepository,
        transactionRepository: TransactionRepository,
        profileRepository: ProfileRepository
    ) {
        _viewModel = State(
            initialValue: BudgetListViewModel(
                repository: repository,
                transactionRepository: transactionRepository,
                profileRepository: profileRepository
            )
        )
    }

    /// Convenience initializer used by the real app — wires up the Firestore-backed
    /// repositories for the given signed-in user.
    init(uid: String) {
        self.init(
            repository: FirestoreBudgetRepository(uid: uid),
            transactionRepository: FirestoreTransactionRepository(uid: uid),
            profileRepository: FirestoreProfileRepository(uid: uid)
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
                totalBudgetInputHeader
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
                // The number pad for the total-budget field has no Return key and
                // nothing else on this screen was dismissing it. `.immediately` tells
                // the List (a scroll view) to resign the keyboard the moment the user
                // taps or drags anywhere inside it — e.g. tapping a budget card while
                // the total-budget field is still focused.
                .scrollDismissesKeyboard(.immediately)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            budgetSheetMode = .new
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("新增預算")
                    }
                }
                .sheet(item: $budgetSheetMode) { mode in
                    AddBudgetView(
                        viewModel: viewModel,
                        // Computed once, at presentation time, from the id being
                        // edited (or nil for "new") — see remainingAllocatableMinorUnits
                        // for why `excluding:` matters when editing.
                        maxLimitMinorUnits: viewModel.remainingAllocatableMinorUnits(
                            excluding: mode.editingBudget?.id
                        ),
                        editingBudget: mode.editingBudget
                    )
                }
            }
        }
    }

    /// Phase 5: the centered, underlined number field under the "計畫" title for
    /// setting this month's total budget. Every budget card's limit slider is capped
    /// by how much of this total hasn't been allocated yet.
    private var totalBudgetInputHeader: some View {
        VStack(spacing: 4) {
            Text("本月總預算")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", text: $totalBudgetText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .focused($isEditingTotalBudget)
                .frame(minWidth: 140)
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.secondary)
                        .frame(height: 1)
                }
                .onSubmit { commitTotalBudget() }
                .onChange(of: isEditingTotalBudget) { _, isFocused in
                    // Committing on "stopped editing" (not on every keystroke) means
                    // we're not writing to Firestore on every digit typed, and lets
                    // the user clear the field and retype without it being rejected
                    // mid-edit.
                    if !isFocused {
                        commitTotalBudget()
                    }
                }
                // The number pad has no Return key, so there's normally no way to
                // dismiss it other than tapping elsewhere. This adds an explicit
                // "完成" button to the keyboard's accessory bar — setting
                // `isEditingTotalBudget = false` both dismisses the keyboard (SwiftUI
                // resigns focus) and triggers the onChange above to commit the value.
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完成") {
                            isEditingTotalBudget = false
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 4)
        // Pull the field's text from the view model only while the user isn't
        // actively typing in it — otherwise a stream update arriving mid-edit
        // (even one caused by our own commitTotalBudget()) would overwrite
        // whatever they're in the middle of typing.
        .onChange(of: viewModel.profile.monthlyBudgetLimitMinorUnits) { _, newValue in
            if !isEditingTotalBudget {
                totalBudgetText = String(newValue)
            }
        }
    }

    private func commitTotalBudget() {
        let parsed = Int64(totalBudgetText) ?? 0
        totalBudgetText = String(parsed)
        Task {
            await viewModel.updateMonthlyBudgetLimit(minorUnits: parsed)
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

    /// Phase 5: the summary area now has two independent tap targets instead of being
    /// one big `DisclosureGroup` label. Tapping the name/numbers opens the edit sheet;
    /// tapping the chevron only expands/collapses the transaction list below. A plain
    /// `DisclosureGroup` can't do this — its whole label is one tap target for
    /// toggling — so this is a custom VStack with its own gesture handling instead.
    private func budgetRow(_ budget: BudgetRecord) -> some View {
        let progress = viewModel.progress(for: budget, month: selectedMonth)
        let isExpanded = expandedBudgetIDs.contains(budget.id)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
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
                // `.contentShape` makes the whole VStack tappable — including the
                // empty space between lines of text, not just the glyphs themselves.
                .contentShape(Rectangle())
                .onTapGesture {
                    budgetSheetMode = .edit(budget)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation {
                        if isExpanded {
                            expandedBudgetIDs.remove(budget.id)
                        } else {
                            expandedBudgetIDs.insert(budget.id)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                // `.plain` keeps this button's own tap area self-contained. Without
                // it, some default button styles let the tap "bubble up" and make
                // the whole row act like one button again, defeating the split above.
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

            if isExpanded {
                budgetTransactionList(for: budget)
                    .padding(.leading, 8)
                    .padding(.bottom, 4)
            }
        }
    }

    /// The expanded content: `selectedMonth`'s expenses under this budget, newest
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
    /// Upper bound for the amount slider, already adjusted (in the initializer) to
    /// include this budget's own current allocation when editing.
    let maxLimitMinorUnits: Int64
    let editingBudget: BudgetRecord?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var limitMinorUnits: Int64
    @State private var expectedMonthlyCount: Int
    @State private var showsCountSlider = false
    @State private var isSaving = false

    /// The "預計消費次數" slider needs *some* upper bound to be a valid SwiftUI
    /// `Slider`. The spec only specified a step of 1, not a maximum, so 31 (the most
    /// days in a month) is a generous-but-finite cap on "how many times a month".
    private let maxExpectedCount = 31

    /// `maxLimitMinorUnits` is passed in as "how much of the total budget is unallocated,
    /// *excluding* this budget's own current limit" (see
    /// `BudgetListViewModel.remainingAllocatableMinorUnits(excluding:)`). To let the
    /// slider represent "keep it the same or raise/lower it", the editable range needs
    /// this budget's current allocation added back in.
    init(viewModel: BudgetListViewModel, maxLimitMinorUnits: Int64, editingBudget: BudgetRecord?) {
        self.viewModel = viewModel
        self.editingBudget = editingBudget
        self.maxLimitMinorUnits = maxLimitMinorUnits + (editingBudget?.limitMinorUnits ?? 0)
        _name = State(initialValue: editingBudget?.name ?? "")
        _limitMinorUnits = State(initialValue: editingBudget?.limitMinorUnits ?? 0)
        _expectedMonthlyCount = State(initialValue: editingBudget?.expectedMonthlyCount ?? 1)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && limitMinorUnits > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("預算名稱") {
                    TextField("例如：餐飲、交通", text: $name)
                }

                Section("每月預算金額") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(amountText(limitMinorUnits))
                            .font(.title3.weight(.semibold))
                        if maxLimitMinorUnits > 0 {
                            Slider(
                                value: Binding(
                                    get: { Double(limitMinorUnits) },
                                    set: { limitMinorUnits = Int64(($0 / 100).rounded()) * 100 }
                                ),
                                in: 0...Double(maxLimitMinorUnits),
                                step: 100
                            )
                        } else {
                            Text("尚未設定本月總預算，或本月總預算已全數分配完畢")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("每月預計消費次數") {
                    Button {
                        showsCountSlider.toggle()
                    } label: {
                        HStack {
                            Text("\(expectedMonthlyCount) 次")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: showsCountSlider ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if showsCountSlider {
                        Slider(
                            value: Binding(
                                get: { Double(expectedMonthlyCount) },
                                set: { expectedMonthlyCount = Int($0.rounded()) }
                            ),
                            in: 1...Double(maxExpectedCount),
                            step: 1
                        )
                    }
                }
            }
            .navigationTitle(editingBudget == nil ? "新增預算" : "編輯預算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingBudget == nil ? "儲存" : "修改") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func amountText(_ minorUnits: Int64) -> String {
        "NT$\(minorUnits)"
    }

    private func save() {
        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if let editingBudget {
                await viewModel.updateBudget(
                    editingBudget,
                    name: trimmedName,
                    limitMinorUnits: limitMinorUnits,
                    expectedMonthlyCount: expectedMonthlyCount
                )
            } else {
                await viewModel.addBudget(
                    name: trimmedName,
                    limitMinorUnits: limitMinorUnits,
                    expectedMonthlyCount: expectedMonthlyCount
                )
            }
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
        ]),
        profileRepository: InMemoryProfileRepository(seed: ProfileRecord(
            monthlyBudgetLimitMinorUnits: 10_000,
            schemaVersion: 1,
            createdAt: .now,
            updatedAt: .now
        ))
    )
}

#Preview("還沒有預算") {
    BudgetListView(
        repository: InMemoryBudgetRepository(),
        transactionRepository: InMemoryFinancialRepository(),
        profileRepository: InMemoryProfileRepository()
    )
}
