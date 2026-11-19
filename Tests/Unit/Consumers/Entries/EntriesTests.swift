import Foundation
import Testing
@testable import Consumers

struct EntriesTests {
    @Test("Strip inline tags", arguments: [
        ("你好 #日常", "你好"),
        ("#开头 正文 #a/b", "正文"),
        ("keep#inline and ## heading", "keep#inline and ## heading"),
        ("a  #tag  b", "a b"),
    ])
    func strip(input: String, expected: String) {
        #expect(Entries.strip(input) == expected)
    }

    @Test("A Vesper entry keeps its tags as the closing line and its photos") func entry() throws {
        let json = Data("""
        {"meta":{"id":"1","occurred":"2026-08-05T11:33:17.191Z","visibility":"private",
        "pinned":"2026-08-05T11:33:17.191Z","favorite":null,"archived":null,"tags":["a"]},
        "body":"hi\\n\\nmore","photos":[{"id":"p","width":4,"height":3,"takenAt":null,"geo":null,"thumbHash":"VRgKFQKAhcJ4h2hotWelaGHACDNb"}]}
        """.utf8)
        let entry = try Client.decoder.decode(EntryDocument.self, from: json).entry
        #expect(entry.content == "hi\n\nmore\n\n#a")
        #expect(entry.visibility == .private && entry.pinned && !entry.favorite)
        #expect(abs(entry.occurred.timeIntervalSince1970 - 1_785_929_597.191) < 0.001)
        let photo = try #require(entry.photos.first)
        #expect(photo.entryId == "1" && photo.title == "hi" && photo.date == entry.occurred)
    }

    @Test("Body and tags split as Vesper stores them") func body() {
        let content = "Line #inline\n\n#daily #Rust"
        #expect(Entries.body(content) == "Line #inline")
        #expect(Entries.tags(in: content) == ["inline", "daily", "rust"])
    }

    @Test("Display membership") func display() {
        let entry = Entry.sample
        #expect(EntryDisplay.all.contains(entry))
        #expect(EntryDisplay.favorites.contains(entry))
        #expect(!EntryDisplay.archived.contains(entry))
    }
}
