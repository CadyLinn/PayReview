import SwiftUI

struct TodayPresentationState {
    var safeToSpend: Decimal?
    var goalContribution: Decimal?

    static let insufficient = TodayPresentationState(safeToSpend: nil, goalContribution: nil)
    static let figmaFixture = TodayPresentationState(safeToSpend: 680, goalContribution: 140)
}

struct DailyExperienceView: View {
    let todayState: TodayPresentationState

    var body: some View {
        TabView {
            TodayLivingView(state: todayState)
                .tabItem { Label("今天", systemImage: "house") }
            PlanLivingView()
                .tabItem { Label("計畫", systemImage: "scope") }
            RecordsLivingView()
                .tabItem { Label("紀錄", systemImage: "list.bullet.rectangle") }
            SettingsLivingView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .tint(PayReviewTheme.primary)
    }
}

private struct TodayLivingView: View {
    let state: TodayPresentationState
    @State private var showsEvaluation = false
    @State private var checklist = [true, true, false]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()
                        Text("7/17 今天").font(.largeTitle.bold())
                        ActivationMascot(size: 72)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("今天約可安心花").font(.subheadline.weight(.medium))
                        Text(state.safeToSpend?.twdFormatted ?? "資料不足")
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                        Text(state.safeToSpend == nil ? "完成計畫計算後，這裡會顯示估算範圍" : "已預留生活支出與日本旅遊最低存款")
                            .font(.footnote)
                    }
                    .foregroundStyle(PayReviewTheme.subtle)
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
                    .background(PayReviewTheme.primary, in: RoundedRectangle(cornerRadius: 28))

                    Button("評估眼前的消費") { showsEvaluation = true }
                        .buttonStyle(PayReviewPrimaryButtonStyle())

                    VStack(alignment: .leading, spacing: 14) {
                        Text("今天的三件事").font(.title3.bold())
                        checklistRow(0, "確認必要支出", "已完成 · 輕震回饋")
                        checklistRow(1, "保留旅遊基金 \(state.goalContribution?.twdFormatted ?? "待計算")", "已完成 · 進度向前")
                        checklistRow(2, "消費前評估一次", "完成後蓋上今日印章")
                    }
                    .padding(18)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24))

                    HStack(spacing: 16) {
                        explorationCard("比價實驗室", "折扣真的\n比較划算嗎？", PayReviewTheme.cautionSurface)
                        explorationCard("本週故事", "看看紀錄\n帶來了什麼", PayReviewTheme.subtle)
                    }

                    SpeechBubble("今天不是追求完美，是知道下一步")
                        .frame(height: 56)
                }
                .padding(24)
            }
            .background(PayReviewTheme.surface.ignoresSafeArea())
            .sheet(isPresented: $showsEvaluation) {
                EvaluationInputView()
            }
        }
    }

    private func checklistRow(_ index: Int, _ title: String, _ subtitle: String) -> some View {
        Button {
            checklist[index].toggle()
        } label: {
            HStack(alignment: .top) {
                Image(systemName: checklist[index] ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checklist[index] ? PayReviewTheme.safe : PayReviewTheme.primary)
                VStack(alignment: .leading) {
                    Text(title).font(.subheadline.weight(.medium))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func explorationCard(_ title: String, _ body: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.bold()).foregroundStyle(PayReviewTheme.primary)
            Text(body).font(.headline).foregroundStyle(PayReviewTheme.primaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(color, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct EvaluationInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Decimal = 0
    @State private var category = "購物"
    @State private var showsResult = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("預計花費", value: $amount, format: .currency(code: "TWD"))
                        .keyboardType(.decimalPad)
                } header: {
                    Text("正在考慮花錢嗎？")
                } footer: {
                    Text("查看前不會改變預算")
                }

                Section("類別（選填）") {
                    Picker("類別", selection: $category) {
                        ForEach(["飲食", "購物", "娛樂", "其他"], id: \.self) { Text($0) }
                    }
                }

                Button("查看影響") { showsResult = true }
                    .disabled(amount <= 0)
            }
            .navigationTitle("消費前評估")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
            .alert("資料不足，尚未完成計算", isPresented: $showsResult) {
                Button("好", role: .cancel) {}
            } message: {
                Text("FinanceEngine 完成並取得最新計畫後，才會顯示預算與目標影響")
            }
        }
    }
}

private struct PlanLivingView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("目前計算假設") {
                    Label("收入週期", systemImage: "calendar")
                    Label("必要支出", systemImage: "checklist")
                    Label("彈性預算", systemImage: "slider.horizontal.3")
                    Label("安全緩衝", systemImage: "shield")
                    Label("目標", systemImage: "flag")
                }
            }
            .navigationTitle("計畫")
        }
    }
}

private struct RecordsLivingView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("新增支出") { ContentUnavailableView("新增支出", systemImage: "minus.circle") }
                    NavigationLink("新增收入") { ContentUnavailableView("新增收入", systemImage: "plus.circle") }
                    NavigationLink("新增轉帳") { ContentUnavailableView("新增轉帳", systemImage: "arrow.left.arrow.right") }
                }
                Section("最近活動") {
                    Text("正式紀錄會更新預算；試算本身不會")
                }
            }
            .navigationTitle("紀錄")
        }
    }
}

private struct SettingsLivingView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("帳號與資料") {
                    Label("登入帳號", systemImage: "person.crop.circle")
                    Label("匯出我的資料", systemImage: "square.and.arrow.up")
                    Label("刪除帳號", systemImage: "trash")
                }
                Section("訂閱") {
                    Label("管理試用與訂閱", systemImage: "creditcard")
                    Label("恢復購買", systemImage: "arrow.clockwise")
                }
            }
            .navigationTitle("設定")
        }
    }
}

#Preview("Today fixture") { DailyExperienceView(todayState: .figmaFixture) }
#Preview("Today live") { DailyExperienceView(todayState: .insufficient) }
