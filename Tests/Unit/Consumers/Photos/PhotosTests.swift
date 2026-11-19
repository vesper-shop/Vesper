import Foundation
import Testing
@testable import Consumers

struct PhotosTests {
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
