import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

struct AuthenticatedUser: Equatable {
    let id: String
    let email: String?
}

protocol AuthenticationServicing {
    @discardableResult
    func observeAuthState(_ change: @escaping (AuthenticatedUser?) -> Void) -> AuthStateDidChangeListenerHandle
    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle)
    func createAccount(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signInWithGoogle() async throws
    func signOut() throws
}

enum AuthenticationServiceError: LocalizedError {
    case cancelled
    case missingGoogleClientID
    case missingGoogleIDToken
    case missingPresentationContext
    case invalidEmail
    case passwordTooShort

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .missingGoogleClientID:
            return "Google 登入設定不完整。"
        case .missingGoogleIDToken:
            return "Google 登入沒有回傳可用的識別資訊。"
        case .missingPresentationContext:
            return "無法顯示 Google 登入畫面。"
        case .invalidEmail:
            return "請輸入有效的 Email。"
        case .passwordTooShort:
            return "密碼至少需要 6 個字元。"
        }
    }
}

final class AuthenticationService: AuthenticationServicing {
    @discardableResult
    func observeAuthState(_ change: @escaping (AuthenticatedUser?) -> Void) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in
            change(user.map { AuthenticatedUser(id: $0.uid, email: $0.email) })
        }
    }

    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }

    func createAccount(email: String, password: String) async throws {
        let credentials = try validatedCredentials(email: email, password: password)
        _ = try await Auth.auth().createUser(
            withEmail: credentials.email,
            password: credentials.password
        )
    }

    func signIn(email: String, password: String) async throws {
        let credentials = try validatedCredentials(email: email, password: password)
        _ = try await Auth.auth().signIn(
            withEmail: credentials.email,
            password: credentials.password
        )
    }

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthenticationServiceError.missingGoogleClientID
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: try presentingViewController())
        } catch {
            guard (error as NSError).code == GIDSignInError.canceled.rawValue else { throw error }
            throw AuthenticationServiceError.cancelled
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthenticationServiceError.missingGoogleIDToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        _ = try await Auth.auth().signIn(with: credential)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    private func presentingViewController() throws -> UIViewController {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.keyWindow?.rootViewController else {
            throw AuthenticationServiceError.missingPresentationContext
        }
        return topViewController(from: rootViewController)
    }

    private func topViewController(from viewController: UIViewController) -> UIViewController {
        if let presentedViewController = viewController.presentedViewController {
            return topViewController(from: presentedViewController)
        }
        if let navigationController = viewController as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return topViewController(from: visibleViewController)
        }
        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return topViewController(from: selectedViewController)
        }
        return viewController
    }

    private func validatedCredentials(email: String, password: String) throws -> (email: String, password: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            throw AuthenticationServiceError.invalidEmail
        }
        guard password.count >= 6 else {
            throw AuthenticationServiceError.passwordTooShort
        }
        return (normalizedEmail, password)
    }
}
