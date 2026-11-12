#if DEBUG
    import Foundation

    /// The guide's UI test hooks on the scripted Live launch
    /// (guide-on-iphone-ipad-and-mac capability).
    extension UITestingLive {
        /// What the guide tests add with `-ui-testing-guide <mode>`: `days`
        /// gives Sport One a programme tomorrow and a guide that reaches two
        /// days ahead; `failed` fails Cabin's guide until Retry.
        enum GuideMode: String {
            case days, failed
        }

        static let guideArgument = "-ui-testing-guide"

        static var guideMode: GuideMode? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: guideArgument), index + 1 < arguments.endIndex else { return nil }
            return GuideMode(rawValue: arguments[index + 1])
        }

        /// Set once Retry asks for Cabin's failed guide again.
        @MainActor static var guideRetried = false
    }

    extension UITestingLive.Layout {
        /// With `-ui-testing-narrow-on-details`, the window turns narrow a
        /// second after the guide's details open, since a tap on the
        /// switch button would close a popover first.
        func detailsOpened() {
            guard ProcessInfo.processInfo.arguments.contains("-ui-testing-narrow-on-details") else { return }
            Task {
                try? await Task.sleep(for: .seconds(1))
                compact = true
            }
        }
    }
#endif
