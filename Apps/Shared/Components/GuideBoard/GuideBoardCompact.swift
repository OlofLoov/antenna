import AntennaCore
import SwiftUI

extension GuideBoard {
    /// The iPhone guide's rows (guide-on-iphone-ipad-and-mac/one-row-per-channel-on-iphone;
    /// `iPhone-Guide`, `iPhone-Guide-Placeholders`): a header line per
    /// channel over a strip of 168 by 54 pt cards.
    enum Compact {
        /// Tile, number and name on one line. A tap plays the channel.
        struct RowHeader<Logo: View>: View {
            let number: Int?
            let name: String
            let look: ChannelLook
            let watch: () -> Void
            @ViewBuilder var logo: Logo
            @ScaledMetric(relativeTo: .subheadline) private var nameSize: CGFloat = 15
            @ScaledMetric(relativeTo: .footnote) private var numberSize: CGFloat = 13

            var body: some View {
                Button(action: watch) {
                    HStack(spacing: 8) {
                        logo
                            .frame(width: 30, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        if let number {
                            Text(String(number))
                                .font(.system(size: numberSize))
                                .monospacedDigit()
                                .foregroundStyle(Palette.textMuted)
                        }
                        Text(name)
                            .font(.system(size: nameSize, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Plays the channel")
            }
        }

        /// A channel's initials on the small 30 by 20 pt tile.
        struct Initials: View {
            let text: String
            let look: ChannelLook

            var body: some View {
                Text(text)
                    .font(.system(size: 9, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(look == .playing ? Palette.text : Browse.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(look == .playing ? Browse.tileSelected : Browse.tile)
            }
        }

        /// A programme card: the start time, NOW on the card that is on, the
        /// title, and a progress bar along the bottom of the card on now.
        struct Card: View {
            let time: String
            let title: String
            let timing: GuideTiming
            let progress: Double?
            @ScaledMetric(relativeTo: .subheadline) private var titleSize: CGFloat = 14
            @ScaledMetric(relativeTo: .caption) private var timeSize: CGFloat = 12

            var body: some View {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(time)
                            .font(.system(size: timeSize))
                            .monospacedDigit()
                            .foregroundStyle(Palette.textMuted)
                        if timing == .now {
                            Text("NOW")
                                .font(.system(size: 11, weight: .bold))
                                .kerning(1)
                                .foregroundStyle(Palette.ground)
                                .padding(.vertical, 1)
                                .padding(.horizontal, 5)
                                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text(title)
                        .font(.system(size: titleSize))
                        .lineLimit(1)
                        .foregroundStyle(timing == .past ? Palette.textMuted : Palette.text)
                }
                .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                .frame(width: GuideStrip.cardWidth, alignment: .topLeading)
                .frame(minHeight: GuideStrip.cardHeight, alignment: .topLeading)
                .background(Palette.surface(0.08))
                .overlay(alignment: .bottom) {
                    if let progress {
                        ProgressTrack(fraction: progress)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
        }

        /// A gap between two programmes: just the times, muted.
        struct GapCard: View {
            let times: String
            @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 12

            var body: some View {
                Text(times)
                    .font(.system(size: size))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textMuted)
                    .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                    .frame(width: GuideStrip.cardWidth, alignment: .topLeading)
                    .frame(minHeight: GuideStrip.cardHeight, alignment: .topLeading)
                    .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }

        /// "Loading guide…", "No programme information" or "Guide unavailable"
        /// in place of the cards.
        struct Placeholder: View {
            let text: String
            @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 14

            var body: some View {
                Text(text)
                    .font(.system(size: size))
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: GuideStrip.cardHeight, alignment: .leading)
                    .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
            }
        }

        /// The bar above the tab bar while a channel plays in Live: the
        /// tile, the programme, "104 Sport One · 26 min left", LIVE with a
        /// red dot while it plays, and a 3 pt progress bar along the top.
        struct NowPlayingBar<Logo: View>: View {
            let title: String
            let detail: String
            let isPlaying: Bool
            let progress: Double?
            let open: () -> Void
            @ViewBuilder var logo: Logo

            var body: some View {
                Button(action: open) {
                    HStack(spacing: 12) {
                        logo
                            .frame(width: 44, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            Text(detail)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if isPlaying {
                            HStack(spacing: 5) {
                                Circle().fill(GuideBoard.liveDot).frame(width: 6, height: 6)
                                Text("LIVE")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(1)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 7)
                            .background(Palette.surface(0.14), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Palette.tabBar)
                    .overlay(alignment: .top) {
                        ProgressTrack(fraction: progress ?? 0)
                            .opacity(progress == nil ? 0 : 1)
                            .accessibilityIdentifier("guide.nowPlaying.progress")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Back to Live")
                .accessibilityIdentifier("guide.nowPlaying")
            }
        }
    }
}

#Preview("Guide rows") {
    VStack(alignment: .leading, spacing: 6) {
        GuideBoard.Compact.RowHeader(number: 104, name: "Sport One", look: .playing, watch: {}) {
            GuideBoard.Compact.Initials(text: "S1", look: .playing)
        }
        HStack(spacing: GuideStrip.spacing) {
            GuideBoard.Compact.Card(time: "20:00", title: "Premier League: Arsenal v Liverpool", timing: .now, progress: 0.78)
            GuideBoard.Compact.GapCard(times: "22:00 – 22:15")
            GuideBoard.Compact.Card(time: "22:15", title: "Match of the Day", timing: .future, progress: nil)
        }
        .padding(.horizontal, 16)
        GuideBoard.Compact.Placeholder(text: GuideLine.loading)
        Spacer()
        GuideBoard.Compact.NowPlayingBar(
            title: "Premier League: Arsenal v Liverpool", detail: "104 Sport One · 26 min left", isPlaying: true, progress: 0.78, open: {}
        ) {
            GuideBoard.Compact.Initials(text: "S1", look: .playing)
        }
    }
    .frame(width: 390, height: 400)
    .background(Palette.ground)
}
