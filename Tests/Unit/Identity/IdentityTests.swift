import Foundation
import Synchronization
import Testing
import Vault
@testable import Identity

@Suite(.serialized)
struct IdentityTests {
    /// A Keychain item of its own, so the tests never touch a real sign-in.
    let account = "identity-tests-\(UUID().uuidString)"

    init() throws {
        URLProtocol.registerClass(Stub.self)
        let session = Session(refreshToken: "r1", account: Account(handle: "a@b.c", name: "A", picture: nil))
        try Vault.save(String(decoding: try JSONEncoder().encode(session), as: UTF8.self), for: account)
        try Vault.save("test-client", for: "\(account)-client \(Identity.scope)")
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

    @Test("Without its client a refresh reads as signed out, keeps the session and registers nothing") func clientless() async throws {
        respond(201, #"{"client_id": "fresh"}"#)
        try Vault.delete("\(account)-client \(Identity.scope)")
        let identity = Identity(vaultAccount: account)
        await #expect {
            try await identity.token()
        } throws: { error in
            if case IdentityError.signedOut = error { true } else { false }
        }
        #expect(Stub.state.withLock { $0.requests } == 0)
        #expect(try Vault.read(account) != nil)
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

    @Test("A callback from another sign-in is rejected before any exchange") func mismatch() async throws {
        respond(200, "")
        let identity = Identity(vaultAccount: account)
        let authorization = try await identity.begin()
        await #expect {
            try await identity.complete(URL(string: "vesper://oauth/callback?code=c&state=other")!, authorization)
        } throws: { error in
            if case IdentityError.rejected = error { true } else { false }
        }
        await #expect {
            try await identity.complete(URL(string: "vesper://oauth/callback?error=access_denied")!, authorization)
        } throws: { error in
            if case IdentityError.rejected("access_denied") = error { true } else { false }
        }
        #expect(Stub.state.withLock { $0.requests } == 0)
        try Vault.delete(account)
    }

    @Test("A client registered for other scopes is replaced by a new registration") func reregister() async throws {
        respond(201, #"{"client_id": "fresh"}"#)
        try Vault.delete("\(account)-client \(Identity.scope)")
        try Vault.save("stale", for: "\(account)-client entries:read offline_access")
        let authorization = try await Identity(vaultAccount: account).begin()
        let items = try #require(URLComponents(url: authorization.url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.first { $0.name == "client_id" }?.value == "fresh")
        #expect(Stub.state.withLock { $0.requests } == 1)
        try Vault.delete(account)
        try Vault.delete("\(account)-client \(Identity.scope)")
        try Vault.delete("\(account)-client entries:read offline_access")
    }
}
