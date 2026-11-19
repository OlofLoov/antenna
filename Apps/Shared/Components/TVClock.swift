import SwiftUI

/// Hours and minutes in the user's locale, 260 wide, right aligned. The
/// system tab bar on Apple TV holds no clock, so the pages draw this one:
/// the channel overlay, the info bar and the Movies and Series hero
/// (`TV-Shell-TabView`). Not focusable. Compiles on every platform so the
/// snapshot job renders its preview.
struct TVClock: View {
    let date: Date
    /// The element name the UI tests find it by.
    var identifier = "shell.clock"

    var body: some View {
        Text(date, format: .dateTime.hour().minute())
            .font(.boardStyle(34, weight: .semibold))
            .letterSpacing(0.5)
            .monospacedDigit()
            .foregroundStyle(Palette.text)
            .frame(width: 260, alignment: .trailing)
            .accessibilityIdentifier(identifier)
    }
}

/// Where the system tab bar sits on Apple TV, for content that starts below it.
enum SystemTabBar {
    /// The foot of the bar, measured from the top of the screen.
    static let bottom = 120.0
}

#Preview("Clock", traits: .fixedLayout(width: 400, height: 120)) {
    TVClock(date: Date(timeIntervalSince1970: 77_640))
        .padding()
        .background(Palette.ground)
}
