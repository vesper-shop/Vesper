import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Normalizes a source image for publication, mirroring `consumers::api::moment::media`:
/// orientation applied, a PNG original, a 600 px JPEG thumbnail at quality 90, and a ThumbHash
/// from a 100 px rendition. HEIC, JPEG and PNG all decode through ImageIO.
enum Media {
    private static let dimensionLimit = 16_384
    private static let pixelLimit = 100_000_000

    static func prepare(_ source: Data) throws -> PreparedPhoto {
        let image = try open(source)
        let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as! [CFString: Any]
        let width = properties[kCGImagePropertyPixelWidth] as! Int
        let height = properties[kCGImagePropertyPixelHeight] as! Int
        guard max(width, height) <= dimensionLimit, width * height <= pixelLimit else {
            throw ConsumerError.media("larger than \(dimensionLimit) px or \(pixelLimit / 1_000_000) megapixels")
        }
        let render = { (size: Int) -> CGImage in
            CGImageSourceCreateThumbnailAtIndex(image, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: size,
            ] as CFDictionary)!
        }
        let encode = { (image: CGImage, type: UTType, options: [CFString: Any]) -> Data in
            let data = NSMutableData()
            let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, image, options as CFDictionary)
            CGImageDestinationFinalize(destination)
            return data as Data
        }

        let original = render(max(width, height))
        let placeholder = render(100)
        var rgba = [UInt8](repeating: 0, count: placeholder.width * placeholder.height * 4)
        let context = CGContext(
            data: &rgba,
            width: placeholder.width,
            height: placeholder.height,
            bitsPerComponent: 8,
            bytesPerRow: placeholder.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(placeholder, in: CGRect(x: 0, y: 0, width: placeholder.width, height: placeholder.height))

        return PreparedPhoto(
            original: encode(original, .png, [:]),
            thumbnail: encode(render(600), .jpeg, [kCGImageDestinationLossyCompressionQuality: 0.9]),
            width: original.width,
            height: original.height,
            thumbHash: ThumbHash.encode(width: placeholder.width, height: placeholder.height, rgba: rgba).map { String(format: "%02x", $0) }.joined(),
            metadata: metadata(properties)
        )
    }

    static func metadata(_ source: Data) throws -> PhotoMetadata {
        metadata(CGImageSourceCopyPropertiesAtIndex(try open(source), 0, nil) as! [CFString: Any])
    }

    private static func open(_ source: Data) throws -> CGImageSource {
        guard let image = CGImageSourceCreateWithData(source as CFData, nil), CGImageSourceGetCount(image) > 0 else {
            throw ConsumerError.media("the file is not a supported image")
        }
        return image
    }

    /// EXIF `DateTimeOriginal` as `YYYY-MM-DDTHH:MM:SS[.sub][±HH:MM]`, as `exif::captured_at`
    /// writes it, and the signed GPS coordinates.
    private static func metadata(_ properties: [CFString: Any]) -> PhotoMetadata {
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        var captured: String?
        if let original = exif?[kCGImagePropertyExifDateTimeOriginal] as? String, original.count == 19 {
            let parts = original.split(separator: " ")
            captured = parts[0].replacingOccurrences(of: ":", with: "-") + "T" + parts[1]
            if let subsecond = exif?[kCGImagePropertyExifSubsecTimeOriginal] as? String, !subsecond.isEmpty {
                captured! += "." + subsecond
            }
            if let offset = exif?[kCGImagePropertyExifOffsetTimeOriginal] as? String, !offset.isEmpty {
                captured! += offset
            }
        }
        var geo: Photo.Geo?
        if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
           let lng = gps[kCGImagePropertyGPSLongitude] as? Double {
            geo = Photo.Geo(
                lat: gps[kCGImagePropertyGPSLatitudeRef] as? String == "S" ? -lat : lat,
                lng: gps[kCGImagePropertyGPSLongitudeRef] as? String == "W" ? -lng : lng
            )
        }
        return PhotoMetadata(captured: captured, geo: geo)
    }
}
