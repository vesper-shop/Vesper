import Foundation
import Testing
@testable import Consumers

struct MemosTests {
    @Test("Strip inline tags", arguments: [
        ("你好 #日常", "你好"),
        ("#开头 正文 #a/b", "正文"),
        ("keep#inline and ## heading", "keep#inline and ## heading"),
        ("a  #tag  b", "a b"),
    ])
    func strip(input: String, expected: String) {
        #expect(Memos.strip(input) == expected)
    }

    @Test("Decode a memo page") func page() throws {
        let json = Data("""
        {"memos":[{"id":"1","r2Key":"memos/1.md","content":"hi","tags":["a"],
        "createdAt":"2026-08-05T11:33:17.191Z","updatedAt":"2026-08-05T11:33:17.191Z",
        "visibility":"private","pinned":true,"favorite":false,"archived":false}],"nextCursor":null}
        """.utf8)
        let page = try Client.decoder.decode(MemoPage.self, from: json)
        #expect(page.memos.first?.visibility == .private)
        let created = try #require(page.memos.first?.createdAt.timeIntervalSince1970)
        #expect(abs(created - 1_785_929_597.191) < 0.001)
        #expect(page.nextCursor == nil)
    }

    @Test("Display membership") func display() {
        let memo = Memo.sample
        #expect(MemoDisplay.all.contains(memo))
        #expect(MemoDisplay.favorites.contains(memo))
        #expect(!MemoDisplay.archived.contains(memo))
    }

    @Test("Photo URLs resolve against Moment") func photo() {
        #expect(Photo.sample.thumbnailURL.absoluteString
            == "https://moment.you-find.me/api/photos/img/thumbnails/c75063d4-7827-4eeb-a9dc-5a57e32158a1.jpg")
        #expect(Photo.sample.date != nil)
    }

    @Test("Photo placeholder decodes from the wire thumbHash") func placeholder() throws {
        #expect(Photo.sample.placeholder == nil)
        let photo = try Client.decoder.decode(Photo.self, from: Data("""
        {"id": "a", "url": "/a.png", "thumbnailUrl": "/a.jpg", "thumbHash": "d507121d0467878f77578748878797875878909508",
         "title": "t", "width": 3, "height": 4, "tags": []}
        """.utf8))
        let image = try #require(photo.placeholder)
        #expect((image.width, image.height) == (23, 32))
    }
}
