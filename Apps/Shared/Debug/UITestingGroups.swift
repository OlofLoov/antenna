#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData

    /// Group settings for the Groups UI tests, added to the store that
    /// `-ui-testing-live` or `-ui-testing-shell` seeds (group-management capability).
    ///
    /// `-ui-testing-groups locked` sets the passcode 2580 and locks the
    /// group the scenario names: Home's Sport on iPhone, iPad and Mac, the
    /// Cabin's Ungrouped on Apple TV. `-ui-testing-groups-owner` makes Forgot
    /// passcode skip the system's device check.
    enum UITestingGroups {
        static let argument = "-ui-testing-groups"
        static let passcode = "2580"

        static func seed(_ context: ModelContext, locking group: CatalogueGroup, arguments: [String] = ProcessInfo.processInfo.arguments) {
            guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else { return }
            switch arguments[index + 1] {
            case "locked":
                let record = GroupRecord(group: group)
                record.locked = true
                context.insert(record)
                if let passcode = PasscodeStore.record(for: passcode, now: .now) { context.insert(passcode) }
            default:
                fatalError("\(argument) takes locked")
            }
        }
    }
#endif
