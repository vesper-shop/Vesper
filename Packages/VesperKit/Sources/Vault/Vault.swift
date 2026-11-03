import Foundation
import Security

/// Generic credential storage in the Keychain. Features own their account names and validation.
public enum Vault {
    private static let service = "me.youfind.vesper"

    public struct Failure: LocalizedError, Sendable {
        public let status: OSStatus

        public var errorDescription: String? {
            SecCopyErrorMessageString(status, nil) as String?
        }
    }

    /// Returns nil only when no item exists; any other Keychain status throws.
    public static func read(_ account: String) throws -> String? {
        var query = query(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return String(decoding: item as! Data, as: UTF8.self)
        case errSecItemNotFound:
            return nil
        default:
            throw Failure(status: status)
        }
    }

    /// Saving an empty value removes the item.
    public static func save(_ value: String, for account: String) throws {
        try delete(account)
        guard !value.isEmpty else { return }
        var item = query(account)
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure(status: status) }
    }

    public static func delete(_ account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
    }

    private static func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
