import SwiftUI

/// The colour tokens of `docs/design/README.md`, section 1.
enum Palette {
    static let ground = Color(red: 0x0B / 255, green: 0x0E / 255, blue: 0x13 / 255)
    static let tabBar = Color(red: 0x11 / 255, green: 0x15 / 255, blue: 0x1C / 255)
    static let text = Color(red: 0xF2 / 255, green: 0xF4 / 255, blue: 0xF8 / 255)
    static let textMuted = Color(red: 0xA7 / 255, green: 0xB0 / 255, blue: 0xBF / 255)
    static let accent = Color(red: 0x5B / 255, green: 0xB8 / 255, blue: 0xFF / 255)
    /// The focused element's fill (DR-2); its text uses `ground`.
    static let focus = text
    static let focusShadow = Color.black.opacity(0.45)
    static let scrimTint = Color(red: 8 / 255, green: 10 / 255, blue: 14 / 255)

    static func surface(_ opacity: Double) -> Color { Color.white.opacity(opacity) }
}

/// The 0.55 scrim the Apple TV shell lays over the picture or the guide
/// under its tab bar (`TV-Shell-Menu`).
struct ShellScrim: View {
    var body: some View {
        Palette.scrimTint.opacity(0.55)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
