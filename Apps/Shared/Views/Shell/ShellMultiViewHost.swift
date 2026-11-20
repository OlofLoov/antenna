#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// Hosts multi-view over the Apple TV shell (tvos-shell/the-shell-hosts-multi-view):
    /// it covers Live with the tab bar hidden, removes tiles whose channel a
    /// refresh took away, and stops every tile when the shell goes, as when
    /// the paywall or "Who's watching?" replaces it.
    struct ShellMultiViewHost: ViewModifier {
        let model: ShellModel
        let catalogue: Catalogue<PersistentIdentifier>
        let guide: OverlayGuide
        let overlay: ChannelOverlayModel
        let focus: FocusState<ShellFocus?>.Binding
        let toggleFavorite: (Channel, RowKey) -> Void
        /// Multi-view handed a channel back to the shell.
        let ended: () -> Void

        func body(content: Content) -> some View {
            content
                .fullScreenCover(isPresented: presented, onDismiss: { focus.wrappedValue = model.liveFocus }) {
                    if let multiView = model.multiView {
                        MultiViewTVScreen(
                            model: multiView, catalogue: catalogue, guide: guide, overlay: overlay, toggleFavorite: toggleFavorite)
                    }
                }
                .onChange(of: model.channels) { _, _ in
                    Task { await model.multiViewChannelsChanged() }
                }
                .onChange(of: model.multiViewEnds) { _, _ in ended() }
                .onDisappear { model.multiView?.stopAll() }
        }

        /// Open while multi-view is; a dismissal from outside leaves it.
        private var presented: Binding<Bool> {
            Binding {
                model.multiView != nil
            } set: { shown in
                guard !shown, let multiView = model.multiView else { return }
                Task { await multiView.leave() }
            }
        }
    }

    /// What the overlay's catalogue is built from; it is rebuilt when either changes.
    struct ShellCatalogueInputs: Equatable {
        let channels: [Channel]
        let favorites: [PersistentIdentifier]
        let profile: UUID
        let rules: GroupRules
        let seen: [UUID: SeenChannels]

        /// When only the favorites changed since `old`, `current` with them
        /// swapped in, which keeps the channels indexed as they are; nil
        /// when the catalogue has to be built again.
        func swapped(
            after old: Self, current: Catalogue<PersistentIdentifier>, favorites: [FavoriteRecord]
        ) -> Catalogue<PersistentIdentifier>? {
            guard old != self, channels == old.channels, profile == old.profile, rules == old.rules, seen == old.seen else {
                return nil
            }
            return current.replacingFavorites(FavoriteRecord.snapshots(favorites, profile: profile))
        }

    }

    /// The shell's catalogue builds, away from the main actor. Only the
    /// newest build lands, with the recents of that moment.
    @MainActor final class ShellCatalogueBuilds {
        private var started = 0
        private var landed = 0

        /// True while a build has not landed, so a favorite changed now
        /// starts a new build instead of swapping into a catalogue about to be replaced.
        var isBuilding: Bool { landed < started }

        /// Builds the catalogue for `inputs`. `latestRecents` gives the
        /// recents when the build is done; `land` gets the catalogue.
        func start(
            _ inputs: ShellCatalogueInputs, favorites: [FavoriteSnapshot<PersistentIdentifier>], recents: [LastChannelKey],
            latestRecents: @escaping @MainActor () -> [LastChannelKey], land: @escaping @MainActor (Catalogue<PersistentIdentifier>) -> Void
        ) {
            started += 1
            let ticket = started
            let request = CatalogueInputs(
                channels: inputs.channels, favorites: favorites, recents: recents, rules: inputs.rules, seen: inputs.seen, now: .now)
            Task { [weak self] in
                let interval = BrowseSignposts.signposter.beginInterval("catalogue")
                var built = await request.catalogue()
                BrowseSignposts.signposter.endInterval("catalogue", interval)
                guard let self, ticket == started else { return }
                landed = ticket
                let recentsNow = latestRecents()
                if recentsNow != recents { built = built.replacingRecents(recentsNow) }
                land(built)
            }
        }
    }
#endif
