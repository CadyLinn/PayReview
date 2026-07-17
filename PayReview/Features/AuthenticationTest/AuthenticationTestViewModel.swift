import Combine
import FirebaseAuth
import Foundation

@MainActor
final class AuthenticationTestViewModel: ObservableObject {
    @Published private(set) var authenticatedUser: AuthenticatedUser?
    @Published var notice: String?
    @Published var errorMessage: String?
    @Published private(set) var isWorking = false
    @Published private(set) var hasResolvedAuthentication = false

    private let authenticationService: AuthenticationServicing
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authenticationService = AuthenticationService()
    }

    init(authenticationService: AuthenticationServicing) {
        self.authenticationService = authenticationService
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
                self?.hasResolvedAuthentication = true
            }
        }
    }

    func signInWithGoogle() async {
        await perform({ [authenticationService] in
            try await authenticationService.signInWithGoogle()
        })
    }

    func createAccount(email: String, password: String) async {
        await perform { [authenticationService] in
            try await authenticationService.createAccount(email: email, password: password)
        }
    }

    func signIn(email: String, password: String) async {
        await perform { [authenticationService] in
            try await authenticationService.signIn(email: email, password: password)
        }
    }

    func signOut() {
        do {
            try authenticationService.signOut()
        } catch {
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
