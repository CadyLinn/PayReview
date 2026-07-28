import Foundation

struct Money: Codable, Hashable, Sendable {
    let minorUnits: Int64 // pos = income; neg = expenses
    let currencyCode: String
}

enum TransactionSource: String, Codable, Sendable {
    case manual
}

struct TransactionRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let amount: Money
    // v2 Phase 2: was a free-text `categoryLabel`; now points at a `BudgetRecord.id`
    // so the UI can offer a fixed Picker of existing budgets instead of typed text,
    // and so Phase 3/4 can group transactions by budget without string-matching.
    // nil means "uncategorized" (the "請選擇類別" default).
    let budgetId: String?
    let occurredAt: Date
    let note: String?
    let source: TransactionSource
    let schemaVersion: Int
    let createdAt: Date
    let updatedAt: Date
}

// 消費頻率 Phase 1: how often a category is expected to be spent on. This drives
// two things: (1) `AddBudgetView` auto-fills (and, for anything but `.custom`,
// locks) "每月預計消費次數" instead of asking the user to guess a number their
// frequency choice already implies; (2) the Today tab uses it to decide whether a
// category should show up as a still-pending "今日固定支出" item on any given day.
enum BudgetFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case monthly
    case custom

    var displayName: String {
        switch self {
        case .daily: return "每日"
        case .weekly: return "每週"
        case .monthly: return "每月"
        case .custom: return "自訂"
        }
    }
}

// v2: a Budget doubles as a category — creating one gives users something to file
// transactions under (Phase 2) and something to track monthly spend against
// (Phase 3/4). There is deliberately no separate structured Category type.
struct BudgetRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let limitMinorUnits: Int64
    let expectedMonthlyCount: Int
    // 消費頻率 Phase 1: `frequencyWeekdays` only means something when `frequency ==
    // .weekly` (values are `Calendar`'s own weekday numbering, 1 = Sunday ... 7 =
    // Saturday); `frequencyMonthDays` only means something when `frequency ==
    // .monthly` (values are day-of-month, 1...30). Both are just empty sets the rest
    // of the time — there's no separate "is this configured" flag because an empty
    // set already means "nothing selected yet".
    let frequency: BudgetFrequency
    let frequencyWeekdays: Set<Int>
    let frequencyMonthDays: Set<Int>
    let schemaVersion: Int
    let createdAt: Date
    let updatedAt: Date

    /// Reserved `budgetId` used to reassign a transaction whose budget was deleted
    /// (see `BudgetListViewModel.deleteBudget`). Deliberately not a real document in
    /// the `budgets` collection — there's no "其他" card to edit or delete, and no
    /// user ever picks it from the category Picker. It exists purely so a transaction
    /// that lost its category shows "其他" instead of collapsing into "未分類", which
    /// already means something different ("the user chose not to categorize this").
    static let otherCategoryId = "other"

    /// Explicit memberwise init (writing the custom `init(from:)` below turns off
    /// Swift's automatic one). The three frequency parameters default to
    /// "no frequency configured" so every call site that existed before 消費頻率
    /// Phase 1 — previews, tests, `addBudget`/`updateBudget` — keeps compiling
    /// unchanged; only `AddBudgetView` needs to actually pass them.
    init(
        id: String,
        name: String,
        limitMinorUnits: Int64,
        expectedMonthlyCount: Int,
        frequency: BudgetFrequency = .custom,
        frequencyWeekdays: Set<Int> = [],
        frequencyMonthDays: Set<Int> = [],
        schemaVersion: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.limitMinorUnits = limitMinorUnits
        self.expectedMonthlyCount = expectedMonthlyCount
        self.frequency = frequency
        self.frequencyWeekdays = frequencyWeekdays
        self.frequencyMonthDays = frequencyMonthDays
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, limitMinorUnits, expectedMonthlyCount
        case frequency, frequencyWeekdays, frequencyMonthDays
        case schemaVersion, createdAt, updatedAt
    }

    /// Custom decoding, not the synthesized one: any `BudgetRecord` document saved
    /// to Firestore *before* 消費頻率 Phase 1 shipped has no `frequency`/
    /// `frequencyWeekdays`/`frequencyMonthDays` keys at all. Swift's auto-generated
    /// `Decodable` would treat those as required keys and throw for every one of
    /// those older documents, breaking `observeBudgets()` for existing users.
    /// `decodeIfPresent(...) ?? default` treats a missing key the same as "this
    /// budget has never had a frequency set" — which is exactly true.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        limitMinorUnits = try container.decode(Int64.self, forKey: .limitMinorUnits)
        expectedMonthlyCount = try container.decode(Int.self, forKey: .expectedMonthlyCount)
        frequency = try container.decodeIfPresent(BudgetFrequency.self, forKey: .frequency) ?? .custom
        frequencyWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .frequencyWeekdays) ?? []
        frequencyMonthDays = try container.decodeIfPresent(Set<Int>.self, forKey: .frequencyMonthDays) ?? []
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

