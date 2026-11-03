#if DEBUG
import Foundation

/// Wire-format samples for previews and tests, decoded through the production decoder.
extension Memo {
    public static let sample: Memo = try! Client.decoder.decode(Memo.self, from: Data("""
    {
      "id": "20260512T004941Z-8e418044",
      "content": "你好👋 这是我的第一个 **memo**，纪念一下\\n主页 https://you-find.me\\n\\n- [x] 写第一条\\n- [ ] 写第二条\\n\\n> 引用一句话\\n\\n#日常",
      "tags": ["日常"],
      "createdAt": "2026-05-12T00:49:41.735Z",
      "updatedAt": "2026-05-12T00:49:41.735Z",
      "visibility": "public",
      "pinned": true,
      "favorite": true,
      "archived": false
    }
    """.utf8))
}

extension Photo {
    public static let sample: Photo = try! Client.decoder.decode(Photo.self, from: Data("""
    {
      "id": "fc20de3d-5d7e-4958-94ae-5dbdb47edc66",
      "url": "/api/photos/img/c75063d4-7827-4eeb-a9dc-5a57e32158a1.png",
      "thumbnailUrl": "/api/photos/img/thumbnails/c75063d4-7827-4eeb-a9dc-5a57e32158a1.jpg",
      "title": "一切都将结束",
      "width": 5712,
      "height": 4284,
      "tags": ["travel"],
      "date": "2026-10-22T17:32:58.652+01:00",
      "description": "照片摄于傍晚准备回诺丁汉途中",
      "format": "PNG",
      "geo": { "lat": 53.480861, "lng": -2.234686 }
    }
    """.utf8))
}
#endif
