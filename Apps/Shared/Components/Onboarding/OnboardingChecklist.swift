import SwiftUI

/// The loading checklist and the summary (`iPhone-Onboard-3`,
/// `iPhone-Onboard-3-NoLive`, `iPhone-Onboard-3-Empty`, `iPhone-Onboard-3-Two`,
/// `TV-Onboard-4`, `TV-Onboard-4-NoLive`, `TV-Onboard-4-Empty`,
/// `TV-Onboard-5`, `TV-Onboard-5-Two`). Takes finished lines and tiles.
enum OnboardingChecklist {
    /// One checklist line, read by VoiceOver as one item with its state,
    /// title and detail.
    struct Line: Identifiable, Equatable {
        enum State: Equatable {
            case done, running, failed
            /// Finished with nothing, such as "No live channels".
            case muted
        }

        enum Bar: Equatable {
            /// The guide downloading: a sliding accent segment.
            case indeterminate
            /// The guide loaded.
            case full
        }

        var id: String
        var state: State
        var title: String
        var detail: String?
        var bar: Bar?
    }

    /// One source's lines; the title shows only with two or more sources.
    struct Section: Identifiable, Equatable {
        var id: String
        var title: String?
        var lines: [Line]
    }

    /// The main button under the lines.
    enum Primary: Equatable {
        case startWatching(enabled: Bool)
        case browseMovies

        var title: String {
            switch self {
            case .startWatching: "Start watching"
            case .browseMovies: "Browse movies"
            }
        }

        var isEnabled: Bool {
            if case .startWatching(let enabled) = self { return enabled }
            return true
        }
    }

    struct Actions {
        var primary: () -> Void
        /// Nil hides Add another source.
        var addAnother: (() -> Void)?
    }

    /// iPhone, and the sheet on iPad and Mac: the heading, each source's
    /// lines in a group, the iCloud note and the buttons.
    struct Phone: View {
        let headline: String
        let subtitle: String
        let sections: [Section]
        let footnote: String?
        let primary: Primary
        let actions: Actions

