import AntennaCore
import SwiftData
import SwiftUI

/// Keeps the reminder center current at the window root: it reads the
/// stored reminders again when they change here or through iCloud, follows
/// guide updates, deletes ended reminders, checks notification permission
/// on each return to the front, and wakes when the next reminder is due.
struct ReminderRuntime: ViewModifier {
    let center: ReminderCenter
    @Query private var records: [ReminderRecord]
    @Environment(\.guideStore) private var guideStore
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .environment(\.reminders, center)
            .onChange(of: records.compactMap(\.reminder), initial: true) { _, _ in center.reload() }
            .onChange(of: guideStore?.index.programmeCount ?? 0) { _, _ in
                if let index = guideStore?.index { center.follow(index) }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                center.active = phase == .active
                guard phase == .active else { return }
                center.tidy()
                Task { await center.refreshAuthorization() }
            }
            .task {
                while !Task.isCancelled {
                    let wait = center.nextWake().map { max(0.5, min(30, $0.timeIntervalSinceNow + 0.1)) } ?? 30
                    try? await Task.sleep(for: .seconds(wait))
                    center.reload()
                }
            }
    }
}
