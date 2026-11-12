#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData

    /// `UITESTING_SUBTITLES=off|auto|always` stores that Subtitles preference
    /// in a UI testing store at launch (sources-and-settings/choose-when-subtitles-show).
    /// Compiled into Debug builds only.
    enum UITestingSubtitles {
        static let variable = "UITESTING_SUBTITLES"

        /// Inserts a preferences record with the mode into the fresh store.
        static func seed(_ context: ModelContext) {
            guard let mode = ProcessInfo.processInfo.environment[variable].flatMap(SubtitleMode.init(rawValue:)) else { return }
            let record = PreferencesRecord()
            record.subtitlesRaw = mode.rawValue
            context.insert(record)
        }
    }
#endif
