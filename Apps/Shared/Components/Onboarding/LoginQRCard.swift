#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// "Send the login from your iPhone" beside the Apple TV's sign-in
    /// fields (`TV-Onboard-SignIn-QR`, `TV-Onboard-SignIn-QR-Checking`,
    /// `TV-Onboard-SignIn-QR-Unreadable`, `TV-Settings-SignIn-QR`): the QR
    /// code for the sign-in link, the status and the hint. Takes values only;
    /// the code is never focusable.
    enum LoginQRCard {
        /// What the card says under the code.
        enum Status: Equatable {
            /// "Waiting for your iPhone", with the number of logins asked for
            /// and the two-minute hint.
            case waiting(count: Int, hint: Bool)
            /// A delivery arrived; these sources are being checked.
            case checking([String])
            /// A delivery arrived that this TV cannot read.
            case unreadable
            /// A delivered login did not work, with the sign-in's sentence.
            case failed(String)
        }

        static let title = "Send the login from your iPhone"
        static let body =
            "Scan the code with your iPhone camera. Antenna there sends the login to this Apple TV, encrypted, through iCloud."
        static let footer = "Prefer the remote? Type here; your iPhone offers its keyboard too."
        static let codeLabel = "QR code. Scan it with your iPhone to send the login to this Apple TV."
        static let unreadable = "Something arrived from your iPhone that this Apple TV can't read."
        static let unreadableHint = "Update Antenna on both, or type the login here."
        static let received = "Login received from your iPhone"

        /// "Waiting for your iPhone", and "· 2 logins" when the code asks for more than one.
        static func waiting(_ count: Int) -> String {
            count > 1 ? "Waiting for your iPhone · \(count) logins" : "Waiting for your iPhone"
        }

        struct Television: View {
            let link: URL
            let status: Status

            var body: some View {
                VStack(alignment: .leading, spacing: Metrics.Spacing.large) {
                    Text(LoginQRCard.title)
                        .font(.callout.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    SetupCard.QRTile(link: link, size: 260, label: LoginQRCard.codeLabel, identifier: "signIn.qr.code")
                        .opacity(isChecking ? 0.4 : 1)
                        .frame(maxWidth: .infinity)
                    Text(LoginQRCard.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    statusRows
                    Text(LoginQRCard.footer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Metrics.Spacing.xLarge)
                .frame(width: 480, alignment: .leading)
                .background(.regularMaterial, in: Metrics.Corner.large.shape())
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("signIn.qr")
            }

            private var isChecking: Bool {
                if case .checking = status { return true }
                return false
            }

            @ViewBuilder private var statusRows: some View {
                VStack(alignment: .leading, spacing: Metrics.Spacing.small) {
                    switch status {
                    case .waiting(let count, let hint):
                        HStack(spacing: Metrics.Spacing.small) {
                            Circle().fill(Palette.accent).frame(width: 12, height: 12).accessibilityHidden(true)
                            Text(LoginQRCard.waiting(count)).font(.caption)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("signIn.qr.status")
                        if hint { line(SetupCard.nothingYet, color: .secondary) }
                    case .checking(let names):
                        VStack(alignment: .leading, spacing: Metrics.Spacing.small) {
                            ForEach(names.isEmpty ? [""] : names, id: \.self) { name in
                                ProgressLine(text: name.isEmpty ? "Login received. Checking…" : "Login received. Checking with \(name)…")
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("signIn.qr.status")
                    case .unreadable:
                        problem(LoginQRCard.unreadable)
                        line(LoginQRCard.unreadableHint, color: .secondary)
                    case .failed(let message):
                        problem(message)
                    }
                }
            }

            private func problem(_ text: String) -> some View {
                HStack(alignment: .firstTextBaseline, spacing: Metrics.Spacing.small) {
                    Circle().fill(OnboardingForm.errorColor).frame(width: 12, height: 12).accessibilityHidden(true)
                    Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(OnboardingForm.errorColor)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("signIn.qr.status")
            }

            private func line(_ text: String, color: HierarchicalShapeStyle) -> some View {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("signIn.qr.hint")
            }
        }
    }

    private let previewLink =
        SetupLink(
            token: PairingToken("AAAAAAAAAAAAAAAAAAAAAA") ?? PairingToken(),
            key: SetupKey(String(repeating: "A", count: 43)), sources: [UUID(), UUID()]
        ).url

    #Preview("Sign-in QR card, waiting for two logins", traits: .fixedLayout(width: 1920, height: 1080)) {
        LoginQRCard.Television(link: previewLink, status: .waiting(count: 2, hint: false))
    }

    #Preview("Sign-in QR card, nothing after two minutes", traits: .fixedLayout(width: 1920, height: 1080)) {
        LoginQRCard.Television(link: previewLink, status: .waiting(count: 1, hint: true))
    }

    #Preview("Sign-in QR card, checking", traits: .fixedLayout(width: 1920, height: 1080)) {
        LoginQRCard.Television(link: previewLink, status: .checking(["Home provider", "Holiday flat"]))
    }

    #Preview("Sign-in QR card, a delivery it cannot read", traits: .fixedLayout(width: 1920, height: 1080)) {
        LoginQRCard.Television(link: previewLink, status: .unreadable)
    }
#endif
