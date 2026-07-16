import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Security
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
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) throws
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async throws
    func signOut() throws
}

enum AuthenticationServiceError: LocalizedError {
    case cancelled
    case missingGoogleClientID
    case missingGoogleIDToken
    case missingPresentationContext
    case nonceGenerationFailed
    case appleAuthorizationUnavailable
    case missingAppleNonce
    case missingAppleCredential
    case missingAppleIDToken
    case invalidAppleIDToken

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
        case .nonceGenerationFailed:
            return "無法安全地開始 Apple 登入，請再試一次。"
        case .appleAuthorizationUnavailable:
            return "Apple 登入目前無法啟動，請確認裝置的 Apple ID 與網路狀態後再試一次。"
        case .missingAppleNonce, .missingAppleCredential:
            return "Apple 登入狀態無法驗證，請再試一次。"
        case .missingAppleIDToken, .invalidAppleIDToken:
            return "Apple 登入沒有回傳可用的識別資訊。"
        }
    }
}

final class AuthenticationService: AuthenticationServicing {
    private var currentAppleNonce: String?

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

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) throws {
        let nonce = try randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async throws {
        let authorization: ASAuthorization
        do {
            authorization = try result.get()
        } catch let error as ASAuthorizationError where error.code == .canceled {
            currentAppleNonce = nil
            throw AuthenticationServiceError.cancelled
        } catch is ASAuthorizationError {
            currentAppleNonce = nil
            throw AuthenticationServiceError.appleAuthorizationUnavailable
        }
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthenticationServiceError.missingAppleCredential
        }
        guard let nonce = currentAppleNonce else {
            throw AuthenticationServiceError.missingAppleNonce
        }
        currentAppleNonce = nil
        guard let tokenData = appleCredential.identityToken else {
            throw AuthenticationServiceError.missingAppleIDToken
        }
        guard let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthenticationServiceError.invalidAppleIDToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
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

    private func randomNonceString(length: Int = 32) throws -> String {
        guard length > 0 else {
            throw AuthenticationServiceError.nonceGenerationFailed
        }

        var randomBytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard result == errSecSuccess else {
            throw AuthenticationServiceError.nonceGenerationFailed
        }

        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { characters[Int($0) % characters.count] })
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
