import AntennaCore
import SwiftUI

extension GuideBoard {
    /// The 160 pt "Filter" field at the start of the iPad and Mac toolbar.
    struct FilterField: View {
        @Binding var text: String

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityHidden(true)
                TextField("Filter", text: $text, prompt: Text("Filter").foregroundStyle(Palette.textMuted))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Filter channels")
                    .accessibilityIdentifier("guide.filter")
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Palette.textMuted)
                            .frame(width: 28, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                    .accessibilityIdentifier("guide.filter.clear")
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(Palette.text)
            .padding(.leading, 12)
            .padding(.trailing, text.isEmpty ? 12 : 2)
            .frame(width: 160, height: 36)
            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    /// The day chips, scrolling sideways: Today, then each later day the guide covers.
    struct Days<Chips: View>: View {
        @ViewBuilder var chips: Chips

        var body: some View {
            ScrollView(.horizontal) {
                HStack(spacing: 6) { chips }
            }
            .scrollIndicators(.hidden)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("guide.days")
        }
    }

    /// One day chip; the selected day is filled white. The chip is drawn 30
    /// pt high inside a 44 pt hit area.
    struct DayChip: View {
        let title: String
        let isSelected: Bool
        let select: () -> Void
        @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = 14

        var body: some View {
            Button(action: select) {
                Text(title)
                    .font(.system(size: size, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Palette.ground : Palette.text)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 14)
                    .background(isSelected ? Palette.focus : Palette.surface(0.08), in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    /// Now, with the accent dot: back to today around the current time.
    struct NowButton: View {
        let action: () -> Void
        @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = 14

        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Circle().fill(Palette.accent).frame(width: 8, height: 8)
                    Text("Now")
                }
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Palette.surface(0.08), in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("guide.now")
        }
    }

    /// Zoom out and zoom in, joined; each is off at its end of the four steps.
    struct ZoomButtons: View {
        let canZoomOut: Bool
        let canZoomIn: Bool
        let zoomOut: () -> Void
        let zoomIn: () -> Void

        var body: some View {
            HStack(spacing: 0) {
                button("minus", "Zoom out", "guide.zoomOut", canZoomOut, zoomOut)
                Rectangle().fill(Palette.surface(0.1)).frame(width: 1, height: 32)
                button("plus", "Zoom in", "guide.zoomIn", canZoomIn, zoomIn)
            }
            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 10))
        }

        private func button(_ image: String, _ label: String, _ id: String, _ on: Bool, _ act: @escaping () -> Void) -> some View {
            let identifier = id
            let enabled = on
            return Button(action: act) {
                Image(systemName: image)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(enabled ? Palette.text : Palette.textMuted.opacity(0.5))
                    .frame(width: 34, height: 32)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
        }
    }

    /// What plays in Live, at the toolbar's end: the tile, a red dot while
    /// it plays, "104 Sport One" and how far the programme has run. A tap
    /// goes back to Live.
    struct NowPlayingChip<Logo: View>: View {
        let channel: String
        let isPlaying: Bool
        let progress: Double?
        let open: () -> Void
        @ViewBuilder var logo: Logo

        var body: some View {
            Button(action: open) {
                HStack(spacing: 10) {
                    logo
                        .frame(width: 40, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if isPlaying {
                                Circle().fill(GuideBoard.liveDot).frame(width: 6, height: 6)
                            }
                            Text(channel).lineLimit(1)
                        }
                        .font(.system(size: 13))
                        ProgressTrack(fraction: progress ?? 0)
                            .opacity(progress == nil ? 0 : 1)
                            .accessibilityIdentifier("guide.nowPlaying.progress")
                    }
                    .frame(width: 128, alignment: .leading)
                }
                .foregroundStyle(Palette.text)
                .padding(.leading, 6)
                .padding(.trailing, 10)
                .frame(height: 36)
                .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 10))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Playing \(channel)" : channel)
            .accessibilityHint("Back to Live")
            .accessibilityIdentifier("guide.nowPlaying")
        }
    }

    /// The red of the live dot.
    static let liveDot = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)

    /// A 3 pt accent bar on a faint track.
    struct ProgressTrack: View {
        let fraction: Double

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Palette.surface(0.16))
                    Rectangle().fill(Palette.accent).frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 3)
            .clipShape(Capsule())
        }
    }
}

#Preview("Guide toolbar") {
    @Previewable @State var text = ""
    HStack(spacing: 12) {
        GuideBoard.FilterField(text: $text)
        GuideBoard.Days {
            GuideBoard.DayChip(title: "Today", isSelected: true) {}
            GuideBoard.DayChip(title: "Wed", isSelected: false) {}
            GuideBoard.DayChip(title: "Thu", isSelected: false) {}
        }
        GuideBoard.NowButton {}
        GuideBoard.ZoomButtons(canZoomOut: true, canZoomIn: false, zoomOut: {}, zoomIn: {})
        GuideBoard.NowPlayingChip(channel: "104 Sport One", isPlaying: true, progress: 0.78, open: {}) {
            GuideBoard.Initials(text: "S1", look: .playing)
        }
    }
    .padding()
    .background(Palette.ground)
}
