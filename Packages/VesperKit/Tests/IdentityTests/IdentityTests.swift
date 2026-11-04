import Foundation
import Synchronization
import Testing
import Vault
@testable import Identity

/// Answers every request to the token endpoint with `Stub.response`, after a delay long enough
/// for concurrent callers to overlap, and counts the requests.
final class Stub: URLProtocol {
    static let state = Mutex((requests: 0, status: 200, body: Data()))

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host() == "you-find.me"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let (status, body) = Self.state.withLock { state in
            state.requests += 1
            return (state.status, state.body)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [self] in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client!.urlProtocol(self, didLoad: body)
            client!.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct IdentityTests {
    /// A Keychain item of its own, so the tests never touch a real sign-in.
    let account = "identity-tests-\(UUID().uuidString)"

    init() throws {
        URLProtocol.registerClass(Stub.self)
        let session = Session(refreshToken: "r1", account: Account(email: "a@b.c", name: "A", picture: nil))
        try Vault.save(String(decoding: try JSONEncoder().encode(session), as: UTF8.self), for: account)
    }

    private func respond(_ status: Int, _ json: String) {
        Stub.state.withLock { $0 = (0, status, Data(json.utf8)) }
    }

    @Test("Concurrent callers share one refresh of a rotating token") func coalesce() async throws {
        respond(200, #"{"access_token": "a1", "expires_in": 3600, "refresh_token": "r2"}"#)
        let identity = Identity(vaultAccount: account)
        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<5 { group.addTask { try await identity.token() } }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(tokens == Array(repeating: "a1", count: 5))
        #expect(Stub.state.withLock { $0.requests } == 1)
        let stored = try JSONDecoder().decode(Session.self, from: Data(try #require(try Vault.read(account)).utf8))
        #expect(stored.refreshToken == "r2")
        try Vault.delete(account)
    }

    @Test("A refused grant signs out and clears the session") func expired() async throws {
        respond(400, #"{"error": "invalid_grant", "error_description": "session not found"}"#)
        let identity = Identity(vaultAccount: account)
        await #expect {
            try await identity.token()
        } throws: { error in
            if case IdentityError.signedOut = error { true } else { false }
        }
        #expect(try Vault.read(account) == nil)
    }

    @Test("Sign-out drops the local session when revocation is refused") func signOut() async throws {
        respond(401, #"{"error":"invalid_client"}"#)
        let identity = Identity(vaultAccount: account)
        await #expect {
            try await identity.signOut()
        } throws: { error in
            if case IdentityError.status = error { true } else { false }
        }
        #expect(try Vault.read(account) == nil)
        await #expect {
            try await identity.token()
        } throws: { error in
            if case IdentityError.signedOut = error { true } else { false }
        }
    }
}
