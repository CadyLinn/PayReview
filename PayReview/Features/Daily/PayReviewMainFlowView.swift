import Combine
import SwiftUI

@MainActor
final class PayReviewFlowStore: ObservableObject {
    enum Tab: Hashable { case today, plan, records, settings }
    enum EvaluationSource { case first, today, comparison }

    @Published var selectedTab: Tab = .today
    @Published var evaluationAmount: Decimal?
    @Published var evaluationCategory = "購物"
    @Published var evaluationSource: EvaluationSource = .first
    private var evaluationID = UUID()
    private var confirmedEvaluationIDs = Set<UUID>()
    private var deferredEvaluationIDs = Set<UUID>()
    private var confirmedRecordIDs = Set<UUID>()
    @Published var records: [PayReviewRecord] = [
        PayReviewRecord(title: "午餐", detail: "飲食 · 已確認", amount: 120, kind: .expense),
        PayReviewRecord(title: "購物 NT$1,000", detail: "已評估 · 晚點決定", amount: 0, kind: .deferred),
        PayReviewRecord(title: "帳戶轉帳", detail: "錢包 → 銀行", amount: 3_000, kind: .transfer)
    ]

    var evaluationAmountValue: Decimal {
        evaluationAmount ?? 0
    }

    var confirmedExpenseTotal: Decimal {
        records
            .filter { $0.kind == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    func beginEvaluation(source: EvaluationSource, amount: Decimal? = nil, category: String = "購物") {
        evaluationID = UUID()
        evaluationSource = source
        evaluationAmount = amount
        evaluationCategory = category
    }

    @discardableResult
    func confirmEvaluatedPurchase() -> Bool {
        guard let evaluationAmount, evaluationAmount > 0 else { return false }
        guard confirmedEvaluationIDs.insert(evaluationID).inserted else { return false }
        let title = evaluationCategory == "購物" ? "評估後購買" : evaluationCategory
        records.insert(
            PayReviewRecord(title: title, detail: "\(evaluationCategory) · 已確認", amount: evaluationAmount, kind: .expense),
            at: 0
        )
        return true
    }

    @discardableResult
    func deferCurrentEvaluation() -> Bool {
        guard let evaluationAmount, evaluationAmount > 0 else { return false }
        guard deferredEvaluationIDs.insert(evaluationID).inserted else { return false }
        records.insert(
            PayReviewRecord(
                title: "\(evaluationCategory) \(evaluationAmount.twdFormatted)",
                detail: "已評估 · 晚點決定",
                amount: 0,
                kind: .deferred
            ),
            at: 0
        )
        return true
    }

    @discardableResult
    func completePlannedExpense(_ expense: PlannedExpenseDraft) -> Bool {
        guard confirmedRecordIDs.insert(expense.id).inserted else { return false }
        records.insert(
            PayReviewRecord(
                title: expense.name,
                detail: "帳單 · 已完成預期支出",
                amount: expense.amount,
                kind: .expense
            ),
            at: 0
        )
        return true
    }

    @discardableResult
    func confirmRecord(
        confirmationID: UUID,
        title: String,
        detail: String,
        amount: Decimal,
        kind: PayReviewRecord.Kind
    ) -> Bool {
        guard confirmedRecordIDs.insert(confirmationID).inserted else { return false }
        records.insert(PayReviewRecord(title: title, detail: detail, amount: amount, kind: kind), at: 0)
        return true
    }
}

struct PayReviewRecord: Identifiable, Equatable {
    enum Kind { case expense, income, transfer, deferred }
    let id = UUID()
    var title: String
    var detail: String
    var amount: Decimal
    var kind: Kind
}

struct PayReviewMainFlowView: View {
    @ObservedObject var setupStore: SetupStore
    @ObservedObject var authentication: AuthenticationTestViewModel
    @StateObject private var flow = PayReviewFlowStore()
    @State private var hasCompletedFirstEvaluation = false
    @State private var showsFirstEvaluation = false

    var body: some View {
        MainTabView(setupStore: setupStore, flow: flow, authentication: authentication)
            .tint(PayReviewTheme.primary)
            .fullScreenCover(isPresented: $showsFirstEvaluation) {
                EvaluationFlowView(flow: flow, startsWithResult: false) {
                    hasCompletedFirstEvaluation = true
                    saveFirstEvaluationProgress()
                    showsFirstEvaluation = false
                }
            }
            .onAppear {
                loadFirstEvaluationProgress()
                guard !hasCompletedFirstEvaluation else { return }
                flow.beginEvaluation(source: .first)
                showsFirstEvaluation = true
            }
    }

    private func loadFirstEvaluationProgress() {
        guard let userID = authentication.authenticatedUser?.id else { return }
        hasCompletedFirstEvaluation = UserDefaults.standard.bool(
            forKey: "payReview.\(userID).hasCompletedFirstEvaluation"
        )
    }

    private func saveFirstEvaluationProgress() {
        guard let userID = authentication.authenticatedUser?.id else { return }
        UserDefaults.standard.set(
            hasCompletedFirstEvaluation,
            forKey: "payReview.\(userID).hasCompletedFirstEvaluation"
        )
    }
}

private struct MainTabView: View {
    @ObservedObject var setupStore: SetupStore
    @ObservedObject var flow: PayReviewFlowStore
    @ObservedObject var authentication: AuthenticationTestViewModel

    var body: some View {
        TabView(selection: $flow.selectedTab) {
            TodayPrototypeView(setupStore: setupStore, flow: flow)
                .tabItem { Label("今天", systemImage: "house.fill") }
                .tag(PayReviewFlowStore.Tab.today)
            PlanPrototypeView(setupStore: setupStore)
                .tabItem { Label("計畫", systemImage: "scope") }
                .tag(PayReviewFlowStore.Tab.plan)
            RecordsPrototypeView(flow: flow)
                .tabItem { Label("紀錄", systemImage: "list.bullet.rectangle") }
                .tag(PayReviewFlowStore.Tab.records)
            SettingsPrototypeView(authentication: authentication)
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
                .tag(PayReviewFlowStore.Tab.settings)
        }
    }
}

private struct TodayPrototypeView: View {
    @ObservedObject var setupStore: SetupStore
    @ObservedObject var flow: PayReviewFlowStore
    @State private var presentedFlow: TodayFlow?

    enum TodayFlow: Hashable, Identifiable {
        case evaluation, comparison, weekly
        var id: Self { self }
    }

    private var safeToSpend: Decimal {
        max(0, setupStore.flexibleBudget - flow.confirmedExpenseTotal)
    }

    private var nextPlannedExpense: PlannedExpenseDraft? {
        setupStore.plannedExpenses.min { $0.amount < $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        Text("7/17 今天").font(.largeTitle.bold())
                        Spacer()
                        ActivationMascot(size: 68)
                    }
                    .payReviewEntrance(delay: 0.02)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("安心可花估算").font(.subheadline.weight(.semibold))
                        Text(safeToSpend.twdFormatted).font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("已扣除目前確認的支出；金額為估算").font(.footnote)
                    }
                    .foregroundStyle(PayReviewTheme.surface)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PayReviewTheme.primary, in: RoundedRectangle(cornerRadius: 28))
                    .payReviewInteractiveTilt(maximumAngle: 4, focusedScale: 1.012)
                    .payReviewEntrance(delay: 0.08)

                    Button("評估眼前的消費") {
                        flow.beginEvaluation(source: .today)
                        presentedFlow = .evaluation
                    }
                    .buttonStyle(PayReviewPrimaryButtonStyle())
                    .payReviewShimmer()
                    .payReviewEntrance(delay: 0.14)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("今天的三件事").font(.title3.bold())
                        if let expense = nextPlannedExpense {
                            Button {
                                flow.completePlannedExpense(expense)
                            } label: {
                                taskRow(
                                    done: flow.records.contains { $0.detail.contains("已完成預期支出") && $0.title == expense.name },
                                    "完成今日固定支出：\(expense.name)",
                                    expense.amount.twdFormatted
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(
                                flow.records.contains {
                                    $0.detail.contains("已完成預期支出") && $0.title == expense.name
                                }
                            )
                        }
                        taskRow(done: true, "保留旅遊基金 NT$140", "已完成 · 進度向前")
                        taskRow(done: false, "消費前評估一次", "完成後蓋上今日印章")
                    }
                    .padding(18)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24))
                    .payReviewEntrance(delay: 0.20)

