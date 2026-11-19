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
}
