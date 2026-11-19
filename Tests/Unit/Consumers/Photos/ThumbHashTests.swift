import CoreGraphics
import Testing
@testable import Consumers

struct ThumbHashTests {
    @Test("ThumbHash header encodes opacity and mean luminance") func header() {
        let grey = (0..<(10 * 10 * 4)).map { UInt8($0 % 4 == 3 ? 255 : 102) }
        let hash = ThumbHash.encode(width: 10, height: 10, rgba: grey)
        let header24 = Int(hash[0]) | Int(hash[1]) << 8 | Int(hash[2]) << 16
        #expect(header24 >> 23 == 0)
        #expect(header24 & 63 == 25)
        // Opaque and square: 7×7 luminance terms (27 AC) and 3×3 chroma (5 AC each), two per byte.
        #expect(hash.count == 5 + (27 + 5 + 5 + 1) / 2)
    }

    @Test("ThumbHash decodes back to the encoded colour and aspect") func image() {
        var rgba = [UInt8](repeating: 255, count: 40 * 20 * 4)
        for i in 0..<(40 * 20) {
            (rgba[i * 4], rgba[i * 4 + 1], rgba[i * 4 + 2]) = (200, 80, 40)
        }
        let hex = ThumbHash.encode(width: 40, height: 20, rgba: rgba).map { String(format: "%02x", $0) }.joined()
        let image = ThumbHash.image(hex)
        #expect(image.width == 32 && abs(image.height - 16) <= 2)
        let pixels = CFDataGetBytePtr(image.dataProvider!.data!)!
        let center = (image.height / 2 * image.width + image.width / 2) * 4
        #expect(abs(Int(pixels[center]) - 200) <= 12)
        #expect(abs(Int(pixels[center + 1]) - 80) <= 12)
        #expect(abs(Int(pixels[center + 2]) - 40) <= 12)
        #expect(pixels[center + 3] == 255)
    }
}
