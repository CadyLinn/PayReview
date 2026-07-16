import AuthenticationServices
import SwiftUI

struct PayReviewSignInView: View {
    @ObservedObject var viewModel: AuthenticationTestViewModel
    let reviewIntroduction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("再次查看介紹", action: reviewIntroduction)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PayReviewTheme.primary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 18) {
                Image("PayReviewMascot")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                    .accessibilityLabel("PayReview 吉祥物")

                Text("付錢前，先看影響")
                    .font(.title.weight(.bold))
                    .foregroundStyle(PayReviewTheme.primaryText)

                Text("輸入眼前金額，也看見這筆錢會帶來什麼改變")
                    .font(.body)
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { request in
                    viewModel.configureAppleRequest(request)
                } onCompletion: { result in
                    Task { await viewModel.completeAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(viewModel.isWorking)

                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    Label("使用 Google 繼續", systemImage: "person.crop.circle")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(PayReviewTheme.primary)
                .disabled(viewModel.isWorking)

                Text("登入時不會要求通知或金融帳戶權限")
                    .font(.footnote)
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .overlay {
            if viewModel.isWorking {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView("正在安全登入")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .background(PayReviewTheme.background.ignoresSafeArea())
    }
}

#Preview {
    PayReviewSignInView(
        viewModel: AuthenticationTestViewModel(),
        reviewIntroduction: {}
    )
}
