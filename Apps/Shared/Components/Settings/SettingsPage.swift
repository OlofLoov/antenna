import AntennaCore
import SwiftUI

/// The Apple TV Settings page (`TV-Settings`, `TV-Settings-Details`): an
/// opaque page split one third and two thirds, as in the system Settings
/// app. The lead column names the page and shows the focused row's footer;
/// the list holds the rows (design-system/pages-cover-what-is-behind-them,
/// design-system/forms-use-the-platform-form-style). The page stays inside
/// the safe area the presentation gives it.
enum SettingsPage {
    /// The lead column and the list side by side on an opaque page.
    struct Split<Lead: View, Content: View>: View {
        @ViewBuilder var lead: Lead
        @ViewBuilder var content: Content

        /// One third of the width inside the Apple TV safe area, less the gap.
        static var leadWidth: CGFloat { 560 }

        var body: some View {
            HStack(alignment: .top, spacing: Metrics.Spacing.xxxxLarge) {
                lead
                    .frame(width: Self.leadWidth)
                    .frame(maxHeight: .infinity)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Palette.ground.ignoresSafeArea())
        }
    }

    /// A symbol, the page title and the focused row's footer, centered.
    struct Lead<Footer: View>: View {
        let symbol: String
        let title: String
        @ViewBuilder var footer: Footer

        var body: some View {
            VStack(spacing: Metrics.Spacing.large) {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("settings.title")
                footer
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxHeight: .infinity)
        }
    }

    /// A source's lead column: its name, type and status lines, with `card`
    /// under them when there is one, such as the QR code for a login.
    struct SourceLead<Card: View>: View {
        let name: String
        let kind: SourceKind
        let lines: [SourceStatusText.Line]
        @ViewBuilder var card: Card

        var body: some View {
            VStack(spacing: Metrics.Spacing.large) {
                VStack(spacing: Metrics.Spacing.xSmall) {
                    Text(name)
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(SourceRowLabel.kindName(kind))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: Metrics.Spacing.xxSmall) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.text)
                            .foregroundStyle(line.style == .error ? AnyShapeStyle(OnboardingForm.errorColor) : AnyShapeStyle(.secondary))
                    }
                }
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.details.status")
                card
            }
            .multilineTextAlignment(.center)
            .frame(maxHeight: .infinity)
        }
    }
}

#Preview("Settings page, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    SettingsPage.Split {
        SettingsPage.Lead(symbol: "gearshape", title: "Sources & Settings") {
            Text("Sources sync to your other devices through iCloud.")
        }
    } content: {
        List {
            Section("Sources") {
                SourceRowLabel(name: "Home", kind: .m3u, lines: [.init("412 channels · Guide 7 days")])
                SourceRowLabel(name: "Provider", kind: .xtream, lines: [.init("Not signed in on this Apple TV", style: .muted)])
                Button("Add a source") {}
                Button("Refresh all sources") {}
            }
            Section("Preferences") {
                LabeledContent("Open on launch", value: "Live")
                LabeledContent("Guide window", value: "3 hours")
            }
        }
    }
    .padding(Metrics.televisionSafeArea)
    .preferredColorScheme(.dark)
}

#Preview("Source details lead, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    SettingsPage.Split {
        SettingsPage.SourceLead(
            name: "Home", kind: .m3u,
            lines: [.init("412 channels · Guide 7 days · 12 minutes ago"), .init("Could not refresh: You're offline.", style: .error)]
        ) {}
    } content: {
        List {
            Section("Source") {
                LabeledContent("Name", value: "Home")
                LabeledContent("Playlist", value: "http://example.com/home.m3u")
            }
        }
    }
    .padding(Metrics.televisionSafeArea)
    .preferredColorScheme(.dark)
}

extension View {
    /// A button row in label colors on iPhone, iPad and Mac, where a button
    /// otherwise draws in the tint. Nothing on Apple TV, where the row draws
    /// light text at rest and dark text on its focused platter
    /// (design-system/focus-is-the-lifted-white-card).
    @ViewBuilder func rowLabelColors() -> some View {
        #if os(tvOS)
            self
        #else
            tint(Color.primary)
        #endif
    }
}
