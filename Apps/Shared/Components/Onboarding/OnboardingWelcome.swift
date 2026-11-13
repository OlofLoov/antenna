import SwiftUI

/// The first screen for a user with no source (first-run-onboarding/a-new-user-is-asked-for-a-provider;
/// `iPhone-Onboard-1` and `TV-Onboard-1`). Compiles on every platform so
/// the snapshot job renders both variants.
enum OnboardingWelcome {
    static let title = "Welcome to Antenna"

    /// What the welcome screen's buttons do. Each variant also takes
    /// `signedInToICloud`; when false it leaves out what it says about sync.
    struct Actions {
        var addSource: () -> Void
        var help: () -> Void
    }

    /// iPhone, and the sheet centered on iPad and Mac: the mark, the title,
    /// three feature rows and the two buttons at the bottom.
    struct Phone: View {
        let signedInToICloud: Bool
        let actions: Actions

        var body: some View {
            VStack(spacing: Metrics.Spacing.small) {
                ScrollView {
                    VStack(spacing: Metrics.Spacing.xLarge) {
                        AntennaMark(size: 112)
                        VStack(spacing: Metrics.Spacing.small) {
                            Text(OnboardingWelcome.title)
                                .font(.largeTitle.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text(
                                "Antenna plays the TV sources you already have. "
                                    + "It comes with no channels, so start by adding a playlist or a login from your provider."
                            )
                            .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        VStack(spacing: Metrics.Spacing.xSmall) {
                            Feature(systemImage: "tv", title: "Live TV with a guide", detail: "Groups, favorites, catch-up")
                            Feature(systemImage: "film", title: "Movies and series", detail: "When your provider includes them")
                            if signedInToICloud {
                                Feature(systemImage: "icloud", title: "Synced with iCloud", detail: "Add here, watch on Apple TV")
                                    .accessibilityIdentifier("onboarding.iCloudNote")
                            }
                        }
                        .padding(.top, Metrics.Spacing.xSmall)
                    }
                    .padding(.top, Metrics.Spacing.xxLarge)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                Button(action: actions.addSource) {
                    Label("Add a source", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle()
                .controlSize(.large)
                .accessibilityIdentifier("onboarding.addSource")
                Button("What is a source?", action: actions.help)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding.help")
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, Metrics.Spacing.large)
            .padding(.bottom, Metrics.Spacing.xLarge)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.welcome")
        }
    }

    /// Apple TV: the mark, the title, Add a source with focus, What is a
    /// source? under it and the iCloud line at the bottom. It paints no
    /// background, so the kinds and the form it pushes share the system's.
    struct Television: View {
        let signedInToICloud: Bool
        let actions: Actions

        var body: some View {
            VStack(spacing: Metrics.Spacing.xLarge) {
                AntennaMark(size: 160)
                VStack(spacing: Metrics.Spacing.medium) {
                    Text(OnboardingWelcome.title)
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(
                        "Antenna plays the TV sources you already have. It does not come with any channels, "
                            + "so the first step is to add a playlist or a login from your provider."
                    )
                    .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 1000)
                VStack(spacing: Metrics.Spacing.medium) {
                    Button("Add a source", action: actions.addSource)
                        .primaryActionStyle()
                        .accessibilityIdentifier("onboarding.addSource")
                    Button("What is a source?", action: actions.help)
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("onboarding.help")
                }
                .padding(.top, Metrics.Spacing.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if signedInToICloud {
                    Text("Signed in to iCloud. Sources added in Antenna on iPhone, iPad or Mac appear here on their own.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("onboarding.iCloudNote")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.welcome")
        }
    }

    /// One feature row on the iPhone welcome: icon tile, title, muted detail.
    private struct Feature: View {
        let systemImage: String
        let title: String
        let detail: String

        var body: some View {
            HStack(spacing: Metrics.Spacing.medium) {
                Image(systemName: systemImage)
                    .font(.body)
                    .frame(width: 40, height: 40)
                    .background(Palette.surface(0.1), in: Metrics.Corner.small.shape())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Metrics.Spacing.xxSmall) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Metrics.Spacing.small)
            .padding(.horizontal, Metrics.Spacing.medium)
            .background(Palette.surface(0.06), in: Metrics.Corner.medium.shape())
            .accessibilityElement(children: .combine)
        }
    }
}

/// The body color and the two Apple TV button styles the paywall still
/// uses until refresh-visual-design moves it to system styles.
enum OnboardingStyle {
    /// Body copy under a title, `#D7DEE8` on the boards.
    static let body = Color(red: 0xD7 / 255, green: 0xDE / 255, blue: 0xE8 / 255)

    /// The lifted white card while focused, the 0.12 surface otherwise
    /// (design-system/focus-is-the-lifted-white-card). 28 pt bold.
    struct PrimaryTV: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            FocusLabel(
                label: configuration.label, font: .system(size: 28, weight: .bold),
                insets: EdgeInsets(top: 20, leading: 48, bottom: 20, trailing: 48), idleText: Palette.text, idleFill: Palette.surface(0.12))
        }
    }

    /// Muted text that turns into the white card when focused. 24 pt.
    struct QuietTV: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            FocusLabel(
                label: configuration.label, font: .system(size: 24),
                insets: EdgeInsets(top: 14, leading: 28, bottom: 14, trailing: 28), idleText: Palette.textMuted, idleFill: .clear)
        }
    }

    private struct FocusLabel<Label: View>: View {
        let label: Label
        let font: Font
        let insets: EdgeInsets
        let idleText: Color
        let idleFill: Color
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(font)
                .padding(insets)
                .foregroundStyle(isFocused ? Palette.ground : idleText)
                .background(isFocused ? Palette.focus : idleFill, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
                .scaleEffect(isFocused ? 1.04 : 1)
        }
    }
}

#Preview("Welcome, iPhone, signed in to iCloud") {
    OnboardingWelcome.Phone(signedInToICloud: true, actions: .init(addSource: {}, help: {}))
}

#Preview("Welcome, iPhone, not signed in to iCloud") {
    OnboardingWelcome.Phone(signedInToICloud: false, actions: .init(addSource: {}, help: {}))
}

#Preview("Welcome, Apple TV, signed in to iCloud", traits: .fixedLayout(width: 1920, height: 1080)) {
    OnboardingWelcome.Television(signedInToICloud: true, actions: .init(addSource: {}, help: {}))
}

#Preview("Welcome, Apple TV, not signed in to iCloud", traits: .fixedLayout(width: 1920, height: 1080)) {
    OnboardingWelcome.Television(signedInToICloud: false, actions: .init(addSource: {}, help: {}))
}
