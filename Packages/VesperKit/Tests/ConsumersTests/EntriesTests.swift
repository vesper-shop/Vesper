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

    @Test("Dates parse with or without fractions and with offsets") func dates() throws {
        let plain = try #require(Client.date("2026-05-12T08:49:41+08:00"))
        let fraction = try #require(Client.date("2026-05-12T00:49:41.000Z"))
        #expect(plain == fraction)
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

    @Test("A Vesper photo splits its caption and shares its entry's page") func photo() {
        #expect(Photo.sample.title == "一切都将结束")
        #expect(Photo.sample.description == "照片摄于傍晚准备回诺丁汉途中")
        #expect(Photo.sample.shareURL.absoluteString == "https://noted-this.date/e/\(Photo.sample.entryId)")
        #expect(Photo.sample.date != nil)
    }

    @Test("Photo metadata spells out unknown fields as null") func meta() throws {
        let meta = PhotoMeta(width: 4, height: 3, thumbHash: "AA", takenAt: nil, geo: nil)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(meta)) as? [String: Any])
        #expect(Set(json.keys) == ["width", "height", "thumbHash", "takenAt", "geo", "place", "exif"])
        #expect(json["takenAt"] is NSNull && json["place"] is NSNull)
        #expect((json["exif"] as? [String: Any])?.count == 7)
    }

    @Test("Thumb hashes convert between Vesper's base64url and hex") func thumbHash() throws {
        let hex = try #require(Photo.hex(base64URL: "1QcSHQRnh493V4dIh4eXh1h4kJUI"))
        #expect(hex == "d507121d0467878f77578748878797875878909508")
        #expect(Photo.base64URL(hex: hex) == "1QcSHQRnh493V4dIh4eXh1h4kJUI")
        let image = try #require(ThumbHash.image(hex))
        #expect((image.width, image.height) == (23, 32))
    }
}
