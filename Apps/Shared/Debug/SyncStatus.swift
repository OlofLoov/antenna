#if DEBUG
    import CloudKit
    import CoreData
    import Foundation
    import Observation
    import os

    /// Debug builds only: what iCloud sync last did on this device, for the
    /// Sync status section in Settings and the `sync` log category. It keeps
    /// the last setup, import and export event the Core Data stack under
    /// SwiftData posts, with the error's domain, code and description, and
    /// the iCloud account's state. CloudKit is asked only when this build
    /// has a container, since making a `CKContainer` without the entitlement
    /// stops the app.
    @MainActor @Observable
    final class SyncStatus {
        static let shared = SyncStatus()

        nonisolated static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "se.codecrave.antenna", category: "sync")

        /// One setup, import or export, as last reported.
        struct Event: Equatable, Sendable {
            var kind: String
            var started: Date
            /// Nil while it runs.
            var ended: Date?
            var succeeded: Bool
            var failure: Failure?
        }

        /// An error by domain and code, with a partial failure's first inner error in its place.
        struct Failure: Equatable, Sendable {
            var domain: String
            var code: Int
            var description: String

            init(_ error: any Error) {
                var error = error as NSError
                let partial = error.domain == CKErrorDomain && error.code == CKError.Code.partialFailure.rawValue
                let inner = (error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: any Error])?.values.first
                if partial, let inner {
                    error = inner as NSError
                } else if error.domain != CKErrorDomain, let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                    error = underlying
                }
                domain = error.domain
                code = error.code
                description = error.localizedDescription
            }

            var line: String { "\(domain) \(code): \(description)" }
        }

        private(set) var setup: Event?
        private(set) var importing: Event?
        private(set) var exporting: Event?
        /// The iCloud account's state for the container, or why it is unknown.
        private(set) var account = "not asked"

        /// The container this build may reach; nil means no sync at all.
        var container: String? { CloudSync.container }
        /// True when iCloud Drive has an identity for the app. Shown next to
        /// the account so the two can be compared; nothing waits on it.
        var identityPresent: Bool { FileManager.default.ubiquityIdentityToken != nil }
        /// True when Play on and the login-drop sweep run: a container and an available account.
        var playOnEnabled: Bool { CloudAccount.shared.available }

        @ObservationIgnored private var observer: (any NSObjectProtocol)?

        /// Starts listening for sync events; later calls do nothing.
        func start() {
            guard observer == nil else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: nil
            ) { [weak self] notification in
                guard
                    let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event
                else { return }
                let recorded = Event(
                    kind: Self.kind(event.type), started: event.startDate, ended: event.endDate, succeeded: event.succeeded,
                    failure: event.error.map(Failure.init))
                Task { @MainActor in self?.record(recorded) }
            }
            let container = container ?? "none"
            let identity = identityPresent ? "present" : "missing"
            Self.logger.log("container \(container, privacy: .public), iCloud Drive identity \(identity, privacy: .public)")
            Task { await checkAccount() }
        }

        private func record(_ event: Event) {
            switch event.kind {
            case "setup": setup = event
            case "import": importing = event
            default: exporting = event
            }
            if event.ended == nil {
                Self.logger.log("\(event.kind, privacy: .public) started")
            } else if let failure = event.failure {
                Self.logger.error("\(event.kind, privacy: .public) failed: \(failure.line, privacy: .public)")
            } else {
                Self.logger.log("\(event.kind, privacy: .public) ended, succeeded \(event.succeeded, privacy: .public)")
            }
        }

        /// Asks CloudKit for the account's state, when this build has a container.
        func checkAccount() async {
            guard let container = CloudSync.container else {
                account = "no container in this build"
                Self.logger.log("account: no container in this build")
                return
            }
            do {
                let status = try await CKContainer(identifier: container).accountStatus()
                account = Self.name(status)
            } catch {
                account = "error \(Failure(error).line)"
            }
            await CloudAccount.shared.refresh()
            let playOn = playOnEnabled ? "on" : "off"
            Self.logger.log("account: \(self.account, privacy: .public), Play on \(playOn, privacy: .public)")
        }

        nonisolated private static func kind(_ type: NSPersistentCloudKitContainer.EventType) -> String {
            switch type {
            case .setup: "setup"
            case .import: "import"
            case .export: "export"
            @unknown default: "other"
            }
        }

        private static func name(_ status: CKAccountStatus) -> String {
            switch status {
            case .available: "available"
            case .noAccount: "no account"
            case .restricted: "restricted"
            case .couldNotDetermine: "could not determine"
            case .temporarilyUnavailable: "temporarily unavailable"
            @unknown default: "unknown \(status.rawValue)"
            }
        }
    }
#endif
