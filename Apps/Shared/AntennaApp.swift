import AntennaCore
import SwiftUI
import SwiftData

@main
struct AntennaApp: App {
    /// One container, CloudKit-backed. The iCloud container id comes from the
    /// entitlements, so `.automatic` resolves to `iCloud.se.codecrave.antenna`.
    /// Profiles live inside it (profiles capability). A Debug build launched by a UI test gets
    /// the in-memory `UITestingStore`, `UITestingShell`, `UITestingScreenshots`
    /// or `UITestingLive` instead.
    private let container: ModelContainer
    /// Downloads and answers guide data for every screen (guide-data capability).
    @State private var guideStore: AppGuideStore
    /// Loads sources one at a time and keeps their status (sources-and-settings capability).
    @State private var refresher: SourceRefresher
    /// Whether the group locks are open on this device (group-management capability).
    @State private var locks = GroupLocks()
    /// Reminders on this device (programme-reminders capability).
    @State private var reminders: ReminderCenter
    #if !os(tvOS)
        /// Files shared to Antenna wait here, outside every gate, until a
        /// screen can show the import sheet (local-m3u-file-import/bring-a-file-in).
        @State private var inbox = ImportInbox()
    #endif
    /// Whether the app is unlocked, read before anything else (paywall-and-entitlement capability).
    @State private var unlock: Unlock

    init() {
        let container = Self.makeContainer()
        self.container = container
        PlaylistFileStore.shared.container = container
        // A profile deleted on another device leaves its per-device values here.
        let profiles = (try? container.mainContext.fetch(FetchDescriptor<ProfileRecord>())) ?? []
        ProfileKeys.prune(.standard, keeping: ProfileStore.list(profiles).profiles.map(\.id))
        ActivityStore.carryOverSearches(from: .standard, into: container.mainContext)
        // Buffers from an earlier run are deleted unread
        // (timeshift-catch-up-and-start-over/changing-channel-starts-fresh).
        TimeshiftStore.standard.clearLeftovers()
        let guideStore = AppGuideStore.live(container: container)
        _guideStore = State(initialValue: guideStore)
        _refresher = State(initialValue: SourceRefresher(Self.refresherDependencies(guide: guideStore)))
        _reminders = State(initialValue: Self.reminderCenter(container: container))
        _unlock = State(initialValue: Unlock.app())
    }

    private static func reminderCenter(container: ModelContainer) -> ReminderCenter {
        #if DEBUG
            UITestingReminders.seed(container)
            if let defaults = UITestingReminders.defaults() {
                return ReminderCenter(
                    context: container.mainContext, notifier: UITestingReminders.notifier() ?? systemNotifier(), defaults: defaults)
            }
        #endif
        return ReminderCenter(context: container.mainContext, notifier: systemNotifier())
    }

    /// The system's notification center; none on Apple TV.
    private static func systemNotifier() -> any ReminderNotifying {
        #if os(tvOS)
            NoReminderNotifications()
        #else
            SystemReminderNotifications()
        #endif
    }

    private static func refresherDependencies(guide: AppGuideStore) -> SourceRefresher.Dependencies {
        #if DEBUG
            if let scripted = UITestingLive.refresherDependencies() { return scripted }
        #endif
        return .app(loader: SourceLoader(), guide: guide)
    }

    private static func makeContainer() -> ModelContainer {
        #if DEBUG
            if let seeded = UITestingStore.container() { return seeded }
            if let seeded = UITestingShell.container() { return seeded }
            if let seeded = UITestingScreenshots.container() { return seeded }
            if let seeded = UITestingLive.container() { return seeded }
            if let seeded = UITestingShelf.container() { return seeded }
            if let empty = UITestingOnboarding.container() { return empty }
        #endif
        let schema = Schema(AntennaSchema.models)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(unlock: unlock) {
                PlatformRoot()
            }
            .environment(\.guideStore, guideStore)
            .environment(\.sourceRefresher, refresher)
            .environment(locks)
            .modifier(GroupLockTimers(locks: locks))
            .modifier(ReminderRuntime(center: reminders))
            // Behind the paywall no banner shows and Watch plays nothing
            // (programme-reminders/watch-plays-the-channel, the paid unlock has lapsed).
            .onChange(of: unlock.gate.applied.isUnlocked, initial: true) { _, unlocked in
                reminders.locked = !unlocked
            }
            #if !os(tvOS)
                .receivingFiles(into: inbox)
            #endif
        }
        .modelContainer(container)
    }
}
