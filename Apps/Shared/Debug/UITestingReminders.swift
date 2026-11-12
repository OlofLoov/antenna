#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData

    /// Reminder hooks for UI tests (programme-reminders capability),
    /// compiled into Debug builds only. They combine with the Live and shell
    /// launches.
    ///
    /// - `-ui-testing-notifications <notDetermined|allowed|denied>` swaps the
    ///   system notification center for a scripted one. Its prompt answers
    ///   allow, or deny with `-ui-testing-notifications-answer deny`. With
    ///   `UITESTING_REMINDER_LOG` naming a file, it appends "ask" for each
    ///   prompt and "schedule <title> | <body>" for each notification it
    ///   adds, so a test can read what would have been delivered.
    /// - `-ui-testing-reminders <seed>` stores reminders at launch.
    /// - `UITESTING_REMINDER_BANNER_SECONDS` shortens the banner's 20 seconds.
    /// - Lead time and delivery state live in their own cleared defaults.
    enum UITestingReminders {
        static let notificationsArgument = "-ui-testing-notifications"
        static let answerArgument = "-ui-testing-notifications-answer"
        static let seedArgument = "-ui-testing-reminders"
        static let logVariable = "UITESTING_REMINDER_LOG"
        static let bannerVariable = "UITESTING_REMINDER_BANNER_SECONDS"

        enum Seed: String {
            /// Three upcoming reminders on Live's Home channels: Weather on
            /// News One, moved from ten minutes earlier; Harbour Talk on Sport
            /// One, no longer in the guide; Late Film on News One tomorrow;
            /// and one that ended an hour ago.
            case list
            /// Kick-off on News One (iPhone, iPad, Mac) or Channel a1 (Apple
            /// TV), two minutes after launch, so it is due at once.
            case due
            /// As `due`, on a channel that no source has.
            case missing
        }

        @MainActor static let launched = Date.now

        private static func value(after argument: String) -> String? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.endIndex else { return nil }
            return arguments[index + 1]
        }

        /// The scripted notification center for any UI test launch, not
        /// asked yet unless the argument says otherwise; nil outside UI tests.
        @MainActor
        static func notifier() -> (any ReminderNotifying)? {
            #if os(tvOS)
                // Apple TV has no notifications to script.
                return nil
            #else
                guard UITestingSearch.testing else { return nil }
                let state: ReminderAuthorization =
                    switch value(after: notificationsArgument) {
                    case "allowed": .allowed
                    case "denied": .denied
                    default: .notDetermined
                    }
                let log = ProcessInfo.processInfo.environment[logVariable].map { URL(fileURLWithPath: $0) }
                return ScriptedNotifications(state: state, allows: value(after: answerArgument) != "deny", log: log)
            #endif
        }

        /// Cleared defaults for any UI test launch, nil otherwise.
        static func defaults() -> UserDefaults? {
            guard UITestingSearch.testing else { return nil }
            let name = "ui-testing-reminders"
            let defaults = UserDefaults(suiteName: name)
            defaults?.removePersistentDomain(forName: name)
            return defaults
        }

        static var bannerSeconds: Double? {
            ProcessInfo.processInfo.environment[bannerVariable].flatMap(Double.init)
        }

        /// Stores the seed's reminders in `container`.
        @MainActor
        static func seed(_ container: ModelContainer) {
            guard let seed = value(after: seedArgument).flatMap(Seed.init) else { return }
            let context = container.mainContext
            #if os(tvOS)
                let source = UITestingShell.playlistID
                let channel = ("a1", "Channel a1")
            #else
                let source = UITestingLive.homeID
                let channel = ("news-one", "News One")
            #endif
            func add(
                _ title: String, _ guideID: String, _ name: String, start: Double, length: Double = 1800, moved: Double? = nil,
                gone: Bool = false
            ) {
                let begin = launched.addingTimeInterval(start)
                context.insert(
                    ReminderRecord(
                        Reminder(
                            sourceID: source, guideID: guideID, start: begin, stop: begin.addingTimeInterval(length), title: title,
                            channelName: name, movedFrom: moved.map { launched.addingTimeInterval($0) }, notListed: gone,
                            createdAt: launched)))
            }
            switch seed {
            case .list:
                add("Weather", "news-one", "News One", start: 1800, moved: 1200)
                add("Harbour Talk", "sport-one", "Sport One", start: 3600, gone: true)
                add("Late Film", "news-one", "News One", start: 86_400)
                add("Old Match", "sport-one", "Sport One", start: -7200)
            case .due:
                add("Kick-off", channel.0, channel.1, start: 120)
            case .missing:
                add("Kick-off", "gone", "Gone TV", start: 120)
            }
            try? context.save()
        }
    }

    /// A notification center that never shows the system prompt.
    @MainActor
    final class ScriptedNotifications: ReminderNotifying {
        private var state: ReminderAuthorization
        private let allows: Bool
        private let log: URL?
        private var pending: [String: ReminderNotificationRequest] = [:]

        init(state: ReminderAuthorization, allows: Bool, log: URL?) {
            self.state = state
            self.allows = allows
            self.log = log
        }

        func authorization() async -> ReminderAuthorization { state }

        func requestAuthorization() async -> Bool {
            guard state == .notDetermined else { return state == .allowed }
            append("ask")
            state = allows ? .allowed : .denied
            return allows
        }

        func schedule(_ requests: [ReminderNotificationRequest]) async {
            let wanted = Dictionary(requests.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for id in pending.keys where wanted[id] == nil {
                append("remove \(pending[id]?.title ?? id)")
            }
            for request in requests where pending[request.id] == nil {
                append("schedule \(request.title) | \(request.body)")
            }
            pending = wanted
        }

        func listen(opened: @escaping @MainActor (String) -> Void, presented: @escaping @MainActor (String) -> Void) {}

        private func append(_ line: String) {
            guard let log else { return }
            let data = Data((line + "\n").utf8)
            if let handle = try? FileHandle(forWritingTo: log) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: log)
            }
        }
    }
#endif
