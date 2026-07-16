import SwiftUI

struct AppRootView: View {
    @StateObject private var authentication = AuthenticationTestViewModel()
    @StateObject private var setupStore = SetupStore()
    @AppStorage("hasSeenPayReviewIntroduction") private var hasSeenIntroduction = false
    @AppStorage("hasCompletedPayReviewPersonalization") private var hasCompletedPersonalization = false
    @AppStorage("hasCompletedPayReviewSetup") private var hasCompletedSetup = false

    var body: some View {
        Group {
            if !authentication.hasResolvedAuthentication {
                LaunchView()
            } else if authentication.authenticatedUser == nil {
                if hasSeenIntroduction {
                    UnauthenticatedActivationView(viewModel: authentication)
                } else {
                    OnboardingFlowView {
                        hasSeenIntroduction = true
                    }
                }
            } else if authentication.isPreparingAccount {
                AccountPreparationView()
            } else if authentication.isAccountReady {
                if !hasCompletedPersonalization {
                    PersonalizedActivationView(store: setupStore) {
                        hasCompletedPersonalization = true
                    }
                } else if !hasCompletedSetup {
                    SetupFlowView(store: setupStore) {
                        hasCompletedSetup = true
                    }
                } else {
                    TrialEligibilityView()
                }
            } else {
                AccountRecoveryView(viewModel: authentication)
            }
        }
        .task {
            authentication.startObserving()
        }
        .alert("登入問題", isPresented: errorBinding) {
            Button("好", role: .cancel) {
                authentication.errorMessage = nil
            }
        } message: {
            Text(authentication.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { authentication.errorMessage != nil },
            set: { if !$0 { authentication.errorMessage = nil } }
        )
    }
}

private struct LaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        ZStack {
            PayReviewTheme.background.ignoresSafeArea()
            Image("PayReviewMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 132, height: 132)
                .clipShape(Circle())
                .scaleEffect(isVisible ? 1 : 0.92)
                .opacity(isVisible ? 1 : 0.7)
                .accessibilityLabel("PayReview")
        }
        .onAppear {
            guard !reduceMotion else {
                isVisible = true
                return
            }
            withAnimation(.easeOut(duration: 0.6)) {
                isVisible = true
            }
        }
    }
}

private struct AccountPreparationView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image("PayReviewMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
            ProgressView("正在準備你的 PayReview")
                .tint(PayReviewTheme.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PayReviewTheme.background.ignoresSafeArea())
    }
}

private struct AccountRecoveryView: View {
    @ObservedObject var viewModel: AuthenticationTestViewModel

    var body: some View {
        ContentUnavailableView {
            Label("帳號狀態尚未確認", systemImage: "arrow.triangle.2.circlepath")
        } description: {
            Text("連線恢復後可以再試一次，不會改變你的財務資料")
        } actions: {
            Button("重新確認") {
                Task { await viewModel.prepareAccountState() }
            }
            .buttonStyle(.borderedProminent)

            Button("登出", role: .destructive) {
                viewModel.signOut()
            }
        }
    }
}

#Preview {
    AppRootView()
}
