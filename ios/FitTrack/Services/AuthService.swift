import Foundation
import Observation

struct PublicUser: Codable {
    let id: String
    let email: String?
    let displayName: String
    let unitPreference: String
}

private struct SessionResponse: Decodable {
    let user: PublicUser
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

private struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

private enum KeychainKey {
    static let accessToken = "accessToken"
    static let refreshToken = "refreshToken"
    static let userID = "userID"
}

private struct AppleSignInBody: Encodable {
    let identityToken: String
    let displayName: String?
    let deviceName: String
}

private struct RegisterBody: Encodable {
    let email: String
    let password: String
    let displayName: String
    let deviceName: String
}

private struct LoginBody: Encodable {
    let email: String
    let password: String
    let deviceName: String
}

private struct RefreshBody: Encodable {
    let refreshToken: String
}

/// Owns the auth session end-to-end: Keychain-backed token storage,
/// login/register/Apple sign-in, and the refresh-on-401 hook wired into
/// `APIClient` (PLAN.md §5). Signing in is optional — Phase 1's local-only
/// experience keeps working if the user never signs in; this only unlocks
/// sync (`SyncEngine`, Phase 2).
@MainActor
@Observable
final class AuthService {
    private(set) var currentUser: PublicUser?
    private(set) var accessToken: String?

    var isSignedIn: Bool { currentUser != nil }

    private static let deviceName = "iPhone" // Refined with UIDevice.current.name at call sites once available.

    init() {
        accessToken = KeychainService.getString(KeychainKey.accessToken)
        if let userID = KeychainService.getString(KeychainKey.userID) {
            currentUser = PublicUser(id: userID, email: nil, displayName: "", unitPreference: "imperial")
        }
        APIClient.shared.accessTokenProvider = { [weak self] in self?.accessToken }
        APIClient.shared.onUnauthorizedRetry = { [weak self] in
            (try? await self?.refresh()) != nil
        }
    }

    func signInWithApple(identityToken: String, displayName: String?) async throws {
        let body = AppleSignInBody(identityToken: identityToken, displayName: displayName, deviceName: Self.deviceName)
        let response: SessionResponse = try await APIClient.shared.request("POST", "/v1/auth/apple", body: body)
        store(response)
    }

    func register(email: String, password: String, displayName: String) async throws {
        let body = RegisterBody(email: email, password: password, displayName: displayName, deviceName: Self.deviceName)
        let response: SessionResponse = try await APIClient.shared.request("POST", "/v1/auth/register", body: body)
        store(response)
    }

    func login(email: String, password: String) async throws {
        let body = LoginBody(email: email, password: password, deviceName: Self.deviceName)
        let response: SessionResponse = try await APIClient.shared.request("POST", "/v1/auth/login", body: body)
        store(response)
    }

    @discardableResult
    func refresh() async throws -> String {
        guard let refreshToken = KeychainService.getString(KeychainKey.refreshToken) else {
            throw APIError.unauthorized
        }
        let body = RefreshBody(refreshToken: refreshToken)
        let response: RefreshResponse = try await APIClient.shared.request("POST", "/v1/auth/refresh", body: body)
        accessToken = response.accessToken
        KeychainService.setString(response.accessToken, for: KeychainKey.accessToken)
        KeychainService.setString(response.refreshToken, for: KeychainKey.refreshToken)
        return response.accessToken
    }

    func signOut() async {
        if let refreshToken = KeychainService.getString(KeychainKey.refreshToken) {
            let body = RefreshBody(refreshToken: refreshToken)
            _ = try? await APIClient.shared.request("POST", "/v1/auth/logout", body: body) as EmptyResponse
        }
        clearLocalSession()
    }

    /// Deletes the account server-side (PLAN.md §5 `DELETE /v1/me`), then
    /// clears the local session. Local SwiftData records are left untouched
    /// here — callers decide separately whether to wipe local data too.
    func deleteAccount() async throws {
        _ = try await APIClient.shared.request("DELETE", "/v1/me", authenticated: true) as EmptyResponse
        clearLocalSession()
    }

    private func store(_ response: SessionResponse) {
        currentUser = response.user
        accessToken = response.accessToken
        KeychainService.setString(response.accessToken, for: KeychainKey.accessToken)
        KeychainService.setString(response.refreshToken, for: KeychainKey.refreshToken)
        KeychainService.setString(response.user.id, for: KeychainKey.userID)
    }

    private func clearLocalSession() {
        currentUser = nil
        accessToken = nil
        KeychainService.delete(KeychainKey.accessToken)
        KeychainService.delete(KeychainKey.refreshToken)
        KeychainService.delete(KeychainKey.userID)
    }
}
