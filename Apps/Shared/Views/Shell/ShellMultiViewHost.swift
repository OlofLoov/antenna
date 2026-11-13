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
    }
#endif