                    HStack(spacing: 14) {
                        explorationButton("比價實驗室", "折扣真的\n比較划算嗎？", PayReviewTheme.cautionSurface) {
                            presentedFlow = .comparison
                        }
                        explorationButton("本週故事", "看看紀錄\n帶來了什麼", PayReviewTheme.subtle) {
                            presentedFlow = .weekly
                        }
                    }
                    .payReviewEntrance(delay: 0.26)

                    MascotSpeechView(message: "今天不是追求完美，是知道下一步")
                        .payReviewEntrance(delay: 0.32)
                }
                .padding(24)
            }
            .background(PayReviewTheme.background.ignoresSafeArea())
            .sheet(item: $presentedFlow) { destination in
                switch destination {
                case .evaluation:
                    EvaluationFlowView(flow: flow, startsWithResult: false) { presentedFlow = nil }
                case .comparison:
                    ComparisonLabView(flow: flow) { presentedFlow = nil }
                case .weekly:
                    WeeklyStoryView { presentedFlow = nil }
                }
            }
        }
    }

    private func taskRow(done: Bool, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? PayReviewTheme.primary : PayReviewTheme.secondaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func explorationButton(
        _ title: String,
        _ detail: String,
        _ color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.footnote.bold()).foregroundStyle(PayReviewTheme.primary)
                Text(detail).font(.headline).foregroundStyle(PayReviewTheme.primaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(color, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(PayReviewPressButtonStyle())
        .payReviewInteractiveTilt(maximumAngle: 6, focusedScale: 1.035)
    }
}

private struct EvaluationFlowView: View {
    @ObservedObject var flow: PayReviewFlowStore
    let startsWithResult: Bool
    let completion: () -> Void
    @State private var path: [EvaluationRoute]

    enum EvaluationRoute: Hashable { case result, record, confirm }

    init(flow: PayReviewFlowStore, startsWithResult: Bool, completion: @escaping () -> Void) {
        self.flow = flow
        self.startsWithResult = startsWithResult
        self.completion = completion
        _path = State(initialValue: startsWithResult ? [.result] : [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            EvaluationInputPrototypeView(flow: flow) { path.append(.result) }
                .navigationDestination(for: EvaluationRoute.self) { route in
                    switch route {
                    case .result:
                        DecisionCardPrototypeView(
                            flow: flow,
                            purchaseAction: { path.append(.record) },
                            deferAction: {
                                flow.deferCurrentEvaluation()
                                completion()
                            },
                            skipAction: completion,
                            adjustPlanAction: {
                                flow.selectedTab = .plan
                                completion()
                            }
                        )
                    case .record:
                        EvaluatedExpensePrototypeView(flow: flow) { path.append(.confirm) }
                    case .confirm:
                        ConfirmEvaluatedPurchaseView(flow: flow) {
                            flow.confirmEvaluatedPurchase()
                            completion()
                        }
                    }
                }
        }
        .tint(PayReviewTheme.primary)
    }
}

private struct EvaluationInputPrototypeView: View {
    @ObservedObject var flow: PayReviewFlowStore
    let continueAction: () -> Void

    private let categories = ["飲食", "購物", "娛樂", "其他"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("第一筆試算 · 精準輸入").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("這筆預計花多少？").font(.largeTitle.bold())
                Text("先輸入金額；查看影響前，不會改變你的真實預算")
                    .font(.subheadline).foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("預計花費").font(.caption).foregroundStyle(.secondary)
                    TextField("NT$0", value: $flow.evaluationAmount, format: .payReviewTWD)
                        .keyboardType(.numberPad)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                }
                .padding(18)
                .background(PayReviewTheme.surface, in: RoundedRectangle(cornerRadius: 24))

                Text("類別（選填）").font(.headline)
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Button(category) { flow.evaluationCategory = category }
                            .buttonStyle(.bordered)
                            .tint(flow.evaluationCategory == category ? PayReviewTheme.primary : PayReviewTheme.secondaryText)
                    }
                }

                MascotSpeechView(message: "不用一次想得很精準，之後都能調整\n這一步只是在幫你看清影響")

                Button("查看 \(flow.evaluationAmountValue.twdFormatted) 的影響", action: continueAction)
                    .buttonStyle(PayReviewPrimaryButtonStyle())
                    .disabled(flow.evaluationAmountValue <= 0)
            }
            .padding(24)
        }
        .background(PayReviewTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DecisionCardPrototypeView: View {
    @ObservedObject var flow: PayReviewFlowStore
    let purchaseAction: () -> Void
    let deferAction: () -> Void
    let skipAction: () -> Void
    let adjustPlanAction: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsPlus = false
    @State private var revealStep = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("付款前評估")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PayReviewTheme.safe)
                    .opacity(revealStep >= 1 ? 1 : 0)
                    .offset(y: revealStep >= 1 ? 0 : 12)

                MascotSpeechView(
                    message: "先把資料補齊，再決定也不遲",
                    avatarSize: 88
                )
                .opacity(revealStep >= 1 ? 1 : 0)

                Text("這筆 \(flow.evaluationAmountValue.twdFormatted)\n目前還不能可靠計算")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(PayReviewTheme.surface)
                    .opacity(revealStep >= 1 ? 1 : 0)
                    .offset(y: revealStep >= 1 ? 0 : 14)

                Text("資料不足時，PayReview 不會替你猜答案")
                    .font(.body.weight(.medium))
                    .foregroundStyle(PayReviewTheme.safe)
                .opacity(revealStep >= 2 ? 1 : 0)
                .offset(y: revealStep >= 2 ? 0 : 18)

                resultCard(
                    "目前知道",
                    "金額是 \(flow.evaluationAmountValue.twdFormatted)，類別是「\(flow.evaluationCategory)」",
                    color: PayReviewTheme.darkRaised,
                    dark: true
                )
                    .opacity(revealStep >= 3 ? 1 : 0)
                    .offset(y: revealStep >= 3 ? 0 : 18)
                resultCard(
                    "還缺什麼",
                    "最新收入、必要支出與可用預算",
                    color: PayReviewTheme.cautionSurface
                )
                    .opacity(revealStep >= 4 ? 1 : 0)
                    .offset(y: revealStep >= 4 ? 0 : 18)
                resultCard(
                    "下一步",
                    "補齊計畫後，再查看預算與目標影響",
                    color: PayReviewTheme.subtle
                )
                    .opacity(revealStep >= 5 ? 1 : 0)
                    .offset(y: revealStep >= 5 ? 0 : 18)

                Button("補齊計畫，再看影響", action: adjustPlanAction)
                    .font(.body.weight(.bold))
                    .foregroundStyle(PayReviewTheme.primaryText)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(PayReviewTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                Button("購買並記錄", action: purchaseAction)
                    .buttonStyle(PayReviewPrimaryButtonStyle())

                HStack(spacing: 12) {
                    Button("晚點決定", action: deferAction)
                    Button("略過", action: skipAction)
                }
                .buttonStyle(.bordered)
                .tint(PayReviewTheme.safe)
                .frame(maxWidth: .infinity)

                HStack {
                    Text("計算狀態：資料不足")
                    Spacer()
                    Button("看看完整 Plus 功能") { showsPlus = true }
                }
                .font(.footnote)
                .foregroundStyle(PayReviewTheme.safe)
                .opacity(revealStep >= 6 ? 1 : 0)
            }
            .padding(24)
        }
        .background(PayReviewTheme.darkSurface.ignoresSafeArea())
        .sheet(isPresented: $showsPlus) { PlusOfferView() }
        .task {
            guard revealStep == 0 else { return }
            if reduceMotion {
                revealStep = 6
                return
            }
            for step in 1...6 {
                try? await Task.sleep(for: .milliseconds(step == 1 ? 80 : 145))
                withAnimation(.easeOut(duration: 0.42)) { revealStep = step }
            }
        }
    }

    private func resultCard(
        _ title: String,
        _ detail: String,
        color: Color,
        dark: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(dark ? PayReviewTheme.safe : PayReviewTheme.primaryText)
            Text(detail)
                .font(.headline)
                .foregroundStyle(dark ? PayReviewTheme.surface : PayReviewTheme.primaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct EvaluatedExpensePrototypeView: View {
    @ObservedObject var flow: PayReviewFlowStore
    let continueAction: () -> Void

    var body: some View {
        Form {
            Section {
                Text("確認評估後的支出").font(.title2.bold())
                Text("尚未確認前，不會更新正式預算").font(.footnote).foregroundStyle(.secondary)
            }
            Section("支出金額") {
                TextField("金額", value: $flow.evaluationAmount, format: .payReviewTWD)
                    .keyboardType(.numberPad).font(.title2.bold())
            }
            Section("類別") {
                Picker("類別", selection: $flow.evaluationCategory) {
                    ForEach(["娛樂", "飲食", "其他", "購物"], id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("日期") { Text("今天 · 7 月 17 日") }
            Section("已從剛才的評估帶入") {
                Text("預計花費 \(flow.evaluationAmountValue.twdFormatted) · 類別：\(flow.evaluationCategory)")
                Text("金額與類別都能修改；確認前不會更新正式預算")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section { Button("確認記帳", action: continueAction).buttonStyle(PayReviewPrimaryButtonStyle()) }
                .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(PayReviewTheme.background)
    }
}

private struct ConfirmEvaluatedPurchaseView: View {
    @ObservedObject var flow: PayReviewFlowStore
    let confirmAction: () -> Void
    @State private var isConfirming = false

    var body: some View {
        List {
            Section {
                Text("最後確認").font(.largeTitle.bold())
                Text("確認後，才會更新你的正式紀錄").foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("評估後購買", value: "− \(flow.evaluationAmountValue.twdFormatted)")
                LabeledContent("類別", value: flow.evaluationCategory)
                LabeledContent("日期", value: "2026 年 7 月 17 日")
                LabeledContent("標籤", value: "評估帶入")
            }
            Section("確認後會發生") {
                Label("建立支出 \(flow.evaluationAmountValue.twdFormatted)", systemImage: "checkmark")
                Label("套用類別「\(flow.evaluationCategory)」", systemImage: "checkmark")
                Label("更新正式預算並等待 Firebase 同步", systemImage: "checkmark")
            }
            Section {
                Button("確認並建立交易") {
                    guard !isConfirming else { return }
                    isConfirming = true
                    confirmAction()
                }
                .buttonStyle(PayReviewPrimaryButtonStyle())
                .disabled(isConfirming)
                Text("確認時使用輕觸回饋，不以煙火慶祝花費")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(PayReviewTheme.background)
    }
}

private struct ComparisonLabView: View {
    private enum Plan: String {
        case a = "A"
        case b = "B"

        var amount: Decimal {
            switch self {
            case .a: 960
            case .b: 1_150
            }
        }
    }

    @ObservedObject var flow: PayReviewFlowStore
    let dismiss: () -> Void
    @State private var evaluatesPlan = false
    @State private var selectedPlan: Plan = .a

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("折扣高，不一定更符合你的計畫").font(.title.bold())
                    Text("同時看實付、買進的份量，以及對目標的機會成本").foregroundStyle(.secondary)
                    comparisonCard(
                        plan: .a,
                        title: "A · 單件購買",
                        price: "實付 NT$960",
                        detail: "折扣 NT$100\n只買現在需要的",
                        impact: "目標日期不變"
                    )
                        .payReviewEntrance(delay: 0.08)
                    comparisonCard(
                        plan: .b,
                        title: "B · 折扣組合",
                        price: "實付 NT$1,150",
                        detail: "折扣 NT$300\n需多買未規劃品項",
                        impact: "預估延後 5 天"
                    )
                        .payReviewEntrance(delay: 0.16)
                    Text("方案 B 折扣較大，但多出的支出會占用旅遊基金進度")
                        .font(.subheadline.weight(.semibold))
                        .padding().background(PayReviewTheme.cautionSurface, in: RoundedRectangle(cornerRadius: 18))
                    Button("用方案 \(selectedPlan.rawValue) 進行評估") {
                        flow.beginEvaluation(source: .comparison, amount: selectedPlan.amount, category: "購物")
                        evaluatesPlan = true
                    }
                    .buttonStyle(PayReviewPrimaryButtonStyle())
                    .payReviewShimmer()
                    Text("只有你能選擇是否標記為臨時想買\n系統不會替你貼標籤")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
            .background(PayReviewTheme.background.ignoresSafeArea())
            .navigationTitle("比價實驗室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回今天", action: dismiss) } }
            .fullScreenCover(isPresented: $evaluatesPlan) {
                EvaluationFlowView(flow: flow, startsWithResult: false) {
                    evaluatesPlan = false
                    dismiss()
                }
            }
        }
    }

    private func comparisonCard(
        plan: Plan,
        title: String,
        price: String,
        detail: String,
        impact: String
    ) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.caption.bold()).foregroundStyle(PayReviewTheme.primary)
                    Spacer()
                    Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(PayReviewTheme.primary)
                }
                Text(price).font(.title.bold())
                Text(detail).font(.subheadline)
                Divider()
                Text(impact).font(.headline)
            }
            .foregroundStyle(PayReviewTheme.primaryText)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedPlan == plan ? PayReviewTheme.subtle : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                if selectedPlan == plan {
                    RoundedRectangle(cornerRadius: 24).stroke(PayReviewTheme.primary, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("選擇方案 \(plan.rawValue)，\(price)")
        .accessibilityAddTraits(selectedPlan == plan ? .isSelected : [])
        .payReviewInteractiveTilt(maximumAngle: 7, focusedScale: selectedPlan == plan ? 1.035 : 1.02)
    }
}

private struct WeeklyStoryView: View {
    let dismiss: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("你的本週故事 · 7/13–7/19").font(.caption.bold()).foregroundStyle(.secondary)
                    Text("這週不是只有記帳\n你真的守住了想前往的地方").font(.largeTitle.bold())
                    storyCard("值得肯定", "你有 3 次在付款前先看影響，其中 2 次選擇了更符合計畫的方案", PayReviewTheme.subtle)
                    storyCard("一個值得注意的變化", "週五晚上的臨時支出較集中，但整體仍在可調整範圍", PayReviewTheme.cautionSurface)
                    storyCard("下週的一個小任務", "先替週五晚上保留 NT$300，完成 3 次付款前評估", Color(.systemBackground))
                    Button("帶著這個計畫進入下週", action: dismiss).buttonStyle(PayReviewPrimaryButtonStyle())
                    Text("金額與狀態由 FinanceEngine 計算\nLLM 只整理說法與下一步").font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }.background(PayReviewTheme.background.ignoresSafeArea())
        }
    }
    private func storyCard(_ title: String, _ detail: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption.bold()); Text(detail).font(.headline) }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading).background(color, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct PlanPrototypeView: View {
    @ObservedObject var setupStore: SetupStore
    var body: some View {
        NavigationStack {
            List {
                Section { Text("以下是目前計算安心可花額度與目標影響的假設").foregroundStyle(.secondary) }
                Section("目前計算假設") {
                    LabeledContent("收入週期", value: setupStore.incomeCadence.rawValue)
                    LabeledContent("必要支出", value: setupStore.plannedExpenseTotal.twdFormatted)
                    LabeledContent("彈性預算", value: setupStore.flexibleBudget.twdFormatted)
                    LabeledContent("安全緩衝", value: "已保留")
                    LabeledContent("目標", value: setupStore.goalName)
                }
                Section { NavigationLink("檢視並調整計畫") { PlanAssumptionsEditorView(store: setupStore) } }
            }
            .navigationTitle("計畫")
        }
    }
}

private struct PlanAssumptionsEditorView: View {
    @ObservedObject var store: SetupStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("收入與週期") {
                Picker("收入週期", selection: $store.incomeCadence) {
                    ForEach(IncomeCadence.allCases) { cadence in
                        Text(cadence.rawValue).tag(cadence)
                    }
                }
                DatePicker("下次收入日", selection: $store.nextIncomeDate, displayedComponents: .date)
                TextField("本期可用收入", value: $store.availableIncome, format: .payReviewTWD)
                    .keyboardType(.numberPad)
            }
            Section("支出與安全空間") {
                LabeledContent("已規劃必要支出", value: store.plannedExpenseTotal.twdFormatted)
                TextField("彈性預算", value: $store.flexibleBudget, format: .payReviewTWD)
                    .keyboardType(.numberPad)
                Text("必要支出會先保留，再計算安心可花額度。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("目標") {
                TextField("目標名稱", text: $store.goalName)
                TextField("目標金額", value: $store.goalAmount, format: .payReviewTWD)
                    .keyboardType(.numberPad)
                DatePicker("目標日期", selection: $store.targetDate, displayedComponents: .date)
            }
            Section {
                Button("儲存並返回計畫") { dismiss() }
                    .buttonStyle(PayReviewPrimaryButtonStyle())
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("調整計畫")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RecordsPrototypeView: View {
    @ObservedObject var flow: PayReviewFlowStore
    @State private var showsAddRecord = false
    @State private var selectedRecord: PayReviewRecord?
    @State private var filter: RecordFilter = .all

    private enum RecordFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case transactions = "交易"
        case evaluations = "評估"
        case deferred = "延後"

        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("紀錄")
                            .font(.largeTitle.bold())
                        Spacer()
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("目前已確認支出")
                                .font(.subheadline.weight(.semibold))
                            Text(confirmedExpenseTotal.twdFormatted)
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                            Text("轉帳不計入收支")
                                .font(.footnote)
                        }
                        Spacer()
                        ActivationMascot(size: 66)
                    }
                    .foregroundStyle(PayReviewTheme.subtle)
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: 112)
                    .background(PayReviewTheme.primary, in: RoundedRectangle(cornerRadius: 26))

                    HStack(spacing: 8) {
                        ForEach(RecordFilter.allCases) { option in
                            Button(option.rawValue) { filter = option }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(PayReviewTheme.primaryText)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(
                                    filter == option ? PayReviewTheme.cautionSurface : PayReviewTheme.subtle,
                                    in: Capsule()
                                )
                        }
                    }

                    Text("今天 · 7 月 17 日")
                        .font(.headline)
                        .foregroundStyle(PayReviewTheme.secondaryText)

                    ForEach(filteredRecords) { record in
                        Button { selectedRecord = record } label: {
                            recordRow(record)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 100)
            }
            .background(PayReviewTheme.surface)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新增紀錄", systemImage: "plus") { showsAddRecord = true }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $showsAddRecord) { AddRecordFlowView(flow: flow) }
            .sheet(item: $selectedRecord) { record in RecordDetailView(record: record, flow: flow) }
        }
    }

    private var confirmedExpenseTotal: Decimal {
        flow.records
            .filter { $0.kind == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var filteredRecords: [PayReviewRecord] {
        switch filter {
        case .all:
            flow.records
        case .transactions:
            flow.records.filter { $0.kind != .deferred }
        case .evaluations:
            flow.records.filter { $0.detail.contains("評估") }
        case .deferred:
            flow.records.filter { $0.kind == .deferred }
        }
    }

    private func recordRow(_ record: PayReviewRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(record.title).font(.headline)
                Text(record.detail).font(.caption).foregroundStyle(PayReviewTheme.secondaryText)
            }
            Spacer()
            Text(record.kind == .deferred ? "不扣預算" : record.amount.twdFormatted)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(PayReviewTheme.primaryText)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(record.kind == .deferred ? PayReviewTheme.cautionSurface : PayReviewTheme.subtle, in: RoundedRectangle(cornerRadius: 20))
        .contentShape(Rectangle())
    }
}

