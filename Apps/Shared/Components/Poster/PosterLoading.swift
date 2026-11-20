import AntennaCore
import SwiftUI

/// Loads the picture at `url` for the frame the view takes, decoded only
/// as large as that frame needs (movies-and-series-browsing/browsing-stays-responsive).
/// A new address clears the picture first; a new frame size keeps it on
/// screen until the picture for that size arrives. Nothing loads until
/// the view has a size.
struct PosterLoading: ViewModifier {
    let url: URL?
    @Binding var poster: Poster?
    @Environment(\.posterLoader) private var loader
    @Environment(\.displayScale) private var scale
    @State private var size = CGSize.zero
    @State private var shownURL: URL?

    private struct Request: Hashable {
        var url: URL?
        var fit: PosterFit?
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: {
                size = $0
            }
            .task(id: Request(url: url, fit: PosterFit(width: size.width, height: size.height, scale: scale))) {
                if url != shownURL {
                    poster = nil
                    shownURL = url
                }
                guard let url, let loader, let fit = PosterFit(width: size.width, height: size.height, scale: scale) else { return }
                let loaded = await loader.load(url, fit)
                guard !Task.isCancelled else { return }
                poster = loaded
            }
    }
}

extension View {
    /// Loads the picture at `url` into `poster`, sized to this view's frame.
    func loadsPoster(_ url: URL?, into poster: Binding<Poster?>) -> some View {
        modifier(PosterLoading(url: url, poster: poster))
    }
}
