import AntennaCore
import SwiftData
import SwiftUI

/// Settings › a source › Guide (boards `iPhone-GuideSources`,
/// `iPad-GuideSources`, `TV-GuideSources`; guide-sources-and-channel-mapping
/// capability). On iPhone one scrolling list with a pushed channel detail;
/// on iPad, Mac and Apple TV the list beside the selected channel's detail.
/// Closes when the source is deleted, here or on another device
/// (guide-sources-and-channel-mapping/settings-follow-you-to-every-device).
struct GuideSourcesScreen: View {
    let id: UUID
    @Environment(\.modelContext) private var context
    @Environment(\.guideStore) private var store
    @Environment(\.dismiss) private var dismiss
    @Query(sort: SourceRecord.displayOrder) private var sources: [SourceRecord]
    @State private var model: GuideSourcesModel?
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var record: SourceRecord? { sources.first { $0.id == id } }

    var body: some View {
        Group {
            if let model {
                layout(model)
            } else {
                Color.clear
            }
        }
        .navigationTitle(GuideSourcesText.title)
        .onChange(of: record == nil) { _, gone in
            if gone { dismiss() }
        }
        .task(id: record?.name) {
            guard let record else { return }
            if let model {
                model.source = record.name
            } else {
                model = GuideSourcesModel(sourceID: id, source: record.name, kind: record.kind, store: store, context: context)
            }
        }
    }

    @ViewBuilder private func layout(_ model: GuideSourcesModel) -> some View {
        #if os(iOS)
            if sizeClass == .compact {
                GuideSourcesCompact(model: model)
            } else {
                GuideSourcesSplit(model: model)
            }
        #else
            GuideSourcesSplit(model: model)
        #endif
    }
}

/// iPhone: the guides and channels in one list; a channel pushes its detail.
private struct GuideSourcesCompact: View {
    @Bindable var model: GuideSourcesModel

    var body: some View {
        GuideSourcesList(model: model)
            .navigationDestination(item: $model.selected) { id in
                GuideChannelDetail(model: model, channelID: id)
                    .navigationTitle(model.channel(id)?.name ?? "")
            }
    }
}

/// iPad, Mac and Apple TV: the list on the left, the selected channel's
/// detail on the right, empty until a channel is picked.
private struct GuideSourcesSplit: View {
    @Bindable var model: GuideSourcesModel

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            GuideSourcesList(model: model)
                .frame(maxWidth: Self.listWidth)
            Divider()
            Group {
                if let id = model.selected {
                    GuideChannelDetail(model: model, channelID: id)
                        .id(id)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private static var listWidth: CGFloat {
        #if os(tvOS)
            860
        #else
            440
        #endif
    }
}
