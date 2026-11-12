import SwiftUI

/// The reminder banner over any screen while Antenna is open
/// (programme-reminders/a-banner-while-antenna-is-open; `iPhone-Reminder-Banner`,
/// `TV-Reminder-Banner`): when it starts, the title, the time and channel,
/// Watch and Dismiss.
enum ReminderBanner {
    /// What the banner says.
    struct Content: Equatable {
        /// "Starts in 5 min".
        let eyebrow: String
        let title: String
        /// "22:00 · 104 Sport One".
        let body: String
    }

    /// iPhone, iPad and Mac: a card at the top. Watch is 36 pt tall with a
    /// 44 pt hit area (design.md deviation); Dismiss is a 44 pt cross.
    struct Touch: View {
        let content: Content
        let watch: () -> Void
        let dismiss: () -> Void

        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(content.eyebrow)
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.textMuted)
                    Text(content.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .accessibilityIdentifier("reminders.banner.title")
                    Text(content.body)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                        .accessibilityIdentifier("reminders.banner.body")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                Button(action: watch) {
                    Text("Watch")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ground)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(Palette.text, in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("reminders.banner.watch")
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.textMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -4)
                .padding(.horizontal, -8)
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("reminders.banner.dismiss")
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 12))
            .foregroundStyle(Palette.text)
            .background(Palette.tabBar, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.surface(0.08), lineWidth: 1))
            .shadow(color: Palette.focusShadow, radius: 16, y: 12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reminders.banner")
        }
    }

    /// Apple TV: 640 pt wide at the top right on the overlay's scrim, with
    /// Watch and Dismiss as 64 pt buttons. Watch takes focus when it appears.
    struct Television<Buttons: View>: View {
        let content: Content
        @ViewBuilder var buttons: Buttons

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Label("Reminder · \(content.eyebrow)", systemImage: "bell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.textMuted)
                Text(content.title)
                    .font(.system(size: 29, weight: .semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("reminders.banner.title")
                Text(content.body)
                    .font(.system(size: 22))
                    .foregroundStyle(ChannelOverlay.tileText)
                    .lineLimit(1)
                    .accessibilityIdentifier("reminders.banner.body")
                HStack(spacing: 14) { buttons }
                    .padding(.top, 4)
            }
            .padding(EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28))
            .frame(width: 640, alignment: .leading)
            .foregroundStyle(Palette.text)
            .background(Palette.scrimTint.opacity(0.88), in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: Palette.focusShadow, radius: 16, y: 12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reminders.banner")
        }
    }

    /// Watch or Dismiss on Apple TV: the white card with focus, 0.12 surface without.
    struct TelevisionButton: View {
        let title: String
        let action: () -> Void

        var body: some View {
            Button(title, action: action)
                .buttonStyle(TelevisionStyle())
        }
    }

    private struct TelevisionStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            TelevisionLabel(label: configuration.label)
        }
    }

    private struct TelevisionLabel<Label: View>: View {
        let label: Label
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .padding(.horizontal, 28)
                .frame(height: 64)
                .background(isFocused ? Palette.focus : Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }
}

private let previewContent = ReminderBanner.Content(eyebrow: "Starts in 5 min", title: "Match of the Day", body: "22:00 · 104 Sport One")

#Preview("Reminder banner, iPhone", traits: .fixedLayout(width: 390, height: 140)) {
    ReminderBanner.Touch(content: previewContent, watch: {}, dismiss: {})
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.ground)
}

#Preview("Reminder banner, Apple TV", traits: .fixedLayout(width: 800, height: 360)) {
    ReminderBanner.Television(content: previewContent) {
        ReminderBanner.TelevisionButton(title: "Watch") {}
        ReminderBanner.TelevisionButton(title: "Dismiss") {}
    }
    .padding(40)
    .background(Palette.ground)
}
