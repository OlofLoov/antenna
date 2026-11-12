import AntennaCore
import SwiftData
import SwiftUI

/// Sources and Settings on every platform (sources-and-settings capability;
/// `iPhone-Settings`, `iPad-Settings`, `TV-Settings`): the sources in the
/// user's order with their status, Add a source, Refresh all, the iCloud
/// note, Profiles, Preferences and About.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.sourceRefresher) private var refresher
    @Environment(\.guideStore) private var guideStore
    @Query(sort: SourceRecord.displayOrder) private var sources: [SourceRecord]
    @Query private var preferenceRecords: [PreferencesRecord]
    @State private var showingAdd = false
    @State private var path: [UUID] = []
    @State private var deleting: SourceRecord?
    @State private var signedInToICloud = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ProfileSettingsRow()
                }
                sourcesSection
                PreferencesSection(preferences: PreferencesStore.current(preferenceRecords), offersMovies: offersMovies) { changed in
                    PreferencesStore.save(changed, in: context)
                }
                Section("About") {
                    LabeledContent("Version", value: Self.version)
                        .accessibilityIdentifier("settings.version")
                    NavigationLink("FFmpeg") { FFmpegNoticeView() }
                        .accessibilityIdentifier("settings.ffmpegNotice")
                }
            }
            .navigationTitle("Sources & Settings")
            #if os(iOS)
                .toolbar { EditButton().accessibilityIdentifier("settings.edit") }
            #endif
            .navigationDestination(for: UUID.self) { id in
                SourceDetailsScreen(id: id, signedInToICloud: signedInToICloud) { record in delete(record) }
            }
            .sheet(isPresented: $showingAdd) {
                SettingsAddSource()
            }
            .deleteSourceConfirmation($deleting, signedInToICloud: signedInToICloud) { record in delete(record) }
            .task { signedInToICloud = ICloudAccount.isSignedIn() }
        }
    }

    // MARK: Sources

    private var sourcesSection: some View {
        Section {
            ForEach(sources) { source in
                NavigationLink(value: source.id) {
                    // Relative times move on each minute.
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        SourceRowLabel(
                            name: source.name, kind: source.kind, lines: lines(for: source, now: timeline.date), metrics: metrics)
                    }
                }
                .accessibilityIdentifier("settings.source.\(source.id.uuidString)")
                #if !os(tvOS)
                    .swipeActions {
                        Button("Delete", role: .destructive) { deleting = source }
                    }
                #endif
            }
            .onMove(perform: move)
            Button("Add a source") { showingAdd = true }
                .accessibilityIdentifier("settings.addSource")
            Button(refreshAllTitle) { refresher?.refresh(sources.map(\.id)) }
                .disabled(sources.isEmpty)
                .accessibilityIdentifier("settings.refreshAll")
        } header: {
            Text("Sources")
        } footer: {
            Text(
                signedInToICloud
                    ? "Sources sync to your other devices through iCloud. "
                        + "Logins sync through iCloud Keychain when it is on, and never to Apple TV."
                    : "Not signed in to iCloud. Sources stay on this device."
            )
            .accessibilityIdentifier("settings.iCloudFooter")
        }
    }

    private var refreshAllTitle: String {
        #if os(tvOS)
            "Refresh all sources"
        #else
            "Refresh all"
        #endif
    }

    private var metrics: SourceRowLabel.Metrics {
        #if os(tvOS)
            .television
        #else
            .phone
        #endif
    }

    private var offersMovies: Bool { sources.contains { $0.kind == .xtream } }

    private func lines(for source: SourceRecord, now: Date) -> [SourceStatusText.Line] {
        #if os(tvOS)
            let text = SourceStatusText(television: true)
        #else
            let text = SourceStatusText()
        #endif
        return text.rowLines(Self.status(of: source, refresher: refresher), now: now)
    }

    /// A record's status: waiting for iCloud without a link, the Stalker
    /// line for a portal, otherwise what the refresher knows.
    static func status(of source: SourceRecord, refresher: SourceRefresher?) -> SourceStatus {
        if source.url == nil { return SourceStatus(load: .waitingForICloud) }
        if source.kind == .stalker { return SourceStatus(load: .unsupported) }
        return refresher?.status(of: source.id) ?? SourceStatus()
    }

    /// Dragging or Move up and Move down: every source gets its position
    /// as its sort order, and the channels follow without a reload
    /// (sources-and-settings/put-sources-in-your-order).
    private func move(from offsets: IndexSet, to destination: Int) {
        var ordered = sources
        ordered.move(fromOffsets: offsets, toOffset: destination)
        SourceOrder.apply(ordered, in: context)
    }

    private func delete(_ record: SourceRecord) {
        path.removeAll { $0 == record.id }
        let removal = SourceRemoval(guide: guideStore, refresher: refresher)
        Task { await removal.delete(record, in: context) }
        deleting = nil
    }

    /// "Version 1.0 (4)" without the word, as the row's label says it.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }
}

