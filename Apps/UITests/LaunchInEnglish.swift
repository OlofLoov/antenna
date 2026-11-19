import XCTest

extension XCUIApplication {
    /// Launches the app in English with a US region, whatever language the
    /// simulator runs in. UI tests find text by its English wording, so every
    /// test launches through here. A test that sets `-AppleLanguages` itself,
    /// such as a right-to-left test, keeps its own language.
    func launchInEnglish() {
        if !launchArguments.contains("-AppleLanguages") {
            launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        }
        launch()
    }
}
