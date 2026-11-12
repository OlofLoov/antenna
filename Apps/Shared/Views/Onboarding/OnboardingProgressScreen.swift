import AntennaCore
import SwiftData
import SwiftUI

/// The loading checklist, then the summary, for the sources connected in
/// this onboarding (first-run-onboarding/the-checklist-shows-real-progress,
/// first-run-onboarding/a-summary-when-everything-has-loaded). On iPhone,
/// iPad and Mac they are one sheet; on Apple TV the summary replaces the
/// checklist with the first channel playing behind it.
struct OnboardingProgressScreen: View {
    let model: OnboardingModel
    let signedInToICloud: Bool
    let finish: (OnboardingHandoff.Request?) -> Void
    /// Called after Add another source resets the form.
    let addAnother: () -> Void
    @Environment(\.modelContext) private var context

    private var progress: OnboardingProgress { OnboardingProgress(setups: model.setups, signedIn: model.signedIn) }

    var body: some View {
        content
    }

    private var actions: OnboardingChecklist.Actions {
        OnboardingChecklist.Actions(
            primary: start,
            addAnother: progress.isEmpty
                ? nil
                : {
                    model.addAnother()
                    addAnother()
                })
    }

    /// Start watching plays the first channel; Browse movies opens Movies
    /// (first-run-onboarding/start-watching-without-waiting-for-the-guide).
    private func start() {
        switch progress.primary {
        case .browseMovies: finish(.movies)
        case .startWatching(true): finish(progress.firstChannel.map(OnboardingHandoff.Request.watch))
        case .startWatching(false): break
        }
    }

    /// Back from a provider with nothing: removes what its Connect saved
    /// and shows the form again (first-run-onboarding/a-provider-with-no-live-channels).
    private func back() {
        for setup in model.setups where setup.isEmpty {
            model.discard(setup, in: context)
        }
    }

    #if os(tvOS)
        @ViewBuilder private var content: some View {
            if model.allFinished, !progress.isEmpty {
                OnboardingSummary.Television(
                    eyebrow: progress.eyebrow, tiles: progress.tiles, liveCaption: progress.liveCaption,
                    footnote: footnote, primary: progress.primary, actions: actions
                ) {
                    if let channel = progress.firstChannel {
                        OnboardingPicture(channel: channel)
                    }
                }
            } else {
                OnboardingChecklist.Television(
                    title: progress.loadingTitle, lines: model.setups.flatMap { progress.lines(for: $0, .television) },
                    primary: progress.primary, caption: caption, start: start
                )
                .onExitCommand {
                    if progress.isEmpty { back() }
                }
            }
        }

        private var caption: String? {
            if progress.isEmpty { return "Press Menu to go back and check the link" }
            guard progress.primary == .startWatching(enabled: true) else { return nil }
            return model.setups.contains { !$0.guide.isFinished } ? "The guide keeps loading behind the picture" : nil
        }

        private var footnote: String {
            let hasLogin = model.setups.contains { $0.connection.login != nil }
            let base = model.setups.count > 1 ? "The sources sync" : "The source syncs"
            let sync =
                signedInToICloud
                ? "\(base) through iCloud to iPhone, iPad and Mac." : "Not signed in to iCloud, so it stays on this Apple TV."
            return hasLogin ? "\(sync) The login stays on this Apple TV." : sync
        }
    #else
        private var content: some View {
            let empty = progress.isEmpty
            return OnboardingChecklist.Phone(
                headline: headline, subtitle: subtitle, sections: progress.sections(.phone),
                footnote: signedInToICloud ? "Synced through iCloud. Antenna on Apple TV, iPad and Mac shows this source on its own." : nil,
                primary: progress.primary, actions: actions
            )
            .navigationTitle(empty ? (model.setups.last?.name ?? "") : progress.title)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationBarBackButtonHidden()
            .toolbar {
                if empty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back", action: back)
                            .accessibilityIdentifier("onboarding.back")
                    }
                }
            }
        }

        private var headline: String {
            if progress.isEmpty { return "Nothing to watch yet" }
            if model.setups.contains(where: \.hasLive) || model.allFinished { return "You're set" }
            return progress.loadingTitle
        }

        private var subtitle: String {
            if progress.isEmpty {
                return model.setups.contains { $0.connection.descriptor.kind == .m3u }
                    ? "The playlist has no channels. Go back and check the link."
                    : "The provider sent no channels, movies or series. Go back and check the details."
            }
            if model.allFinished { return "Everything has loaded." }
            return "Everything below is loading. The guide finishes in the background while you watch."
        }
    #endif
}

#if os(tvOS)
    /// The first channel playing full screen behind the Apple TV summary.
    /// Its engine stops when the summary goes; the shell then tunes the
    /// same channel on its own engine.
    private struct OnboardingPicture: View {
        let channel: Channel
        @State private var engine = RoutedEngine.app()

        var body: some View {
            PlayerSurfaceView(engine: engine)
                .accessibilityHidden(true)
                .task(id: channel) {
                    try? await engine.load(channel.streamURL, options: PlaybackOptions())
                    guard !Task.isCancelled else { return }
                    await engine.play()
                }
                .onDisappear {
                    Task { [engine] in await engine.stop() }
                }
        }
    }
#endif
