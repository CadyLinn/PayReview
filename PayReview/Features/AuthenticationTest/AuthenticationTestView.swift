import SwiftUI

struct AuthenticationTestView: View {
    @StateObject private var viewModel = AuthenticationTestViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let user = viewModel.authenticatedUser {
                    signedInView(user: user)
                } else {
                    signInView
                }
            }
            .navigationTitle("PayReview")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
        .alert("登入問題", isPresented: errorBinding) {
            Button("好", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("通知", isPresented: noticeBinding) {
            Button("好", role: .cancel) {
                viewModel.notice = nil
            }
        } message: {
            Text(viewModel.notice ?? "")
        }
    }

    private var signInView: some View {
        Form {
            Section {
                Button("使用 Google 登入") {
                    Task {
                        await viewModel.signInWithGoogle()
                    }
                }
                .disabled(viewModel.isWorking)
            }

            Section("使用 Email") {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                SecureField("密碼", text: $viewModel.password)
                    .textContentType(.password)

                Button("登入") {
                    Task {
                        await viewModel.signInWithEmail()
                    }
                }
                .disabled(viewModel.isWorking)

                Button("建立帳號") {
                    Task {
                        await viewModel.createAccount()
                    }
                }
                .disabled(viewModel.isWorking)

                Button("寄送重設密碼信") {
                    Task {
                        await viewModel.resetPassword()
                    }
                }
                .disabled(viewModel.isWorking)
            }
        }
        .overlay {
            if viewModel.isWorking {
                ProgressView()
            }
        }
    }

    private func signedInView(user: AuthenticatedUser) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("已登入")
                .font(.title2.weight(.semibold))
            Text(user.email ?? "此帳號未提供 Email")
                .foregroundStyle(.secondary)
            if viewModel.isPreparingAccount {
                ProgressView("正在確認帳號狀態")
            } else if viewModel.isAccountReady {
                NavigationLink("開始建立計畫") {
                    SetupFlowView()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("查看資料測試") {
                    FirestoreTestView()
                }
            } else {
                Text("帳號狀態尚未確認，無法存取財務資料。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("重新確認帳號狀態") {
                    Task {
                        await viewModel.prepareAccountState()
                    }
                }
            }
            Button("登出", role: .destructive) {
                viewModel.signOut()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var noticeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.notice != nil },
            set: { if !$0 { viewModel.notice = nil } }
        )
    }
}

#Preview {
    AuthenticationTestView()
}
