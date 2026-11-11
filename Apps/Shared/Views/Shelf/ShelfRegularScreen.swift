#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// Movies or Series in the iPad and Mac content column (board
    /// `iPad-Movies`, `iPad-Movies-Rows`): the toolbar with the section's
    /// name, the banner card and the rows. The sidebar is the window's.
    struct ShelfRegularScreen<Leading: View>: View {
        let kind: ShelfTitle.Kind
        /// The sidebar button while the sidebar is folded.
        @ViewBuilder var leading: Leading
        @Environment(ShelfLibrary.self) private var library

        var body: some View {
            let model = library.model(kind)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    leading
                    Text(kind.sectionTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                }
                .padding(EdgeInsets(top: 18, leading: 24, bottom: 0, trailing: 24))
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ShelfView.Metrics.pad.rowSpacing) {
                        switch model.status {
                        case .titles(let banner, let waiting):
                            ShelfBannerHost(model: model, actions: .none) {
                                ShelfBanner.Pad()
                                    .padding(.horizontal, 24)
                            }
                            ShelfNotices(model: model, banner: banner, waiting: waiting)
                            ShelfRowsContent(model: model, actions: .none)
                        case let status:
                            ShelfStatusContent(model: model, status: status)
                        }
                    }
                    .padding(.vertical, 22)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.ground)
            .environment(\.shelfMetrics, .pad)
            .environment(\.shelfPrefix, kind.prefix)
            .task(id: kind) { model.open() }
        }
    }
#endif
