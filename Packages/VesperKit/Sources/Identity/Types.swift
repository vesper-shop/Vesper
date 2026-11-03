import Foundation

public struct Account: Codable, Hashable, Sendable {
    public let email: String
    public let name: String
    public let picture: URL?
}

public struct Authorization: Sendable {
    public let url: URL
    let verifier: String
    let state: String
}

public enum IdentityError: LocalizedError, Sendable {
    case signedOut
    /// The grant was refused as expired or revoked (`invalid_grant`).
    case expired
    case rejected(String)
    case status(operation: String, code: Int)

    public var errorDescription: String? {
        switch self {
        case .signedOut: "Sign in with your you-find.me account."
        case .expired: "Your you-find.me sign-in expired. Sign in again."
        case .rejected(let reason): "you-find.me declined the sign-in: \(reason)."
        case .status(let operation, let code): "you-find.me \(operation) returned \(code)."
        }
    }
}

struct Session: Codable {
    let refreshToken: String
    let account: Account
}

/// RFC 6749 §5.2 error body; the token endpoint answers every 400 with one.
struct OAuthFailure: Decodable {
    let error: String
}

struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}
