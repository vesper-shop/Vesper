import Consumers
import Foundation
import Testing
@testable import Social

struct SocialTests {
    private func memo(_ content: String, visibility: String = "public") throws -> Memo {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(decoder.singleValueContainer().decode(String.self))
        }
        return try decoder.decode(Memo.self, from: Data("""
        {"id":"1","content":\(String(data: JSONEncoder().encode(content), encoding: .utf8)!),"tags":[],
        "createdAt":"2026-08-05T11:33:17.191Z","updatedAt":"2026-08-05T11:33:17.191Z",
        "visibility":"\(visibility)","pinned":false,"favorite":false,"archived":false}
        """.utf8))
    }

    @Test("X drops tags, Telegram keeps them") func tags() throws {
        let memo = try memo("**Hello** world\nsecond line\n\n- item #日常")
        #expect(try Social.text(memo, for: .x) == "Hello world\nsecond line\n\nitem")
        #expect(try Social.text(memo, for: .telegram) == "Hello world\nsecond line\n\nitem #日常")
    }

    @Test("Private memos are refused") func privacy() throws {
        #expect(throws: SocialError.self) { try Social.text(try memo("hi", visibility: "private"), for: .x) }
    }

    @Test("X counts non-ASCII double and truncates with an ellipsis") func limit() throws {
        let text = try Social.text(try memo(String(repeating: "字", count: 200)), for: .x)
        #expect(text.hasSuffix("…"))
        #expect(SocialProvider.x.measure(text) <= 280)
    }

    @Test("Compose links carry the text") func compose() throws {
        let url = try Social.compose(try memo("hi there"), on: .x)
        #expect(url.absoluteString == "https://x.com/intent/post?text=hi%20there")
    }
}
