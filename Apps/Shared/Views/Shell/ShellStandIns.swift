#if os(tvOS)
    import AntennaCore
    import SwiftUI

    // Temporary screens for specs not built yet. Each goes when its spec
    // ships: the Guide with the guide grid, Movies and Series with their
    // browsing screens, Search with search, the channel picker with the
    // channel overlay.

    /// One focusable line. Holds focus without the Focus token, like the
    /// loading screen's holder.
    private struct StandInLine: View {
        let text: String
        let focus: FocusState<ShellFocus?>.Binding

        var body: some View {
            Text(text)
                .font(.system(size: 29))
                .foregroundStyle(Palette.textMuted)
                .focusable()
                .focusEffectDisabled()
                .focused(focus, equals: .content)
        }
    }

    /// Stands in for the guide grid. The picture sits in the board's
    /// 480 by 270 box (drawn by `ShellView`); the clock is the guide's.
    struct GuideStandIn: View {
        let date: Date
        let focus: FocusState<ShellFocus?>.Binding

        var body: some View {
            VStack(alignment: .leading, spacing: 40) {
                HStack(alignment: .top) {
                    Spacer()
                    Text(date, format: .dateTime.hour().minute())
                        .font(.system(size: 34, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.text)
                        .accessibilityIdentifier("guide.clock")
                }
                .frame(height: 270, alignment: .top)
                StandInLine(text: "The programme guide is not available yet.", focus: focus)
                    .accessibilityIdentifier("guide.standIn")
                Spacer()
            }
            .padding(.top, 54)
            .padding(.leading, 584)
            .padding(.trailing, 64)
        }
    }

    /// Stands in for Movies, Series or Search under the tab bar.
    struct ContentStandIn: View {
        let text: String
        let identifier: String
        let focus: FocusState<ShellFocus?>.Binding

        var body: some View {
            VStack(alignment: .leading) {
                StandInLine(text: text, focus: focus)
                    .accessibilityIdentifier(identifier)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 180)
            .padding(.leading, 64)
        }
    }

    /// Stands in for the channel overlay so the user can change
    /// channel: a list of loaded channels on the overlay scrim.
    struct ChannelPicker: View {
        let channels: [Channel]
        let focus: FocusState<ShellFocus?>.Binding
        let pick: (Channel) -> Void

        var body: some View {
            ZStack(alignment: .leading) {
                Palette.scrimTint.opacity(0.88).ignoresSafeArea()
                List(Array(channels.enumerated()), id: \.offset) { index, channel in
                    Button {
                        pick(channel)
                    } label: {
                        ChannelRow(channel: channel)
                    }
                    .focused(focus, equals: .picker(index))
                    .accessibilityIdentifier("overlay.channel.\(index)")
                }
                .frame(width: 700)
                .padding(.leading, 64)
                .accessibilityIdentifier("overlay.channels")
            }
        }
    }
#endif
