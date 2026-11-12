import AntennaCore
import SwiftUI

extension GuideBoard {
    /// A programme's details (guide-on-iphone-ipad-and-mac/read-about-a-programme):
    /// when and where it airs, the title, times and length, progress when it
    /// is on now, the description and Watch. The popover on iPad and Mac
    /// and the sheet on iPhone use the same parts at their own sizes.
    enum Details {
        /// The popover, 340 pt wide, with a close button beside the eyebrow.
        struct Popover: View {
            let details: GuidePanel.Details
            let watch: () -> Void
            let close: () -> Void

            var body: some View {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        Eyebrow(details: details)
                        Spacer(minLength: 0)
                        Button(action: close) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Palette.text)
                                .frame(width: 28, height: 28)
                                .background(Palette.surface(0.12), in: Circle())
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(-8)
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("guide.panel.close")
                    }
                    Texts(details: details, titleSize: 17, summarySize: 14)
                    WatchButton(height: 44, size: 15, watch: watch)
                        .padding(.top, 4)
                }
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
                .frame(width: 340, alignment: .leading)
                .foregroundStyle(Palette.text)
                .background(GuideBoard.panelGround)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("guide.panel")
            }
        }

        /// The sheet at the medium detent on iPhone, with a 50 pt Watch.
        struct Sheet: View {
            let details: GuidePanel.Details
            let watch: () -> Void

            var body: some View {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(details: details)
                        Texts(details: details, titleSize: 22, summarySize: 15)
                        WatchButton(height: 50, size: 17, watch: watch)
                            .padding(.top, 6)
                    }
                    .padding(EdgeInsets(top: 24, leading: 20, bottom: 20, trailing: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(Palette.text)
                .background(GuideBoard.panelGround)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("guide.panel")
            }
        }

        /// "Now · Sport One" in the accent, otherwise "Tue 20:00 · Sport One" muted.
        struct Eyebrow: View {
            let details: GuidePanel.Details

            var body: some View {
                Text(details.eyebrow)
                    .font(.system(size: 12, weight: .semibold))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(details.look == .now ? Palette.accent : Palette.textMuted)
                    .lineLimit(2)
                    .accessibilityIdentifier("guide.panel.eyebrow")
            }
        }

        /// Title, times and length, progress when on now, and the description.
        struct Texts: View {
            let details: GuidePanel.Details
            let titleSize: CGFloat
            let summarySize: CGFloat

            var body: some View {
                Text(details.title)
                    .font(.system(size: titleSize, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("guide.panel.title")
                if let meta = details.meta {
                    Text(meta)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityIdentifier("guide.panel.meta")
                }
                if let progress = details.progress {
                    Browse.ProgressBar(fraction: progress)
                        .accessibilityElement()
                        .accessibilityLabel("Progress")
                        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
                        .accessibilityIdentifier("guide.panel.progress")
                }
                if let summary = details.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: summarySize))
                        .lineSpacing(summarySize * 0.3)
                        .foregroundStyle(Browse.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("guide.panel.summary")
                }
            }
        }

        /// White Watch across the panel.
        struct WatchButton: View {
            let height: CGFloat
            let size: CGFloat
            let watch: () -> Void

            var body: some View {
                Button(action: watch) {
                    Text("Watch")
                        .font(.system(size: size, weight: .semibold))
                        .foregroundStyle(Palette.ground)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .background(Palette.text, in: RoundedRectangle(cornerRadius: height > 44 ? 12 : 10))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("guide.watch")
            }
        }
    }

    /// The details' ground.
    static let panelGround = Color(red: 0x16 / 255, green: 0x1B / 255, blue: 0x24 / 255)
}

private let previewDetails = GuidePanel.Details(
    eyebrow: "Now · Sport One", look: .now, title: "Premier League: Arsenal v Liverpool", meta: "20:00 – 22:00 · 2 h · Football",
    progress: 0.78, summary: "Second half from the Emirates. Commentary by the studio team, with analysis at full time.")

#Preview("Guide details popover") {
    GuideBoard.Details.Popover(details: previewDetails, watch: {}, close: {})
        .padding()
        .background(Palette.ground)
}

#Preview("Guide details sheet") {
    GuideBoard.Details.Sheet(details: previewDetails, watch: {})
        .frame(width: 390, height: 420)
        .background(Palette.ground)
}
