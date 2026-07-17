import SwiftUI

struct SetupCompleteView: View {
    @ObservedObject var store: SetupStore
    let continueAction: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealsCelebration = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("設定完成")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PayReviewTheme.primary)

                celebration

                VStack(spacing: 8) {
                    Text("你的自訂目標已準備好出發")
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("接下來會把收入、支出與預算整理成今天能做到的步驟")
                        .font(.body)
                        .foregroundStyle(PayReviewTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                summary

                Text("設定都收好了，現在一起看看第一步")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(PayReviewTheme.primaryText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

                Button("建立我的自訂目標計畫", action: continueAction)
                    .buttonStyle(PayReviewPrimaryButtonStyle())

                Text("今天先到這裡就很好，之後我們再一起調整")
                    .font(.footnote)
                    .foregroundStyle(PayReviewTheme.secondaryText)
            }
            .padding()
        }
        .background(PayReviewTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if reduceMotion {
                revealsCelebration = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    revealsCelebration = true
                }
            }
        }
    }

    private var celebration: some View {
        ZStack {
            CelebrationBurst(style: .fireworks, particleCount: 40)
                .frame(width: 310, height: 210)

            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? PayReviewTheme.safe : Color.orange)
                    .frame(width: CGFloat(5 + index % 3 * 2))
                    .offset(
                        x: cos(Double(index) * .pi / 6) * 104,
                        y: sin(Double(index) * .pi / 6) * 104
                    )
                    .opacity(revealsCelebration ? 1 : 0)
                    .scaleEffect(revealsCelebration ? 1 : 0.2)
            }

            Image("PayReviewMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 160)
                .clipShape(Circle())
                .scaleEffect(revealsCelebration ? 1 : 0.92)
                .modifier(PayReviewFloatingEffect())
        }
        .frame(height: 210)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PayReview 吉祥物與設定完成裝飾")
    }

    private var summary: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 20) {
            GridRow {
                summaryValue("自訂目標", store.goalName)
                summaryValue("固定支出", "\(store.plannedExpenses.count) 個項目")
            }
            GridRow {
                summaryValue("每週彈性預算", store.flexibleBudget.twdFormatted)
                    .gridCellColumns(2)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PayReviewTheme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func summaryValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(PayReviewTheme.secondaryText)
            Text(value)
                .font(.headline)
                .foregroundStyle(PayReviewTheme.primaryText)
        }
    }
}
