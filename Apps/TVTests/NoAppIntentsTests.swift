import Foundation
import Testing

/// The Apple TV app carries no Siri or Shortcuts actions.
@Suite struct NoAppIntentsTests {
    @Test("app-intents/apple-tv-ships-no-actions the app has no App Intents metadata")
    func noMetadata() {
        let metadata = Bundle.main.bundleURL.appending(path: "Metadata.appintents")
        #expect(!FileManager.default.fileExists(atPath: metadata.path))
    }
}
