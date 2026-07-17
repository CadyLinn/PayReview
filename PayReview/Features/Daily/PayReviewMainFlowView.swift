import Combine
import SwiftUI

@MainActor
final class PayReviewFlowStore: ObservableObject {
    enum Tab: Hashable { case today, plan, records }
    enum EvaluationSource { case first, today, comparison }

    @Published var selectedTab: Tab = .today
    @Published var evaluationAmount: Decimal = 1_000
    @Published var evaluationCategory = "購物"
    @Published var evaluationSource: EvaluationSource = .first
    private var evaluationID = UUID()
    private var confirmedEvaluationIDs = Set<UUID>()
    private var deferredEvaluationIDs = Set<UUID>()
    private var confirmedRecordIDs = Set<UUID>()
    @Published var records: [PayReviewRecord] = [
        PayReviewRecord(title: "電信費", detail: "帳單 · 已完成預期支出", amount: 699, kind: .expense),
        PayReviewRecord(title: "午餐", detail: "飲食 · 已確認", amount: 120, kind: .expense),
        PayReviewRecord(title: "購物 NT$1,000", detail: "已評估 · 晚點決定", amount: 0, kind: .deferred),
        PayReviewRecord(title: "帳戶轉帳", detail: "錢包 → 銀行", amount: 3_000, kind: .transfer)
    ]

    func beginEvaluation(source: EvaluationSource, amount: Decimal = 1_000, category: String = "購物") {
        evaluationID = UUID()
        evaluationSource = source
        evaluationAmount = amount
        evaluationCategory = category
    }

    @discardableResult
    func confirmEvaluatedPurchase() -> Bool {
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
    @StateObject private var flow = PayReviewFlowStore()
    @AppStorage("hasCompletedFirstPayReviewEvaluation") private var hasCompletedFirstEvaluation = false
    @State private var showsFirstEvaluation = false

    var body: some View {
        MainTabView(setupStore: setupStore, flow: flow)
            .tint(PayReviewTheme.primary)
            .fullScreenCover(isPresented: $showsFirstEvaluation) {
                EvaluationFlowView(flow: flow, startsWithResult: false) {
                    hasCompletedFirstEvaluation = true
                    showsFirstEvaluation = false
                }
            }
            .onAppear {
                guard !hasCompletedFirstEvaluation else { return }
                flow.beginEvaluation(source: .first)
                showsFirstEvaluation = true
            }
    }
}

private struct MainTabView: View {
    @ObservedObject var setupStore: SetupStore
    @ObservedObject var flow: PayReviewFlowStore

