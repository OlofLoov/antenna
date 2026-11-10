// tvOS-specific code goes here (focus tweaks, Top Shelf extension hookup).

import SwiftUI

/// The Apple TV window root: "Who's watching?" when there are two or more
/// profiles (profiles capability), then the shell (tvos-shell capability).
struct PlatformRoot: View {
    var body: some View {
        ProfileGate {
            ShellView()
        }
    }
}
