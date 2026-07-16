import SwiftUI

struct GoalSetupView: View {
    @ObservedObject var store: SetupStore
    let continueAction: () -> Void

    var body: some View {
        Form {
            Section {
                SetupProgressHeader(completedSteps: 1)
                    .listRowBackground(Color.clear)

                VStack(alignment: .leading, spacing: 8) {
                    Text("想先為哪件事留一個位置？")
                        .font(.title2.weight(.bold))
                    Text("先選一個想前往的方向就好，每個數字之後都能再調整")
                        .font(.subheadline)
                        .foregroundStyle(PayReviewTheme.secondaryText)
                }
                .listRowBackground(Color.clear)

                MascotSpeechView(message: "先選一個方向，之後都能再調整")
                    .listRowBackground(Color.clear)
            }

            Section("目標內容") {
                TextField("目標名稱", text: $store.goalName)

                TextField(
                    "目標金額",
                    value: $store.goalAmount,
                    format: .currency(code: "TWD")
                )
                .keyboardType(.decimalPad)

                TextField(
                    "目前已存",
                    value: $store.savedAmount,
                    format: .currency(code: "TWD")
                )
                .keyboardType(.decimalPad)

                DatePicker(
                    "目標完成日期",
                    selection: $store.targetDate,
                    displayedComponents: .date
                )
            }

            Section {
                Button("用這個目標建立計畫", action: continueAction)
                    .buttonStyle(PayReviewPrimaryButtonStyle())
            }
            .listRowBackground(Color.clear)
        }
        .payReviewSetupBackground()
        .navigationTitle("目標")
        .navigationBarTitleDisplayMode(.inline)
    }
}
