import AntennaCore
import SwiftData
import SwiftUI

/// What onboarding asks the app to open with when it closes: the first
/// channel playing (first-run-onboarding/start-watching-without-waiting-for-the-guide)
/// or Movies (first-run-onboarding/a-provider-with-no-live-channels). The
/// app takes the request once.
@MainActor @Observable
final class OnboardingHandoff {
    enum Request: Equatable {
        case watch(Channel)
        case movies
    }

    private(set) var request: Request?

    func hand(_ request: Request) {
        self.request = request
    }

    /// The channel to play, cleared once taken.
    func takeChannel() -> Channel? {
        guard case .watch(let channel) = request else { return nil }
        request = nil
        return channel
    }

    /// True once when Movies should open.
    func takeMovies() -> Bool {
        guard request == .movies else { return false }
        request = nil
        return true
    }
}

extension EnvironmentValues {
    /// Set by `OnboardingGate` around the app; nil in previews.
    @Entry var onboardingHandoff: OnboardingHandoff? = .none
}

#if os(tvOS)
    extension ShellModel {
        /// Opens Guide or Movies at launch when the preference says so; the
        /// launch tune picks the channel as before.
        func openOnLaunch(in context: ModelContext) {
            let sources = (try? context.fetch(FetchDescriptor<SourceRecord>())) ?? []
            let preferences = PreferencesStore.current(in: context)
            switch preferences.launchScreen(offersMovies: sources.contains { $0.kind == .xtream }) {
            case .live: break
            case .guide: Task { _ = await select(.guide) }
            case .movies: Task { _ = await select(.movies) }
            }
        }
    }

    extension OnboardingHandoff {
        /// Start watching tunes the shell to onboarding's first channel;
        /// Browse movies opens Movies.
        func apply(to shell: ShellModel) {
            if let channel = takeChannel() {
                shell.tune(channel)
            } else if takeMovies() {
                Task { _ = await shell.select(.movies) }
            }
        }
    }
#endif
