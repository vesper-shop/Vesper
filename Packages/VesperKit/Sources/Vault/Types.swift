import Foundation
import Security

extension Vault {
    public struct Failure: LocalizedError, Sendable {
        public let status: OSStatus

        public var errorDescription: String? {
            SecCopyErrorMessageString(status, nil) as String?
        }
    }
}
