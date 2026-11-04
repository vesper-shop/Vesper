import CryptoKit
import Foundation
import Vault

public actor Identity {
    public static let shared = Identity()
    public static let callbackScheme = "vesper"

    private static let issuer = URL(string: "https://you-find.me/api/auth/oauth2/")!
    private static let client = "vesper"
    private static let redirect = "vesper://oauth/callback"
    private static let resources = ["https://memos.you-find.me", "https://moment.you-find.me", "https://knowledge.you-find.me"]
    private static let scope = "openid profile email offline_access memos:read memos:write moment:read moment:write knowledge:read knowledge:write"

    /// The Keychain item holding the session.
    private let vaultAccount: String
    private var access: (token: String, expiry: Date)?
    private var refreshing: Task<String, any Error>?
    private var epoch = 0

    init(vaultAccount: String = "you-find-me") {
        self.vaultAccount = vaultAccount
    }

    public nonisolated func begin() -> Authorization {
        let verifier = Self.random()
        let state = Self.random()
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        var components = URLComponents(url: Self.issuer.appending(path: "authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: Self.client),
            .init(name: "redirect_uri", value: Self.redirect),
            .init(name: "scope", value: Self.scope),
            .init(name: "state", value: state),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
        ] + Self.resources.map { .init(name: "resource", value: $0) }
        return Authorization(url: components.url!, verifier: verifier, state: state)
    }

    public func complete(_ callback: URL, _ authorization: Authorization) async throws -> Account {
        guard let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems else {
            throw IdentityError.rejected("the callback carried no result")
        }
        let value = { (name: String) in items.first { $0.name == name }?.value }
        if let error = value("error") {
            throw IdentityError.rejected(error)
        }
        guard value("state") == authorization.state, let code = value("code") else {
            throw IdentityError.rejected("the callback did not match this sign-in")
        }
        let response = try await exchange([
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", Self.redirect),
            ("code_verifier", authorization.verifier),
        ])
        guard let refreshToken = response.refreshToken else {
            throw IdentityError.rejected("no refresh token was issued")
        }
        let account = try await profile(response.accessToken)
        try store(Session(refreshToken: refreshToken, account: account))
        return account
    }

    public func account() async throws -> Account? {
        guard try session() != nil else { return nil }
        let epoch = epoch
        let token = try await self.token()
        guard let session = try session() else { return nil }
        let profile: Account
        do {
            profile = try await self.profile(token)
        } catch {
            return session.account
        }
        guard epoch == self.epoch, let session = try self.session() else { return nil }
        try store(Session(refreshToken: session.refreshToken, account: profile))
        return profile
    }

    public func token() async throws -> String {
        if let access, access.expiry > Date().addingTimeInterval(60) {
            return access.token
        }
        // Refresh tokens rotate, so concurrent callers must share one refresh: a second request
        // with the same token would be refused as reuse.
        if let refreshing {
            return try await refreshing.value
        }
        let epoch = epoch
        let task = Task {
            guard let session = try session() else { throw IdentityError.signedOut }
            let response: TokenResponse
            do {
                response = try await exchange([("grant_type", "refresh_token"), ("refresh_token", session.refreshToken)])
            } catch IdentityError.expired {
                try Vault.delete(vaultAccount)
                throw IdentityError.signedOut
            }
            guard epoch == self.epoch else {
                access = nil
                throw IdentityError.signedOut
            }
            if let rotated = response.refreshToken {
                try store(Session(refreshToken: rotated, account: session.account))
            }
            return response.accessToken
        }
        refreshing = task
        defer { refreshing = nil }
        return try await task.value
    }

    public func invalidate() {
        access = nil
    }

    public func signOut() async throws {
        let current = try session()
        epoch += 1
        try Vault.delete(vaultAccount)
        access = nil
        guard let current else { return }
        _ = try await post("revoke", [
            ("token", current.refreshToken),
            ("token_type_hint", "refresh_token"),
            ("client_id", Self.client),
        ], operation: "sign-out")
    }

    private func exchange(_ fields: [(String, String)]) async throws -> TokenResponse {
        let data = try await post(
            "token",
            fields + [("client_id", Self.client)] + Self.resources.map { ("resource", $0) },
            operation: "sign-in"
        )
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        access = (response.accessToken, Date().addingTimeInterval(TimeInterval(response.expiresIn)))
        return response
    }

    private func post(_ path: String, _ fields: [(String, String)], operation: String) async throws -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        var request = URLRequest(url: Self.issuer.appending(path: path), timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(fields.map { name, value in
            "\(name)=\(value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&").utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as! HTTPURLResponse).statusCode
        if code == 400, try JSONDecoder().decode(OAuthFailure.self, from: data).error == "invalid_grant" {
            throw IdentityError.expired
        }
        guard (200..<300).contains(code) else { throw IdentityError.status(operation: operation, code: code) }
        return data
    }

    private func session() throws -> Session? {
        try Vault.read(vaultAccount).map { try JSONDecoder().decode(Session.self, from: Data($0.utf8)) }
    }

    private func store(_ session: Session) throws {
        try Vault.save(String(decoding: try JSONEncoder().encode(session), as: UTF8.self), for: vaultAccount)
    }

    private func profile(_ token: String) async throws -> Account {
        var request = URLRequest(url: Self.issuer.appending(path: "userinfo"), timeoutInterval: 30)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as! HTTPURLResponse).statusCode
        guard (200..<300).contains(code) else { throw IdentityError.status(operation: "profile", code: code) }
        return try JSONDecoder().decode(Account.self, from: data)
    }

    private static func random() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        precondition(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
