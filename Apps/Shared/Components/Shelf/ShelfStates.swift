import AntennaCore
import SwiftUI

extension ShelfView {
    /// Gray poster frames in place of a row until a source answers
    /// (design-system/loading-shows-real-progress-per-step, a deviation
    /// design.md names), with each source and how far it got.
    struct Loading: View {
        let sources: [ShelfSource]
        @Environment(\.shelfMetrics) private var metrics
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            VStack(alignment: .leading, spacing: metrics.rowSpacing) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: metrics.gap) {
                        ForEach(0..<8, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: metrics.corner, style: .continuous)
                                .fill(Palette.surface(0.06))
                                .frame(width: metrics.poster.width, height: metrics.poster.height)
                        }
                    }
                    .padding(.horizontal, metrics.gutter)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                    .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: metrics.headerSpacing) {
                    ForEach(sources) { source in
                        HStack(spacing: 12) {
                            Text(source.name)
                                .foregroundStyle(Palette.text)
                            Spacer(minLength: 12)
                            if let detail = Self.detail(source.state) {
                                Text(detail).foregroundStyle(Palette.textMuted)
                            } else {
                                ProgressView().accessibilityLabel("Loading")
                            }
                        }
                        .font(.system(size: metrics.caption))
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("\(prefix).loading.\(source.id.uuidString)")
                    }
                }
                .padding(.horizontal, metrics.gutter)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).loading")
        }

        /// What the list says about a source that is not loading.
        static func detail(_ state: ShelfSourceState) -> String? {
            switch state {
            case .loading: nil
            case .loaded(let count): ShelfText.titles(count)
            case .offline: "Offline"
            case .failed: "Could not load"
            case .waitingForLogin: "Waiting for login"
            }
        }
    }

    /// A centered title with a line per source under it and whatever the
    /// screen adds below, such as Retry.
    struct Message<Below: View>: View {
        let title: String
        let lines: [String]
        @ViewBuilder var below: Below
        @Environment(\.shelfMetrics) private var metrics

        var body: some View {
            VStack(spacing: metrics.headerSpacing) {
                Text(title)
                    .font(.system(size: metrics.header, weight: .bold))
                    .foregroundStyle(Palette.text)
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: metrics.caption))
                        .foregroundStyle(Browse.textSecondary)
                }
                below
                    .padding(.top, metrics.headerSpacing)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, metrics.gutter)
            .padding(.vertical, metrics.rowSpacing * 2)
            .frame(maxWidth: .infinity)
        }
    }

    /// Retry under a message: the 0.12 surface, the white card when focused.
    struct RetryButton: View {
        let retry: () -> Void
        @Environment(\.shelfMetrics) private var metrics
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            Button(action: retry) {
                Text("Retry")
                    .font(.system(size: metrics.caption + 2, weight: .semibold))
                    .padding(.horizontal, metrics.caption * 1.6)
                    .frame(minHeight: max(44, metrics.caption * 2.8))
            }
            .buttonStyle(ShelfBanner.BannerButtonStyle(fill: .secondary))
            .accessibilityIdentifier("\(prefix).retry")
        }
    }

    /// "Cabin · waiting for login": text only.
    struct WaitingNote: View {
        let source: ShelfSource
        @Environment(\.shelfMetrics) private var metrics
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            Text("\(source.name) · waiting for login")
                .font(.system(size: metrics.caption))
                .foregroundStyle(Browse.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("\(prefix).waiting.\(source.id.uuidString)")
        }
    }
}

private let previewSources = [
    ShelfSource(id: ShelfFixtures.source, name: "Cabin", state: .loading),
    ShelfSource(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000F2") ?? UUID(), name: "Office", state: .waitingForLogin),
]

#Preview("Loading, iPhone", traits: .fixedLayout(width: 390, height: 600)) {
    ShelfView.Loading(sources: previewSources)
        .background(Palette.ground)
}

#Preview("Could not load movies, iPad", traits: .fixedLayout(width: 914, height: 400)) {
    ShelfView.Message(title: ShelfStatus.failedTitle(.movie), lines: ["Office: waiting for its login to sync from iCloud"]) {
        ShelfView.RetryButton {}
    }
    .environment(\.shelfMetrics, .pad)
    .background(Palette.ground)
}

#Preview("Nothing here yet, Apple TV", traits: .fixedLayout(width: 1920, height: 600)) {
    ShelfView.Message(title: ShelfStatus.emptyTitle, lines: ["Cabin: no movies", "Office: waiting for its login to sync from iCloud"]) {
        EmptyView()
    }
    .environment(\.shelfMetrics, .tv)
    .background(Palette.ground)
}
