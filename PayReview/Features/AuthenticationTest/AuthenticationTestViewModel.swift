import Combine
import AuthenticationServices
import FirebaseAuth
import Foundation

@MainActor
final class AuthenticationTestViewModel: ObservableObject {
    @Published private(set) var authenticatedUser: AuthenticatedUser?
    @Published var notice: String?
    @Published var errorMessage: String?
    @Published private(set) var isWorking = false
    @Published private(set) var isPreparingAccount = false
    @Published private(set) var isAccountReady = false
    @Published private(set) var hasResolvedAuthentication = false

    private let authenticationService: AuthenticationServicing
    private let accountStateService: AccountStateServicing
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authenticationService = AuthenticationService()
        accountStateService = AccountStateService()
    }

    init(
        authenticationService: AuthenticationServicing,
        accountStateService: AccountStateServicing
    ) {
        self.authenticationService = authenticationService
        self.accountStateService = accountStateService
    }

    func stopObserving() {
        if let authStateHandle {
            authenticationService.removeAuthStateListener(authStateHandle)
            self.authStateHandle = nil
        }
    }

    func startObserving() {
        guard authStateHandle == nil else { return }
        authStateHandle = authenticationService.observeAuthState { [weak self] user in
            Task { @MainActor in
                self?.authenticatedUser = user
                self?.isAccountReady = false
                self?.hasResolvedAuthentication = true

                if user != nil {
                    await self?.prepareAccountState()
                }
            }
        }
    }

    func signInWithGoogle() async {
        await perform({ [authenticationService] in
            try await authenticationService.signInWithGoogle()
        })
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            try authenticationService.configureAppleRequest(request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        await perform {
            try await self.authenticationService.completeAppleSignIn(result)
        }
    }

    func signOut() {
        do {
            try authenticationService.signOut()
            isAccountReady = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareAccountState() async {
        guard authenticatedUser != nil, !isPreparingAccount else { return }

        isPreparingAccount = true
        errorMessage = nil
        defer { isPreparingAccount = false }

        do {
            try await accountStateService.ensureActiveAccountState()
            isAccountReady = true
        } catch {
            isAccountReady = false
            errorMessage = error.localizedDescription
        }
    }

    private func perform(
        _ action: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil
    ) async {
        isWorking = true
        notice = nil
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await action()
            onSuccess?()
        } catch AuthenticationServiceError.cancelled {
            notice = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
