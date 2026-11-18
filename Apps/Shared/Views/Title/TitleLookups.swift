import AntennaCore
import Foundation

/// The movie database lookup title pages use (title-metadata), nil when
/// the app has none. Release builds have none until the Code Crave lookup
/// service exists, so they show no scores and no Movie info switch. A
/// Debug build launched with `-mock-title-scores YES`, or with Sample scores
/// on in Settings, uses `MockTitleLookup` through `DebugTitleScores`.
enum TitleLookups {
    static var app: KeptTitleLookup? {
        #if DEBUG
            if DebugTitleScores.isOn { return DebugTitleScores.lookup }
        #endif
        return nil
    }
}
