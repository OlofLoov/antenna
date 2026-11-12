import AntennaCore
import Foundation

#if !os(tvOS)
    import UserNotifications
#endif

/// Whether this device can notify (programme-reminders/the-app-says-when-reminders-cannot-notify).
enum ReminderAuthorization: Equatable, Sendable {
    case allowed
    case denied
    case notDetermined
    /// Apple TV, which has no notifications.
    case unavailable
}

/// One notification to keep pending. Its id holds the reminder's key, never a stream link.
struct ReminderNotificationRequest: Equatable, Sendable {
    var id: String
    var title: String
    var body: String
    var fireAt: Date

    static let prefix = "reminder."

    /// The reminder key's text from a request id, or nil for another app's id.
    static func key(fromID id: String) -> String? {
        id.hasPrefix(prefix) ? String(id.dropFirst(prefix.count)) : nil
    }
}

/// The notification center reminders schedule on. The app uses the
/// system's; UI tests use a scripted one, since the permission prompt
/// cannot be answered reliably from a test (design.md).
@MainActor
protocol ReminderNotifying: AnyObject {
    func authorization() async -> ReminderAuthorization
    /// Shows the system prompt once; true when the user allowed.
    func requestAuthorization() async -> Bool
    /// Keeps exactly `requests` pending among the reminder notifications.
    func schedule(_ requests: [ReminderNotificationRequest]) async
    /// Told the reminder key of a notification the user tapped, and of one
    /// that showed while Antenna was in front.
    func listen(opened: @escaping @MainActor (String) -> Void, presented: @escaping @MainActor (String) -> Void)
}

/// Apple TV: no notifications, so reminders show only as banners.
@MainActor
final class NoReminderNotifications: ReminderNotifying {
    func authorization() async -> ReminderAuthorization { .unavailable }
    func requestAuthorization() async -> Bool { false }
    func schedule(_ requests: [ReminderNotificationRequest]) async {}
    func listen(opened: @escaping @MainActor (String) -> Void, presented: @escaping @MainActor (String) -> Void) {}
}

#if !os(tvOS)
    /// The system notification center. Set as its delegate at launch, so a
    /// tap that opened the app is not missed.
    @MainActor
    final class SystemReminderNotifications: NSObject, ReminderNotifying, UNUserNotificationCenterDelegate {
        private let center = UNUserNotificationCenter.current()
        private var opened: (@MainActor (String) -> Void)?
        private var presented: (@MainActor (String) -> Void)?
        /// Taps that arrived before anyone listened.
        private var early: [String] = []

        override init() {
            super.init()
            center.delegate = self
        }

        func authorization() async -> ReminderAuthorization {
            switch await center.notificationSettings().authorizationStatus {
            case .authorized, .provisional, .ephemeral: .allowed
            case .denied: .denied
            case .notDetermined: .notDetermined
            @unknown default: .denied
            }
        }

        func requestAuthorization() async -> Bool {
            (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }

        func schedule(_ requests: [ReminderNotificationRequest]) async {
            let pending = await center.pendingNotificationRequests().filter {
                ReminderNotificationRequest.key(fromID: $0.identifier) != nil
            }
            let wanted = Set(requests.map(\.id))
            let stale = pending.map(\.identifier).filter { !wanted.contains($0) }
            if !stale.isEmpty { center.removePendingNotificationRequests(withIdentifiers: stale) }
            let current = Dictionary(
                pending.map { ($0.identifier, ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()) },
                uniquingKeysWith: { first, _ in first })
            for request in requests
            where current[request.id].flatMap(\.self).map({ abs($0.timeIntervalSince(request.fireAt)) >= 1 }) ?? true {
                try? await center.add(Self.system(request))
            }
        }

        func listen(opened: @escaping @MainActor (String) -> Void, presented: @escaping @MainActor (String) -> Void) {
            self.opened = opened
            self.presented = presented
            early.forEach(opened)
            early = []
        }

        private static func system(_ request: ReminderNotificationRequest) -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default
            let trigger: UNNotificationTrigger
            let seconds = request.fireAt.timeIntervalSinceNow
            if seconds < 60 {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
            } else {
                // Components in the current zone; the moment stays the same
                // because the zone is part of them
                // (programme-reminders/a-notification-before-the-programme-starts).
                let components = Calendar.current.dateComponents(
                    [.timeZone, .year, .month, .day, .hour, .minute, .second], from: request.fireAt)
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }
            return UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)
        }

        nonisolated func userNotificationCenter(
            _ center: UNUserNotificationCenter, willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            let id = notification.request.identifier
            guard let key = ReminderNotificationRequest.key(fromID: id) else { return [] }
            await MainActor.run { presented?(key) }
            return [.banner, .list, .sound]
        }

        nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
            guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
                let key = ReminderNotificationRequest.key(fromID: response.notification.request.identifier)
            else { return }
            await MainActor.run {
                if let opened { opened(key) } else { early.append(key) }
            }
        }
    }
#endif