        var body: some View {
            VStack(spacing: Metrics.Spacing.small) {
                ScrollView {
                    VStack(spacing: Metrics.Spacing.large) {
                        VStack(spacing: Metrics.Spacing.xSmall) {
                            Text(headline)
                                .font(.title.bold())
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("onboarding.headline")
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.top, Metrics.Spacing.xSmall)
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: Metrics.Spacing.xSmall) {
                                if let title = section.title {
                                    Text(title)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, Metrics.Spacing.medium)
                                }
                                VStack(spacing: 0) {
                                    ForEach(section.lines) { line in
                                        LineRow(line: line, metrics: .phone, last: line.id == section.lines.last?.id)
                                    }
                                }
                                .background(Palette.surface(0.06), in: Metrics.Corner.medium.shape())
                            }
                        }
                        if let footnote {
                            Text(footnote)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Metrics.Spacing.medium)
                        }
                    }
                    .padding(.horizontal, Metrics.Spacing.medium)
                }
                .scrollBounceBehavior(.basedOnSize)
                VStack(spacing: Metrics.Spacing.small) {
                    Button(action: actions.primary) {
                        Text(primary.title)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle()
                    .controlSize(.large)
                    .disabled(!primary.isEnabled)
                    .accessibilityIdentifier("onboarding.primary")
                    if let addAnother = actions.addAnother {
                        Button(action: addAnother) {
                            Text("Add another source")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .accessibilityIdentifier("onboarding.addAnother")
                    }
                }
                .padding(.horizontal, Metrics.Spacing.medium)
                .padding(.bottom, Metrics.Spacing.large)
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.checklist")
        }
    }

    /// Apple TV while loading: the title, the lines in one card, and Start
    /// watching now once channels are in.
    struct Television: View {
        let title: String
        let lines: [Line]
        let primary: Primary
        /// The muted words beside the button, such as "The guide keeps loading behind the picture".
        let caption: String?
        let start: () -> Void

        var body: some View {
            VStack(spacing: Metrics.Spacing.xxLarge) {
                VStack(spacing: Metrics.Spacing.small) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("This runs once.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                VStack(spacing: 0) {
                    ForEach(lines) { line in
                        LineRow(line: line, metrics: .television, last: line.id == lines.last?.id)
                    }
                }
                .padding(.vertical, Metrics.Spacing.medium)
                .padding(.horizontal, Metrics.Spacing.xLarge)
                .frame(width: 1000)
                .background(Palette.surface(0.06), in: Metrics.Corner.large.shape())
                HStack(spacing: Metrics.Spacing.large) {
                    Button(primary == .browseMovies ? primary.title : "Start watching now", action: start)
                        .primaryActionStyle()
                        .disabled(!primary.isEnabled)
                        .accessibilityIdentifier("onboarding.primary")
                    if let caption {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.checklist")
        }
    }

    /// Text styles and sizes for one platform: callout over footnote on
    /// iPhone, body over caption on Apple TV.
    struct LineMetrics {
        var title: Font
        var detail: Font
        var height: CGFloat
        var marker: CGFloat
        var bar: CGFloat
        var padding: CGFloat

        static let phone = LineMetrics(title: .callout, detail: .footnote, height: 60, marker: 26, bar: 4, padding: 16)
        static let television = LineMetrics(title: .body, detail: .caption, height: 96, marker: 44, bar: 6, padding: 0)
    }

    /// The marker, the title over the detail, and the guide's bar.
    struct LineRow: View {
        let line: Line
        let metrics: LineMetrics
        var last = false

        var body: some View {
            HStack(spacing: metrics.padding == 0 ? Metrics.Spacing.large : Metrics.Spacing.small) {
                marker
                VStack(alignment: .leading, spacing: line.bar == nil ? Metrics.Spacing.xxSmall : Metrics.Spacing.xSmall) {
                    Text(line.title)
                        .font(metrics.title)
                        .foregroundStyle(titleColor)
                    if let detail = line.detail {
                        Text(detail)
                            .font(metrics.detail)
                            .foregroundStyle(.secondary)
                    }
                    if let bar = line.bar {
                        GuideBar(bar: bar, height: metrics.bar)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: metrics.height)
            .padding(.horizontal, metrics.padding)
            .overlay(alignment: .bottom) {
                if !last { Rectangle().fill(Palette.surface(0.08)).frame(height: 1) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([stateWord, line.title, line.detail].compactMap(\.self).joined(separator: ", "))
            .accessibilityIdentifier("onboarding.line.\(line.id)")
        }

        private var titleColor: Color {
            switch line.state {
            case .failed: OnboardingForm.errorColor
            case .muted: Palette.textMuted
            case .done, .running: Palette.text
            }
        }

        private var stateWord: String {
            switch line.state {
            case .done, .muted: "Done"
            case .running: "Loading"
            case .failed: "Failed"
            }
        }

        @ViewBuilder private var marker: some View {
            switch line.state {
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(metrics.marker * 0.05)
                    .foregroundStyle(Palette.accent)
                    .frame(width: metrics.marker, height: metrics.marker)
            case .running:
                ProgressView()
                    .frame(width: metrics.marker, height: metrics.marker)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(metrics.marker * 0.05)
                    .foregroundStyle(OnboardingForm.errorColor)
                    .frame(width: metrics.marker, height: metrics.marker)
            case .muted:
                Image(systemName: "minus.circle")
                    .resizable()
                    .scaledToFit()
                    .padding(metrics.marker * 0.05)
                    .foregroundStyle(Palette.textMuted)
                    .frame(width: metrics.marker, height: metrics.marker)
            }
        }
    }

    /// The guide line's bar: a fixed accent segment while downloading, as
    /// on the boards, or a full bar once loaded.
    private struct GuideBar: View {
        let bar: Line.Bar
        let height: CGFloat

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surface(0.16))
                    switch bar {
                    case .full:
                        Capsule().fill(Palette.accent)
                    case .indeterminate:
                        Capsule().fill(Palette.accent)
                            .frame(width: proxy.size.width * 0.3)
                            .offset(x: proxy.size.width * 0.35)
                    }
                }
            }
            .frame(height: height)
            .accessibilityHidden(true)
        }
    }
}
