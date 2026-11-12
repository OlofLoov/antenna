import SwiftUI

/// The Apple TV summary over the first channel playing (`TV-Onboard-5`,
/// `TV-Onboard-5-Two`): the eyebrow, "You're set", the tiles, Start
/// watching or Browse movies, and Add another source. The picture is the
/// caller's `background`.
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
                VStack(alignment: .leading, spacing: 44) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(eyebrow.uppercased())
                            .font(.system(size: 20, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(Palette.accent)
                            .accessibilityIdentifier("onboarding.eyebrow")
                        Text("You're set")
                            .font(.system(size: 64, weight: .heavy))
                            .accessibilityAddTraits(.isHeader)
                        if liveCaption != nil {
                            Text(
                                "The first channel is already playing. Press the touch surface for the channel list, "
                                    + "press play/pause for the channel bar."
                            )
                            .font(.system(size: 26))
                            .foregroundStyle(OnboardingStyle.body)
                        }
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(tiles) { tile in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(tile.value).font(.system(size: 44, weight: .bold)).monospacedDigit()
                                Text(tile.caption).font(.system(size: 20)).foregroundStyle(Palette.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 24)
                            .padding(.horizontal, 28)
                            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("onboarding.tile.\(tile.id)")
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            Button(primary.title, action: actions.primary)
                                .buttonStyle(OnboardingStyle.PrimaryTV())
                                .disabled(!primary.isEnabled)
                                .accessibilityIdentifier("onboarding.primary")
                            if let addAnother = actions.addAnother {
                                Button("Add another source", action: addAnother)
                                    .buttonStyle(OnboardingStyle.PrimaryTV())
                                    .accessibilityIdentifier("onboarding.addAnother")
                            }
                        }
                        Text(footnote)
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.textMuted)
                    }
                }
                .padding(.horizontal, 96)
                .frame(width: 1000, alignment: .leading)
                .frame(maxHeight: .infinity)
                .background(Palette.scrimTint.opacity(0.88))
            }
            .overlay(alignment: .bottomTrailing) {
                if let liveCaption {
                    HStack(spacing: 14) {
                        Circle().fill(OnboardingForm.errorColor).frame(width: 12, height: 12)
                        Text(liveCaption)
                    }
                    .font(.system(size: 24))
                    .foregroundStyle(Palette.textMuted)
                    .padding(.trailing, 64)
                    .padding(.bottom, 44)
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
