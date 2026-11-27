#if os(tvOS)
    import CloudKit
    import UIKit

    extension Notification.Name {
        /// iCloud says the `PlayRequests` zone changed; the TV looks for a waiting request.
        static let playRequestsChanged = Notification.Name("se.codecrave.antenna.playRequestsChanged")
    }

    /// Takes the silent push iCloud sends when a request lands in the
    /// `PlayRequests` zone (play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable).
    /// The `remote-notification` background mode and the push entitlement are
    /// already there for CloudKit.
    final class PlayOnAppDelegate: NSObject, UIApplicationDelegate {
        func application(
            _ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
        ) -> Bool {
            if CloudSync.container != nil { application.registerForRemoteNotifications() }
            return true
        }

        func application(
            _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]
        ) async -> UIBackgroundFetchResult {
            guard CKNotification(fromRemoteNotificationDictionary: userInfo)?.subscriptionID == CloudKitPlayRequests.subscriptionID
            else { return .noData }
            NotificationCenter.default.post(name: .playRequestsChanged, object: nil)
            return .newData
        }
    }
#endif
