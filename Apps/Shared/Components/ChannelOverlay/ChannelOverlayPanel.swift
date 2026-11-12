import AntennaCore
import SwiftUI

extension ChannelOverlay {
    /// The programme on now, as the panel shows it.
    struct PanelNow: Equatable {
        let title: String
        /// "20:00 – 22:00 · 26 min left".
        let times: String
        let progress: Double
        let summary: String?
    }

    /// One programme that follows, as the panel lists it.
    struct PanelNext: Equatable, Identifiable {
        let time: String
        let title: String
        var id: String { time + title }
    }

    /// The now-and-next panel for the highlighted channel (`Main`): logo,
    /// name and badges; the programme on now with its times, time left,
    /// progress and description, or a line saying there is none; up to
    /// three programmes that follow, each drawn by `nextRow`; then Watch
    /// and the favorite button.
    struct Panel<Logo: View, NextRow: View, Buttons: View>: View {
        let name: String
        /// The channel number and the catch-up badge, in that order.
        let badges: [String]
        /// Nil shows `nothingOn` in its place.
        let now: PanelNow?
        let nothingOn: String
        let next: [PanelNext]
        /// "Changing tile 2 of 3" above the logo while a multi-view tile picks a channel.
        var eyebrow: String?
        @ViewBuilder var logo: Logo
        @ViewBuilder var nextRow: (PanelNext) -> NextRow
        @ViewBuilder var buttons: Buttons

        var body: some View {
            VStack(alignment: .leading, spacing: 28) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityIdentifier("overlay.pickTarget")
                }
                header
                nowSection
                if !next.isEmpty {
                    Rectangle().fill(Palette.surface(0.08)).frame(height: 1)
                    nextSection
                }
                Spacer(minLength: 0)
                HStack(spacing: 14) { buttons }
                    .tvFocusSection()
            }
            .padding(EdgeInsets(top: 48, leading: 40, bottom: 48, trailing: 48))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // The whole panel takes a move right from any row, so the
            // buttons at its foot are reached from the top of the list too.
            .tvFocusSection()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("overlay.panel")
        }

        private var header: some View {
            HStack(spacing: 24) {
                logo
                    .frame(width: 132, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("overlay.panel.logo")
                VStack(alignment: .leading, spacing: 8) {
                    Text(name)
                        .font(.system(size: 38, weight: .bold))
                        .lineLimit(1)
                    HStack(spacing: 10) {
                        ForEach(badges, id: \.self) { badge in
                            Text(badge)
                                .font(.system(size: 18, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(ChannelOverlay.tileText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.textMuted, lineWidth: 1.5))
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("overlay.panel.badges")
                }
            }
        }

        @ViewBuilder private var nowSection: some View {
            if let now {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("NOW")
                            .font(.system(size: 20, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Palette.accent)
                        Spacer(minLength: 12)
                        Text(now.times)
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("overlay.panel.remaining")
                    }
                    Text(now.title)
                        .font(.system(size: 32, weight: .semibold))
                        .lineLimit(2)
                        .accessibilityIdentifier("overlay.panel.now")
                    PanelProgress(fraction: now.progress)
                        .accessibilityIdentifier("overlay.panel.progress")
                    if let summary = now.summary {
                        Text(summary)
                            .font(.system(size: 24))
                            .lineSpacing(6)
                            .foregroundStyle(ChannelOverlay.tileText)
                            .lineLimit(4)
                            .accessibilityIdentifier("overlay.panel.summary")
                    }
                }
            } else {
                Text(nothingOn)
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("overlay.panel.now")
            }
        }

        private var nextSection: some View {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(next) { item in
                    nextRow(item)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("overlay.panel.next")
        }
    }

    /// A programme that follows, as text.
    struct NextLine: View {
        let item: PanelNext

        var body: some View {
            NextLabel(item: item, mark: nil)
                .padding(.vertical, 7)
                .accessibilityElement(children: .combine)
        }
    }

    /// A programme that follows as a row the remote reaches: select sets or
    /// removes its reminder (programme-reminders/set-a-reminder-in-one-tap).
    /// Focused, it says what select does; a set reminder shows a bell.
    struct NextReminderRow: View {
        let item: PanelNext
        let isSet: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                NextLabel(item: item, mark: isSet)
            }
            .buttonStyle(NextRowStyle())
            .accessibilityLabel("\(item.time) \(item.title)")
            .accessibilityValue(isSet ? ReminderText.reminderSet : ReminderText.remindMe)
        }
    }

    private struct NextLabel: View {
        let item: PanelNext
        /// Nil for a plain line; otherwise whether a reminder is set.
        let mark: Bool?
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text(item.time)
                    .font(.system(size: 22).monospacedDigit())
                    .foregroundStyle(isFocused ? ChannelOverlay.mutedOnFocus : Palette.textMuted)
                    .frame(width: 92, alignment: .leading)
                Text(item.title)
                    .font(.system(size: 26))
                    .lineLimit(1)
                Spacer(minLength: 12)
                if let mark, isFocused {
                    Text(mark ? ReminderText.reminderSet : ReminderText.remindMe)
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(1)
                }
                if mark == true {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private struct NextRowStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            NextRowCard(label: configuration.label)
        }
    }

    private struct NextRowCard<Label: View>: View {
        let label: Label
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(isFocused ? Palette.focus : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
                .padding(.horizontal, -12)
        }
    }

    private struct PanelProgress: View {
        let fraction: Double

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surface(0.16))
                    Capsule().fill(Palette.accent).frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
            .frame(height: 6)
            .accessibilityElement()
            .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
        }
    }

    /// Watch: tunes the highlighted channel. Multi-view's picker names the
    /// tile instead, "Show in tile 2".
    struct WatchButton: View {
        var title = "Watch"
        let watch: () -> Void

        var body: some View {
            Button(title, action: watch)
                .buttonStyle(PanelButtonStyle(width: nil))
        }
    }

    /// "Add to multi-view" over full-screen live, "Add as new tile" in the picker.
    struct MultiViewButton: View {
        let title: String
        let add: () -> Void

        var body: some View {
            Button(action: add) {
                Label(title, systemImage: "square.grid.2x2")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(PanelButtonStyle(width: nil))
        }
    }

    /// The star that adds or removes the highlighted channel from Favorites,
    /// labeled with what the next press does.
    struct FavoriteButton: View {
        let isFavorite: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 26))
            }
            .buttonStyle(PanelButtonStyle(width: 64))
            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
        }
    }

    private struct PanelButtonStyle: ButtonStyle {
        let width: CGFloat?

        func makeBody(configuration: Configuration) -> some View {
            PanelButtonLabel(label: configuration.label, width: width)
        }
    }

    private struct PanelButtonLabel<Label: View>: View {
        let label: Label
        let width: CGFloat?
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .padding(.horizontal, width == nil ? 28 : 0)
                .frame(width: width, height: 64)
                .background(isFocused ? Palette.focus : Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }
}

