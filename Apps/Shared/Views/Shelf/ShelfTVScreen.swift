#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// Movies or Series under the Apple TV tab bar (board `TV-Movies`,
    /// `TV-Movies-Rows`): the banner full bleed, then the rows. The banner's
    /// Play button is where focus lands when the tab opens.
    struct ShelfTVScreen: View {
        let kind: ShelfTitle.Kind
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(ShelfLibrary.self) private var library

        var body: some View {
            let model = library.model(kind)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: ShelfView.Metrics.tv.rowSpacing) {
                    switch model.status {
                    case .titles(let banner, let waiting):
                        ShelfBannerHost(model: model, actions: .none) {
                            ShelfBanner.Television {
                                ShelfTVBannerButtons(focus: focus)
                            }
                        }
                        ShelfNotices(model: model, banner: banner, waiting: waiting)
                        ShelfRowsContent(model: model, actions: .none)
                    case let status:
                        ShelfTVStatus(model: model, status: status, focus: focus)
                            .padding(.top, 180)
                    }
                }
                .padding(.bottom, 60)
            }
            .scrollClipDisabled()
            .ignoresSafeArea()
            .background(Palette.ground)
            .environment(\.shelfMetrics, .tv)
            .environment(\.shelfPrefix, kind.prefix)
            .task(id: kind) { model.open() }
            // The loading holder had focus; once titles replace it, Play takes it.
            .onChange(of: model.status.showsTitles) { _, titles in
                guard titles, focus.wrappedValue == nil || focus.wrappedValue == .content else { return }
                focus.wrappedValue = nil
                Task {
                    await Task.yield()
                    focus.wrappedValue = .content
                }
            }
        }
    }

    /// Play, More info and My list. Focus on any of them holds the banner;
    /// moving right past My list or left past Play pages it
    /// (movies-and-series-browsing/new-titles-up-front).
    private struct ShelfTVBannerButtons: View {
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(\.shelfBanner) private var banner
        @FocusState private var focused: Part?

        enum Part: Hashable { case play, info, myList }

        var body: some View {
            Group {
                ShelfBanner.PlayButton(type: .tv)
                    .fixedSize()
                    .focused(focus, equals: .content)
                    .focused($focused, equals: .play)
                ShelfBanner.InfoButton(type: .tv, title: "More info")
                    .fixedSize()
                    .focused($focused, equals: .info)
                ShelfBanner.MyListButton(type: .tv)
                    .focused($focused, equals: .myList)
            }
            .onMoveCommand { direction in
                switch (direction, focused) {
                case (.right, .myList?): banner?.actions.page(1)
                case (.left, .play?): banner?.actions.page(-1)
                default: break
                }
            }
            .onChange(of: focused != nil) { _, inside in
                banner?.actions.interacting(inside)
            }
        }
    }

    /// Loading, the failure message with Retry, or "Nothing here yet".
    /// Something on it always takes focus when the tab opens.
    private struct ShelfTVStatus: View {
        let model: ShelfModel
        let status: ShelfStatus
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            switch status {
            case .offline(let waiting):
                failure(ShelfStatus.offlineTitle, [ShelfStatus.offlineLine] + waiting)
            case .failed(let waiting):
                failure(ShelfStatus.failedTitle(model.kind), waiting)
            case .loading, .empty, .titles:
                ShelfStatusContent(model: model, status: status)
                    .focusable()
                    .focusEffectDisabled()
                    .focused(focus, equals: .content)
            }
        }

        private func failure(_ title: String, _ lines: [String]) -> some View {
            ShelfView.Message(title: title, lines: lines) {
                ShelfView.RetryButton(retry: model.retry)
                    .focused(focus, equals: .content)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).error")
        }
    }
#endif
