import Foundation
import Testing
@testable import Consumers

struct ClientTests {
    @Test("Dates parse with or without fractions and with offsets") func dates() throws {
        let plain = try #require(Client.date("2026-05-12T08:49:41+08:00"))
        let fraction = try #require(Client.date("2026-05-12T00:49:41.000Z"))
        #expect(plain == fraction)
    }
}
