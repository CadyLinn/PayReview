import SwiftUI

struct BuildingPlanView: View {
    @ObservedObject var store: SetupStore
    let completion: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCalculating = false
    @State private var isReady = false

    var body: some View {
        ZStack {
            PayReviewTheme.darkSurface.ignoresSafeArea()

            VStack(spacing: 28) {
                Text("正在建立自訂目標計畫")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PayReviewTheme.safe)

                ZStack {
                    Circle()
                        .stroke(PayReviewTheme.safe.opacity(0.35), lineWidth: 2)
                        .frame(width: 238, height: 238)

                    ProgressView()
                        .controlSize(.large)
                        .tint(PayReviewTheme.safe)
                        .scaleEffect(2.2)

                    Image("PayReviewMascot")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 154, height: 154)
                        .clipShape(Circle())
                        .scaleEffect(isCalculating && !reduceMotion ? 1.03 : 1)
                }

                VStack(spacing: 10) {
                    Text("正在把自訂目標，變成今天能做到的步驟")
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text("收入、固定支出與彈性預算會由計算引擎整理\n你的真實預算尚未被改變")
                        .foregroundStyle(PayReviewTheme.safe)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("已整理目標與日期", systemImage: "checkmark")
                    Label("已預留必要支出", systemImage: "checkmark")
                    Label("正在計算今天可用範圍", systemImage: "circle.fill")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(PayReviewTheme.safe)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PayReviewTheme.darkRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                if isReady {
                    Button("查看完整功能", action: completion)
                        .buttonStyle(PayReviewPrimaryButtonStyle())
                        .transition(.opacity.combined(with: .scale))
                } else {
                    Text("計畫建立完成後，會從第一筆消費試算開始")
                        .font(.footnote)
                        .foregroundStyle(PayReviewTheme.safe.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isCalculating = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isReady = true
                }
            }
        }
    }
}