private struct AddRecordFlowView: View {
    @ObservedObject var flow: PayReviewFlowStore
    @Environment(\.dismiss) private var dismiss
    @State private var type = 0
    @State private var amount: Decimal = 699
    @State private var category = "帳單"
    @State private var showsReview = false
    @State private var isConfirming = false
    @State private var confirmationID = UUID()

    var body: some View {
        NavigationStack {
            Form {
                Section("這次想留下哪一種紀錄？") {
                    Picker("類型", selection: $type) { Text("支出").tag(0); Text("收入").tag(1); Text("轉帳").tag(2) }.pickerStyle(.segmented)
                    Text(type == 2 ? "轉帳不會算成花費" : "正式紀錄會更新預算；試算本身不會").font(.footnote).foregroundStyle(.secondary)
                }
                Section(type == 0 ? "支出金額" : type == 1 ? "收入金額" : "轉帳金額") {
                    TextField("金額", value: $amount, format: .payReviewTWD).keyboardType(.numberPad)
                    if type != 2 { TextField("類別", text: $category) }
                }
                if type == 0 {
                    Section("找到可能對應的預期支出") {
                        Text("電信費 NT$699 · 7 月 20 日")
                        Text("確認後會完成這筆預期支出，不會再次扣除預算").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if type == 2 { Section { Text("這筆錢只是在自己的帳戶間移動，不計入收入或支出") } }
                Section {
                    Button("檢查後再記錄") { showsReview = true }
                        .buttonStyle(PayReviewPrimaryButtonStyle())
                        .disabled(amount <= 0 || (type != 2 && category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(type == 0 ? "新增支出" : type == 1 ? "新增收入" : "新增轉帳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .navigationDestination(isPresented: $showsReview) {
                reviewView
            }
        }
    }

    private var reviewView: some View {
        List {
            Section {
                Text("最後確認").font(.largeTitle.bold())
                Text("確認後才會建立正式紀錄並更新相關計算。")
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("類型", value: typeTitle)
                LabeledContent("金額", value: amount.twdFormatted)
                if type != 2 { LabeledContent("類別", value: category) }
                LabeledContent("日期", value: "今天")
            }
            if type == 0 {
                Section("預期支出配對") {
                    Text("電信費 NT$699 · 7 月 20 日")
                    Text("確認後會完成這筆預期支出，不會再次扣除預算。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("確認並建立\(typeTitle)") {
                    confirmRecord()
                }
                .buttonStyle(PayReviewPrimaryButtonStyle())
                .disabled(isConfirming)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("確認紀錄")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var typeTitle: String {
        type == 0 ? "支出" : type == 1 ? "收入" : "轉帳"
    }

    private func confirmRecord() {
        guard !isConfirming else { return }
        isConfirming = true
        let kind: PayReviewRecord.Kind = type == 0 ? .expense : type == 1 ? .income : .transfer
        let title = type == 0 ? category : type == 1 ? "收入" : "帳戶轉帳"
        let detail = type == 0 ? "\(category) · 已確認" : type == 1 ? "收入 · 已確認" : "錢包 → 銀行"
        flow.confirmRecord(
            confirmationID: confirmationID,
            title: title,
            detail: detail,
            amount: amount,
            kind: kind
        )
        dismiss()
    }
}

private struct RecordDetailView: View {
    let record: PayReviewRecord
    @ObservedObject var flow: PayReviewFlowStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(record.title).font(.largeTitle.bold())
                    Text(record.kind == .deferred ? "不扣預算" : record.amount.twdFormatted).font(.title.bold())
                    if record.kind == .deferred {
                        Label("尚未建立交易", systemImage: "clock")
                            .foregroundStyle(.secondary)
                    } else {
                        Label("原型紀錄，尚未同步到雲端", systemImage: "internaldrive")
                            .foregroundStyle(PayReviewTheme.primary)
                    }
                }
                Section {
                    LabeledContent("類型", value: recordKindTitle)
                    LabeledContent("日期", value: "2026 年 7 月 17 日")
                    LabeledContent("資料來源", value: record.kind == .deferred ? "消費評估" : "手動")
                }
                if record.kind == .expense && record.title == "電信費" {
                    Section("計畫連結") {
                        Text("已完成預期支出「電信費」")
                        Text("這筆交易已取代原預留項目，不會重複扣除").font(.footnote).foregroundStyle(.secondary)
                    }
                } else if record.kind == .transfer {
                    Section("計算方式") { Text("轉帳不計入收入或支出。") }
                } else if record.kind == .deferred {
                    Section("評估狀態") { Text("這是保留的評估，不會改變正式預算或目標。") }
                }
                Section { Button("刪除紀錄", role: .destructive) { confirmsDelete = true } }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() } } }
            .alert("要移除這筆紀錄嗎？", isPresented: $confirmsDelete) {
                Button("確認刪除", role: .destructive) { flow.records.removeAll { $0.id == record.id }; dismiss() }
                Button("先保留這筆紀錄", role: .cancel) {}
            } message: { Text("刪除後，這筆交易會從紀錄與計算中移除") }
        }
    }

    private var recordKindTitle: String {
        switch record.kind {
        case .expense: "支出"
        case .income: "收入"
        case .transfer: "轉帳"
        case .deferred: "待決定評估"
        }
    }
}

private struct SettingsPrototypeView: View {
    @ObservedObject var authentication: AuthenticationTestViewModel
    @State private var showsPlus = false
    @State private var showsSignOut = false
    @State private var showsDelete = false
    @State private var showsIntroduction = false

    var body: some View {
        NavigationStack {
            List {
                Section("帳號與安全") {
                    LabeledContent("帳號", value: authentication.authenticatedUser?.email ?? "已登入")
                    Label("帳號狀態已確認", systemImage: "checkmark.circle.fill")
                }
                Section("訂閱與購買") { Button("管理方案、續訂與恢復購買") { showsPlus = true } }
                Section("使用指南") {
                    Button {
                        showsIntroduction = true
                    } label: {
                        Label("重播動態介紹", systemImage: "play.rectangle")
                    }
                }
                Section("隱私與資料") {
                    NavigationLink("隱私權與資料使用") { policyView("隱私權與資料使用") }
                    NavigationLink("匯出我的資料") { policyView("下載紀錄與目前設定") }
                    Button("刪除帳號", role: .destructive) { showsDelete = true }
                }
                Section { Button("安全登出") { showsSignOut = true } }
            }
            .navigationTitle("帳號與安全")
            .sheet(isPresented: $showsPlus) { PlusOfferView() }
            .sheet(isPresented: $showsSignOut) {
                SafeSignOutView(
                    signOut: {
                        showsSignOut = false
                        authentication.signOut()
                    },
                    cancel: { showsSignOut = false }
                )
            }
            .sheet(isPresented: $showsDelete) { AccountDeletionPrototypeView { showsDelete = false } }
            .fullScreenCover(isPresented: $showsIntroduction) {
                OnboardingFlowView {
                    showsIntroduction = false
                }
            }
        }
    }

    private func policyView(_ title: String) -> some View {
        List {
            Section { Text(title).font(.title2.bold()) }
            Section("你的控制") {
                Label("不用連結銀行也能使用核心功能", systemImage: "building.columns")
                Label("可匯出紀錄與目前設定", systemImage: "square.and.arrow.up")
                Label("可從 App 內發起完整帳號刪除", systemImage: "trash")
            }
            Section { Text("確切金額、商家、備註與目標名稱不會送到產品分析。") }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AccountDeletionPrototypeView: View {
    let cancel: () -> Void
    @State private var understandsSubscription = false
    @State private var confirmsUnsyncedChanges = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("刪除帳號前，先確認資料狀態").font(.title2.bold())
                    Text("刪除與登出是不同流程；完成後無法復原。")
                        .foregroundStyle(.secondary)
                }
                Section("刪除流程") {
                    Label("使用目前登入方式重新驗證", systemImage: "person.badge.key")
                    Label("等待待同步紀錄，最多 30 秒", systemImage: "arrow.triangle.2.circlepath")
                    Label("建立安全刪除工作並清除本機資料", systemImage: "lock.shield")
                }
                Section {
                    Toggle("我了解刪除帳號不會自動取消 Apple 訂閱", isOn: $understandsSubscription)
                    Toggle("若仍有未同步變更，我會再次確認是否永久捨棄", isOn: $confirmsUnsyncedChanges)
                }
                Section {
                    Button("帳號刪除功能尚未完成", role: .destructive) {}
                        .disabled(true)
                    Button("先保留帳號", action: cancel)
                }
            }
            .navigationTitle("刪除帳號")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SafeSignOutView: View {
    let signOut: () -> Void
    let cancel: () -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                ActivationMascot(size: 112)
                Text("先讓紀錄安全到家，\n再跟這台裝置說再見").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text("目前沒有連接中的正式財務寫入").font(.headline)
                Text("登出後，需要再次使用 Email 或 Google 登入。").foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("確認登出", action: signOut).buttonStyle(PayReviewPrimaryButtonStyle())
                Button("取消登出", action: cancel).buttonStyle(.bordered)
                Text("正式 Firestore 寫入啟用後，這裡會先等待 pending writes。").font(.footnote).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(PayReviewTheme.background)
        }
    }
}

private struct PlusOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showsTrial = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("PAYREVIEW PLUS").font(.caption.bold()).foregroundStyle(PayReviewTheme.primary)
                    Text("不要等到月底，\n才知道今天花太多").font(.largeTitle.bold())
                    Text("讓每一次紀錄，持續改善下一次的消費決定").foregroundStyle(.secondary)
                    feature("付款前", "先算預算與對目標的影響")
                    feature("比價時", "比較實付、折扣與機會成本")
                    feature("每週結束", "把紀錄變成下週的小行動")
                    HStack { plan("建議\n年繳", "NT$800／年\n符合資格者可試用 7 天", true); plan("月繳", "NT$120\n每月", false) }
                    Button("選擇方案並繼續") { showsTrial = true }.buttonStyle(PayReviewPrimaryButtonStyle())
                    Text("正式版本會顯示 App Store 提供的價格、續訂日期與試用資格。可隨時取消。")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }
            .background(PayReviewTheme.background.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("稍後再說") { dismiss() } } }
            .sheet(isPresented: $showsTrial) { TrialEligibilityView() }
        }
    }
    private func feature(_ title: String, _ detail: String) -> some View { VStack(alignment: .leading) { Text(title).font(.caption.bold()); Text(detail).font(.headline) }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18)) }
    private func plan(_ title: String, _ detail: String, _ selected: Bool) -> some View { VStack(alignment: .leading) { Text(title).font(.headline); Text(detail).font(.subheadline) }.padding().frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading).background(selected ? PayReviewTheme.subtle : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20)) }
}

#Preview {
    PayReviewMainFlowView(
        setupStore: SetupStore(),
        authentication: AuthenticationTestViewModel()
    )
}
