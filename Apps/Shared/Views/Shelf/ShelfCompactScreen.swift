#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The Movies tab on iPhone and in a narrow iPad window (board
    /// `iPhone-Movies`, `iPhone-Movies-Rows`): the Movies | Series switch
    /// over a tall banner, then the rows. Once the banner scrolls away the
    /// switch stays pinned on the ground color.
    struct ShelfCompactScreen: View {
        @Environment(ShelfLibrary.self) private var library
        @State private var kind: ShelfTitle.Kind = .movie
        @State private var pinned = false

        var body: some View {
            let model = library.model(kind)
            GeometryReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ShelfView.Metrics.phone.rowSpacing) {
                        switch model.status {
                        case .titles(let banner, let waiting):
                            ShelfBannerHost(model: model, actions: .none) {
                                ShelfBanner.Phone {
                                    topBar
                                        .padding(.top, proxy.safeAreaInsets.top)
                                        .opacity(pinned ? 0 : 1)
                                        .accessibilityHidden(pinned)
                                }
                            }
                            ShelfNotices(model: model, banner: banner, waiting: waiting)
                            ShelfRowsContent(model: model, actions: .none)
                        case let status:
                            topBar.padding(.top, proxy.safeAreaInsets.top)
                            ShelfStatusContent(model: model, status: status)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top > 420
                } action: { _, past in
                    pinned = past
                }
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .top) {
                    if pinned {
                        topBar
                            .padding(.bottom, 10)
                            .background(Palette.ground.ignoresSafeArea(edges: .top))
                            .overlay(alignment: .bottom) { Rectangle().fill(Palette.surface(0.08)).frame(height: 1) }
                    }
                }
            }
            .background(Palette.ground)
            .environment(\.shelfMetrics, .phone)
            .environment(\.shelfPrefix, kind.prefix)
            .task(id: kind) { model.open() }
        }

        private var topBar: some View {
            HStack {
                ShelfView.KindSwitch(selection: kind) { kind = $0 }
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
#endif
