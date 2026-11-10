#if os(tvOS)
    import SwiftUI

    /// The Live tab's loading and empty screens under the tab bar
    /// (tvos-shell/a-loading-screen-at-launch, tvos-shell/an-empty-screen-with-retry).
    /// Nothing once a channel plays.
    struct ShellLiveLayer: View {
        let model: ShellModel
        let focus: FocusState<ShellFocus?>.Binding

        var body: some View {
            if model.tab == .live {
                switch model.liveScreen {
                case .playing:
                    EmptyView()
                case .loading:
                    ShellLoading.Screen(rows: model.sources.map(\.loadingRow))
                        .focusable()
                        .focusEffectDisabled()
                        .focused(focus, equals: .liveScreen)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("shell.loading")
                case .empty:
                    ShellEmpty.Screen(lines: model.sources.filter(\.state.addedNothing).map(\.emptyLine)) {
                        ShellEmpty.RetryButton {
                            model.retry()
                            focus.wrappedValue = .liveScreen
                        }
                        .focused(focus, equals: .liveScreen)
                        .accessibilityIdentifier("shell.retry")
                    }
                }
            }
        }
    }
#endif
