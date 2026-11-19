import CoreGraphics
import Foundation

/// ThumbHash (Evan Wallace's reference algorithm, as the `thumbhash` crate the desktop uses): a DCT
/// of luminance, two chroma channels and alpha, packed into a few bytes.
enum ThumbHash {
    /// `rgba` holds `width × height` RGBA pixels; both sides must be at most 100.
    static func encode(width w: Int, height h: Int, rgba: [UInt8]) -> [UInt8] {
        precondition(w <= 100 && h <= 100, "ThumbHash encodes images up to 100×100")
        var avgR = 0.0, avgG = 0.0, avgB = 0.0, avgA = 0.0
        for i in 0..<(w * h) {
            let alpha = Double(rgba[i * 4 + 3]) / 255
            avgR += alpha / 255 * Double(rgba[i * 4])
            avgG += alpha / 255 * Double(rgba[i * 4 + 1])
            avgB += alpha / 255 * Double(rgba[i * 4 + 2])
            avgA += alpha
        }
        if avgA > 0 {
            avgR /= avgA
            avgG /= avgA
            avgB /= avgA
        }
        let hasAlpha = avgA < Double(w * h)
        let limit = hasAlpha ? 5.0 : 7.0
        let lx = max(1, Int((limit * Double(w) / Double(max(w, h))).rounded()))
        let ly = max(1, Int((limit * Double(h) / Double(max(w, h))).rounded()))
        var l = [Double](repeating: 0, count: w * h)
        var p = l, q = l, a = l
        for i in 0..<(w * h) {
            let alpha = Double(rgba[i * 4 + 3]) / 255
            let r = avgR * (1 - alpha) + alpha / 255 * Double(rgba[i * 4])
            let g = avgG * (1 - alpha) + alpha / 255 * Double(rgba[i * 4 + 1])
            let b = avgB * (1 - alpha) + alpha / 255 * Double(rgba[i * 4 + 2])
            l[i] = (r + g + b) / 3
            p[i] = (r + g) / 2 - b
            q[i] = r - g
            a[i] = alpha
        }

        let channel = { (values: [Double], nx: Int, ny: Int) -> (dc: Double, ac: [Double], scale: Double) in
            var dc = 0.0, ac: [Double] = [], scale = 0.0
            var fx = [Double](repeating: 0, count: w)
            for cy in 0..<ny {
                var cx = 0
                while cx * ny < nx * (ny - cy) {
                    var f = 0.0
                    for x in 0..<w { fx[x] = cos(.pi / Double(w) * Double(cx) * (Double(x) + 0.5)) }
                    for y in 0..<h {
                        let fy = cos(.pi / Double(h) * Double(cy) * (Double(y) + 0.5))
                        for x in 0..<w { f += values[x + y * w] * fx[x] * fy }
                    }
                    f /= Double(w * h)
                    if cx > 0 || cy > 0 {
                        ac.append(f)
                        scale = max(scale, abs(f))
                    } else {
                        dc = f
                    }
                    cx += 1
                }
            }
            if scale > 0 { ac = ac.map { 0.5 + 0.5 / scale * $0 } }
            return (dc, ac, scale)
        }

        let lc = channel(l, max(3, lx), max(3, ly))
        let pc = channel(p, 3, 3)
        let qc = channel(q, 3, 3)
        let ac = hasAlpha ? channel(a, 5, 5) : (dc: 0, ac: [], scale: 0)
        let landscape = w > h
        let header24 = Int((63 * lc.dc).rounded())
            | Int((31.5 + 31.5 * pc.dc).rounded()) << 6
            | Int((31.5 + 31.5 * qc.dc).rounded()) << 12
            | Int((31 * lc.scale).rounded()) << 18
            | (hasAlpha ? 1 : 0) << 23
        let header16 = (landscape ? ly : lx)
            | Int((63 * pc.scale).rounded()) << 3
            | Int((63 * qc.scale).rounded()) << 9
            | (landscape ? 1 : 0) << 15
        var hash = [header24 & 255, (header24 >> 8) & 255, header24 >> 16, header16 & 255, header16 >> 8].map(UInt8.init)
        if hasAlpha {
            hash.append(UInt8(Int((15 * ac.dc).rounded()) | Int((15 * ac.scale).rounded()) << 4))
        }
        let start = hash.count
        var index = 0
        for values in hasAlpha ? [lc.ac, pc.ac, qc.ac, ac.ac] : [lc.ac, pc.ac, qc.ac] {
            for f in values {
                if start + index >> 1 >= hash.count { hash.append(0) }
                hash[start + index >> 1] |= UInt8(Int((15 * f).rounded()) << ((index & 1) << 2))
                index += 1
            }
        }
        return hash
    }

