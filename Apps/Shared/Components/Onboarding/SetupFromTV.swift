import SwiftUI

/// The iPhone, iPad and Mac side of setting up an Apple TV
/// (`iPhone-Onboard-2-FromTV`, `-Waiting`, `-Sent`, `-Timeout`): the
/// banner over the add-source form, and the sending screen that replaces
/// the form after Connect. Takes values and closures.
enum SetupFromTV {
    /// "iPhone", "iPad" or "Mac".
    typealias Device = String

    /// "Opened from your Apple TV", with the count of sources already on this device.
    struct Banner: View {
        let device: Device
        /// Sources with an address already on this device.
        let existing: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "appletv")
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Opened from your Apple TV")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Fill this in here. The source syncs to the Apple TV through iCloud.")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textMuted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("onboarding.fromTV.banner")
                if let line = Self.existing(existing, device: device) {
                    Text(line)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                        .padding(.horizontal, 4)
                        .accessibilityIdentifier("onboarding.fromTV.existing")
                }
            }
        }

        static func existing(_ count: Int, device: Device) -> String? {
            switch count {
            case 0: nil
            case 1:
                "This \(device) already has 1 source. It appears on the Apple TV on its own when both use the same iCloud account."
            default:
                "This \(device) already has \(count) sources. "
                    + "They appear on the Apple TV on their own when both use the same iCloud account."
            }
        }
    }

    /// The line over the plain form for a link from a newer Antenna.
    struct UpdateLine: View {
        let device: Device

        var body: some View {
            Text("This code is from a newer Antenna. Update Antenna on this \(device) to set up your Apple TV from here.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textMuted)
                .padding(.horizontal, 4)
                .accessibilityIdentifier("onboarding.fromTV.update")
        }
    }

    /// Where the source is on its way.
    enum Delivery: Equatable {
        case sending
        case sent
        case notSent
        case notSignedIn
    }

    /// "Sending to your Apple TV": the source saved here, its way to the
    /// TV, and Continue, which turns primary once the row is done or stalled.
    struct Sending: View {
        let device: Device
        let sourceName: String
        let delivery: Delivery
        let continueHere: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sending to your Apple TV")
                        .font(.system(size: 22, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Through iCloud. Antenna on the Apple TV picks it up on its own.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.textMuted)
                }
                VStack(spacing: 0) {
                    StatusRow(state: .done, title: "Saved on this \(device)", detail: sourceName)
                        .accessibilityIdentifier("onboarding.sending.row.saved")
                    StatusRow(state: tvState, title: tvTitle, detail: tvDetail)
                        .accessibilityIdentifier("onboarding.sending.row.tv")
                }
                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                Label("The login stays in your iCloud Keychain. If the Apple TV asks for it, enter it once there.", systemImage: "lock")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textMuted)
                Spacer(minLength: 0)
                Button(action: continueHere) {
                    Text("Continue on \(device)")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(primary ? Palette.ground : Palette.text)
                        .background(primary ? Palette.text : Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.sending.continue")
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.sending")
        }

        private var primary: Bool { delivery != .sending }

        private var tvState: StatusRow.State {
            switch delivery {
            case .sending: .running
            case .sent: .done
            case .notSent, .notSignedIn: .failed
            }
        }

        private var tvTitle: String {
            switch delivery {
            case .sending: "Sending to your Apple TV…"
            case .sent: "Handed to iCloud. Open Antenna on your Apple TV."
            case .notSent, .notSignedIn: "Not sent yet"
            }
        }

        private var tvDetail: String? {
            switch delivery {
            case .sending: "Usually a few seconds"
            case .sent: nil
            case .notSent: "Check that this \(device) is online and signed in to iCloud. It sends on its own once it can."
            case .notSignedIn:
                "This \(device) isn't signed in to iCloud, so the source can't reach your Apple TV. "
                    + "Sign in to iCloud in Settings and it sends on its own."
            }
        }
    }

    /// One row: a done check, a ring or "In progress" with Reduce Motion,
    /// or the error glyph; read by VoiceOver as state, title and detail.
    struct StatusRow: View {
        enum State { case done, running, failed }

        let state: State
        let title: String
        let detail: String?
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                marker.frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .semibold))
                    if let detail {
                        Text(detail)
                            .font(.system(size: 15))
                            .foregroundStyle(state == .failed ? OnboardingForm.errorColor : Palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([stateLabel, title, detail].compactMap(\.self).joined(separator: ". "))
        }

        @ViewBuilder private var marker: some View {
            switch state {
            case .done:
                Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Palette.accent)
            case .running where reduceMotion:
                Text("In progress").font(.system(size: 11)).foregroundStyle(Palette.textMuted).fixedSize()
            case .running:
                ProgressView()
            case .failed:
                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 22)).foregroundStyle(OnboardingForm.errorColor)
            }
        }

        private var stateLabel: String {
            switch state {
            case .done: "Done"
            case .running: "In progress"
            case .failed: "Not done"
            }
        }
    }
}

#Preview("From Apple TV, sending") {
    SetupFromTV.Sending(device: "iPhone", sourceName: "Home provider", delivery: .sending) {}
}

#Preview("From Apple TV, sent") {
    SetupFromTV.Sending(device: "iPhone", sourceName: "Home provider", delivery: .sent) {}
}

#Preview("From Apple TV, not sent after 30 s") {
    SetupFromTV.Sending(device: "iPhone", sourceName: "Home provider", delivery: .notSent) {}
}

#Preview("From Apple TV, not signed in to iCloud") {
    SetupFromTV.Sending(device: "iPhone", sourceName: "Home provider", delivery: .notSignedIn) {}
}

#Preview("From Apple TV, banner with two sources") {
    SetupFromTV.Banner(device: "iPhone", existing: 2).padding().background(Palette.ground)
}
