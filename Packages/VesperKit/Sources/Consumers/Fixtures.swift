#if DEBUG
import Foundation

/// Wire-format samples for previews and tests, decoded through the production decoder.
extension Entry {
    public static let sample: Entry = try! Client.decoder.decode(EntryDocument.self, from: Data("""
    {
      "meta": {
        "id": "a3105774-2e43-45fa-aeec-c355db7e2e07",
        "occurred": "2026-05-12T00:49:41.735Z",
        "visibility": "public",
        "pinned": "2026-05-12T00:50:00.000Z",
        "favorite": "2026-05-12T00:50:00.000Z",
        "archived": null,
        "tags": ["日常"]
      },
      "body": "你好👋 这是我的第一个 **memo**，纪念一下\\n主页 https://you-find.me\\n\\n- [x] 写第一条\\n- [ ] 写第二条\\n\\n> 引用一句话"
    }
    """.utf8)).entry
}

extension Photo {
    public static let sample: Photo = try! Client.decoder.decode(Photo.self, from: Data("""
    {
      "id": "fc20de3d-5d7e-4958-94ae-5dbdb47edc66",
      "entryId": "671461a5-0188-4ae0-bada-76939da23ba8",
      "caption": "一切都将结束\\n\\n照片摄于傍晚准备回诺丁汉途中",
      "tags": ["travel"],
      "width": 5712,
      "height": 4284,
      "takenAt": 1792690378652,
      "occurredAt": 1792690378652,
      "geo": { "lat": 53.480861, "lng": -2.234686 },
      "thumbHash": "VRgKFQKAhcJ4h2hotWelaGHACDNb"
    }
    """.utf8))
}
#endif
