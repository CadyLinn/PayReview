import Foundation
import Observation

enum BudgetListState: Equatable {
    case loading
    case loaded([BudgetRecord])
    case error
}

@MainActor
@Observable
final class BudgetListViewModel {
    private(set) var state: BudgetListState = .loading

    // v2 Phase 3: to show "剩餘預算/本月已消費" per budget, this view model also needs
    // the transaction list — not just budgets. Same reasoning as `TransactionListViewModel.budgets`
    // in Phase 2: this is supplementary data for a calculation, not something the screen's
    // own loading/error state should depend on, so it's a separate property that just starts
    // empty and fills in whenever the stream delivers something.
    private(set) var transactions: [TransactionRecord] = []

    // v2 Phase 5: the user-set total monthly budget, shown as the centered number
    // field under the "計畫" title and used to cap how much any one budget's limit
    // slider can reach. Same "supplementary, starts at a sensible default" treatment
    // as `transactions` above — `.unset` (0) until the profile stream delivers
    // something real.
    private(set) var profile: ProfileRecord = .unset

    private let repository: BudgetRepository
    private let transactionRepository: TransactionRepository
    private let profileRepository: ProfileRepository

    init(
        repository: BudgetRepository,
        transactionRepository: TransactionRepository,
        profileRepository: ProfileRepository
    ) {
        self.repository = repository
        self.transactionRepository = transactionRepository
        self.profileRepository = profileRepository
    }

    /// Runs the budgets stream, the transactions stream, and the profile stream side
    /// by side, same `async let` pattern as `TransactionListViewModel.start()` — see
    /// that file for the full explanation of why a plain sequential `for await` can't
    /// observe more than one stream at once.
    func start() async {
        async let budgetsTask: Void = observeBudgets()
        async let transactionsTask: Void = observeTransactions()
        async let profileTask: Void = observeProfile()
        _ = await (budgetsTask, transactionsTask, profileTask)
    }

    private func observeBudgets() async {
        for await latest in await repository.observeBudgets() {
            state = .loaded(latest)
        }
        state = .error
    }

    private func observeTransactions() async {
        for await latest in await transactionRepository.observeTransactions() {
            transactions = latest
        }
    }

    private func observeProfile() async {
        for await latest in await profileRepository.observeProfile() {
            profile = latest
        }
    }

    /// Persists a new total monthly budget. Called when the user submits the
    /// centered number field under the "計畫" title.
    func updateMonthlyBudgetLimit(minorUnits: Int64) async {
        do {
            try await profileRepository.setMonthlyBudgetLimit(minorUnits: minorUnits)
        } catch {
            print("Failed to update monthly budget limit: \(error)")
        }
    }

    /// Sum of every existing budget's `limitMinorUnits`, optionally excluding one
    /// (pass the budget's own id when editing it, so its current allocation doesn't
    /// count against itself).
    func allocatedMinorUnits(excluding excludedBudgetId: String? = nil) -> Int64 {
        guard case .loaded(let budgets) = state else { return 0 }
        return budgets
            .filter { $0.id != excludedBudgetId }
            .reduce(Int64(0)) { $0 + $1.limitMinorUnits }
    }

    /// How much of the total monthly budget is still unallocated — this becomes the
    /// slider's upper bound in `AddBudgetView`. Clamped to 0 so that shrinking the
    /// total budget below what's already allocated never produces a negative (and
    /// therefore invalid) slider range.
    func remainingAllocatableMinorUnits(excluding excludedBudgetId: String? = nil) -> Int64 {
        max(0, profile.monthlyBudgetLimitMinorUnits - allocatedMinorUnits(excluding: excludedBudgetId))
    }

