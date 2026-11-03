import SwiftUI

/// Semantic design tokens, mirroring `packages/ui/src/styles/tokens.css`.
/// Views use these roles only, never `Palette` values or ad-hoc colors.
public enum Theme {
    public static let background = Color(light: Palette.lightPaper, dark: Palette.darkBase)
    public static let muted = Color(light: Palette.lightCloud, dark: Palette.darkMuted)
    public static let foreground = Color(light: Palette.lightInk, dark: Palette.darkText)
    public static let mutedForeground = Color(light: Palette.lightFog, dark: Palette.darkTextDim)
    public static let border = Color(light: Palette.lightOat, dark: Palette.darkBorder)
    public static let divider = Color(light: Palette.lightOat, dark: Palette.darkMuted)
    public static let accent = Color(light: Palette.brandLight, dark: Palette.brandDark)
    public static let accentForeground = Color(light: Palette.lightPaper, dark: Palette.darkBase)
    public static let success = Color(light: Palette.successLight, dark: Palette.successDark)
    public static let error = Color(light: Palette.errorLight, dark: Palette.errorDark)
    public static let skeleton = Color(light: Palette.lightOat, dark: Palette.darkBorder)
    public static let shine = Color(light: Palette.lightPaper, dark: Palette.darkRaised)
    public static let shadow = Color(light: Palette.black, dark: Palette.black)
    /// `--color-image-scrim`: text laid over photographs.
    public static let scrim = Color(light: Palette.black, dark: Palette.black).opacity(0.78)
    /// `--color-on-dark`.
    public static let onDark = Color(light: Palette.white, dark: Palette.white)

    /// `--radius-*`, scaled for touch: desktop pixels read small on a phone.
    public enum Radius {
        public static let sm: CGFloat = 4
        public static let md: CGFloat = 6
        public static let lg: CGFloat = 10
    }

    /// Widest a reading column grows on wide screens (an unfolded iPhone Duo, iPad, Mac).
    public static let readable: CGFloat = 720

    public enum Space {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 24
        /// Room at the end of a feed so its last item clears the floating buttons.
        public static let tail: CGFloat = 104
    }

    /// `--duration-*` as motion: `quick` for state flips, `gentle` for layout and images,
    /// `bouncy` for things that physically open and close.
    public enum Motion {
        public static let quick = Animation.smooth(duration: 0.18)
        public static let gentle = Animation.smooth(duration: 0.32)
        public static let bouncy = Animation.spring(duration: 0.45, bounce: 0.22)
    }

    /// On iOS every role is a text style at its default size, so it follows Dynamic Type; macOS
    /// has no Dynamic Type and its text styles run smaller, so it gets the same sizes fixed.
    public enum Font {
        #if os(iOS)
        public static let display = SwiftUI.Font.title2.weight(.semibold)
        public static let title = SwiftUI.Font.title3.weight(.semibold)
        public static let headline = SwiftUI.Font.headline
        public static let body = SwiftUI.Font.callout
        public static let detail = SwiftUI.Font.subheadline
        public static let meta = SwiftUI.Font.footnote
        public static let caption = SwiftUI.Font.caption
        public static let mono = SwiftUI.Font.system(.subheadline, design: .monospaced)
        public static let monoCaption = SwiftUI.Font.system(.caption2, design: .monospaced)
        #else
        public static let display = SwiftUI.Font.system(size: 22, weight: .semibold)
        public static let title = SwiftUI.Font.system(size: 20, weight: .semibold)
        public static let headline = SwiftUI.Font.system(size: 17, weight: .semibold)
        public static let body = SwiftUI.Font.system(size: 16)
        public static let detail = SwiftUI.Font.system(size: 15)
        public static let meta = SwiftUI.Font.system(size: 13)
        public static let caption = SwiftUI.Font.system(size: 12)
        public static let mono = SwiftUI.Font.system(size: 14, design: .monospaced)
        public static let monoCaption = SwiftUI.Font.system(size: 11, design: .monospaced)
        #endif
    }
}
