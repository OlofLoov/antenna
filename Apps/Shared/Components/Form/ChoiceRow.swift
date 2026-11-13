#if os(tvOS)
    import SwiftUI

    /// A choice among a few values as an Apple TV list row
    /// (`TV-Settings-Preferences`, `TV-Settings-Preferences-Choices`;
    /// design-system/forms-use-the-platform-form-style):
    /// the label and the current value, never an unlabeled segmented control.
    /// Selecting it pushes the list of choices with a checkmark on the current
    /// one, and picking one goes back to the row.
    struct ChoiceRow<Value: Hashable>: View {
        let label: String
        @Binding var selection: Value
        let choices: [Value]
        let title: (Value) -> String

        var body: some View {
            NavigationLink {
                ChoiceList(label: label, selection: $selection, choices: choices, title: title)
            } label: {
                LabeledContent(label, value: title(selection))
            }
        }
    }

    /// The pushed page of a `ChoiceRow`: the settings split page with the label
    /// on the left and one row per value on the right, the current one ticked.
    private struct ChoiceList<Value: Hashable>: View {
        let label: String
        @Binding var selection: Value
        let choices: [Value]
        let title: (Value) -> String
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            SettingsPage.Split {
                SettingsPage.Lead(symbol: "gearshape", title: label) {}
            } content: {
                list
            }
        }

        private var list: some View {
            List {
                ForEach(choices, id: \.self) { choice in
                    Button {
                        selection = choice
                        dismiss()
                    } label: {
                        HStack {
                            Text(title(choice))
                            Spacer(minLength: Metrics.Spacing.medium)
                            if choice == selection {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityAddTraits(choice == selection ? .isSelected : [])
                }
            }
            .listStyle(.grouped)
            .accessibilityIdentifier("settings.choices")
        }
    }

    #Preview("Choice rows") {
        @Previewable @State var hours = 2
        NavigationStack {
            List {
                ChoiceRow(label: "Guide window", selection: $hours, choices: [2, 3, 4]) { "\($0) hours" }
            }
        }
        .preferredColorScheme(.dark)
    }

    #Preview("Choice list") {
        @Previewable @State var hours = 3
        NavigationStack {
            ChoiceList(label: "Guide window", selection: $hours, choices: [2, 3, 4]) { "\($0) hours" }
        }
        .preferredColorScheme(.dark)
    }
#endif
