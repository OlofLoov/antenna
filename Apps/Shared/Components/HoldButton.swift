import AntennaCore
import SwiftUI

/// A button with one action for a click of select and another for holding
/// it, such as the full-screen picture: a click opens the channel list, a
/// hold opens the info panel. The click that ends a hold does nothing, so
/// one press does one thing (tvos-shell/one-press-does-one-thing). Style,
/// focus and disabling apply from outside as on a `Button`.
struct HoldButton<Label: View>: View {
    let click: () -> Void
    let hold: () -> Void
    @ViewBuilder var label: Label
    @State private var press = HeldPress()

    var body: some View {
        Button {
            guard !press.takeRelease() else { return }
            click()
        } label: {
            label
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                press.held()
                hold()
            })
    }
}
