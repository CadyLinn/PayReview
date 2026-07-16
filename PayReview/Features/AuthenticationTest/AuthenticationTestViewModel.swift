import Combine
import FirebaseAuth
import Foundation

@MainActor
final class AuthenticationTestViewModel: ObservableObject {
    @Published private(set) var authenticatedUser: AuthenticatedUser?
    @Published var email = ""
    @Published var password = ""
    @Published var notice: String?
    @Published var errorMessage: String?
    @Published private(set) var isWorking = false
    @Published private(set) var isPreparingAccount = false
    @Published private(set) var isAccountReady = false

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

                if user != nil {
                    await self?.prepareAccountState()
                }
            }
        }
    }

    func signInWithGoogle() async {
        await perform({ [authenticationService] in
            try await authenticationService.signInWithGoogle()
        }, requiresEmail: false)
    }

    func signInWithEmail() async {
        await perform { [authenticationService, email, password] in
            try await authenticationService.signIn(email: email, password: password)
        }
    }

    func createAccount() async {
        await perform { [authenticationService, email, password] in
            try await authenticationService.createAccount(email: email, password: password)
        }
    }

    func resetPassword() async {
        let email = email
        await perform { [authenticationService] in
            try await authenticationService.sendPasswordReset(to: email)
        } onSuccess: {
            self.notice = "重設密碼信已寄出。"
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
        requiresEmail: Bool = true,
        onSuccess: (() -> Void)? = nil
    ) async {
        guard !requiresEmail || !email.isEmpty else {
            errorMessage = "請先輸入 Email。"
            return
        }

        isWorking = true
        notice = nil
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await action()
            onSuccess?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
