#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The group rules and the passcode over the Apple TV shell
    /// (group-management capability): `rulesChanged` gets the rules from
    /// the records, and the prompt shows for a locked group picked in the
    /// overlay and over a channel that becomes locked while it plays.
    struct ShellGroupLocks: ViewModifier {
        let model: ShellModel
        let catalogue: Catalogue<PersistentIdentifier>
        let rulesChanged: (GroupRules) -> Void

        func body(content: Content) -> some View {
            content
                .modifier(GroupRulesFeed(changed: rulesChanged))
                .modifier(
                    GroupLockPrompt(
                        name: catalogue.label(of:), opened: { _ in },
                        playingIsLocked: model.tuned.flatMap(RowKey.init).map(catalogue.isLocked) ?? false,
                        playingName: model.tuned?.name ?? "This channel",
                        pause: { Task { await model.engine.pause() } },
                        resume: { Task { await model.engine.play() } },
                        leave: leave))
        }

        /// Plays the first channel the user may watch, or stops.
        private func leave() {
            let rows = catalogue.rows(in: catalogue.fallbackGroup) + catalogue.rows(in: .all)
            if let next = rows.lazy.compactMap(catalogue.channel(for:)).first {
                Task { await model.pick(next) }
            } else {
                Task { await model.engine.stop() }
            }
        }
    }
#endif
