import SwiftUI

struct PayReviewSignInView: View {
    @ObservedObject var viewModel: AuthenticationTestViewModel
    let backAction: () -> Void
    @State private var isPresented = false

    var body: some View {
        ActivationDesignCanvas {
            ZStack(alignment: .topLeading) {
                PayReviewTheme.surface

                ActivationBackButton(action: backAction)
                    .position(x: 46, y: 64)
                    .accessibilityLabel("返回介紹")
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.02, distance: 32)

                Text("安全登入")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PayReviewTheme.primary)
                    .position(x: 118, y: 66)
                    .payReviewSlideReveal(isActive: isPresented, edge: .bottom, delay: 0.04, distance: 18)

                ActivationMascot(size: 104)
                    .position(x: 76, y: 134)
                    .modifier(PayReviewFloatingEffect())
                    .payReviewDepthReveal(isActive: isPresented, delay: 0.06)

                SpeechBubble("先把計畫安全留下來，\n之後才能在裝置間繼續")
                    .frame(width: 220, height: 58)
                    .position(x: 226, y: 127)
                    .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.20)

                Text("登入後，開始建立你的計畫")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PayReviewTheme.primaryText)
                    .frame(width: 345, alignment: .leading)
                    .position(x: 196.5, y: 242)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.28)

                Text("你的目標、設定與確認過的紀錄，會安全同步到 Firebase 雲端資料庫")
                    .font(.system(size: 16))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345, alignment: .leading)
                    .position(x: 196.5, y: 292)
                    .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.34)

                VStack(alignment: .leading, spacing: 8) {
                    Label("不要求銀行帳戶", systemImage: "checkmark")
                    Label("不要求通知、相簿或位置權限", systemImage: "checkmark")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PayReviewTheme.primaryText)
                .padding(.horizontal, 18)
                .frame(width: 345, height: 106, alignment: .leading)
                .background(PayReviewTheme.subtle, in: RoundedRectangle(cornerRadius: 20))
                .position(x: 196.5, y: 383)
                .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.40)

                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    Text("使用 Google 登入")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PayReviewTheme.primary)
                        .frame(width: 343, height: 46)
                }
                .background(PayReviewTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 203 / 255, green: 221 / 255, blue: 211 / 255), lineWidth: 1)
                }
                .disabled(viewModel.isWorking)
                .position(x: 196.5, y: 544)
                .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.48, distance: 110)

                Text("隱私權政策　·　使用條款　·　登入問題")
                    .font(.system(size: 13))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345)
                    .position(x: 196.5, y: 616)
                    .payReviewSlideReveal(isActive: isPresented, edge: .bottom, delay: 0.54, distance: 24)

                if viewModel.isWorking {
                    ZStack {
                        Color.black.opacity(0.12)
                        ProgressView("正在安全登入")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .frame(width: 393, height: 852)
                }
            }
        }
        .onAppear { isPresented = true }
        .onDisappear { isPresented = false }
    }
}

#Preview {
    PayReviewSignInView(
        viewModel: AuthenticationTestViewModel(),
        backAction: {}
    )
}
