import CryptoKit
import Foundation
import Vault

public actor Identity {
    public static let shared = Identity()
    public static let callbackScheme = "vesper"
    public static let origin = URL(string: "https://noted-this.date")!

    private static let issuer = origin.appending(path: "api/auth/oauth2/")
    private static let workspace = origin.appending(path: "api/workspace")
    private static let redirect = "vesper://oauth/callback"
    private static let resources = [origin.appending(path: "mcp").absoluteString]
    static let scope = "entries:create entries:read entries:update entries:delete photos:create photos:read tags:read offline_access"

    private let vaultAccount: String
    /// Vesper checks requested scopes against the ones registered, so a new scope needs a new client.
    private var clientAccount: String { "\(vaultAccount)-client \(Self.scope)" }
    private var access: (token: String, expiry: Date)?
    private var refreshing: Task<String, any Error>?
    private var epoch = 0

    init(vaultAccount: String = "vesper") {
        self.vaultAccount = vaultAccount
    }

    public func begin() async throws -> Authorization {
        let client = try await clientID()
        let verifier = Self.random()
        let state = Self.random()
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        var components = URLComponents(url: Self.issuer.appending(path: "authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: client),
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
        ], client: try await clientID())
        guard let refreshToken = response.refreshToken else {
            throw IdentityError.rejected("no refresh token was issued")
        }
        let account = try await profile(response.accessToken)
        try store(Session(refreshToken: refreshToken, account: account))
        return account
    }

    public func saved() throws -> Account? {
        try session()?.account
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
            // A refresh token belongs to the client it was issued to, so a refresh never registers one.
            guard let session = try session(), let client = try Vault.read(clientAccount) else { throw IdentityError.signedOut }
            let response: TokenResponse
            do {
                response = try await exchange([("grant_type", "refresh_token"), ("refresh_token", session.refreshToken)], client: client)
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
                // Saving again moves a client kept from before keychain sharing to where widgets read.
                try Vault.save(client, for: clientAccount)
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
            ("client_id", try await clientID()),
        ], operation: "sign-out")
    }

    private func exchange(_ fields: [(String, String)], client: String) async throws -> TokenResponse {
        let data = try await post(
            "token",
            fields + [("client_id", client)] + Self.resources.map { ("resource", $0) },
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
        var request = URLRequest(url: Self.workspace, timeoutInterval: 30)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as! HTTPURLResponse).statusCode
        guard (200..<300).contains(code) else { throw IdentityError.status(operation: "profile", code: code) }
        let workspace = try JSONDecoder().decode(WorkspaceResponse.self, from: data)
        return Account(
            handle: "@\(workspace.workspace.handle)",
            name: workspace.profile.name,
            picture: workspace.profile.image
        )
    }

    /// Vesper registers clients dynamically, so the first sign-in registers this app and keeps the id.
    private func clientID() async throws -> String {
        if let saved = try Vault.read(clientAccount) { return saved }
        var request = URLRequest(url: Self.issuer.appending(path: "register"), timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_name": "Vesper",
            "application_type": "native",
            "redirect_uris": [Self.redirect],
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "none",
            "scope": Self.scope,
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as! HTTPURLResponse).statusCode
        guard (200..<300).contains(code) else { throw IdentityError.status(operation: "registration", code: code) }
        let client = try JSONDecoder().decode(Registration.self, from: data).clientID
        try Vault.save(client, for: clientAccount)
        return client
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
