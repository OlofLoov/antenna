import SwiftUI

/// An action VoiceOver offers by name. Kept as a value, so the actions a
/// screen offers can be read and run in a unit test, which XCUITest cannot do.
struct NamedAction: Identifiable {
    let name: String
    let run: () -> Void

    var id: String { name }
}

extension View {
    /// Offers each of `actions` to VoiceOver under its name, in order.
    func accessibilityActions(_ actions: [NamedAction]) -> some View {
        accessibilityActions {
            ForEach(actions) { action in
                Button(action.name, action: action.run)
            }
        }
    }
}
