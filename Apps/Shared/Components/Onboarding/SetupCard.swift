import AntennaCore
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// "Set up from your iPhone" beside the Apple TV's details form
/// (`TV-Onboard-3-QR`, `TV-Onboard-3-QR-Timeout`, `TV-Onboard-3-QR-SignIn`):
/// the QR code for the setup link, the status, and the two-minute hint or
/// the arrived source. Takes values and one closure.
enum SetupCard {
    /// What the card says under the code.
    enum Status: Equatable {
        /// "Waiting for your iPhone", with the hint once two minutes passed.
        case waiting(hint: String?)
        /// A login source arrived: its name and what has not reached the TV.
        case arrived(name: String, missing: String)
        /// A login source arrived and its login is on the way or being
        /// checked: "Waiting for the login…" or "Checking the login…" (`TV-Onboard-3-QR-Received`).
        case awaitingLogin(name: String, progress: String)
    }

    static let waitingForLogin = "Waiting for the login…"
    static let checkingLogin = "Checking the login…"

    static let title = "Set up from your iPhone"
    static let body =
        "Point your iPhone camera at the code. Antenna opens there with this form, "
        + "and what you enter syncs to this Apple TV through iCloud."
    static let footer =
        "Antenna also appears in the App Switcher on your iPhone. Prefer the remote? Type here; your iPhone offers its keyboard too."
    static let nothingYet =
        "Nothing yet? Your iPhone needs Antenna installed, an internet connection and the same iCloud account as this Apple TV."
    static let cannotSetUp = "A source arrived from iCloud that this Apple TV can't set up here. Update Antenna, or type the source here."
    static let codeLabel = "QR code. Scan it with your iPhone to set up this Apple TV from there."

    /// What has not reached the TV for a source of `kind`.
    static func missing(_ kind: SourceKind) -> String {
        kind == .stalker ? "The MAC address hasn't reached this Apple TV." : "The login hasn't reached this Apple TV."
    }

    static let accent = Palette.accent

    /// The card. `action` sits under the status, for the "Sign in on this
    /// Apple TV" button after an arrival.
    struct Television<Action: View>: View {
        let link: URL
        let status: Status
        @ViewBuilder var action: Action

        var body: some View {
            VStack(alignment: .leading, spacing: Metrics.Spacing.large) {
                HStack(alignment: .top, spacing: Metrics.Spacing.xLarge) {
                    QRTile(link: link, size: 220)
                        .opacity(isArrived ? 0.4 : 1)
                    VStack(alignment: .leading, spacing: Metrics.Spacing.small) {
                        Text(SetupCard.title)
                            .font(.callout.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text(SetupCard.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                statusRows
                action
                Text(SetupCard.footer)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Metrics.Spacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: Metrics.Corner.large.shape())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.qr")
        }

        private var isArrived: Bool {
            switch status {
            case .arrived, .awaitingLogin: true
            case .waiting: false
            }
        }

        @ViewBuilder private var statusRows: some View {
            switch status {
            case .waiting(let hint):
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: Metrics.Spacing.small) {
                        Circle().fill(SetupCard.accent).frame(width: 12, height: 12).accessibilityHidden(true)
                        Text("Waiting for your iPhone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("onboarding.qr.status")
                    if let hint {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("onboarding.qr.hint")
                    }
                }
            case .arrived(let name, let missing):
                VStack(alignment: .leading, spacing: 12) {
                    Row(symbol: "checkmark.circle.fill", color: SetupCard.accent, text: "\(name) arrived from your iPhone", state: "Done")
                        .accessibilityIdentifier("onboarding.qr.status")
                    Row(symbol: "exclamationmark.circle.fill", color: OnboardingForm.errorColor, text: missing, state: "Missing")
                        .foregroundStyle(OnboardingForm.errorColor)
                }
            case .awaitingLogin(let name, let progress):
                VStack(alignment: .leading, spacing: 12) {
                    Row(symbol: "checkmark.circle.fill", color: SetupCard.accent, text: "\(name) arrived from your iPhone", state: "Done")
                        .accessibilityIdentifier("onboarding.qr.status")
                    ProgressLine(text: progress)
                        .accessibilityIdentifier("onboarding.qr.login")
                }
            }
        }
    }

    /// The button under an arrived source, which moves focus to the login fields.
    struct SignInHere: View {
        let action: () -> Void

        var body: some View {
            Button("Sign in on this Apple TV", action: action)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboarding.qr.signInHere")
        }
    }

    /// One status line with its glyph, at caption size, read as one element.
    private struct Row: View {
        let symbol: String
        let color: Color
        let text: String
        let state: String

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.Spacing.small) {
                Image(systemName: symbol)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(state). \(text)")
        }
    }

    /// The white tile with the code, 300 pt unless `size` says otherwise.
    /// White, because a scanner needs a light quiet zone; not focusable.
    struct QRTile: View {
        let link: URL
        var size: CGFloat = 300
        var label = SetupCard.codeLabel
        var identifier = "onboarding.qr.code"

        var body: some View {
            Group {
                if let image = QRCode.image(for: link) {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                }
            }
            .padding(size / 15)
            .frame(width: size, height: size)
            .background(Color.white, in: Metrics.Corner.medium.shape())
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier(identifier)
        }
    }
}

extension SetupCard.Television where Action == EmptyView {
    init(link: URL, status: SetupCard.Status) {
        self.init(link: link, status: status) { EmptyView() }
    }
}

/// QR codes drawn with Core Image.
enum QRCode {
    /// The code for `url` with medium error correction, one pixel per
    /// module; nil when Core Image cannot draw it.
    static func image(for url: URL) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        return CIContext(options: [.useSoftwareRenderer: true]).createCGImage(output, from: output.extent)
    }
}

#if os(tvOS)
    private let previewLink = SetupLink(token: PairingToken("AAAAAAAAAAAAAAAAAAAAAA") ?? PairingToken()).url

    #Preview("QR card, waiting", traits: .fixedLayout(width: 1920, height: 1080)) {
        SetupCard.Television(link: previewLink, status: .waiting(hint: nil))
    }

    #Preview("QR card, nothing after two minutes", traits: .fixedLayout(width: 1920, height: 1080)) {
        SetupCard.Television(link: previewLink, status: .waiting(hint: SetupCard.nothingYet))
    }

    #Preview("QR card, Xtream arrived", traits: .fixedLayout(width: 1920, height: 1080)) {
        SetupCard.Television(link: previewLink, status: .arrived(name: "Home provider", missing: SetupCard.missing(.xtream))) {
            SetupCard.SignInHere {}
        }
    }
#endif
