import SwiftUI

struct AppRootView: View {
    @StateObject private var authentication = AuthenticationTestViewModel()
    @StateObject private var setupStore = SetupStore()
    @AppStorage("hasSeenPayReviewIntroduction") private var hasSeenIntroduction = false
    @AppStorage("hasCompletedPayReviewPersonalization") private var hasCompletedPersonalization = false
    @AppStorage("hasCompletedPayReviewSetup") private var hasCompletedSetup = false
    @State private var introductionStartsAtFinalPage = false
    @State private var startsAtSignIn = false

    var body: some View {
        Group {
            if !authentication.hasResolvedAuthentication {
                LaunchView()
            } else if authentication.authenticatedUser == nil {
                if hasSeenIntroduction {
                    UnauthenticatedActivationView(
                        viewModel: authentication,
                        initiallyShowsSignIn: startsAtSignIn,
                        replayIntroduction: {
                            introductionStartsAtFinalPage = true
                            startsAtSignIn = false
                            withAnimation(PayReviewMotion.easeOut(PayReviewMotion.navigation)) {
                                hasSeenIntroduction = false
                            }
                        }
                    )
                } else {
                    OnboardingFlowView(
                        startsAtFinalPage: introductionStartsAtFinalPage,
                        completion: {
                            introductionStartsAtFinalPage = false
                            startsAtSignIn = false
                            hasSeenIntroduction = true
                        },
                        skip: {
                            introductionStartsAtFinalPage = false
                            startsAtSignIn = true
                            withAnimation(.easeOut(duration: 0.25)) {
                                hasSeenIntroduction = true
                            }
                        }
                    )
                }
            } else {
                if !hasCompletedPersonalization {
                    PersonalizedActivationView(
                        store: setupStore,
                        backToSignIn: {
                            startsAtSignIn = true
                            authentication.signOut()
                        },
                        completion: {
                            hasCompletedPersonalization = true
                        }
                    )
                } else if !hasCompletedSetup {
                    SetupFlowView(store: setupStore) {
                        hasCompletedSetup = true
                    }
                } else {
                    PayReviewMainFlowView(setupStore: setupStore)
                }
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

#Preview {
    AppRootView()
}
