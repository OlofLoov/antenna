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
            VStack(spacing: 10) {
                ScrollView {
                    VStack(spacing: 28) {
                        Mark(size: 112, corner: 28, glyph: 64)
                        VStack(spacing: 12) {
                            Text(OnboardingWelcome.title)
                                .font(.system(size: 34, weight: .heavy))
                                .accessibilityAddTraits(.isHeader)
                            Text(
                                "Antenna plays the TV sources you already have. "
                                    + "It comes with no channels, so start by adding a playlist or a login from your provider."
                            )
                            .font(.system(size: 17))
                            .foregroundStyle(OnboardingStyle.body)
                        }
                        .multilineTextAlignment(.center)
                        VStack(spacing: 10) {
                            Feature(systemImage: "tv", title: "Live TV with a guide", detail: "Groups, favorites, catch-up")
                            Feature(systemImage: "film", title: "Movies and series", detail: "When your provider includes them")
                            if signedInToICloud {
                                Feature(systemImage: "icloud", title: "Synced with iCloud", detail: "Add here, watch on Apple TV")
                                    .accessibilityIdentifier("onboarding.iCloudNote")
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.top, 54)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                Button(action: actions.addSource) {
                    Label("Add a source", systemImage: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(Palette.ground)
                        .background(Palette.text, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.addSource")
                Button("What is a source?", action: actions.help)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.textMuted)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.help")
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.welcome")
        }
    }

    /// Apple TV: the mark, the title, Add a source with focus, What is a
    /// source? under it and the iCloud line at the bottom.
    struct Television: View {
        let signedInToICloud: Bool
        let actions: Actions

        var body: some View {
            VStack(spacing: 36) {
                Mark(size: 160, corner: 40, glyph: 92)
                VStack(spacing: 18) {
                    Text(OnboardingWelcome.title)
                        .font(.system(size: 64, weight: .heavy))
                        .accessibilityAddTraits(.isHeader)
                    Text(
                        "Antenna plays the TV sources you already have. It does not come with any channels, "
                            + "so the first step is to add a playlist or a login from your provider."
                    )
                    .font(.system(size: 30))
                    .foregroundStyle(OnboardingStyle.body)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)
                VStack(spacing: 16) {
                    Button("Add a source", action: actions.addSource)
                        .buttonStyle(OnboardingStyle.PrimaryTV())
                        .accessibilityIdentifier("onboarding.addSource")
                    Button("What is a source?", action: actions.help)
                        .buttonStyle(OnboardingStyle.QuietTV())
                        .accessibilityIdentifier("onboarding.help")
                }
                .padding(.top, 12)
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if signedInToICloud {
                    Text("Signed in to iCloud. Sources added in Antenna on iPhone, iPad or Mac appear here on their own.")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.textMuted)
                        .padding(.bottom, 56)
                        .accessibilityIdentifier("onboarding.iCloudNote")
                }
            }
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.welcome")
        }
    }

    /// The antenna mark on its blue tile.
    private struct Mark: View {
        let size: CGFloat
        let corner: CGFloat
        let glyph: CGFloat

        var body: some View {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: glyph * 0.7, weight: .regular))
                .foregroundStyle(Palette.text)
                .frame(width: size, height: size)
                .background(OnboardingStyle.markTile, in: RoundedRectangle(cornerRadius: corner))
                .accessibilityHidden(true)
        }
    }

    /// One feature row on the iPhone welcome: icon tile, title, muted detail.
    private struct Feature: View {
        let systemImage: String
        let title: String
        let detail: String

        var body: some View {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .frame(width: 40, height: 40)
                    .background(Palette.surface(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    Text(detail).font(.system(size: 13)).foregroundStyle(Palette.textMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
        }
    }
}

/// Colors and button styles the onboarding boards share.
enum OnboardingStyle {
    /// Body copy under a title, `#D7DEE8` on the boards.
    static let body = Color(red: 0xD7 / 255, green: 0xDE / 255, blue: 0xE8 / 255)
    /// The tile behind the antenna mark, `#1E3A5F`.
    static let markTile = Color(red: 0x1E / 255, green: 0x3A / 255, blue: 0x5F / 255)

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
