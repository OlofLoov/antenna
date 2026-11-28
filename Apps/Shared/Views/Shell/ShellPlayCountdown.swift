#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The banners over a page that can take the highlight: a reminder's,
    /// and the countdown for a request from a phone.
    struct ShellBanners: View {
        let model: ShellModel
        let catalogue: Catalogue<PersistentIdentifier>
        let overlay: ChannelOverlayModel
        let focus: FocusState<ShellFocus?>.Binding

        var body: some View {
            ZStack {
                ShellReminderBanner(model: model, catalogue: catalogue, overlay: overlay, focus: focus)
                ShellPlayCountdown(focus: focus)
            }
        }
    }

    /// The countdown over every Apple TV screen for a request the TV did not
    /// start at once (`TV-FromIPhone-Countdown`,
    /// play-on-apple-tv/the-tv-counts-down-a-waiting-request). Cancel takes
    /// focus when it appears, so one click stops it; Play now plays at once;
    /// Menu cancels. At zero the request plays with no press on the remote.
    /// Cancel puts focus back where it was; a play moves it as a request
    /// from the network does.
    struct ShellPlayCountdown: View {
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(PlayRequestInbox.self) private var inbox: PlayRequestInbox?
        @Environment(\.locale) private var locale
        @FocusState private var local: Target?
        @State private var before: ShellFocus?
        @State private var left = Int(PlayCountdown.length)

        enum Target: Hashable {
            case cancel, playNow
        }

        var body: some View {
            ZStack(alignment: .topTrailing) {
                if let inbox, let countdown = inbox.countdown {
                    let eyebrow = PlayOnText.from(countdown.request.senderName, locale: locale)
                    FromDeviceCountdown(
                        eyebrow: eyebrow, title: countdown.request.displayTitle, time: PlayOnText.startsIn(left, locale: locale)
                    ) {
                        ReminderBanner.TelevisionButton(title: "Cancel") { cancel() }
                            .focused($local, equals: .cancel)
                            .accessibilityIdentifier("playOn.countdown.cancel")
                        ReminderBanner.TelevisionButton(title: "Play now") { playNow() }
                            .focused($local, equals: .playNow)
                            .accessibilityIdentifier("playOn.countdown.playNow")
                    }
                    .focusSection()
                    .onExitCommand { cancel() }
                    .padding(.top, 60)
                    .padding(.trailing, 80)
                    .transition(.opacity)
                    .onAppear {
                        before = focus.wrappedValue
                        left = countdown.secondsLeft(at: .now)
                    }
                    .task(id: countdown.id) {
                        local = .cancel
                        let spoken: String = "\(eyebrow), \(countdown.request.displayTitle)"
                        AccessibilityNotification.Announcement(spoken).post()
                        var refocused = false
                        while !Task.isCancelled, inbox.countdown?.id == countdown.id {
                            let now = Date.now
                            left = countdown.secondsLeft(at: now)
                            // A tune landing as the banner appears can take the highlight back.
                            if !refocused, now.timeIntervalSince(countdown.started) > 0.5 {
                                refocused = true
                                if local == nil { local = .cancel }
                            }
                            if countdown.isDue(at: now) {
                                local = nil
                                inbox.tick(now: now)
                                return
                            }
                            try? await Task.sleep(for: .milliseconds(250))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }

        /// Cancel or Menu: the TV stays where it was and focus goes back.
        private func cancel() {
            let target = before
            local = nil
            inbox?.cancelCountdown()
            if let target { focus.wrappedValue = target }
        }

        private func playNow() {
            local = nil
            inbox?.playNow()
        }
    }
#endif
