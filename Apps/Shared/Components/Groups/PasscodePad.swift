import SwiftUI

/// The passcode prompt (`TV-Groups-Locked`, `iPhone-Groups-Locked`): a
/// title, what is locked, four digit boxes, the error line, a keypad and a
/// footer the screen supplies, such as Forgot passcode.
enum PasscodePad {
    /// Four boxes, the first `filled` showing a dot.
    struct Digits: View {
        let filled: Int

        var body: some View {
            HStack(spacing: 16) {
                ForEach(1...4, id: \.self) { slot in
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Palette.textMuted, lineWidth: 2)
                        .frame(width: 56, height: 64)
                        .overlay {
                            if slot <= filled { Circle().fill(Palette.text).frame(width: 14, height: 14) }
                        }
                        .accessibilityIdentifier("groups.passcode.digit.\(slot)")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(filled) of 4 digits entered")
        }
    }

    /// Keys 1 to 9, 0 and delete. `enabled` is false while a wait runs.
    struct Keypad: View {
        let enabled: Bool
        let type: (Character) -> Void
        let delete: () -> Void

        private let rows: [[Character]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

        var body: some View {
            Grid(horizontalSpacing: 16, verticalSpacing: 12) {
                ForEach(rows, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { digit in key(digit) }
                    }
                }
                GridRow {
                    Color.clear.frame(width: 1, height: 1)
                    key("0")
                    Button(action: delete) {
                        Image(systemName: "delete.left").frame(minWidth: 64, minHeight: 52)
                    }
                    .accessibilityLabel("Delete")
                    .accessibilityIdentifier("groups.passcode.key.delete")
                }
            }
            .disabled(!enabled)
        }

        private func key(_ digit: Character) -> some View {
            Button {
                type(digit)
            } label: {
                Text(String(digit)).font(.title2.monospacedDigit()).frame(minWidth: 64, minHeight: 52)
            }
            .accessibilityIdentifier("groups.passcode.key.\(digit)")
        }
    }

    /// The whole prompt. `error` is the line under the digits, nil for none.
    struct Prompt<Footer: View>: View {
        let title: String
        let message: String
        let filled: Int
        let error: String?
        let enabled: Bool
        let type: (Character) -> Void
        let delete: () -> Void
        @ViewBuilder let footer: Footer

        var body: some View {
            VStack(spacing: 20) {
                Text(title).font(.title.bold()).foregroundStyle(Palette.text)
                Text(message).foregroundStyle(Palette.textMuted).multilineTextAlignment(.center)
                Digits(filled: filled)
                Text(error ?? " ")
                    .foregroundStyle(Palette.text)
                    .accessibilityIdentifier("groups.passcode.error")
                    .accessibilityHidden(error == nil)
                Keypad(enabled: enabled, type: type, delete: delete)
                footer
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("groups.passcode")
        }
    }

    /// The prompt while the passcode has not reached this device yet
    /// (group-management/unlock-with-the-passcode): no digit keys.
    struct Waiting: View {
        let message: String

        var body: some View {
            VStack(spacing: 16) {
                Text("Enter passcode").font(.title.bold()).foregroundStyle(Palette.text)
                Text(message).foregroundStyle(Palette.textMuted)
                ProgressView()
                Text("Waiting for the passcode from iCloud.")
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("groups.passcode.waiting")
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("groups.passcode")
        }
    }
}

#Preview("Prompt") {
    PasscodePad.Prompt(
        title: "Enter passcode", message: "Movies is locked.", filled: 2, error: "Wrong passcode", enabled: true, type: { _ in },
        delete: {}
    ) {
        Text("Forgot passcode?").foregroundStyle(Palette.accent)
    }
}

#Preview("Waiting") {
    PasscodePad.Waiting(message: "Movies is locked.")
}