extension BudgetRecord {
    /// Whether this category is scheduled to show up in "今日固定支出" on
    /// `referenceDate`. `.daily` always matches. `.weekly` matches when today's
    /// weekday (`Calendar`'s numbering: 1 = Sunday ... 7 = Saturday) is one of the
    /// selected circles. `.monthly` matches when today's day-of-month (1...30) is
    /// one of the selected days. `.custom` never matches automatically — a custom
    /// count has no particular day attached to it, so those categories simply don't
    /// participate in this feature.
    func isScheduled(on referenceDate: Date = .now, calendar: Calendar = .current) -> Bool {
        switch frequency {
        case .daily:
            return true
        case .weekly:
            return frequencyWeekdays.contains(calendar.component(.weekday, from: referenceDate))
        case .monthly:
            return frequencyMonthDays.contains(calendar.component(.day, from: referenceDate))
        case .custom:
            return false
        }
    }

    /// Suggested "每月預計消費次數" for a given frequency selection — what
    /// `AddBudgetView` auto-fills the count to once a frequency is chosen, instead
    /// of leaving the user to guess a number their own selection already implies.
    /// `nil` for `.custom` means "don't override — leave whatever the user's slider
    /// already says alone."
    ///
    /// The daily/weekly numbers are deliberately approximations (a generic "30 days"
    /// and "4 weeks" per month, not the exact count for whichever month it happens
    /// to be) — this is a planning estimate shown next to a slider, not a value
    /// anything else in the app depends on being exact.
    static func suggestedExpectedMonthlyCount(
        frequency: BudgetFrequency,
        weekdays: Set<Int>,
        monthDays: Set<Int>
    ) -> Int? {
        switch frequency {
        case .daily:
            return 30
        case .weekly:
            return weekdays.count * 4
        case .monthly:
            return monthDays.count
        case .custom:
            return nil
        }
    }
}

// v2 Phase 5: a single per-user document (not a collection) holding whole-app
// settings that aren't tied to any one transaction or budget. Today that's just
// the total monthly budget the user allocates individual BudgetRecords out of;
// more settings can be added to this same document later without a schema
// migration, since it's already a flexible "one document per user" shape.
struct ProfileRecord: Codable, Equatable, Sendable {
    let monthlyBudgetLimitMinorUnits: Int64
    let schemaVersion: Int
    let createdAt: Date
    let updatedAt: Date

    /// What a brand-new user has before they've ever set a total budget — 0, not
    /// some placeholder Optional, so the rest of the app (sliders, arithmetic) never
    /// has to unwrap a "maybe there's no profile yet" case.
    static let unset = ProfileRecord(
        monthlyBudgetLimitMinorUnits: 0,
        schemaVersion: 1,
        createdAt: .now,
        updatedAt: .now
    )
}
