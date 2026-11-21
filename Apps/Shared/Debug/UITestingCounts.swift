#if DEBUG
    extension UITestingLive {
        /// Counts of view builds the UI tests read.
        @MainActor enum Counts {
            private static var guideList = 0

            /// Counts one build of the iPhone guide list and returns the count.
            static func guideListBuilds() -> Int {
                guideList += 1
                return guideList
            }
        }
    }
#endif
