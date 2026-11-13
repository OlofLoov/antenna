import SwiftUI

/// Fetches a channel logo. The app provides its logo cache; previews leave it
/// out and show the initials.
struct LogoLoader: Sendable {
    /// The logo when it is already in memory, so a row draws it in its first frame.
    var cached: @Sendable (URL) -> DecodedLogo?
    var load: @Sendable (URL) async -> DecodedLogo?
}

extension EnvironmentValues {
    @Entry var logoLoader: LogoLoader?
}

/// A channel logo, or `placeholder` while it is missing, loading or broken
/// (design-system/channels-without-a-logo-show-initials). A logo shown once
/// shows at once in every later row, panel and guide line.
struct LogoImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: Placeholder
    @Environment(\.logoLoader) private var loader
    @State private var loaded: (url: URL, logo: DecodedLogo)?

    var body: some View {
        if let image {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
        } else {
            placeholder
                .task(id: url) {
                    guard let url, let loader, let logo = await loader.load(url) else { return }
                    loaded = (url, logo)
                }
        }
    }

    private var image: CGImage? {
        guard let url else { return nil }
        if let loaded, loaded.url == url { return loaded.logo.image }
        return loader?.cached(url)?.image
    }
}
