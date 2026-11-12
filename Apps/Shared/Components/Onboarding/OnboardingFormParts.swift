import AntennaCore
import SwiftUI

/// The pieces the add-source form is built from.
extension OnboardingForm {
    /// M3U playlist, Xtream login, Stalker portal and Jellyfin server.
    struct KindPicker: View {
        let kind: SourceKind
        let choose: (SourceKind) -> Void

        var body: some View {
            HStack(spacing: 4) {
                segment("M3U playlist", .m3u)
                segment("Xtream login", .xtream)
                segment("Stalker", .stalker)
                    .accessibilityLabel("Stalker portal")
                segment("Jellyfin", .jellyfin)
                    .accessibilityLabel("Jellyfin server")
            }
            .padding(4)
            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 12))
        }

        private func segment(_ title: String, _ value: SourceKind) -> some View {
            let selected = kind == value
            return Button {
                choose(value)
            } label: {
                Text(title)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundStyle(selected ? Palette.ground : Palette.text)
                    .background(selected ? Palette.text : .clear, in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("onboarding.kind.\(value.rawValue)")
        }
    }

    /// "A link is on the clipboard" with Fill in, or "No link on the clipboard".
    struct ClipboardBanner: View {
        let offer: ClipboardOffer
        let fillIn: () -> Void

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer == .link ? "A link is on the clipboard" : "No link on the clipboard")
                        .font(.system(size: 15, weight: .semibold))
                    Text(offer == .link ? "Antenna reads it only when you tap Fill in" : "Type the details from your provider below")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                }
                Spacer(minLength: 0)
                if offer == .link {
                    Button("Fill in", action: fillIn)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .foregroundStyle(Palette.ground)
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.fillIn")
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.clipboard")
        }
    }

    /// One labeled row of the grouped iPhone form.
    struct Row<Field: View>: View {
        let label: String
        var last = false
        @ViewBuilder var field: Field

        var body: some View {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(OnboardingStyle.body)
                    .frame(width: 88, alignment: .leading)
                    .accessibilityHidden(true)
                field
                    .font(.system(size: 16))
                    .accessibilityLabel(label)
            }
            .frame(minHeight: 48)
            .padding(.horizontal, 14)
            .overlay(alignment: .bottom) {
                if !last { Rectangle().fill(Palette.surface(0.08)).frame(height: 1) }
            }
        }
    }

    /// A link field: no autocapitalization or correction, the URL keyboard.
    struct LinkField: View {
        let placeholder: String
        @Binding var text: String
        let identifier: String

        var body: some View {
            TextField(placeholder, text: $text)
                .plainEntry()
                #if os(iOS)
                    .keyboardType(.URL)
                #endif
                .accessibilityIdentifier(identifier)
        }
    }

    /// The password, hidden unless the eye control reveals it.
    struct PasswordField: View {
        @Binding var text: String
        @Binding var reveals: Bool
        let revealSize: CGFloat
        var placeholder = ""

        var body: some View {
            HStack(spacing: 4) {
                Group {
                    if reveals {
                        TextField(placeholder, text: $text).plainEntry()
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .accessibilityIdentifier("onboarding.field.password")
                Button {
                    reveals.toggle()
                } label: {
                    Image(systemName: reveals ? "eye.slash" : "eye")
                        .foregroundStyle(Palette.textMuted)
                        .frame(width: revealSize, height: revealSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reveals ? "Hide password" : "Show password")
                .accessibilityIdentifier("onboarding.revealPassword")
            }
        }
    }

    /// One Apple TV field with its uppercase label above it.
    struct Stacked<Field: View>: View {
        let label: String
        var optional = false
        @ViewBuilder var field: Field

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                (Text(label.uppercased()).fontWeight(.semibold) + Text(optional ? " (optional)" : ""))
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityHidden(true)
                field
                    .font(.system(size: 28))
                    .accessibilityLabel(optional ? "\(label), optional" : label)
            }
        }
    }

    /// The card about the keyboard an iPhone nearby offers. It describes
    /// the system offer and claims nothing Antenna does.
    struct TypeOnPhoneCard: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "iphone")
                    .font(.system(size: 36))
                    .frame(width: 72, height: 72)
                    .background(Palette.surface(0.1), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
                Text("Easier to type on iPhone")
                    .font(.system(size: 30, weight: .bold))
                Text(
                    "An unlocked iPhone or iPad nearby offers its keyboard for this Apple TV. Tap that notification and the fields "
                        + "fill in here as you type. Or add the source in Antenna on iPhone and it syncs over."
                )
                .font(.system(size: 22))
                .foregroundStyle(OnboardingStyle.body)
                Text("The offer comes from iOS and needs no setup.")
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(36)
            .frame(width: 480, alignment: .leading)
            .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine)
        }
    }
}

extension View {
    /// No autocapitalization or autocorrection, for links and usernames.
    func plainEntry() -> some View {
        #if os(iOS) || os(tvOS)
            self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
            self.autocorrectionDisabled()
        #endif
    }
}