/// Writes the sources' sort order.
@MainActor
enum SourceOrder {
    static func apply(_ ordered: [SourceRecord], in context: ModelContext) {
        for (index, record) in ordered.enumerated() where record.sortOrder != index {
            record.sortOrder = index
        }
        try? context.save()
    }

    /// Moves `record` one place up or down among `sources`.
    static func move(_ record: SourceRecord, by step: Int, among sources: [SourceRecord], in context: ModelContext) {
        guard let index = sources.firstIndex(where: { $0.id == record.id }) else { return }
        let target = index + step
        guard sources.indices.contains(target) else { return }
        var ordered = sources
        ordered.swapAt(index, target)
        apply(ordered, in: context)
    }
}

/// Open on launch, Guide window, Refresh sources and, on Apple TV, the swipe.
private struct PreferencesSection: View {
    let preferences: AppPreferences
    let offersMovies: Bool
    let change: (AppPreferences) -> Void

    var body: some View {
        Section("Preferences") {
            // A stored Movies reads as Live where Movies is not offered, without a write.
            Picker("Open on launch", selection: launchBinding) {
                ForEach(AppPreferences.LaunchScreen.allCases.filter { $0 != .movies || offersMovies }, id: \.self) { screen in
                    Text(screen.title).tag(screen)
                }
            }
            .accessibilityIdentifier("settings.openOnLaunch")
            Picker("Guide window", selection: binding(\.guideHours)) {
                ForEach(AppPreferences.guideHours, id: \.self) { hours in
                    Text(AppPreferences.hoursTitle(hours)).tag(hours)
                }
            }
            .accessibilityIdentifier("settings.guideWindow")
            Picker("Refresh sources", selection: binding(\.refresh)) {
                ForEach(AppPreferences.RefreshInterval.ordered, id: \.self) { interval in
                    Text(interval.title).tag(interval)
                }
            }
            .accessibilityIdentifier("settings.refreshSources")
            #if os(tvOS)
                Picker("Swipe up or down while watching", selection: binding(\.swipe)) {
                    ForEach(AppPreferences.Swipe.allCases, id: \.self) { swipe in
                        Text(swipe.title).tag(swipe)
                    }
                }
                .accessibilityIdentifier("settings.swipe")
            #endif
        }
    }

    private var launchBinding: Binding<AppPreferences.LaunchScreen> {
        Binding(get: { preferences.launchScreen(offersMovies: offersMovies) }, set: { binding(\.openOnLaunch).wrappedValue = $0 })
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { preferences[keyPath: keyPath] },
            set: { value in
                var changed = preferences
                changed[keyPath: keyPath] = value
                change(changed)
            })
    }
}

extension View {
    /// "Delete <name>?" with what goes, Delete and Cancel
    /// (sources-and-settings/delete-a-source-and-everything-that-came-with-it).
    func deleteSourceConfirmation(
        _ record: Binding<SourceRecord?>, signedInToICloud: Bool, delete: @escaping (SourceRecord) -> Void
    ) -> some View {
        modifier(DeleteSourceConfirmation(record: record, signedInToICloud: signedInToICloud, delete: delete))
    }
}

private struct DeleteSourceConfirmation: ViewModifier {
    @Binding var record: SourceRecord?
    let signedInToICloud: Bool
    let delete: (SourceRecord) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.sourceRefresher) private var refresher

    func body(content: Content) -> some View {
        content.alert(
            record.map { SourceRemoval.title(name: $0.name) } ?? "",
            isPresented: Binding(get: { record != nil }, set: { if !$0 { record = nil } }), presenting: record
        ) { shown in
            Button("Delete", role: .destructive) { delete(shown) }
                .accessibilityIdentifier("settings.confirmDelete")
            Button("Cancel", role: .cancel) {}
        } message: { shown in
            Text(
                SourceRemoval.message(
                    channels: refresher?.status(of: shown.id).channels, favorites: SourceRemoval.favorites(of: shown.id, in: context),
                    signedInToICloud: signedInToICloud))
        }
    }
}

#if os(iOS) || os(macOS)
    extension LiveSection {
        /// The section the launch preference opens over the restored one, after
        /// onboarding's Browse movies; nil for Live (sources-and-settings/choose-how-the-app-behaves).
        @MainActor static func launch(_ records: [PreferencesRecord], hasXtream: Bool) -> LiveSection? {
            LiveSection(PreferencesStore.current(records).launchScreen(offersMovies: hasXtream))
        }

        /// The sidebar section a launch preference other than Live opens; nil for Live.
        init?(_ screen: AppPreferences.LaunchScreen) {
            switch screen {
            case .live: return nil
            case .guide: self = .guide
            case .movies: self = .movies
            }
        }
    }
#endif
