import SwiftUI

extension ZapBar {
    /// What is on: title and times, progress, then "Next" and time left; or
    /// the guide's state line alone, with no progress or next programme.
    struct NowPlaying: View {
        enum Content: Equatable {
            case programme(title: String, times: String, progress: Double, next: String?, remaining: String)
            case message(String)
        }

        let content: Content

        var body: some View {
            switch content {
            case .programme(let title, let times, let progress, let next, let remaining):
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 24) {
                        Text(title)
                            .font(.system(size: 34, weight: .semibold))
                            .lineLimit(1)
                            .accessibilityIdentifier("zapBar.programme")
                        Spacer(minLength: 0)
                        Text(times)
                            .font(.system(size: 24).monospacedDigit())
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("zapBar.times")
                    }
                    Progress(fraction: progress)
                        .accessibilityIdentifier("zapBar.progress")
                    HStack(alignment: .firstTextBaseline, spacing: 24) {
                        if let next {
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text("NEXT")
                                    .font(.system(size: 18, weight: .semibold))
                                    .tracking(1.5)
                                    .foregroundStyle(Palette.textMuted)
                                Text(next)
                                    .font(.system(size: 24))
                                    .foregroundStyle(ChannelOverlay.tileText)
                                    .lineLimit(1)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("zapBar.next")
                        }
                        Spacer(minLength: 0)
                        Text(remaining)
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("zapBar.remaining")
                    }
                }
            case .message(let text):
                Text(text)
                    .font(.system(size: 30))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("zapBar.programme")
            }
        }
    }

    /// The 6 pt accent bar (design-system/a-current-programme-always-shows-its-progress).
    private struct Progress: View {
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

    /// The badges over the footer: LIVE with its dot, then the outlined
    /// quality badges; the catch-up days, a dot, and the browse hint.
    struct Status: View {
        /// "LIVE" first when playing, then picture and sound.
        let badges: [String]
        let catchUp: String?
        let hint: String

        var body: some View {
            VStack(alignment: .trailing, spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(badges, id: \.self) { badge in
                        if badge == "LIVE" {
                            HStack(spacing: 8) {
                                Circle().fill(Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255)).frame(width: 10, height: 10)
                                Text(badge)
                            }
                            .badge(filled: true)
                            .accessibilityIdentifier("zapBar.live")
                        } else {
                            Text(badge)
                                .badge(filled: false)
                                .accessibilityIdentifier("zapBar.quality")
                        }
                    }
                }
                HStack(spacing: 10) {
                    if let catchUp {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20))
                            .accessibilityHidden(true)
                        Text(catchUp)
                            .accessibilityIdentifier("zapBar.catchup")
                        Circle().fill(Palette.textMuted).frame(width: 4, height: 4)
                            .accessibilityHidden(true)
                    }
                    Text(hint)
                        .accessibilityIdentifier("zapBar.hint")
                }
                .font(.system(size: 20))
                .foregroundStyle(Palette.textMuted)
            }
        }
    }
}

extension View {
    /// A zap bar badge: 18 pt semibold, the LIVE one on the 0.12 surface,
    /// the quality ones outlined.
    fileprivate func badge(filled: Bool) -> some View {
        font(.system(size: 18, weight: .semibold))
            .tracking(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(filled ? Palette.text : ChannelOverlay.tileText)
            .background(filled ? Palette.surface(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(filled ? .clear : Palette.textMuted, lineWidth: 1.5))
    }
}

#Preview("Zap bar, a programme on now", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .bottom) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        ZapBar.Bar {
            ZapBar.ChannelIdentity(number: 104, name: "Sport One", position: "Sport · 4 of 42") {
                ZapBar.Initials(text: "S1")
            }
        } nowPlaying: {
            ZapBar.NowPlaying(
                content: .programme(
                    title: "Premier League: Arsenal v Liverpool", times: "20:00 – 22:00", progress: 0.78,
                    next: "22:00 · Match of the Day", remaining: "26 min left"))
        } status: {
            ZapBar.Status(badges: ["LIVE", "1080p", "AAC 5.1"], catchUp: "Catch-up 7 days", hint: "Press to browse channels")
        }
    }
}

#Preview("Zap bar, guide unavailable while buffering", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .bottom) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        ZapBar.Bar {
            ZapBar.ChannelIdentity(number: 104, name: "Sport One", position: "All channels · 131 of 1312") {
                ZapBar.Initials(text: "S1")
            }
        } nowPlaying: {
            ZapBar.NowPlaying(content: .message("Guide unavailable"))
        } status: {
            ZapBar.Status(badges: [], catchUp: nil, hint: "Press to browse channels")
        }
    }
}
