#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The reminder banner over every Apple TV screen, the only way a
    /// reminder shows there (programme-reminders/a-banner-while-antenna-is-open;
    /// `TV-Reminder-Banner`). Watch takes focus when it appears; Dismiss,
    /// Menu or 20 seconds close it and focus goes back where it was. Watch
    /// plays the channel full screen, switching the overlay's group to All
    /// channels when it lacks the channel (programme-reminders/watch-plays-the-channel).
    struct ShellReminderBanner: View {
        let model: ShellModel
        let catalogue: Catalogue<PersistentIdentifier>
        let overlay: ChannelOverlayModel
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(\.reminders) private var reminders
        @FocusState private var local: Target?
        @State private var before: ShellFocus?

        enum Target: Hashable {
            case watch, dismiss
        }

        var body: some View {
            ZStack(alignment: .topTrailing) {
                if let reminders, let shown = reminders.banner {
                    ReminderBanner.Television(content: ReminderBannerText.content(shown, catalogue: catalogue)) {
                        ReminderBanner.TelevisionButton(title: "Watch") { close { reminders.watchBanner() } }
                            .focused($local, equals: .watch)
                            .accessibilityIdentifier("reminders.banner.watch")
                        ReminderBanner.TelevisionButton(title: "Dismiss") { close { reminders.dismissBanner() } }
                            .focused($local, equals: .dismiss)
                            .accessibilityIdentifier("reminders.banner.dismiss")
                    }
                    .focusSection()
                    .onExitCommand { close { reminders.dismissBanner() } }
                    .padding(.top, 44)
                    .padding(.trailing, 64)
                    .transition(.opacity)
                    .onAppear { before = focus.wrappedValue }
                    .task(id: shown.key) {
                        local = .watch
                        try? await Task.sleep(for: .seconds(ReminderBannerText.timeout))
                        if reminders.banner?.key == shown.key { close { reminders.dismissBanner() } }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .onChange(of: reminders?.watchRequest) { _, _ in watch() }
        }

        /// Closes the banner and puts focus back where it was before.
        private func close(_ action: () -> Void) {
            let target = before
            local = nil
            action()
            if let target, reminders?.banner == nil { focus.wrappedValue = target }
        }

        private func watch() {
            guard let reminders, let key = reminders.watchRequest else { return }
            reminders.watchRequest = nil
            let rows = catalogue.rows(in: .all)
            guard let row = rows.first(where: { catalogue.channel(for: $0).flatMap(GuideLookup.key(for:)) == key }),
                let channel = catalogue.channel(for: row)
            else {
                Task {
                    await model.showLive()
                    focus.wrappedValue = model.liveFocus
                }
                return
            }
            let group = overlay.lastTuned ?? model.tuned.flatMap(catalogue.sourceGroup(of:)) ?? .all
            overlay.tuned(from: catalogue.rows(in: group).contains(row) ? group : .all)
            Task {
                await model.pickFromOverlay(channel)
                focus.wrappedValue = .picture
            }
        }
    }
#endif
