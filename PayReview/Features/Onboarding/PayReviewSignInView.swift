import AuthenticationServices
import SwiftUI

struct PayReviewSignInView: View {
    @ObservedObject var viewModel: AuthenticationTestViewModel

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 393, proxy.size.height / 852)

            ZStack(alignment: .topLeading) {
                PayReviewTheme.background

                Image("PayReviewSignInMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 78)
                    .position(x: 196.5, y: 131)
                    .accessibilityLabel("PayReview")

                Text("付錢前，先看影響")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PayReviewTheme.primaryText)
                    .frame(width: 320)
                    .position(x: 196.5, y: 210)

                Text("輸入眼前金額，也看見這筆錢會帶來什麼改變")
                    .font(.system(size: 17))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(width: 320)
                    .position(x: 196.5, y: 266)

                SignInWithAppleButton(.continue) { request in
                    viewModel.configureAppleRequest(request)
                } onCompletion: { result in
                    Task { await viewModel.completeAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(width: 345, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(viewModel.isWorking)
                .position(x: 196.5, y: 698)

                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    Text("使用 Google 繼續")
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
                .position(x: 196.5, y: 758)

                Text("登入時不會要求通知或金融帳戶權限")
                    .font(.system(size: 13))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345)
                    .position(x: 196.5, y: 803)

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
            .frame(width: 393, height: 852)
            .scaleEffect(scale)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .ignoresSafeArea()
        .background(PayReviewTheme.background.ignoresSafeArea())
    }
}

#Preview {
    PayReviewSignInView(viewModel: AuthenticationTestViewModel())
}
