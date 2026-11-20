import XCTest

extension XCUIApplication {
    /// Launches the app in English with a US region, whatever language,
    /// region and clock the simulator or its Mac use. UI tests find text by
    /// its English wording and compare times with `UITestLocale.time(_:)`,
    /// so every test launches through here. A test that sets
    /// `-AppleLanguages` itself, such as a right-to-left test, keeps its own
    /// language and region. Either way the clock follows the region: the
    /// 12-hour and 24-hour overrides are switched off.
    func launchInEnglish() {
        if !launchArguments.contains("-AppleLanguages") {
            launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", UITestLocale.english.identifier]
        }
        launchArguments += ["-AppleICUForce12HourTime", "NO", "-AppleICUForce24HourTime", "NO"]
        launch()
    }
}

/// The locale `launchInEnglish()` gives the app, for tests that compare a
/// time or number the app wrote. The test runner's own `Locale.current`
/// follows the simulator and can differ.
enum UITestLocale {
    static let english = Locale(identifier: "en_US")

    /// A time as the app writes it in the guide: "2:30 PM".
    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(english))
    }
}