    /// A stable ordering of budgets for the macOS-Storage-style overview bar, where
    /// each budget is drawn as a colored segment. Colors there are assigned by *index
    /// in this list*, so the order has to be deterministic and not depend on whatever
    /// order the Firestore snapshot happens to deliver documents in — otherwise a
    /// category's color (and its position left-to-right in the bar/legend) could
    /// shuffle between app launches even though nothing the user did actually changed.
    /// Sorting by `createdAt` (oldest first) with `id` as a tiebreaker for the rare
    /// case of equal timestamps gives a fixed order: whichever budget you made first
    /// keeps the same color and the same position.
    func budgetsSortedForOverview() -> [BudgetRecord] {
        guard case .loaded(let budgets) = state else { return [] }
        return budgets.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id < rhs.id
        }
    }

    func addBudget(
        name: String,
        limitMinorUnits: Int64,
        expectedMonthlyCount: Int,
        frequency: BudgetFrequency = .custom,
        frequencyWeekdays: Set<Int> = [],
        frequencyMonthDays: Set<Int> = []
    ) async {
        let id = repository.newBudgetID()
        let now = Date()
        let budget = BudgetRecord(
            id: id,
            name: name,
            limitMinorUnits: limitMinorUnits,
            expectedMonthlyCount: expectedMonthlyCount,
            frequency: frequency,
            frequencyWeekdays: frequencyWeekdays,
            frequencyMonthDays: frequencyMonthDays,
            schemaVersion: 1,
            createdAt: now,
            updatedAt: now
        )
        do {
            try await repository.addBudget(budget)
        } catch {
            // v1/v2 keep this simple: log only, no dedicated error-presentation state yet.
            print("Failed to add budget: \(error)")
        }
    }

    /// Phase 5: applies edits made in `AddBudgetView`'s edit mode. `original` carries
    /// over `id` and `createdAt` unchanged — editing a budget shouldn't reset when it
    /// was first created, only `updatedAt` and the three user-editable fields change.
    func updateBudget(
        _ original: BudgetRecord,
        name: String,
        limitMinorUnits: Int64,
        expectedMonthlyCount: Int,
        frequency: BudgetFrequency = .custom,
        frequencyWeekdays: Set<Int> = [],
        frequencyMonthDays: Set<Int> = []
    ) async {
        let updated = BudgetRecord(
            id: original.id,
            name: name,
            limitMinorUnits: limitMinorUnits,
            expectedMonthlyCount: expectedMonthlyCount,
            frequency: frequency,
            frequencyWeekdays: frequencyWeekdays,
            frequencyMonthDays: frequencyMonthDays,
            schemaVersion: original.schemaVersion,
            createdAt: original.createdAt,
            updatedAt: Date()
        )
        do {
            try await repository.updateBudget(updated)
        } catch {
            print("Failed to update budget: \(error)")
        }
    }

    /// Permanently deletes a budget — called from the red "刪除預算" button in
    /// `AddBudgetView`'s edit mode. Before deleting, every transaction currently
    /// tagged with this budget gets reassigned to `BudgetRecord.otherCategoryId`
    /// ("其他"), so deleting a category never silently orphans a transaction or makes
    /// past spending vanish from history.
    ///
    /// This does the reassignment first and the deletion last, and each write is a
    /// separate `await` — not wrapped in a single atomic Firestore batch. That means
    /// if this gets interrupted partway (e.g. the app is killed mid-delete), some
    /// transactions could end up reassigned to "其他" while the budget document still
    /// exists. That's an acceptable "best effort" tradeoff for v2's scope — matches
    /// the rest of this codebase's simple sequential-await style — but a fully
    /// robust version would use a `WriteBatch` so all of this succeeds or fails together.
    func deleteBudget(_ budget: BudgetRecord) async {
        let affectedTransactions = transactions.filter { $0.budgetId == budget.id }
        do {
            for transaction in affectedTransactions {
                let reassigned = TransactionRecord(
                    id: transaction.id,
                    amount: transaction.amount,
                    budgetId: BudgetRecord.otherCategoryId,
                    occurredAt: transaction.occurredAt,
                    note: transaction.note,
                    source: transaction.source,
                    schemaVersion: transaction.schemaVersion,
                    createdAt: transaction.createdAt,
                    updatedAt: Date()
                )
                try await transactionRepository.updateTransaction(reassigned)
            }
            try await repository.deleteBudget(id: budget.id)
        } catch {
            print("Failed to delete budget: \(error)")
        }
    }

    /// One budget's progress for a given month. Everything the "類別" area in
    /// `BudgetListView` needs to render is bundled here so the view stays dumb —
    /// it just formats numbers, it doesn't decide what they mean.
    struct BudgetProgress: Equatable {
        /// Total spent this month under this budget, as a positive magnitude.
        let spentMinorUnits: Int64
        /// `budget.limitMinorUnits - spentMinorUnits`. Can go negative when over budget.
        let remainingMinorUnits: Int64
        /// How many expense transactions this month were filed under this budget.
        let usedCount: Int
        let expectedCount: Int
        /// Suggested amount for the *next* purchase, or nil if already over budget
        /// (the view shows "已超出預算" in that case instead of a number).
        let suggestedNextAmountMinorUnits: Int64?
    }

    /// Computes `BudgetProgress` for `budget` by filtering `transactions` down to the
    /// ones that (a) are tagged with this budget's id, (b) are expenses (negative
    /// `minorUnits` — a stray income transaction someone mis-tagged with a budget
    /// shouldn't count as "spending" or reduce the used-count), and (c) fall in
    /// `referenceDate`'s month. `referenceDate` defaults to now; Phase 4's month
    /// navigation will pass a different date instead of adding a second method.
    ///
    /// This is a synchronous, pure function over `transactions` + `budget` — no async,
    /// no repository calls — which is what makes it cheap to call once per row every
    /// time the view redraws, and easy to unit test directly without spinning up streams.
    func progress(
        for budget: BudgetRecord,
        month referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> BudgetProgress {
        let expenses = monthlyExpenses(for: budget, month: referenceDate, calendar: calendar)

        let spentMinorUnits = expenses.reduce(Int64(0)) { $0 + (-$1.amount.minorUnits) }
        let usedCount = expenses.count
        let remainingMinorUnits = budget.limitMinorUnits - spentMinorUnits

        let suggestedNextAmountMinorUnits: Int64?
        if remainingMinorUnits <= 0 {
            suggestedNextAmountMinorUnits = nil
        } else {
            // max(..., 1) avoids a divide-by-zero once the user has already hit or
            // passed their expected count for the month but still has budget left —
            // in that case we just suggest spending the whole remainder on "the next one".
            let remainingCount = max(budget.expectedMonthlyCount - usedCount, 1)
            suggestedNextAmountMinorUnits = remainingMinorUnits / Int64(remainingCount)
        }

        return BudgetProgress(
            spentMinorUnits: spentMinorUnits,
            remainingMinorUnits: remainingMinorUnits,
            usedCount: usedCount,
            expectedCount: budget.expectedMonthlyCount,
            suggestedNextAmountMinorUnits: suggestedNextAmountMinorUnits
        )
    }

    /// Phase 4: the transactions behind one budget's disclosure list, for a given month,
    /// newest first — same ordering `TransactionListView` uses for the main "紀錄" list.
    /// Reuses `monthlyExpenses(for:month:calendar:)` so the summary numbers in `progress(for:)`
    /// and the detail list shown when a card is expanded can never disagree about which
    /// transactions count: there is exactly one place that defines "belongs to this
    /// budget, this month".
    ///
    /// Named `monthlyTransactions` rather than `transactions` on purpose — this type
    /// already has a stored property called `transactions` (the full unfiltered list),
    /// and giving the method a distinct name avoids relying on Swift's call-syntax
    /// overload resolution to tell them apart.
    func monthlyTransactions(
        for budget: BudgetRecord,
        month referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [TransactionRecord] {
        monthlyExpenses(for: budget, month: referenceDate, calendar: calendar)
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    /// Shared filter behind both `progress(for:)` and `transactions(for:)`: transactions
    /// tagged with this budget, that are expenses (not income), that fall in the given month.
    private func monthlyExpenses(
        for budget: BudgetRecord,
        month referenceDate: Date,
        calendar: Calendar
    ) -> [TransactionRecord] {
        transactions.filter { transaction in
            transaction.budgetId == budget.id
                && transaction.amount.minorUnits < 0
                && calendar.isDate(transaction.occurredAt, equalTo: referenceDate, toGranularity: .month)
        }
    }
}
