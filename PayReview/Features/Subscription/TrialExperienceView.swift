import SwiftUI

struct TrialEligibilityView: View {
    @State private var showsUnavailable = false

    var body: some View {
        ActivationDesignCanvas {
            ZStack(alignment: .topLeading) {
                PayReviewTheme.background

                Text("符合資格的年費方案")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345)
                    .position(x: 196.5, y: 44)

                ActivationMascot(size: 112)
                    .position(x: 196.5, y: 132)

                Text("免費試用期間，\n完整功能都為你開啟")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(PayReviewTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .frame(width: 345)
                    .position(x: 196.5, y: 250)

                Text("先實際使用消費評估、比價、記帳與每週摘要，\n再決定是否繼續")
                    .font(.system(size: 15))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(width: 317)
                    .position(x: 196.5, y: 320)

                VStack(alignment: .leading, spacing: 17) {
                    Text("試用期間解鎖")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PayReviewTheme.safe)
                    Label("無限消費情境與恢復方案", systemImage: "checkmark")
                    Label("折扣與機會成本比較", systemImage: "checkmark")
                    Label("收入、支出、轉帳與完整紀錄", systemImage: "checkmark")
                    Label("LLM 每週摘要與下週 Checklist", systemImage: "checkmark")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PayReviewTheme.surface)
                .padding(18)
                .frame(width: 345, height: 214, alignment: .topLeading)
                .background(PayReviewTheme.darkRaised, in: RoundedRectangle(cornerRadius: 26))
                .position(x: 196.5, y: 487)

                ActivationButton("開始 7 天免費試用") {
                    showsUnavailable = true
                }
                .position(x: 196.5, y: 648)

                Text("今天不收費\n若未取消，試用結束後依 App Store 顯示的年費自動續訂")
                    .font(.system(size: 12))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(width: 345)
                    .position(x: 196.5, y: 710)

                Text("試用結束與首次收費日期：由 App Store 顯示")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345)
                    .position(x: 196.5, y: 746)

                Text("恢復購買　·　使用條款　·　隱私權政策")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345)
                    .position(x: 196.5, y: 798)
            }
        }
        .alert("尚未連接 App Store 方案", isPresented: $showsUnavailable) {
            Button("好", role: .cancel) {}
        } message: {
            Text("加入核准的 Product ID 後，這裡會顯示你的試用資格、價格與首次收費日期")
        }
    }
}

struct AllFeaturesUnlockedView: View {
    let continueAction: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrates = false

    var body: some View {
        ActivationDesignCanvas {
            ZStack(alignment: .topLeading) {
                PayReviewTheme.background

                ForEach(0..<16, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 2) ? PayReviewTheme.safe : PayReviewTheme.cautionSurface)
                        .frame(width: CGFloat(6 + index % 3 * 3), height: CGFloat(6 + index % 3 * 3))
                        .position(
                            x: CGFloat(35 + (index * 53) % 325),
                            y: CGFloat(55 + (index * 79) % 290)
                        )
                        .opacity(celebrates ? 1 : 0)
                }

                Circle().fill(PayReviewTheme.safe).frame(width: 224, height: 224).position(x: 196.5, y: 204)
                ActivationMascot(size: 160).position(x: 196.5, y: 204)

                Text("完整體驗已解鎖")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(PayReviewTheme.primaryText)
                    .frame(width: 345)
                    .position(x: 196.5, y: 370)
                Text("接下來的每筆正式紀錄，都能更新你的預算、目標與下一次評估")
                    .font(.system(size: 15))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(width: 317)
                    .position(x: 196.5, y: 420)

                VStack(alignment: .leading, spacing: 5) {
                    Text("PLUS 免費試用中").font(.system(size: 13, weight: .bold)).foregroundStyle(PayReviewTheme.safe)
                    Text("全部功能已開啟").font(.system(size: 17, weight: .bold)).foregroundStyle(PayReviewTheme.surface)
                }
                .padding(.horizontal, 18)
                .frame(width: 345, height: 72, alignment: .leading)
                .background(PayReviewTheme.darkRaised, in: RoundedRectangle(cornerRadius: 22))
                .position(x: 196.5, y: 522)

                HStack(spacing: 12) {
                    unlockedAction("消費前評估", PayReviewTheme.cautionSurface)
                    unlockedAction("比價實驗室", PayReviewTheme.subtle)
                    unlockedAction("看今天", PayReviewTheme.darkRaised, dark: true)
                }
                .position(x: 192, y: 619)

                ActivationButton("先記錄第一筆", action: continueAction)
                    .position(x: 196.5, y: 712)
                Text("試用狀態與管理入口會持續顯示在設定中")
                    .font(.system(size: 12))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345)
                    .position(x: 196.5, y: 768)
            }
        }
        .onAppear {
            if reduceMotion {
                celebrates = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { celebrates = true }
            }
        }
    }

    private func unlockedAction(_ title: String, _ color: Color, dark: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(dark ? PayReviewTheme.surface : PayReviewTheme.primaryText)
            .frame(width: 104, height: 70)
            .background(color, in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview("Trial") { TrialEligibilityView() }
#Preview("Unlocked") { AllFeaturesUnlockedView(continueAction: {}) }
