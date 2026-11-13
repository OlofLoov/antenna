import SwiftUI

/// What a form field takes: the keyboard it offers and how a row shows the value.
enum FieldEntry: Sendable {
    /// Words, such as a name.
    case text
    /// A link or server address: the URL keyboard, no capitals, no autocorrection.
    case link
    /// A username or MAC address: no capitals, no autocorrection.
    case login
    /// A password: dots on the row, a secure keyboard.
    case secure
}

#if os(tvOS)
    import UIKit

    /// A text field as an Apple TV form row (`TV-Refresh-AddSource`,
    /// `TV-Settings-Details`; design-system/forms-use-the-platform-form-style):
    /// the label on the left and the value on the right, or the prompt while
    /// the value is empty. The row is a system list button, so focus gives it
    /// the light platter with dark text. Selecting it opens the system
    /// keyboard full screen under the label, and the row shows what was typed
    /// once the keyboard closes. A secure row shows dots for a value and
    /// never the value itself.
    struct FieldRow: View {
        let label: String
        @Binding var text: String
        var prompt = ""
        var entry = FieldEntry.text
        @State private var editing = false

        var body: some View {
            Button {
                editing = true
            } label: {
                LabeledContent {
                    Text(shown)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } label: {
                    Text(label)
                }
            }
            .background {
                KeyboardField(title: label, text: $text, entry: entry, editing: $editing)
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(label)
            .accessibilityValue(entry == .secure ? "" : text)
        }

        private var shown: String {
            if text.isEmpty { return prompt }
            return entry == .secure ? String(repeating: "•", count: 8) : text
        }
    }

    /// The hidden `UITextField` behind a `FieldRow`. Becoming first responder
    /// is what makes tvOS present its full-screen keyboard; SwiftUI's
    /// `TextField` only does that when the user selects the field itself.
    private struct KeyboardField: UIViewRepresentable {
        let title: String
        @Binding var text: String
        let entry: FieldEntry
        @Binding var editing: Bool

        func makeUIView(context: Context) -> UITextField {
            let field = UITextField()
            field.delegate = context.coordinator
            field.placeholder = title
            // Nothing of the field shows on the row; the keyboard draws its own copy.
            field.borderStyle = .none
            field.backgroundColor = .clear
            field.textColor = .clear
            field.tintColor = .clear
            field.clipsToBounds = true
            field.isSecureTextEntry = entry == .secure
            field.keyboardType = entry == .link ? .URL : .default
            field.autocapitalizationType = entry == .text ? .words : .none
            field.autocorrectionType = entry == .text ? .default : .no
            field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
            return field
        }

        func updateUIView(_ field: UITextField, context: Context) {
            context.coordinator.parent = self
            if field.text != text { field.text = text }
            if editing, !field.isFirstResponder {
                field.becomeFirstResponder()
            }
        }

        func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
            CGSize(width: 1, height: 1)
        }

        func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

        final class Coordinator: NSObject, UITextFieldDelegate {
            var parent: KeyboardField

            init(parent: KeyboardField) {
                self.parent = parent
            }

            @objc func changed(_ field: UITextField) {
                parent.text = field.text ?? ""
            }

            /// Menu closes the keyboard by putting the field's text back, so
            /// the row keeps what `changed` saw last, as SwiftUI's
            /// `TextField` does.
            func textFieldDidEndEditing(_ field: UITextField) {
                parent.editing = false
            }
        }
    }

    #Preview("Field rows, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
        @Previewable @State var name = ""
        @Previewable @State var server = "http://tv.example-provider.net:8080"
        @Previewable @State var password = "secret"
        List {
            FieldRow(label: "Name", text: $name, prompt: "Optional")
            FieldRow(label: "Server", text: $server, prompt: "Required", entry: .link)
            FieldRow(label: "Password", text: $password, prompt: "Required", entry: .secure)
        }
        .frame(width: 1120)
    }
#endif
