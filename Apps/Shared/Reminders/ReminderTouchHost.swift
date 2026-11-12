import AntennaCore
import SwiftUI

#if os(iOS) || os(macOS)
    extension View {
        /// The reminder banner over the window's tabs or columns, and Watch
        /// from a banner or a notification playing in Live
        /// (programme-reminders/watch-plays-the-channel).
        func reminderBanner(
            live: LiveModel, watch: @escaping @MainActor (Channel) -> Void, showLive: @escaping @MainActor () -> Void
        ) -> some View {
            modifier(ReminderTouchHost(live: live, watch: watch, showLive: showLive))
        }
    }

    /// On iPhone the banner spans the top with 12 pt margins; on iPad and
    /// Mac it is 400 pt wide at the top trailing corner, 16 pt in. It closes
    /// on Dismiss, a swipe up, or after 20 seconds.
    private struct ReminderTouchHost: ViewModifier {
        let live: LiveModel
        let watch: @MainActor (Channel) -> Void
        let showLive: @MainActor () -> Void
        @Environment(\.reminders) private var reminders
        #if os(iOS)
            @Environment(\.horizontalSizeClass) private var sizeClass
        #endif

        func body(content: Content) -> some View {
            content
                .overlay(alignment: compact ? .top : .topTrailing) { banner }
                .animation(.easeOut(duration: 0.2), value: reminders?.banner)
                .onChange(of: reminders?.watchRequest, initial: true) { _, _ in resolve() }
                .onChange(of: live.channels.count) { _, _ in resolve() }
                .onChange(of: live.sources) { _, _ in resolve() }
        }

        @ViewBuilder private var banner: some View {
            if let reminders, let shown = reminders.banner {
                ReminderBanner.Touch(content: ReminderBannerText.content(shown, catalogue: live.catalogue)) {
                    reminders.watchBanner()
                } dismiss: {
                    reminders.dismissBanner()
                }
                .frame(maxWidth: compact ? .infinity : 400)
                .padding(compact ? 12 : 16)
                .gesture(
                    DragGesture(minimumDistance: 10).onEnded { drag in
                        if drag.translation.height < -20 { reminders.dismissBanner() }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: shown.key) {
                    try? await Task.sleep(for: .seconds(ReminderBannerText.timeout))
                    if reminders.banner?.key == shown.key { reminders.dismissBanner() }
                }
            }
        }

        /// Plays the asked-for channel once it is loaded, switching to All
        /// channels when the group on screen lacks it. Live opens at once;
        /// with the channel gone and every source settled, nothing plays.
        private func resolve() {
            guard let reminders, let key = reminders.watchRequest else { return }
            let channels = live.catalogue.rows(in: .all).compactMap(live.catalogue.channel(for:))
            if let channel = channels.first(where: { GuideKey(channel: $0) == key }) {
                reminders.watchRequest = nil
                watch(channel)
                return
            }
            showLive()
            guard !live.sources.isEmpty, !live.sources.contains(where: { $0.state == .loading }) else { return }
            reminders.watchRequest = nil
        }

        private var compact: Bool {
            #if os(iOS)
                sizeClass == .compact
            #else
                false
            #endif
        }
    }
#endif

/// What the banner says about a reminder, with the channel's number when the catalogue has it.
enum ReminderBannerText {
    @MainActor
    static func content<Token: Hashable & Sendable>(_ reminder: Reminder, catalogue: Catalogue<Token>) -> ReminderBanner.Content {
        let text = ReminderText()
        let row = catalogue.rows(in: .all).first { catalogue.channel(for: $0).flatMap(GuideKey.init(channel:)) == reminder.guideKey }
        let number = row.flatMap { catalogue.number(for: $0) ?? catalogue.channel(for: $0)?.number }
        return ReminderBanner.Content(
            eyebrow: text.bannerEyebrow(reminder, now: .now), title: reminder.title, body: text.bannerBody(reminder, number: number))
    }

    /// Twenty seconds, shorter in UI tests that ask.
    static var timeout: Double {
        #if DEBUG
            if let seconds = UITestingReminders.bannerSeconds { return seconds }
        #endif
        return 20
    }
}
