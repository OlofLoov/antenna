#if !os(tvOS)
    import AntennaCore
    import SwiftUI

    /// "Sign in your Apple TV" on iPhone, iPad and Mac (`iPhone-SignIn-FromTV`,
    /// `iPhone-SignIn-FromTV-Sending`, `iPhone-SignIn-FromTV-Sent`,
    /// `iPhone-SignIn-FromTV-NotPickedUp`, `iPhone-SignIn-FromTV-Offline`,
    /// `iPhone-SignIn-FromTV-NotSignedIn`, `iPhone-SignIn-FromTV-Used`,
    /// `iPhone-SignIn-FromTV-None`). Takes values and closures.
    enum SendLogins {
        /// One requested source.
        struct Row: Identifiable, Equatable {
            enum State: Equatable {
                case ready
                case notHere
                case sending
                case sent
            }

            let id: UUID
            let name: String
            let kind: SourceKind
            let state: State
        }

        /// The status line above the list.
        enum Status: Equatable {
            case sending
            case pickedUp
            case notPickedUp
            case problem(String)
        }

        static let heading = "Sign in your Apple TV"
        static let body = "Your Apple TV asked for these logins. They're encrypted for that Apple TV only and go through your iCloud."

        /// "1 source the Apple TV asked for isn't on this iPhone yet. …"
        static func missing(_ count: Int, device: String) -> String? {
            guard count > 0 else { return nil }
            let sources = count == 1 ? "1 source the Apple TV asked for isn't" : "\(count) sources the Apple TV asked for aren't"
            return "\(sources) on this \(device) yet. New sources can take a minute to arrive through iCloud."
        }

        static func none(device: String) -> String {
            "None of the sources this Apple TV asked for are on this \(device). "
                + "Both need the same iCloud account, and new sources can take a minute to arrive."
        }

        static func lock(device: String) -> String { "Logins stay in your iCloud Keychain on this \(device)." }

        /// The type line under a source's name.
        static func kindName(_ kind: SourceKind) -> String {
            switch kind {
            case .xtream: "Xtream"
            case .stalker: "Stalker portal"
            case .jellyfin: "Jellyfin"
            case .channelsDVR: "Channels DVR"
            case .m3u: "M3U playlist"
            case .m3uFile: "Playlist file"
            }
        }

        /// The body of the sheet: heading, status, rows, the missing line and the lock note.
        struct Content: View {
            let device: String
            let rows: [Row]
            let missing: Int
            let status: Status?
            let enter: (UUID) -> Void

            var body: some View {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 12) {
                        Image(systemName: "appletv")
                            .font(.system(size: 34))
                            .frame(width: 72, height: 72)
                            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 18))
                            .accessibilityHidden(true)
                        Text(SendLogins.heading)
                            .font(.system(size: 22, weight: .bold))
                            .accessibilityAddTraits(.isHeader)
                        Text(SendLogins.body)
                            .font(.system(size: 15))
                            .foregroundStyle(OnboardingStyle.body)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    if let status { StatusLine(status: status, device: device) }
                    if rows.isEmpty {
                        Text(SendLogins.none(device: device))
                            .font(.system(size: 15))
                            .foregroundStyle(OnboardingStyle.body)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("sendLogins.missing")
                    } else {
                        list
                        if let line = SendLogins.missing(missing, device: device) {
                            Text(line)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.textMuted)
                                .padding(.horizontal, 4)
                                .accessibilityIdentifier("sendLogins.missing")
                        }
                        Label(SendLogins.lock(device: device), systemImage: "lock")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textMuted)
                            .padding(.horizontal, 4)
                    }
                }
            }

            private var list: some View {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Divider().overlay(Palette.surface(0.08)) }
                        RowView(row: row, device: device) { enter(row.id) }
                    }
                }
                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("sendLogins.list")
            }
        }

        /// A source's name and type, and on the right its state or Enter.
        /// VoiceOver reads it as state, name, type.
        struct RowView: View {
            let row: Row
            let device: String
            let enter: () -> Void

            var body: some View {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name).font(.system(size: 16))
                        Text(SendLogins.kindName(row.kind)).font(.system(size: 13)).foregroundStyle(Palette.textMuted)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stateText). \(row.name). \(SendLogins.kindName(row.kind))")
                    .accessibilityIdentifier("sendLogins.row")
                    Spacer(minLength: 8)
                    trailing
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 60)
            }

            private var stateText: String {
                switch row.state {
                case .ready: "Ready to send"
                case .notHere: "Not on this \(device)"
                case .sending: "Sending"
                case .sent: "Sent"
                }
            }

            @ViewBuilder private var trailing: some View {
                switch row.state {
                case .ready:
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Palette.accent)
                        Text(stateText).font(.system(size: 13)).foregroundStyle(Palette.textMuted)
                    }
                    .accessibilityHidden(true)
                case .notHere:
                    HStack(spacing: 10) {
                        Text(stateText).font(.system(size: 13)).foregroundStyle(Palette.textMuted).accessibilityHidden(true)
                        Button("Enter", action: enter)
                            .font(.system(size: 15, weight: .semibold))
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Enter the login for \(row.name)")
                            .accessibilityIdentifier("sendLogins.enter")
                    }
                case .sending, .sent:
                    Text(stateText).font(.system(size: 13)).foregroundStyle(Palette.textMuted).accessibilityHidden(true)
                }
            }
        }

        /// The status card above the list.
        struct StatusLine: View {
            let status: Status
            let device: String

            var body: some View {
                Group {
                    switch status {
                    case .sending:
                        SetupFromTV.StatusRow(state: .running, title: "Sending to your Apple TV…", detail: nil)
                    case .pickedUp:
                        SetupFromTV.StatusRow(
                            state: .done, title: "Your Apple TV picked up the logins.",
                            detail: "It checks them with the provider and signs in.")
                    case .notPickedUp:
                        SetupFromTV.StatusRow(
                            state: .failed, title: "Not picked up yet",
                            detail: "Keep the sign-in open on the Apple TV. If the code there changed, scan the new one.")
                    case .problem(let text):
                        SetupFromTV.StatusRow(state: .failed, title: text, detail: nil)
                            .foregroundStyle(OnboardingForm.errorColor)
                    }
                }
                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("sendLogins.status")
            }
        }

        /// The white primary button at the bottom.
        struct Primary: View {
            let title: String
            let identifier: String
            var enabled = true
            let action: () -> Void

            var body: some View {
                Button(action: action) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(Palette.ground)
                        .background(Palette.text, in: RoundedRectangle(cornerRadius: 14))
                        .opacity(enabled ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityIdentifier(identifier)
            }
        }
    }

    private let previewRows = [
        SendLogins.Row(id: UUID(), name: "Home provider", kind: .xtream, state: .ready),
        SendLogins.Row(id: UUID(), name: "Holiday flat", kind: .stalker, state: .notHere),
    ]

    #Preview("Sign in your Apple TV") {
        SendLogins.Content(device: "iPhone", rows: previewRows, missing: 1, status: nil) { _ in }
            .padding(16)
            .background(Palette.ground)
            .preferredColorScheme(.dark)
    }

    #Preview("Sign in your Apple TV, picked up") {
        SendLogins.Content(
            device: "iPhone", rows: [.init(id: UUID(), name: "Home provider", kind: .xtream, state: .sent)], missing: 0,
            status: .pickedUp
        ) { _ in }
        .padding(16)
        .background(Palette.ground)
        .preferredColorScheme(.dark)
    }

    #Preview("Sign in your Apple TV, none here") {
        SendLogins.Content(device: "iPhone", rows: [], missing: 2, status: nil) { _ in }
            .padding(16)
            .background(Palette.ground)
            .preferredColorScheme(.dark)
    }
#endif
