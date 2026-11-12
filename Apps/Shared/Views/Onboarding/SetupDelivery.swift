import CoreData
import Foundation
import Observation

/// Whether a source saved on the iPhone has reached iCloud
/// (iphone-as-setup-device/the-iphone-says-what-to-check-when-sending-stalls,
/// iphone-as-setup-device/the-iphone-confirms-the-hand-off-to-icloud).
/// Only a successful upload that started at or after the save counts.
@MainActor @Observable
final class SetupDelivery {
    enum State: Equatable {
        /// "Sending to your Apple TV…"
        case sending
        /// "Handed to iCloud. Open Antenna on your Apple TV."
        case sent
        /// "Not sent yet" after 30 seconds without a confirmation.
        case notSent
        /// "Not sent yet" at once: this device is not signed in to iCloud.
        case notSignedIn
    }

    struct Dependencies {
        var identity: any ICloudIdentity
        var exports: any SyncEventSource
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        var timeout = Duration.seconds(30)
    }

    private(set) var state = State.sending
    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private let savedAt: Date

    init(savedAt: Date, dependencies: Dependencies) {
        self.savedAt = savedAt
        self.dependencies = dependencies
    }

    /// Follows the uploads until the task is cancelled.
    func run() async {
        let exports = dependencies.exports.successfulExports()
        guard await dependencies.identity.isSignedIn() else {
            state = .notSignedIn
            return await follow(exports)
        }
        let timer = Task { [dependencies, weak self] in
            guard (try? await dependencies.sleep(dependencies.timeout)) != nil else { return }
            if self?.state == .sending { self?.state = .notSent }
        }
        defer { timer.cancel() }
        await follow(exports)
    }

    private func follow(_ exports: AsyncStream<DateInterval>) async {
        for await export in exports where export.start >= savedAt {
            state = .sent
            return
        }
    }
}

/// Successful uploads to iCloud, as the time each one ran.
@MainActor
protocol SyncEventSource {
    func successfulExports() -> AsyncStream<DateInterval>
}

/// The export events SwiftData's CloudKit container posts through
/// `NSPersistentCloudKitContainer.eventChangedNotification`. Whether
/// SwiftData posts them is one of the device checks in task 1.1.
struct CloudKitExportEvents: SyncEventSource {
    func successfulExports() -> AsyncStream<DateInterval> {
        AsyncStream { continuation in
            let task = Task {
                let name = NSPersistentCloudKitContainer.eventChangedNotification
                for await note in NotificationCenter.default.notifications(named: name) {
                    let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                    guard let event = note.userInfo?[key] as? NSPersistentCloudKitContainer.Event, event.type == .export,
                        event.succeeded, let end = event.endDate
                    else { continue }
                    continuation.yield(DateInterval(start: event.startDate, end: max(end, event.startDate)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Uploads that a test sends with `export(_:)`.
@MainActor
final class ScriptedExports: SyncEventSource {
    private var continuations: [AsyncStream<DateInterval>.Continuation] = []

    func successfulExports() -> AsyncStream<DateInterval> {
        let (stream, continuation) = AsyncStream.makeStream(of: DateInterval.self)
        continuations.append(continuation)
        return stream
    }

    func export(_ interval: DateInterval) {
        continuations.forEach { $0.yield(interval) }
    }
}

extension SetupDelivery.Dependencies {
    /// CloudKit, or a scripted iCloud and upload in a Debug build launched for UI tests.
    @MainActor static var app: Self {
        #if DEBUG
            if let scripted = UITestingSetup.deliveryDependencies() { return scripted }
        #endif
        return .init(identity: CloudKitIdentity(), exports: CloudKitExportEvents())
    }
}
