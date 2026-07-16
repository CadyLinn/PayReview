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
    func signInWithGoogle() async throws
    func signIn(email: String, password: String) async throws
    func createAccount(email: String, password: String) async throws
    func sendPasswordReset(to email: String) async throws
    func signOut() throws
}

enum AuthenticationServiceError: LocalizedError {
    case missingGoogleClientID
    case missingGoogleIDToken
    case missingPresentationContext

    var errorDescription: String? {
        switch self {
        case .missingGoogleClientID:
            return "Google 登入設定不完整。"
        case .missingGoogleIDToken:
            return "Google 登入沒有回傳可用的識別資訊。"
        case .missingPresentationContext:
            return "無法顯示 Google 登入畫面。"
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

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthenticationServiceError.missingGoogleClientID
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: try presentingViewController())

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthenticationServiceError.missingGoogleIDToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        _ = try await Auth.auth().signIn(with: credential)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func createAccount(email: String, password: String) async throws {
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func sendPasswordReset(to email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
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
}
