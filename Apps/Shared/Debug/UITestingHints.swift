#if DEBUG && os(tvOS)
    import AntennaCore
    import Foundation

    /// Remote hints in UI tests (control-hints capability). With
    /// `-ui-testing-hints` the app starts with "Show remote hints" back at
    /// its default and the legend never fades, so a test can read it
    /// without racing the timer.
    enum UITestingHints {
        static let argument = "-ui-testing-hints"

        /// Read once, the first time a legend host asks; that first read
        /// clears the stored setting.
        static let holds: Bool = {
            guard ProcessInfo.processInfo.arguments.contains(argument) else { return false }
            UserDefaults.standard.removeObject(forKey: ControlHintsSetting.key)
            return true
        }()
    }
#endif
