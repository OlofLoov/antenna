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
            VStack(spacing: 10) {
                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 8) {
                            Text(headline)
                                .font(.system(size: 30, weight: .heavy))
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("onboarding.headline")
                            Text(subtitle)
                                .font(.system(size: 15))
                                .foregroundStyle(OnboardingStyle.body)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                if let title = section.title {
                                    Text(title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .tracking(1)
                                        .textCase(.uppercase)
                                        .foregroundStyle(Palette.textMuted)
                                        .padding(.horizontal, 4)
                                }
                                VStack(spacing: 0) {
                                    ForEach(section.lines) { line in
                                        LineRow(line: line, metrics: .phone, last: line.id == section.lines.last?.id)
                                    }
                                }
                                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        if let footnote {
                            Text(footnote)
                                .font(.system(size: 14))
                                .foregroundStyle(OnboardingStyle.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollBounceBehavior(.basedOnSize)
                VStack(spacing: 10) {
                    Button(action: actions.primary) {
                        Text(primary.title)
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(Palette.ground)
                            .background(Palette.text.opacity(primary.isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(!primary.isEnabled)
                    .accessibilityIdentifier("onboarding.primary")
                    if let addAnother = actions.addAnother {
                        Button(action: addAnother) {
                            Text("Add another source")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Palette.surface(0.1), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.addAnother")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
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
            VStack(spacing: 44) {
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 52, weight: .heavy))
                        .accessibilityAddTraits(.isHeader)
                    Text("This runs once.")
                        .font(.system(size: 24))
                        .foregroundStyle(Palette.textMuted)
                }
                .multilineTextAlignment(.center)
                VStack(spacing: 0) {
                    ForEach(lines) { line in
                        LineRow(line: line, metrics: .television, last: line.id == lines.last?.id)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                .frame(width: 1000)
                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 20))
                HStack(spacing: 16) {
                    Button(primary == .browseMovies ? primary.title : "Start watching now", action: start)
                        .buttonStyle(OnboardingStyle.PrimaryTV())
                        .disabled(!primary.isEnabled)
                        .accessibilityIdentifier("onboarding.primary")
                    if let caption {
                        Text(caption)
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.textMuted)
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

    /// Font sizes and heights for one platform.
    struct Metrics {
        var title: CGFloat
        var detail: CGFloat
        var height: CGFloat
        var marker: CGFloat
        var bar: CGFloat
        var padding: CGFloat

        static let phone = Metrics(title: 16, detail: 13, height: 60, marker: 26, bar: 4, padding: 14)
        static let television = Metrics(title: 27, detail: 20, height: 96, marker: 44, bar: 6, padding: 0)
    }

    /// The marker, the title over the detail, and the guide's bar.
    struct LineRow: View {
        let line: Line
        let metrics: Metrics
        var last = false

        var body: some View {
            HStack(spacing: metrics.padding == 0 ? 24 : 12) {
                marker
                VStack(alignment: .leading, spacing: line.bar == nil ? 2 : 8) {
                    Text(line.title)
                        .font(.system(size: metrics.title))
                        .foregroundStyle(titleColor)
                    if let detail = line.detail {
                        Text(detail)
                            .font(.system(size: metrics.detail))
                            .foregroundStyle(Palette.textMuted)
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
                    .font(.system(size: metrics.marker * 0.9))
                    .foregroundStyle(Palette.accent)
                    .frame(width: metrics.marker, height: metrics.marker)
            case .running:
                ProgressView()
                    .frame(width: metrics.marker, height: metrics.marker)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: metrics.marker * 0.9))
                    .foregroundStyle(OnboardingForm.errorColor)
                    .frame(width: metrics.marker, height: metrics.marker)
            case .muted:
                Image(systemName: "minus.circle")
                    .font(.system(size: metrics.marker * 0.9))
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
