import SwiftUI

/// The Apple TV summary over the first channel playing (`TV-Onboard-5`,
/// `TV-Onboard-5-Two`): the source line, "You're set", the tiles, Start
/// watching or Browse movies, and Add another source. The source line is
/// secondary text, not an accent eyebrow (design-system/one-accent-color).
/// The picture is the caller's `background`.
enum OnboardingSummary {
    /// One number and what it counts, such as "412" over "live channels · 18 groups".
    struct Tile: Identifiable, Equatable {
        var id: String
        var value: String
        var caption: String
    }

    struct Television<Picture: View>: View {
        let eyebrow: String
        let tiles: [Tile]
        /// "Live · 101 Eurosport 1"; nil without a live channel.
        let liveCaption: String?
        let footnote: String
        let primary: OnboardingChecklist.Primary
        let actions: OnboardingChecklist.Actions
        @ViewBuilder var picture: Picture

        var body: some View {
            ZStack(alignment: .leading) {
                picture
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255))
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: Metrics.Spacing.xxLarge) {
                    VStack(alignment: .leading, spacing: Metrics.Spacing.small) {
                        Text(eyebrow)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("onboarding.eyebrow")
                        Text("You're set")
                            .font(.title2.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        if liveCaption != nil {
                            Text(
                                "The first channel is already playing. Press the touch surface for the channel list, "
                                    + "press play/pause for the channel bar."
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Metrics.Spacing.medium), GridItem(.flexible(), spacing: Metrics.Spacing.medium),
                        ],
                        spacing: Metrics.Spacing.medium
                    ) {
                        ForEach(tiles) { tile in
                            VStack(alignment: .leading, spacing: Metrics.Spacing.xSmall) {
                                Text(tile.value).font(.title3.bold()).monospacedDigit()
                                Text(tile.caption).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Metrics.Spacing.large)
                            .padding(.horizontal, Metrics.Spacing.large)
                            .background(Palette.surface(0.08), in: Metrics.Corner.medium.shape())
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("onboarding.tile.\(tile.id)")
                        }
                    }
                    VStack(alignment: .leading, spacing: Metrics.Spacing.medium) {
                        HStack(spacing: Metrics.Spacing.large) {
                            Button(primary.title, action: actions.primary)
                                .primaryActionStyle()
                                .disabled(!primary.isEnabled)
                                .accessibilityIdentifier("onboarding.primary")
                            if let addAnother = actions.addAnother {
                                Button("Add another source", action: addAnother)
                                    .buttonStyle(.glass)
                                    .accessibilityIdentifier("onboarding.addAnother")
                            }
                        }
                        Text(footnote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Metrics.Spacing.xxxxLarge)
                .frame(width: 1000, alignment: .leading)
                .frame(maxHeight: .infinity)
                .background(Palette.scrimTint.opacity(0.88))
            }
            .overlay(alignment: .bottomTrailing) {
                if let liveCaption {
                    HStack(spacing: Metrics.Spacing.small) {
                        Circle().fill(OnboardingForm.errorColor).frame(width: 12, height: 12)
                        Text(liveCaption)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, Metrics.televisionSafeArea.trailing)
                    .padding(.bottom, Metrics.televisionSafeArea.bottom)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("onboarding.liveCaption")
                }
            }
            .foregroundStyle(Palette.text)
            .ignoresSafeArea()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.summary")
        }
    }
}