#Preview("Channel overlay panel, a programme on now", traits: .fixedLayout(width: 860, height: 1080)) {
    ChannelOverlay.Panel(
        name: "Sport One", badges: ["104", "CATCH-UP 7D"],
        now: .init(
            title: "Premier League: Arsenal v Liverpool", times: "20:00 – 22:00 · 26 min left", progress: 0.78,
            summary: "Second half from the Emirates. Commentary by the studio team, with analysis at full time."),
        nothingOn: "No programme information",
        next: [
            .init(time: "22:00", title: "Match of the Day"), .init(time: "23:15", title: "Sports Tonight"),
            .init(time: "00:00", title: "Replay: Premier League"),
        ]
    ) {
        ChannelOverlay.Initials(text: "S1")
    } nextRow: { item in
        ChannelOverlay.NextReminderRow(item: item, isSet: item.time == "22:00") {}
    } buttons: {
        ChannelOverlay.WatchButton {}
        ChannelOverlay.FavoriteButton(isFavorite: false) {}
        ChannelOverlay.MultiViewButton(title: "Add to multi-view") {}
    }
    .background(Palette.scrimTint)
}

#Preview("Channel overlay panel, picking for a multi-view tile", traits: .fixedLayout(width: 860, height: 1080)) {
    ChannelOverlay.Panel(
        name: "Arena HD", badges: ["106"], now: nil, nothingOn: "No programme information", next: [], eyebrow: "Changing tile 2 of 3"
    ) {
        ChannelOverlay.Initials(text: "ARN")
    } nextRow: { item in
        ChannelOverlay.NextLine(item: item)
    } buttons: {
        ChannelOverlay.WatchButton(title: "Show in tile 2") {}
        ChannelOverlay.FavoriteButton(isFavorite: false) {}
        ChannelOverlay.MultiViewButton(title: "Add as new tile") {}
    }
    .background(Palette.scrimTint)
}

#Preview("Channel overlay panel, nothing on now", traits: .fixedLayout(width: 860, height: 1080)) {
    ChannelOverlay.Panel(name: "Arena HD", badges: ["106"], now: nil, nothingOn: "No programme information", next: []) {
        ChannelOverlay.Initials(text: "AH")
    } nextRow: { item in
        ChannelOverlay.NextLine(item: item)
    } buttons: {
        ChannelOverlay.WatchButton {}
        ChannelOverlay.FavoriteButton(isFavorite: true) {}
    }
    .background(Palette.scrimTint)
}

extension ChannelOverlay {
    /// The muted 26 pt line centered in the channel column when the group
    /// has no channels; it takes no focus.
    struct EmptyGroup: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.system(size: 26))
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("overlay.emptyGroup")
        }
    }

    /// The outlined badge on a channel already in a multi-view tile.
    struct TileBadge: View {
        let text: String
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            let color = isFocused ? ChannelOverlay.mutedOnFocus : Palette.textMuted
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .tracking(1)
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(color, lineWidth: 1.5))
        }
    }
}

extension View {
    /// `focusSection()` on Apple TV; nothing elsewhere, where the panel only renders for previews.
    @ViewBuilder func tvFocusSection() -> some View {
        #if os(tvOS)
            focusSection()
        #else
            self
        #endif
    }
}
