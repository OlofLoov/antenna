#if os(tvOS)
    import AntennaCore
    import SwiftUI

    // Temporary screens for specs not built yet. Each goes when its spec
    // ships: Search with search.

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

    /// Stands in for Search under the tab bar.
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
#endif
