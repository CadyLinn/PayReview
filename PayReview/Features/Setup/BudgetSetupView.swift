import SwiftUI

struct BudgetSetupView: View {
    @ObservedObject var store: SetupStore
    let continueAction: () -> Void
    @State private var sliderPosition: Double = 24

    var body: some View {
        Form {
            Section {
                SetupProgressHeader(completedSteps: 4)
                    .listRowBackground(Color.clear)

                VStack(alignment: .leading, spacing: 8) {
                    Text("想為每天保留多少選擇空間？")
                        .font(.title2.weight(.bold))
                    Text("這不是限制，而是替每天保留一個能安心調整的範圍")
                        .font(.subheadline)
                        .foregroundStyle(PayReviewTheme.secondaryText)
                }
                .listRowBackground(Color.clear)

                MascotSpeechView(
                    message: "先從讓你安心的數字開始就好",
                    avatarSize: 84,
                    avatarOnTrailingEdge: true
                )
                .listRowBackground(Color.clear)
            }

            Section("每週彈性預算") {
                Text(store.flexibleBudget.twdFormatted)
                    .font(.largeTitle.weight(.bold))
                    .frame(maxWidth: .infinity)

                Slider(value: $sliderPosition, in: 0...90, step: 1) {
                    Text("每週彈性預算")
                } minimumValueLabel: {
                    Text("保守")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("寬鬆")
                        .font(.caption)
                }
                .onChange(of: sliderPosition) { _, newValue in
                    store.updateFlexibleBudget(sliderPosition: newValue)
                }

                Text("往左更保守，往右多留一點彈性")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PayReviewTheme.primary)
                    .frame(maxWidth: .infinity)
            }

            Section {
                Button("完成我的設定", action: continueAction)
                    .buttonStyle(PayReviewPrimaryButtonStyle())

                Text("這只是起點，之後可以跟著生活慢慢調整")
                    .font(.footnote)
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
        .payReviewSetupBackground()
        .navigationTitle("彈性預算")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sliderPosition = store.flexibleBudgetSliderPosition
        }
    }
}
