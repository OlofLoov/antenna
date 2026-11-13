import SwiftUI

/// The rows the add-source form and the Apple TV sign-in are built from,
/// for a system `Form` (design-system/forms-use-the-platform-form-style):
/// each row is a label with the field or value beside it. On Apple TV the
/// field is the system text field, which takes the light platter when
/// focused and opens the full-screen keyboard when selected; the row itself
/// draws no fill, so no field sits inside a second capsule.
enum FieldRow {
    /// What a field holds, which sets its keyboard and correction.
    enum Entry {
        /// A name: the platform's default keyboard and correction.
        case words
        /// A link, server or portal: the URL keyboard, no correction.
        case link
        /// A username, login or MAC address: no capitalization or correction.
        case plain
    }

    /// A labeled text field.
    struct Text: View {
        let label: String
        @Binding var text: String
        var prompt = ""
        var entry = Entry.words
        let identifier: String

        var body: some View {
            LabeledContent {
                TextField(label, text: $text, prompt: SwiftUI.Text(prompt))
                    .entry(entry)
                    .accessibilityLabel(label)
                    .accessibilityIdentifier(identifier)
            } label: {
                Label(text: label)
            }
            .fieldRowBackground()
        }
    }

    /// A labeled password field. On iPhone, iPad and Mac the eye button
    /// beside it shows what is typed.
    struct Secret: View {
        let label: String
        @Binding var text: String
        var prompt = ""
        /// Nil leaves out the eye button, as on Apple TV.
        var reveals: Binding<Bool>?
        var identifier = "onboarding.field.password"

        var body: some View {
            LabeledContent {
                HStack(spacing: Metrics.Spacing.xSmall) {
                    Group {
                        if reveals?.wrappedValue == true {
                            TextField(label, text: $text, prompt: SwiftUI.Text(prompt)).entry(.plain)
                        } else {
                            SecureField(label, text: $text, prompt: SwiftUI.Text(prompt))
                        }
                    }
                    .accessibilityLabel(label)
                    .accessibilityIdentifier(identifier)
                    if let reveals {
                        Button {
                            reveals.wrappedValue.toggle()
                        } label: {
                            Image(systemName: reveals.wrappedValue ? "eye.slash" : "eye")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .tint(Palette.textMuted)
                        .accessibilityLabel(reveals.wrappedValue ? "Hide password" : "Show password")
                        .accessibilityIdentifier("onboarding.revealPassword")
                    }
                }
            } label: {
                Label(text: label)
            }
            .fieldRowBackground()
        }
    }

    /// A value that cannot be changed here, such as a server that came
    /// from the iPhone. Not focusable; VoiceOver reads it as its label and value.
    struct Value: View {
        let label: String
        let value: String
        let identifier: String

        var body: some View {
            LabeledContent {
                SwiftUI.Text(value)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            } label: {
                Label(text: label)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityIdentifier(identifier)
            .fieldRowBackground()
        }
    }

    /// A row that shows its label and current value and does something
    /// when selected, such as Type going back to the kinds on Apple TV.
    struct Choice: View {
        let label: String
        let value: String
        let identifier: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                LabeledContent(label, value: value)
            }
            .accessibilityIdentifier(identifier)
        }
    }

    /// Content under the fields, lined up with them, such as the Apple TV
    /// buttons: moving focus down from a field lands on what is under it.
    struct Indented<Content: View>: View {
        @ViewBuilder var content: Content

        var body: some View {
            LabeledContent {
                content
            } label: {
                Label(text: "")
            }
            .fieldRowBackground()
        }
    }

    /// The row's label, the same width in every row so the fields line up.
    private struct Label: View {
        let text: String

        var body: some View {
            SwiftUI.Text(text)
                .frame(minWidth: FieldRow.labelWidth, alignment: .leading)
                .accessibilityHidden(true)
        }
    }

    /// Wide enough for "MAC address" and "Username" at body size.
    static var labelWidth: CGFloat {
        #if os(tvOS)
            220
        #else
            96
        #endif
    }
}

extension View {
    /// The keyboard and correction for `entry`.
    @ViewBuilder fileprivate func entry(_ entry: FieldRow.Entry) -> some View {
        switch entry {
        case .words: self
        case .plain: plainEntry()
        case .link:
            #if os(iOS)
                plainEntry().keyboardType(.URL)
            #else
                plainEntry()
            #endif
        }
    }

    /// On Apple TV the field is the row: the list draws no fill behind it.
    @ViewBuilder fileprivate func fieldRowBackground() -> some View {
        #if os(tvOS)
            listRowBackground(Color.clear)
        #else
            self
        #endif
    }

    /// No autocapitalization or autocorrection, for links and usernames.
    func plainEntry() -> some View {
        #if os(iOS) || os(tvOS)
            self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
            self.autocorrectionDisabled()
        #endif
    }
}

private struct FieldRowSample: View {
    @State private var fields = SourceFieldsSample()

    var body: some View {
        Form {
            Section {
                FieldRow.Choice(label: "Type", value: "Xtream login", identifier: "sample.kind") {}
            }
            Section {
                FieldRow.Text(label: "Name", text: $fields.name, prompt: "Optional", identifier: "sample.name")
                FieldRow.Value(label: "Server", value: "http://tv.example-provider.net:8080", identifier: "sample.server")
                FieldRow.Text(label: "Username", text: $fields.username, prompt: "Required", entry: .plain, identifier: "sample.username")
                FieldRow.Secret(label: "Password", text: $fields.password, prompt: "Required")
            } footer: {
                Text("Saved in the Keychain on this device.")
            }
        }
    }

    struct SourceFieldsSample {
        var name = "Home provider"
        var username = ""
        var password = ""
    }
}

#Preview("Field rows, Apple TV", traits: .fixedLayout(width: 1000, height: 700)) {
    FieldRowSample()
}

#Preview("Field rows, iPhone") {
    FieldRowSample()
}