    static func image(_ hex: String) -> CGImage {
        let hash = stride(from: 0, to: hex.count, by: 2).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return UInt8(hex[start..<hex.index(start, offsetBy: 2)], radix: 16)!
        }
        let header24 = Int(hash[0]) | Int(hash[1]) << 8 | Int(hash[2]) << 16
        let header16 = Int(hash[3]) | Int(hash[4]) << 8
        let lDC = Double(header24 & 63) / 63
        let pDC = Double((header24 >> 6) & 63) / 31.5 - 1
        let qDC = Double((header24 >> 12) & 63) / 31.5 - 1
        let lScale = Double((header24 >> 18) & 31) / 31
        let hasAlpha = header24 >> 23 != 0
        let pScale = Double((header16 >> 3) & 63) / 63
        let qScale = Double((header16 >> 9) & 63) / 63
        let landscape = header16 >> 15 != 0
        let lx = max(3, landscape ? (hasAlpha ? 5 : 7) : header16 & 7)
        let ly = max(3, landscape ? header16 & 7 : (hasAlpha ? 5 : 7))
        let aDC = hasAlpha ? Double(hash[5] & 15) / 15 : 1
        let aScale = hasAlpha ? Double(hash[5] >> 4) / 15 : 0
        let start = hasAlpha ? 6 : 5
        var index = 0
        let channel = { (nx: Int, ny: Int, scale: Double) -> [Double] in
            var ac: [Double] = []
            for cy in 0..<ny {
                var cx = cy > 0 ? 0 : 1
                while cx * ny < nx * (ny - cy) {
                    let nibble = (Int(hash[start + index >> 1]) >> ((index & 1) << 2)) & 15
                    ac.append((Double(nibble) / 7.5 - 1) * scale)
                    index += 1
                    cx += 1
                }
            }
            return ac
        }
        let lAC = channel(lx, ly, lScale)
        let pAC = channel(3, 3, pScale * 1.25)
        let qAC = channel(3, 3, qScale * 1.25)
        let aAC = hasAlpha ? channel(5, 5, aScale) : []

        let ratio = Double(landscape ? (hasAlpha ? 5 : 7) : header16 & 7) / Double(landscape ? header16 & 7 : (hasAlpha ? 5 : 7))
        let w = Int((ratio > 1 ? 32 : 32 * ratio).rounded())
        let h = Int((ratio > 1 ? 32 / ratio : 32).rounded())
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let fxCount = max(lx, hasAlpha ? 5 : 3)
        let fyCount = max(ly, hasAlpha ? 5 : 3)
        var fx = [Double](repeating: 0, count: fxCount)
        var fy = [Double](repeating: 0, count: fyCount)
        let sum = { (ac: [Double], nx: Int, ny: Int) -> Double in
            var total = 0.0, j = 0
            for cy in 0..<ny {
                var cx = cy > 0 ? 0 : 1
                while cx * ny < nx * (ny - cy) {
                    total += ac[j] * fx[cx] * fy[cy] * 2
                    j += 1
                    cx += 1
                }
            }
            return total
        }
        for y in 0..<h {
            for x in 0..<w {
                for cx in 0..<fxCount { fx[cx] = cos(.pi / Double(w) * (Double(x) + 0.5) * Double(cx)) }
                for cy in 0..<fyCount { fy[cy] = cos(.pi / Double(h) * (Double(y) + 0.5) * Double(cy)) }
                let l = lDC + sum(lAC, lx, ly)
                let p = pDC + sum(pAC, 3, 3)
                let q = qDC + sum(qAC, 3, 3)
                let a = hasAlpha ? aDC + sum(aAC, 5, 5) : aDC
                let b = l - 2 / 3 * p
                let r = (3 * l - b + q) / 2
                let g = r - q
                let i = (y * w + x) * 4
                for (offset, value) in [r, g, b, a].enumerated() {
                    rgba[i + offset] = UInt8(max(0, min(1, value)) * 255)
                }
            }
        }
        return CGImage(
            width: w,
            height: h,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: CGDataProvider(data: Data(rgba) as CFData)!,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )!
    }
}
