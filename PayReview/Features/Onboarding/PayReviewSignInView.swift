import SwiftUI

enum AuthenticationIntent {
    case createAccount
    case signIn
}

struct PayReviewSignInView: View {
    @ObservedObject var viewModel: AuthenticationTestViewModel
    let intent: AuthenticationIntent
    let backAction: () -> Void
    @State private var isPresented = false
    @State private var showsEmailFields = false
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            ActivationDesignCanvas {
                ZStack(alignment: .topLeading) {
                    PayReviewTheme.surface

                    ActivationMascot(size: 104)
                        .position(x: 76, y: 94)
                        .modifier(PayReviewFloatingEffect())
                        .payReviewDepthReveal(isActive: isPresented, delay: 0.06)

                    SpeechBubble("先把計畫安全留下來，\n之後才能在裝置間繼續")
                        .frame(width: 220, height: 58)
                        .position(x: 226, y: 87)
                        .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.20)

                Text(intent == .createAccount ? "建立帳號後，開始設定你的計畫" : "登入並繼續你的用錢計畫")
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

                if showsEmailFields {
                    TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
                    .payReviewCredentialField()
                    .position(x: 196.5, y: 492)
                        .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.04, distance: 50)

                    SecureField("密碼（至少 6 個字元）", text: $password)
                    .textContentType(intent == .createAccount ? .newPassword : .password)
                    .submitLabel(intent == .createAccount ? .continue : .go)
                    .focused($focusedField, equals: .password)
                    .onSubmit(submitEmailAuthentication)
                    .payReviewCredentialField()
                    .position(x: 196.5, y: 550)
                        .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.08, distance: 50)

                    Button(action: submitEmailAuthentication) {
                        Text(intent == .createAccount ? "使用 Email 建立帳號" : "使用 Email 登入")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(PayReviewTheme.surface)
                            .frame(width: 345, height: 48)
                            .background(PayReviewTheme.primary, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(viewModel.isWorking)
                    .position(x: 196.5, y: 608)

                    Button("返回其他登入方式") {
                        focusedField = nil
                        showsEmailFields = false
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PayReviewTheme.primary)
                    .frame(width: 345, height: 44)
                    .position(x: 196.5, y: 670)
                } else {
                    Button {
                        Task { await viewModel.signInWithGoogle() }
                    } label: {
                        Text(intent == .createAccount ? "使用 Google 建立帳號" : "使用 Google 登入")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(PayReviewTheme.surface)
                            .frame(width: 345, height: 48)
                            .background(PayReviewTheme.primary, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(viewModel.isWorking)
                    .position(x: 196.5, y: 544)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.48, distance: 110)

                    Button {
                        showsEmailFields = true
                        focusedField = .email
                    } label: {
                        Text(intent == .createAccount ? "使用 Email 建立帳號" : "使用 Email 登入")
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
                    .position(x: 196.5, y: 606)
                    .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.54, distance: 110)
                }

                Text("隱私權政策　·　使用條款　·　登入問題")
                    .font(.system(size: 13))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345)
                    .position(x: 196.5, y: 730)
                    .payReviewSlideReveal(isActive: isPresented, edge: .bottom, delay: 0.62, distance: 24)

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: backAction) {
                        Label("返回介紹", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(intent == .createAccount ? "安全建立帳號" : "安全登入")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PayReviewTheme.primary)
                }
            }
        }
        .tint(PayReviewTheme.primary)
        .onAppear { isPresented = true }
        .onDisappear { isPresented = false }
    }

    private func submitEmailAuthentication() {
        focusedField = nil
        Task {
            if intent == .createAccount {
                await viewModel.createAccount(email: email, password: password)
            } else {
                await viewModel.signIn(email: email, password: password)
            }
        }
    }
}

private extension View {
    func payReviewCredentialField() -> some View {
        font(.system(size: 16))
            .foregroundStyle(PayReviewTheme.primaryText)
            .padding(.horizontal, 16)
            .frame(width: 345, height: 48)
            .background(PayReviewTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 203 / 255, green: 221 / 255, blue: 211 / 255), lineWidth: 1)
            }
    }
}

#Preview {
    PayReviewSignInView(
        viewModel: AuthenticationTestViewModel(),
        intent: .signIn,
        backAction: {}
    )
}
