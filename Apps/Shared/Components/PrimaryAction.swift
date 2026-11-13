import SwiftUI

extension View {
    /// The system style for a screen's main action, such as Connect, Add a
    /// source or Start watching (design-system/controls-use-system-styles):
    /// glass prominent in the accent tint on iPhone, iPad and Mac, and
    /// bordered on Apple TV, where it rests translucent like the buttons
    /// beside it and takes the light platter with dark text when focused
    /// (design-system/focus-is-the-lifted-white-card). Glass prominent on
    /// Apple TV rests white with white text, so it is not used there.
    @ViewBuilder func primaryActionStyle() -> some View {
        #if os(tvOS)
            buttonStyle(.bordered)
        #else
            buttonStyle(.glassProminent)
        #endif
    }
}