    var body: some View {
        TabView(selection: $flow.selectedTab) {
            TodayPrototypeView(setupStore: setupStore, flow: flow)
                .tabItem { Label("今天", systemImage: "house.fill") }
                .tag(PayReviewFlowStore.Tab.today)
            PlanPrototypeView(setupStore: setupStore)
                .tabItem { Label("計畫", systemImage: "scope") }
                .tag(PayReviewFlowStore.Tab.plan)
            RecordsPrototypeView(setupStore: setupStore, flow: flow)
                .tabItem { Label("紀錄", systemImage: "list.bullet.rectangle") }
                .tag(PayReviewFlowStore.Tab.records)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        Text("7/17 今天").font(.largeTitle.bold())
                        Spacer()
                        NavigationLink {
                            SettingsPrototypeView(embedsNavigationStack: false)
                        } label: {
                            ActivationMascot(size: 68)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("帳號與安全設定")
                    }
                    .payReviewEntrance(delay: 0.02)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("今天約可安心花").font(.subheadline.weight(.semibold))
                        Text("NT$680").font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("已預留生活支出與\(setupStore.goalName)最低存款").font(.footnote)
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
                        taskRow(done: true, "確認必要支出", "已完成 · 輕震回饋")
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
                            purchase: { path.append(.record) },
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
                    TextField("NT$0", value: $flow.evaluationAmount, format: .currency(code: "TWD"))
                        .keyboardType(.decimalPad)
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

                Button("查看 \(flow.evaluationAmount.twdFormatted) 的影響", action: continueAction)
                    .buttonStyle(PayReviewPrimaryButtonStyle())
                    .disabled(flow.evaluationAmount <= 0)
            }
            .padding(24)
        }
        .background(PayReviewTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DecisionCardPrototypeView: View {
    @ObservedObject var flow: PayReviewFlowStore
    let purchase: () -> Void
    let deferAction: () -> Void
    let skipAction: () -> Void
    let adjustPlanAction: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsPlus = false
    @State private var revealStep = 0

    private var overage: Decimal { max(0, flow.evaluationAmount - 680) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("第一次評估結果").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .opacity(revealStep >= 1 ? 1 : 0)
                    .offset(y: revealStep >= 1 ? 0 : 12)
                Text("想買沒有錯；先看看哪條路\n最符合你現在的計畫")
                    .font(.title.bold())
                    .opacity(revealStep >= 1 ? 1 : 0)
                    .offset(y: revealStep >= 1 ? 0 : 14)

                VStack(alignment: .leading, spacing: 6) {
                    Text(overage > 0 ? "超出目前可用額度" : "仍在目前可用額度內")
                        .font(.subheadline.weight(.semibold))
                    Text(overage > 0 ? overage.twdFormatted : (680 - flow.evaluationAmount).twdFormatted)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(overage > 0 ? PayReviewTheme.cautionSurface : PayReviewTheme.subtle, in: RoundedRectangle(cornerRadius: 24))
                .opacity(revealStep >= 2 ? 1 : 0)
                .offset(y: revealStep >= 2 ? 0 : 18)

                resultCard("預算", overage > 0 ? "本週彈性空間不足 \(overage.twdFormatted)" : "買完仍保留 \((680 - flow.evaluationAmount).twdFormatted)")
                    .opacity(revealStep >= 3 ? 1 : 0)
                    .offset(y: revealStep >= 3 ? 0 : 18)
                resultCard("目標", overage > 0 ? "若不調整其他支出，預估延後 4 天" : "使用彈性預算支付，目標日期不變")
                    .opacity(revealStep >= 4 ? 1 : 0)
                    .offset(y: revealStep >= 4 ? 0 : 18)
                resultCard("恢復", overage > 0 ? "接下來 4 天每天保留 NT$80" : "不需要改變原本目標日期")
                    .opacity(revealStep >= 5 ? 1 : 0)
                    .offset(y: revealStep >= 5 ? 0 : 18)

                Button("完成評估並確認購買記帳", action: purchase)
                    .buttonStyle(PayReviewPrimaryButtonStyle())
                    .payReviewShimmer()
                Button("晚點再決定", action: deferAction)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("調整計畫", action: adjustPlanAction)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("略過這次評估", action: skipAction)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("\(flow.evaluationAmount.twdFormatted) · \(flow.evaluationCategory)")
                    Spacer()
                    Button("看看完整 Plus 功能") { showsPlus = true }
                }
                .font(.footnote.weight(.semibold))
                .opacity(revealStep >= 6 ? 1 : 0)
            }
            .padding(24)
        }
        .background(PayReviewTheme.background.ignoresSafeArea())
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

    private func resultCard(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(detail).font(.headline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
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
                TextField("金額", value: $flow.evaluationAmount, format: .currency(code: "TWD"))
                    .keyboardType(.decimalPad).font(.title2.bold())
            }
            Section("類別") {
                Picker("類別", selection: $flow.evaluationCategory) {
                    ForEach(["娛樂", "飲食", "其他", "購物"], id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("日期") { Text("今天 · 7 月 17 日") }
            Section("已從剛才的評估帶入") {
                Text("預計花費 \(flow.evaluationAmount.twdFormatted) · 類別：\(flow.evaluationCategory)")
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
                LabeledContent("評估後購買", value: "− \(flow.evaluationAmount.twdFormatted)")
                LabeledContent("類別", value: flow.evaluationCategory)
                LabeledContent("日期", value: "2026 年 7 月 17 日")
                LabeledContent("標籤", value: "評估帶入")
            }
            Section("確認後會發生") {
                Label("建立支出 \(flow.evaluationAmount.twdFormatted)", systemImage: "checkmark")
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
    @ObservedObject var flow: PayReviewFlowStore
    let dismiss: () -> Void
    @State private var evaluatesPlan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("折扣高，不一定更符合你的計畫").font(.title.bold())
                    Text("同時看實付、買進的份量，以及對目標的機會成本").foregroundStyle(.secondary)
                    comparisonCard("A · 單件購買", "實付 NT$960", "折扣 NT$100\n只買現在需要的", "目標日期不變", highlighted: true)
                        .payReviewEntrance(delay: 0.08)
                    comparisonCard("B · 折扣組合", "實付 NT$1,150", "折扣 NT$300\n需多買未規劃品項", "預估延後 5 天", highlighted: false)
                        .payReviewEntrance(delay: 0.16)
                    Text("方案 B 折扣較大，但多出的支出會占用旅遊基金進度")
                        .font(.subheadline.weight(.semibold))
                        .padding().background(PayReviewTheme.cautionSurface, in: RoundedRectangle(cornerRadius: 18))
                    Button("用方案 A 進行評估") {
                        flow.beginEvaluation(source: .comparison, amount: 960, category: "購物")
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

    private func comparisonCard(_ title: String, _ price: String, _ detail: String, _ impact: String, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.bold()).foregroundStyle(PayReviewTheme.primary)
            Text(price).font(.title.bold())
            Text(detail).font(.subheadline)
            Divider()
            Text(impact).font(.headline)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlighted ? PayReviewTheme.subtle : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24))
        .overlay { if highlighted { RoundedRectangle(cornerRadius: 24).stroke(PayReviewTheme.primary, lineWidth: 2) } }
        .payReviewInteractiveTilt(maximumAngle: 7, focusedScale: highlighted ? 1.035 : 1.02)
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
    @State private var draftGoalName: String
    @State private var draftIncomeCadence: IncomeCadence
    @State private var draftPlannedExpenseTotal: Int
    @State private var draftFlexibleBudget: Int
    @State private var showsUpdatedPlan = false

    init(setupStore: SetupStore) {
        self.setupStore = setupStore
        _draftGoalName = State(initialValue: setupStore.goalName)
        _draftIncomeCadence = State(initialValue: setupStore.incomeCadence)
        _draftPlannedExpenseTotal = State(initialValue: NSDecimalNumber(decimal: setupStore.plannedExpenseTotal).intValue)
        _draftFlexibleBudget = State(initialValue: NSDecimalNumber(decimal: setupStore.flexibleBudget).intValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("計畫").font(.largeTitle.bold())

                    VStack(alignment: .leading, spacing: 14) {
                        TextField("自訂目標", text: $draftGoalName)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("目標金額 \(setupStore.goalAmount.twdFormatted) · \(setupStore.targetDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.footnote)

                        Divider()

                        Text("目前計算假設").font(.title3.bold())
                        assumptionControlRow("calendar", "收入週期") {
                            Picker("收入週期", selection: $draftIncomeCadence) {
                                Text("每日").tag(IncomeCadence.daily)
                                Text("每月").tag(IncomeCadence.monthly)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        Divider().padding(.leading, 52)
                        assumptionControlRow("checklist", "必要支出") {
                            moneyWheelPicker(selection: $draftPlannedExpenseTotal)
                        }
                        Divider().padding(.leading, 52)
                        assumptionControlRow("slider.horizontal.3", "彈性預算") {
                            moneyWheelPicker(selection: $draftFlexibleBudget)
                        }
                        Divider().padding(.leading, 52)
                        assumptionRow("shield", "安全緩衝", "已保留")
                    }
                    .padding(18)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Button {
                        updatePlan()
                    } label: {
                        HStack(spacing: 8) {
                            Text(showsUpdatedPlan ? "計畫已更新" : "更新計畫")
                            Image(systemName: showsUpdatedPlan ? "checkmark" : "arrow.clockwise")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PayReviewPrimaryButtonStyle())
                }
                .padding(24)
            }
            .background(PayReviewTheme.background.ignoresSafeArea())
        }
    }

    private func assumptionRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(PayReviewTheme.primary)
                .frame(width: 40, height: 40)
                .background(PayReviewTheme.subtle, in: Circle())

            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(PayReviewTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func assumptionControlRow<Control: View>(
        _ icon: String,
        _ title: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(PayReviewTheme.primary)
                .frame(width: 40, height: 40)
                .background(PayReviewTheme.subtle, in: Circle())

            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            control()
                .foregroundStyle(PayReviewTheme.primaryText)
        }
    }

    private func moneyWheelPicker(selection: Binding<Int>) -> some View {
        Picker("金額", selection: selection) {
            ForEach(moneyOptions, id: \.self) { value in
                Text(Decimal(value).twdFormatted).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.wheel)
        .frame(width: 138, height: 88)
        .clipped()
    }

    private var moneyOptions: [Int] {
        let minimum = otherPlannedExpenseTotal
        let options = Array(stride(from: minimum, through: 100_000, by: 100))
        return Array(Set(options + [draftPlannedExpenseTotal, draftFlexibleBudget])).sorted()
    }

    private var otherPlannedExpenseTotal: Int {
        let total = setupStore.plannedExpenses
            .dropFirst()
            .reduce(Decimal.zero) { $0 + $1.amount }
        return NSDecimalNumber(decimal: total).intValue
    }

    private func updatePlan() {
        let trimmedGoalName = draftGoalName.trimmingCharacters(in: .whitespacesAndNewlines)
        setupStore.goalName = trimmedGoalName.isEmpty ? setupStore.goalName : trimmedGoalName
        setupStore.incomeCadence = draftIncomeCadence
        setupStore.updatePlannedExpenseTotal(to: Decimal(draftPlannedExpenseTotal))
        setupStore.flexibleBudget = Decimal(draftFlexibleBudget)
        showsUpdatedPlan = true
    }
}

private struct RecordsPrototypeView: View {
    @ObservedObject var setupStore: SetupStore
    @ObservedObject var flow: PayReviewFlowStore
    @State private var showsAddRecord = false
    @State private var selectedRecord: PayReviewRecord?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("紀錄").font(.largeTitle.bold())
                        Text("最近發生了什麼？你做了哪些選擇？")
                            .font(.subheadline)
                            .foregroundStyle(PayReviewTheme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("本週已確認支出")
                            .font(.subheadline.weight(.semibold))
                        Text(confirmedExpenseTotal.twdFormatted)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        Text("\(confirmedExpenseCount) 筆支出已記入計畫 · 轉帳不計入收支")
                            .font(.footnote)
                    }
                    .foregroundStyle(PayReviewTheme.surface)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PayReviewTheme.primary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                    Button("記錄一筆") { showsAddRecord = true }
                        .buttonStyle(PayReviewPrimaryButtonStyle())

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("今天 · 7 月 17 日").font(.title3.bold())
                            Spacer()
                            Text("\(flow.records.count) 筆").font(.caption).foregroundStyle(.secondary)
                        }

                        ForEach(Array(flow.records.enumerated()), id: \.element.id) { index, record in
                            Button { selectedRecord = record } label: { recordRow(record) }
                                .buttonStyle(PayReviewPressButtonStyle())

                            if index < flow.records.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    MascotSpeechView(message: "紀錄不是檢討，是幫你看見下一步")
                }
                .padding(24)
            }
            .background(PayReviewTheme.background.ignoresSafeArea())
            .sheet(isPresented: $showsAddRecord) { AddRecordFlowView(setupStore: setupStore, flow: flow) }
            .sheet(item: $selectedRecord) { record in RecordDetailView(record: record, flow: flow) }
        }
    }

    private var confirmedExpenseTotal: Decimal {
        flow.records
            .filter { $0.kind == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var confirmedExpenseCount: Int {
        flow.records.filter { $0.kind == .expense }.count
    }

    private func recordRow(_ record: PayReviewRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: recordIcon(for: record.kind))
                .font(.body.weight(.semibold))
                .foregroundStyle(recordIconColor(for: record.kind))
                .frame(width: 40, height: 40)
                .background(recordIconBackground(for: record.kind), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title).font(.subheadline.weight(.semibold))
                Text(record.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(recordAmount(for: record)).font(.subheadline.weight(.semibold))
                if record.kind == .deferred {
                    Text("尚未記入")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PayReviewTheme.secondaryText)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func recordAmount(for record: PayReviewRecord) -> String {
        switch record.kind {
        case .expense: return "−\(record.amount.twdFormatted)"
        case .income: return "+\(record.amount.twdFormatted)"
        case .transfer: return record.amount.twdFormatted
        case .deferred: return "晚點決定"
        }
    }

    private func recordIcon(for kind: PayReviewRecord.Kind) -> String {
        switch kind {
        case .expense: return "arrow.up.right"
        case .income: return "arrow.down.left"
        case .transfer: return "arrow.left.arrow.right"
        case .deferred: return "clock"
        }
    }

    private func recordIconColor(for kind: PayReviewRecord.Kind) -> Color {
        kind == .expense ? PayReviewTheme.primary : PayReviewTheme.primaryText
    }

    private func recordIconBackground(for kind: PayReviewRecord.Kind) -> Color {
        switch kind {
        case .expense: return PayReviewTheme.cautionSurface
        case .income: return PayReviewTheme.safe.opacity(0.35)
        case .transfer: return PayReviewTheme.subtle
        case .deferred: return Color(.systemGray6)
        }
    }
}

private struct AddRecordFlowView: View {
    @ObservedObject var setupStore: SetupStore
    @ObservedObject var flow: PayReviewFlowStore
    @Environment(\.dismiss) private var dismiss
    @State private var type = 0
    @State private var amountInput = ""
    @State private var category = "帳單"
    @State private var selectedPlannedExpenseID: UUID?
    @State private var note = ""
    @State private var showsReview = false
    @State private var isConfirming = false
    @State private var confirmationID = UUID()

    var body: some View {
        NavigationStack {
            Form {
                Section("這次想留下哪一種紀錄？") {
                    Picker("類型", selection: $type) { Text("支出").tag(0); Text("收入").tag(1) }
                        .pickerStyle(.segmented)
                }
                Section(type == 0 ? "支出金額" : "收入金額") {
                    TextField("金額", text: $amountInput)
                        .keyboardType(.decimalPad)
                    TextField("類別", text: $category)
                }
                if type == 0 {
                    Section("固定預算") {
                        Picker("選擇現有固定預算", selection: $selectedPlannedExpenseID) {
                            Text("不使用固定預算").tag(nil as UUID?)
                            ForEach(setupStore.plannedExpenses) { expense in
                                Text("\(expense.name) · \(expense.amount.twdFormatted)")
                                    .tag(expense.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section("備註") {
                    TextField("新增備註（選填）", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Button("檢查後再記錄") { showsReview = true }
                        .buttonStyle(PayReviewPrimaryButtonStyle())
                        .disabled(amount <= 0 || category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .listRowBackground(Color.clear)
            }
            .onChange(of: selectedPlannedExpenseID) { _, id in
                guard let expense = setupStore.plannedExpenses.first(where: { $0.id == id }) else { return }
                category = expense.name
                amountInput = String(NSDecimalNumber(decimal: expense.amount).int64Value)
            }
            .navigationTitle(type == 0 ? "新增支出" : "新增收入")
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
                LabeledContent("類別", value: category)
                LabeledContent("日期", value: "今天")
            }
            if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("備註") { Text(note) }
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
        type == 0 ? "支出" : "收入"
    }

    private var amount: Decimal {
        Decimal(string: amountInput) ?? .zero
    }

    private func confirmRecord() {
        guard !isConfirming else { return }
        isConfirming = true
        let kind: PayReviewRecord.Kind = type == 0 ? .expense : .income
        let title = type == 0 ? category : "收入"
        let detail = type == 0 ? "\(category) · 已確認" : "收入 · 已確認"
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
                        Label("Firebase 雲端已確認", systemImage: "checkmark.circle.fill")
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
    let embedsNavigationStack: Bool
    @State private var showsPlus = false
    @State private var showsSignOut = false
    @State private var showsDelete = false
    @State private var showsIntroduction = false

    init(embedsNavigationStack: Bool = true) {
        self.embedsNavigationStack = embedsNavigationStack
    }

    var body: some View {
        Group {
            if embedsNavigationStack {
                NavigationStack { settingsContent }
            } else {
                settingsContent
            }
        }
    }

    private var settingsContent: some View {
        List {
            Section("帳號與安全") { LabeledContent("Apple ID", value: "已登入"); Label("Firebase 雲端已同步", systemImage: "checkmark.circle.fill") }
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
        .sheet(isPresented: $showsSignOut) { SafeSignOutView { showsSignOut = false } }
        .sheet(isPresented: $showsDelete) { AccountDeletionPrototypeView { showsDelete = false } }
        .fullScreenCover(isPresented: $showsIntroduction) {
            OnboardingFlowView {
                showsIntroduction = false
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
                    Label("重新驗證 Apple ID", systemImage: "person.badge.key")
                    Label("等待待同步紀錄，最多 30 秒", systemImage: "arrow.triangle.2.circlepath")
                    Label("建立安全刪除工作並清除本機資料", systemImage: "lock.shield")
                }
                Section {
                    Toggle("我了解刪除帳號不會自動取消 Apple 訂閱", isOn: $understandsSubscription)
                    Toggle("若仍有未同步變更，我會再次確認是否永久捨棄", isOn: $confirmsUnsyncedChanges)
                }
                Section {
                    Button("重新驗證並繼續", role: .destructive) { cancel() }
                        .disabled(!understandsSubscription || !confirmsUnsyncedChanges)
                    Button("先保留帳號", action: cancel)
                }
            }
            .navigationTitle("刪除帳號")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SafeSignOutView: View {
    let cancel: () -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                ActivationMascot(size: 112)
                Text("先讓紀錄安全到家，\n再跟這台裝置說再見").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text("還有 2 筆紀錄正在安全同步").font(.headline)
                Text("完成後就能登出。失敗時會保留目前帳號，不會丟棄紀錄").foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("繼續等待並安全登出", action: cancel).buttonStyle(PayReviewPrimaryButtonStyle())
                Button("取消登出", action: cancel).buttonStyle(.bordered)
                Text("等待上限 30 秒；可隨時取消").font(.footnote).foregroundStyle(.secondary)
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

#Preview { PayReviewMainFlowView(setupStore: SetupStore()) }
