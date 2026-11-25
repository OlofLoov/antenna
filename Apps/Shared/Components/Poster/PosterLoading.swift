import AntennaCore
import SwiftUI

/// Where a card's picture is: still loading, shown, or missing because the
/// title has none or it failed to load.
enum PosterPhase: Equatable {
    case loading
    case shown(CGImage)
    case missing

    /// The picture once it has loaded.
    var image: CGImage? {
        if case .shown(let image) = self { image } else { nil }
    }
}

/// Loads the picture at `url` for the frame the view takes, decoded at that
/// frame's size on screen (movies-and-series-browsing/browsing-stays-responsive).
/// A picture already in memory shows in the view's first frame with no
/// fade. One that has to load fades in over 0.2 s when it lands, at once
/// under Reduce Motion. A new address clears the picture first; a new
/// frame size keeps it on screen until the picture for that size arrives.
/// Nothing loads until the view has a size, and a view that leaves the
/// screen keeps no picture.
struct PosterLoading: ViewModifier {
    /// How a picture that had to load comes in.
    static let fadeIn = Animation.easeOut(duration: 0.2)

    let url: URL?
    @Binding var phase: PosterPhase
    @Environment(\.posterLoader) private var loader
    @Environment(\.displayScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var size = CGSize.zero
    /// The address and frame `phase` holds the picture for.
    @State private var shown: Request?
    /// The address and frame last looked up in memory, so a miss is looked
    /// up and counted once.
    @State private var looked: Request?

    private struct Request: Hashable {
        var url: URL?
        var fit: PosterFit?
    }

    private func request(for size: CGSize) -> Request {
        Request(url: url, fit: PosterFit(width: size.width, height: size.height, scale: scale))
    }

    /// Shows a kept picture before the first frame draws, ahead of the task.
    private func lookUp(for size: CGSize) {
        let request = request(for: size)
        guard request != shown, request != looked, let url, let fit = request.fit, let loader else { return }
        looked = request
        if let kept = loader.kept(url, fit) {
            phase = .shown(kept.image)
            shown = request
        }
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: {
                size = $0
                lookUp(for: $0)
            }
            .onAppear { lookUp(for: size) }
            // The cache owns the picture. A view off screen lets go of it, so
            // posters in memory stay within the cache's limit.
            .onDisappear {
                phase = .loading
                shown = nil
                looked = nil
            }
            .task(id: request(for: size)) {
                let request = request(for: size)
                guard request != shown else { return }
                if url != shown?.url, phase != .loading { phase = .loading }
                guard let url, let loader else {
                    phase = .missing
                    shown = request
                    return
                }
                guard let fit = request.fit else { return }
                if request != looked {
                    looked = request
                    if let kept = loader.kept(url, fit) {
                        phase = .shown(kept.image)
                        shown = request
                        return
                    }
                }
                let loaded = await loader.load(url, fit)
                guard !Task.isCancelled else { return }
                shown = request
                withAnimation(reduceMotion ? nil : Self.fadeIn) {
                    phase = loaded.map { .shown($0.image) } ?? .missing
                }
            }
    }
}

extension View {
    /// Loads the picture at `url` into `phase`, sized to this view's frame.
    func loadsPoster(_ url: URL?, into phase: Binding<PosterPhase>) -> some View {
        modifier(PosterLoading(url: url, phase: phase))
    }
}
