import SwiftUI

/// Physical colors, mirroring `packages/ui/src/styles/palette.css`.
/// Only `Theme` may reference the palette; views consume semantic tokens.
enum Palette {
    static let black: UInt32 = 0x000000
    static let white: UInt32 = 0xFFFFFF

    static let lightPaper: UInt32 = 0xFAF7EB
    static let lightCloud: UInt32 = 0xF5F2EC
    static let lightOat: UInt32 = 0xE8E0D0
    static let lightFog: UInt32 = 0x726E69
    static let lightInk: UInt32 = 0x1A1A1A

    static let darkBase: UInt32 = 0x1A1917
    static let darkMuted: UInt32 = 0x242220
    static let darkBorder: UInt32 = 0x332F2C
    static let darkRaised: UInt32 = 0x423D38
    static let darkText: UInt32 = 0xE6E3DC
    static let darkTextDim: UInt32 = 0x9A948D

    static let brandLight: UInt32 = 0x963C5A
    static let brandDark: UInt32 = 0xD8A0B2
    static let successLight: UInt32 = 0x4D5E38
    static let successDark: UInt32 = 0xA8B890
    static let errorLight: UInt32 = 0xA03030
    static let errorDark: UInt32 = 0xD06464
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            NSColor(rgb: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#else
private extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
