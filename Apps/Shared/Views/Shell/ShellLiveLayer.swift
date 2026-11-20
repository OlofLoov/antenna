#if os(tvOS)
    import SwiftUI

    /// The Live tab's loading and empty screens
    /// (tvos-shell/a-loading-screen-at-launch, tvos-shell/an-empty-screen-with-retry).
    /// Nothing once a channel plays. Open Settings on the empty screen takes
    /// focus first (design-system/empty-and-error-states-share-one-layout).
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
                        Button("Open Settings") { Task { await model.show(.settings) } }
                            .focused(focus, equals: .liveScreen)
                            .accessibilityIdentifier("shell.empty.settings")
                        Button("Try again") {
                            model.retry()
                            // Once the loading screen has replaced this one, its holder takes focus.
                            Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                focus.wrappedValue = .liveScreen
                            }
                        }
                        .accessibilityIdentifier("shell.retry")
                    }
                }
            }
        }
    }
#endif
