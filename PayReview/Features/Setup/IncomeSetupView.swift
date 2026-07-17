import SwiftUI

struct IncomeSetupView: View {
    @ObservedObject var store: SetupStore
    let continueAction: () -> Void

    var body: some View {
        Form {
            Section {
                SetupProgressHeader(completedSteps: 2)
                    .listRowBackground(Color.clear)

                VStack(alignment: .leading, spacing: 8) {
                    Text("先放一個最接近生活的收入節奏")
                        .font(.title2.weight(.bold))
                    Text("不用精準到每一天，這只是幫計畫找到開始計算的位置")
                        .font(.subheadline)
                        .foregroundStyle(PayReviewTheme.secondaryText)
                }
                .listRowBackground(Color.clear)

                MascotSpeechView(message: "收入不固定也沒關係，先選最接近的方式")
                    .listRowBackground(Color.clear)
            }

            Section("收入週期") {
                Picker("收入週期", selection: $store.incomeCadence) {
                    ForEach(IncomeCadence.allCases) { cadence in
                        Text(cadence.rawValue).tag(cadence)
                    }
                }

                DatePicker(
                    "下一次收入日",
                    selection: $store.nextIncomeDate,
                    displayedComponents: .date
                )
            }

            Section("每期可用收入") {
                TextField(
                    "收入金額",
                    value: $store.availableIncome,
                    format: .payReviewTWD
                )
                .font(.title2.weight(.bold))
                .keyboardType(.numberPad)

                Stepper("每次調整 NT$500") {
                    store.adjustIncome(by: 500)
                } onDecrement: {
                    store.adjustIncome(by: -500)
                }
            }

            Section {
                Button("儲存收入，繼續", action: continueAction)
                    .buttonStyle(PayReviewPrimaryButtonStyle())

                Text("今天先填到這裡就很好，之後想起來再補")
                    .font(.footnote)
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
        .payReviewSetupBackground()
        .navigationTitle("收入")
        .navigationBarTitleDisplayMode(.inline)
    }
}
