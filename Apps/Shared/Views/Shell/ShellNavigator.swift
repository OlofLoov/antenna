import AntennaCore
import SwiftUI

/// A programme another screen asks the Guide to show.
struct ProgrammeKey: Hashable, Sendable {
    var guideKey: GuideKey
    var start: Date
}

/// How other screens send the user somewhere. The Apple TV shell provides
/// one, and so does the window root on iPhone, iPad and Mac. On Apple TV
/// each call closes the channel picker first.
struct ShellNavigator {
    enum Destination: Hashable, Sendable {
        case search
        /// The Guide, told which programme to show.
        case guide(programmeKey: ProgrammeKey)
    }

    var show: @MainActor (Destination) -> Void
    /// Live, full screen on Apple TV with no tab bar, for example after a tune.
    var showLive: @MainActor () -> Void
    /// Makes `group` the current group, the one Live and the Guide both show.
    var setGroup: @MainActor (CatalogueGroup) -> Void = { _ in }

    /// This navigator with `setGroup` replaced.
    func settingGroup(_ set: @escaping @MainActor (CatalogueGroup) -> Void) -> ShellNavigator {
        var copy = self
        copy.setGroup = set
        return copy
    }
}

#if os(iOS) || os(macOS)
    extension ShellNavigator {
        /// Where a window on iPhone, iPad or Mac can go.
        enum Place {
            case live, guide, search
        }

        /// The window root's navigator: `select` shows a place, the Guide
        /// opens at a programme through `guide`, and the group is Live's.
        @MainActor
        static func window(live: LiveModel, guide: GuideBoardModel, select: @escaping @MainActor (Place) -> Void) -> ShellNavigator {
            ShellNavigator(
                show: { destination in
                    switch destination {
                    case .search: select(.search)
                    case .guide(let programmeKey):
                        guide.request = programmeKey
                        select(.guide)
                    }
                },
                showLive: { select(.live) },
                setGroup: { live.show($0) })
        }

        /// Opens the Guide at a later programme Search picked
        /// (guide-on-iphone-ipad-and-mac/open-at-a-programme). False for a
        /// channel with no guide id, which has no place in the guide.
        @MainActor
        func showLater(_ programme: Programme, on channel: Channel) -> Bool {
            guard let key = GuideLookup.key(for: channel) else { return false }
            show(.guide(programmeKey: ProgrammeKey(guideKey: key, start: programme.start)))
            return true
        }
    }
#endif

#if os(iOS) || os(macOS)
    extension LiveSection {
        /// The sidebar section that shows `place`.
        init(_ place: ShellNavigator.Place) {
            switch place {
            case .live: self = .live
            case .guide: self = .guide
            case .search: self = .search
            }
        }
    }
#endif

#if os(tvOS)
    extension ShellNavigator {
        /// A navigator that forwards to `model`.
        @MainActor
        static func forwarding(to model: ShellModel) -> ShellNavigator {
            ShellNavigator(
                show: { destination in Task { await model.show(destination) } },
                showLive: { Task { await model.showLive() } }
            )
        }
    }
#endif

extension EnvironmentValues {
    /// Set once by `ShellView` on Apple TV and by the window root elsewhere.
    /// Nil outside them.
    @Entry var shellNavigator: ShellNavigator? = .none
}
