import AntennaCore
import SwiftUI

/// One channel on the Guide sources screen (board
/// `iPhone-GuideSources-Diagnosis`): why it has no guide or where its guide
/// comes from, Remove match when it has one, and the search over the
/// playlist's guide entries, starting from its name
/// (guide-sources-and-channel-mapping/pick-the-right-guide-entry-by-hand).
struct GuideChannelDetail: View {
    @Bindable var model: GuideSourcesModel
    let channelID: String
    @State private var query: String

    init(model: GuideSourcesModel, channelID: String) {
        self.model = model
        self.channelID = channelID
        _query = State(initialValue: model.channel(channelID)?.name ?? "")
    }

    var body: some View {
        List {
            if let channel = model.channel(channelID) {
                Section {
                    GuideSourcesRows.Card(card: model.card(for: channel))
                    if model.match(for: channel) != nil {
                        Button(GuideSourcesText.removeMatch, role: .destructive) { model.removeMatch(for: channel) }
                            .accessibilityIdentifier("guideSources.removeMatch")
                    }
                    if let error = model.error {
                        Text(error)
                            .foregroundStyle(OnboardingForm.errorColor)
                            .accessibilityIdentifier("guideSources.picker.error")
                    }
                } header: {
                    Text(heading(channel))
                }
                picker(channel)
            }
        }
    }

    /// "Sport One · 104".
    private func heading(_ channel: Channel) -> String {
        let number = channel.number.map { ChannelNumber(major: $0, minor: channel.minorNumber).description }
        return [channel.name, number].compactMap(\.self).joined(separator: " · ")
    }

    @ViewBuilder private func picker(_ channel: Channel) -> some View {
        Section(GuideSourcesText.pickerTitle) {
            TextField(GuideSourcesText.pickerPrompt, text: $query)
                .autocorrectionDisabled()
                .accessibilityIdentifier("guideSources.picker.field")
            results(channel)
        }
    }

    @ViewBuilder private func results(_ channel: Channel) -> some View {
        if !model.hasLoadedGuide {
            Text(GuideSourcesText.notDownloadedPicker)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("guideSources.picker.empty")
        } else if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            let found = model.search(query)
            if found.entries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.text.noMatch(query.trimmingCharacters(in: .whitespaces)))
                    Text(GuideSourcesText.noMatchCaption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("guideSources.picker.empty")
            } else {
                let search = SearchQuery(query)
                ForEach(Array(found.entries.enumerated()), id: \.element.id) { position, entry in
                    let detail = model.text.detail(entry, guide: model.name(entry.guide))
                    let nameRanges = search.highlights(in: entry.name)
                    GuideSourcesRows.Entry(
                        name: entry.name, nameRanges: nameRanges, detail: detail,
                        detailRanges: nameRanges.isEmpty ? search.highlights(in: detail) : [],
                        identifier: "guideSources.picker.row.\(position)",
                        pick: { model.pick(entry, for: channel) })
                }
                if found.total > found.entries.count {
                    Text(model.text.showing(found.entries.count, of: found.total))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
