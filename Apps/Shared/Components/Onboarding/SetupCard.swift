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
    }

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
            VStack(alignment: .leading, spacing: 24) {
                Text(SetupCard.title)
                    .font(.system(size: 30, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                QRTile(link: link)
                    .opacity(isArrived ? 0.4 : 1)
                Text(SetupCard.body)
                    .font(.system(size: 22))
                    .foregroundStyle(OnboardingStyle.body)
                    .fixedSize(horizontal: false, vertical: true)
                statusRows
                action
                Text(SetupCard.footer)
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(36)
            .frame(width: 520, alignment: .leading)
            .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.qr")
        }

        private var isArrived: Bool {
            if case .arrived = status { return true }
            return false
        }

        @ViewBuilder private var statusRows: some View {
            switch status {
            case .waiting(let hint):
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Circle().fill(SetupCard.accent).frame(width: 12, height: 12).accessibilityHidden(true)
                        Text("Waiting for your iPhone")
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.textMuted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("onboarding.qr.status")
                    if let hint {
                        Text(hint)
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.textMuted)
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
            }
        }
    }

    /// The button under an arrived source, which moves focus to the login fields.
    struct SignInHere: View {
        let action: () -> Void

        var body: some View {
            Button("Sign in on this Apple TV", action: action)
                .buttonStyle(OnboardingStyle.PrimaryTV())
                .accessibilityIdentifier("onboarding.qr.signInHere")
        }
    }

    /// One status line with its 28 pt glyph, read as one element.
    private struct Row: View {
        let symbol: String
        let color: Color
        let text: String
        let state: String

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.system(size: 22))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(state). \(text)")
        }
    }

    /// The white 300 pt tile with the code. White, because a scanner needs
    /// a light quiet zone; not focusable.
    struct QRTile: View {
        let link: URL

        var body: some View {
            Group {
                if let image = QRCode.image(for: link) {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                }
            }
            .padding(20)
            .frame(width: 300, height: 300)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement()
            .accessibilityLabel(SetupCard.codeLabel)
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier("onboarding.qr.code")
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
