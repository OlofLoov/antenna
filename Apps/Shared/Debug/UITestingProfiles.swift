#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData

    /// `-ui-testing-profiles` adds Dad (Main) and Kids to a UI testing store,
    /// so launch asks who is watching (profiles capability). Compiled into
    /// Debug builds only.
    enum UITestingProfiles {
        static let argument = "-ui-testing-profiles"
        static let kidsID = UUID(uuidString: "00000000-0000-0000-0000-00000000000C") ?? UUID()

        /// Whether the app was launched with the profiles.
        static var isOn: Bool { ProcessInfo.processInfo.arguments.contains(argument) }

        /// Inserts Dad and Kids when the argument is on, and forgets which
        /// profile this device was on either way.
        static func seed(_ context: ModelContext) {
            if isOn {
                context.insert(ProfileRecord(Profile(id: Profile.mainID, name: "Dad", colorIndex: 0, sortOrder: 0, createdAt: .now)))
                context.insert(ProfileRecord(Profile(id: kidsID, name: "Kids", colorIndex: 5, sortOrder: 1, createdAt: .now)))
            }
            UserDefaults.standard.removeObject(forKey: CurrentProfileStore.key)
        }
    }
#endif
