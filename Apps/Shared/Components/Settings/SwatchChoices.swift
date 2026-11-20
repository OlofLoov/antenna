import AntennaCore
import SwiftUI

/// A Settings row for a choice that is easier seen than read, such as the
/// accent or the app icon (`iPhone-Settings-Appearance`, `TV-Settings-Appearance`):
/// the label, then a swatch and the name of the current choice. It pushes
/// `SwatchChoiceList`. `swatch` draws a choice at the side it is given.
struct SwatchChoiceRow<Value: Hashable, Swatch: View>: View {
    let label: LocalizedStringResource
    let footer: LocalizedStringResource
    @Binding var selection: Value
    let choices: [Value]
    let id: (Value) -> String
    let title: (Value) -> LocalizedStringResource
    @ViewBuilder let swatch: (Value, CGFloat) -> Swatch

    #if os(tvOS)
        private let side: CGFloat = 40
    #else
        private let side: CGFloat = 24
    #endif

    var body: some View {
        NavigationLink {
            SwatchChoiceList(
                label: label, footer: footer, selection: $selection, choices: choices, id: id, title: title, swatch: swatch)
        } label: {
            LabeledContent {
                HStack(spacing: Metrics.Spacing.small) {
                    swatch(selection, side)
                        .accessibilityHidden(true)
                    Text(title(selection))
                }
            } label: {
                Text(label)
            }
        }
    }
}

/// The pushed page of a `SwatchChoiceRow` (`iPhone-Settings-AppIcon`,
/// `TV-Settings-Accent`): one row per choice with its swatch and name, a
/// checkmark on the current one. Picking a row goes back. On Apple TV it is
/// the settings split page with the footer in the lead column.
struct SwatchChoiceList<Value: Hashable, Swatch: View>: View {
    let label: LocalizedStringResource
    let footer: LocalizedStringResource
    @Binding var selection: Value
    let choices: [Value]
    let id: (Value) -> String
    let title: (Value) -> LocalizedStringResource
    @ViewBuilder let swatch: (Value, CGFloat) -> Swatch
    @Environment(\.dismiss) private var dismiss

    #if os(tvOS)
        private let side: CGFloat = 56
    #else
        private let side: CGFloat = 44
    #endif

    var body: some View {
        #if os(tvOS)
            SettingsPage.Split {
                SettingsPage.Lead(symbol: "paintpalette", title: label) {
                    Text(footer)
                }
            } content: {
                list
                    .listStyle(.grouped)
            }
        #else
            list
                .navigationTitle(Text(label))
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
        #endif
    }

    private var list: some View {
        List {
            Section {
                ForEach(choices, id: \.self) { choice in
                    Button {
                        selection = choice
                        dismiss()
                    } label: {
                        HStack(spacing: Metrics.Spacing.medium) {
                            swatch(choice, side)
                                .accessibilityHidden(true)
                            Text(title(choice))
                            Spacer(minLength: Metrics.Spacing.medium)
                            if choice == selection {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    #if !os(tvOS)
                        .foregroundStyle(Palette.text)
                    #endif
                    .accessibilityAddTraits(choice == selection ? .isSelected : [])
                    .accessibilityIdentifier("settings.choice.\(id(choice))")
                }
            } footer: {
                #if !os(tvOS)
                    Text(footer)
                #endif
            }
        }
        .accessibilityIdentifier("settings.choices")
    }
}

/// A round swatch of an accent.
struct AccentSwatch: View {
    let accent: ProfileAccent
    let side: CGFloat

    var body: some View {
        Circle()
            .fill(accent.color)
            .frame(width: side * 0.6, height: side * 0.6)
            .frame(width: side, height: side)
    }
}

#Preview("Accent choices") {
    @Previewable @State var accent = ProfileAccent.teal
    NavigationStack {
        SwatchChoiceList(
            label: "Accent", footer: "The accent is for this profile on every device.", selection: $accent,
            choices: ProfileAccent.allCases, id: \.rawValue, title: \.title
        ) { choice, side in
            AccentSwatch(accent: choice, side: side)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Accent row") {
    @Previewable @State var accent = ProfileAccent.amber
    NavigationStack {
        List {
            SwatchChoiceRow(
                label: "Accent", footer: "The accent is for this profile on every device.", selection: $accent,
                choices: ProfileAccent.allCases, id: \.rawValue, title: \.title
            ) { choice, side in
                AccentSwatch(accent: choice, side: side)
            }
        }
    }
    .preferredColorScheme(.dark)
}
