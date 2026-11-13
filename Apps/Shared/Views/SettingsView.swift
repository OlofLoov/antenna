import AntennaCore
import SwiftData
import SwiftUI

/// Sources and Settings on every platform (sources-and-settings capability;
/// `iPhone-Settings`, `iPad-Settings`, `TV-Settings`): the sources in the
/// user's order with their status, Add a source, Refresh all, the iCloud
/// note, Profiles, Groups, Preferences and About.
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
    #if !os(tvOS)
        @State private var fileImport: FileImportAsk?
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ProfileSettingsRow()
                    GroupsSettingsRow()
                }
                sourcesSection
                Section {
                    RemindersSettingsRow()
                }
                PreferencesSection(preferences: PreferencesStore.current(preferenceRecords), offersMovies: offersMovies) { changed in
                    PreferencesStore.save(changed, in: context)
                }
                #if os(tvOS)
                    Section { RemoteHintsRow() }
                #endif
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
            .addSourcePresentation(isPresented: $showingAdd)
            .deleteSourceConfirmation($deleting, signedInToICloud: signedInToICloud) { record in delete(record) }
            .task { signedInToICloud = ICloudAccount.isSignedIn() }
            #if !os(tvOS)
                .playlistDropTarget { fileImport = FileImportAsk(dropped: $0) }
                .modifier(SettingsFileImport(ask: $fileImport))
            #endif
        }
        #if os(tvOS)
            .controlHints(.settings)
            .controlHintsLegend()
        #endif
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
            #if !os(tvOS)
                // local-m3u-file-import/bring-a-file-in
                Button("Import a file") { fileImport = FileImportAsk() }
                    .accessibilityIdentifier("import.pickFile")
            #endif
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

    /// Movies is a launch choice when a source offers titles
    /// (m3u-playlists/playlist-titles-show-on-every-platform).
    private var offersMovies: Bool { TitleOffer(records: sources, refresher: refresher).any }

    private func lines(for source: SourceRecord, now: Date) -> [SourceStatusText.Line] {
        #if os(tvOS)
            let text = SourceStatusText(television: true)
        #else
            let text = SourceStatusText()
        #endif
        return Self.fileLines(source) + text.rowLines(Self.status(of: source, refresher: refresher), now: now)
    }

    /// "Imported 3 November 2026 · home-playlist.m3u" for a file source,
    /// nothing for a link source (local-m3u-file-import/import-and-watch).
    static func fileLines(_ source: SourceRecord) -> [SourceStatusText.Line] {
        guard source.kind == .m3uFile else { return [] }
        let date = source.importedAt.map { "Imported \($0.formatted(date: .long, time: .omitted))" }
        let parts = [date, source.fileName].compactMap(\.self)
        return parts.isEmpty ? [] : [.init(parts.joined(separator: " · "))]
    }

    /// A record's status: waiting for iCloud without a link, otherwise what
    /// the refresher knows.
    static func status(of source: SourceRecord, refresher: SourceRefresher?) -> SourceStatus {
        if source.descriptor == nil { return SourceStatus(load: .waitingForICloud) }
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

/// Open on launch, Guide window, Refresh sources, on Apple TV the swipe, and Subtitles.
private struct PreferencesSection: View {
    let preferences: AppPreferences
    let offersMovies: Bool
    let change: (AppPreferences) -> Void

    var body: some View {
        Section {
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
            subtitlesPicker
        } header: {
            Text("Preferences")
        } footer: {
            // sources-and-settings/choose-when-subtitles-show
            Text(preferences.subtitles.explanation)
                .accessibilityIdentifier("settings.subtitles.footer")
        }
    }

    /// Off, Auto and Always; on Apple TV a list pushed with the current one ticked.
    private var subtitlesPicker: some View {
        Picker("Subtitles", selection: binding(\.subtitles)) {
            ForEach(SubtitleMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        #if os(tvOS)
            .pickerStyle(.navigationLink)
        #endif
        .accessibilityIdentifier("settings.subtitles")
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
        /// Movies opens Series when only series are offered.
        @MainActor static func launch(_ records: [PreferencesRecord], offer: TitleOffer) -> LiveSection? {
            LiveSection(PreferencesStore.current(records).launchScreen(offersMovies: offer.any), offer: offer)
        }

        /// The sidebar section a launch preference other than Live opens; nil for Live.
        init?(_ screen: AppPreferences.LaunchScreen, offer: TitleOffer) {
            switch screen {
            case .live: return nil
            case .guide: self = .guide
            case .movies: self = .titles(offer)
            }
        }
    }
#endif
