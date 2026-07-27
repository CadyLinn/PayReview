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

                #if DEBUG
                // 開發用途：完全略過登入畫面。只有在裝置上完全沒有 persisted session
                // （首次啟動、清過模擬器、或明確 signOut 過）時才會觸發一次；
                // 一旦成功登入（含匿名），這個 uid 會被 Firebase 持久化，之後重跑不會再進這裡。
                // 這段程式碼在 Release build 不會被編譯進去，正式登入按鈕完全不受影響。
                if user == nil {
                    await self?.signInAnonymouslyForDevelopment()
                }
                #endif
            }
        }
    }

    #if DEBUG
    private func signInAnonymouslyForDevelopment() async {
        guard authenticatedUser == nil else { return }
        do {
            try await authenticationService.signInAnonymously()
        } catch {
            errorMessage = "開發用匿名登入失敗：\(error.localizedDescription)"
        }
    }
    #endif

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
