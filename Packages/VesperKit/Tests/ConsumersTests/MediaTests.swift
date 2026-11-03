import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Consumers

struct MediaTests {
    /// A 1200×800 opaque gradient encoded as PNG.
    private func fixture() -> (png: Data, rgba: [UInt8]) {
        var rgba = [UInt8](repeating: 255, count: 1200 * 800 * 4)
        for y in 0..<800 {
            for x in 0..<1200 {
                rgba[(y * 1200 + x) * 4] = UInt8(x * 255 / 1199)
                rgba[(y * 1200 + x) * 4 + 1] = UInt8(y * 255 / 799)
                rgba[(y * 1200 + x) * 4 + 2] = 128
            }
        }
        let context = CGContext(
            data: &rgba, width: 1200, height: 800, bitsPerComponent: 8, bytesPerRow: 4800,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return (data as Data, rgba)
    }

    @Test("Prepare keeps size, bounds the thumbnail and hashes") func prepare() throws {
        let prepared = try Media.prepare(fixture().png)
        #expect((prepared.width, prepared.height) == (1200, 800))
        let thumbnail = CGImageSourceCreateWithData(prepared.thumbnail as CFData, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(thumbnail, 0, nil) as! [CFString: Any]
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 600)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 400)
        #expect(prepared.thumbHash.count.isMultiple(of: 2) && prepared.thumbHash.count >= 10)
    }

    @Test("Reject non-images") func reject() {
        #expect(throws: ConsumerError.self) { try Media.prepare(Data("not an image".utf8)) }
    }

    @Test("ThumbHash header encodes opacity and mean luminance") func thumbHash() {
        let grey = (0..<(10 * 10 * 4)).map { UInt8($0 % 4 == 3 ? 255 : 102) }
        let hash = ThumbHash.encode(width: 10, height: 10, rgba: grey)
        let header24 = Int(hash[0]) | Int(hash[1]) << 8 | Int(hash[2]) << 16
        #expect(header24 >> 23 == 0)
        #expect(header24 & 63 == 25)
        // Opaque and square: 7×7 luminance terms (27 AC) and 3×3 chroma (5 AC each), two per byte.
        #expect(hash.count == 5 + (27 + 5 + 5 + 1) / 2)
    }

    @Test("ThumbHash decodes back to the encoded colour and aspect") func thumbHashImage() {
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
