#if DEBUG && os(tvOS)
    import AntennaCore
    import Foundation
    import SwiftUI

    /// Multi-view under the shell's UI tests (multi-view capability): every
    /// tile plays on a scripted engine, and a probe on each tile reads
    /// `"<state> loads=<n> file=<name>[ muted]"`.
    ///
    /// `UITESTING_TILE_FAIL=<file>:<reason>` fails the first load of that
    /// file in a tile with `noDecoderFree`, `serverError` or `notAllowed`.
    /// `UITESTING_MULTIVIEW_CAP` sets the tile limit.
    extension UITestingShell {
        /// The tiles' engines for the UI tests, recording mute on the scripted engine.
        @MainActor static var multiView: MultiViewModel.Dependencies {
            var dependencies = MultiViewModel.Dependencies()
            dependencies.tiles.make = {
                let scripted = Engine(failing: false, isTile: true)
                return RoutedEngine(system: scripted, demuxer: scripted)
            }
            dependencies.tiles.mute = { engine, muted in
                ((engine as? RoutedEngine)?.demuxer as? Engine)?.muted = muted
            }
            return dependencies
        }

        /// The failure a tile's first load of `file` throws, nil to play.
        @MainActor static func tileFailure(_ file: String, tile: Bool) -> PlaybackFailure? {
            guard tile, let value = ProcessInfo.processInfo.environment["UITESTING_TILE_FAIL"] else { return nil }
            let parts = value.split(separator: ":").map(String.init)
            guard parts.count == 2, parts[0] == file, failedTiles.insert(file).inserted else { return nil }
            switch parts[1] {
            case "noDecoderFree": return .noDecoderFree
            case "serverError": return .serverError
            case "notAllowed": return .notAllowed
            default: fatalError("UITESTING_TILE_FAIL takes <file>:noDecoderFree, serverError or notAllowed")
            }
        }

        @MainActor private static var failedTiles: Set<String> = []

        /// A tile's engine summary as `<identifier>.debug`; nothing outside UI tests.
        struct TileProbe: View {
            let engine: RoutedEngine?
            let identifier: String

            var body: some View {
                if let engine = engine?.demuxer as? Engine {
                    Text(engine.summary)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityIdentifier("\(identifier).debug")
                        .accessibilityValue(engine.summary)
                        .allowsHitTesting(false)
                }
            }
        }
    }
#endif
