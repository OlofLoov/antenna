import AntennaCore
import Foundation
import os

/// The players behind multi-view's tiles, one routed engine each. Runs a
/// session's commands in order, so a tile is muted before the next one is
/// unmuted and two tiles are never heard at once
/// (multi-view/sound-follows-the-highlighted-tile). The single player
/// trades engines with tile 1 on the way in and with the kept tile on the
/// way out, so neither reloads (multi-view/leave-multi-view).
@MainActor
final class TileEngines {
    struct Dependencies {
        /// A new tile's engine.
        var make: @MainActor () -> RoutedEngine = { .app() }
        var mute: @MainActor (any PlaybackEngine, Bool) -> Void = { $0.setMuted($1) }
        var playback: @MainActor (any PlaybackEngine, TilePlayback) -> Void = { $0.setPlayback($1) }
        var refusalsFinal: @MainActor (any PlaybackEngine, Bool) -> Void = { $0.setRefusalsFinal($1) }
        /// The options a channel opens with, such as its remembered languages.
        var options: @MainActor (Channel) -> PlaybackOptions = { _ in PlaybackOptions() }
        /// Pauses and resumes each tile with the app, as the single player does.
        var lifecycle: @MainActor (any PlaybackEngine) -> PlaybackLifecycle? = { engine in
            let lifecycle = PlaybackLifecycle(engine: engine)
            lifecycle.start()
            return lifecycle
        }
    }

    static let signposter = OSSignposter(subsystem: "se.codecrave.antenna", category: "multiview")

    /// The engine of each tile by tile id.
    private(set) var engines: [Int: RoutedEngine] = [:]
    private var loads: [Int: Task<Void, Never>] = [:]
    private var lifecycles: [Int: PlaybackLifecycle] = [:]
    private let dependencies: Dependencies
    /// The single player the shell or Live screen shows outside multi-view.
    let single: RoutedEngine

    init(single: RoutedEngine, dependencies: Dependencies = Dependencies()) {
        self.single = single
        self.dependencies = dependencies
    }

    /// Runs `commands` in order. `channel` finds a command's channel; a
    /// load whose channel is gone does nothing. `failed` hears a tile's
    /// load that threw a reason.
    func run(
        _ commands: [MultiViewSession.Command], channel: (RowKey) -> Channel?,
        failed: @escaping @MainActor (Int, PlaybackFailure) -> Void = { _, _ in }
    ) async {
        for command in commands {
            switch command {
            case .adopt(let tile):
                let engine = newEngine(for: tile, muted: nil)
                await single.exchange(with: engine)
                dependencies.playback(engine, .tile)
                dependencies.playback(single, .single)
            case .load(let tile, let key):
                guard let found = channel(key) else { continue }
                load(found, in: tile, failed: failed)
            case .mute(let tile):
                engines[tile].map { dependencies.mute($0, true) }
            case .unmute(let tile):
                guard let engine = engines[tile] else { continue }
                dependencies.mute(engine, false)
                Self.signposter.emitEvent("tile audible", "\(tile)")
            case .stop(let tile):
                end(tile)
            case .keep(let tile):
                guard let engine = engines[tile] else { continue }
                await single.exchange(with: engine)
                dependencies.playback(single, .single)
                dependencies.refusalsFinal(single, false)
                end(tile)
            }
        }
    }

    /// Fails a provider refusal at once for each tile that shares its
    /// source with another tile, and lets every other tile retry.
    func sharingChanged(_ session: MultiViewSession) {
        for tile in session.tiles {
            guard let engine = engines[tile.id] else { continue }
            dependencies.refusalsFinal(engine, session.othersShare(source: tile.channel.sourceID, besides: tile.id))
        }
    }

    /// Stops every tile, as when the paywall or a profile switch replaces
    /// the screen.
    func stopAll() {
        engines.keys.forEach(end)
    }

    /// A new engine for `tile`, muted or unmuted unless `muted` is nil.
    private func newEngine(for tile: Int, muted: Bool?) -> RoutedEngine {
        let engine = dependencies.make()
        if let muted { dependencies.mute(engine, muted) }
        dependencies.playback(engine, .tile)
        engines[tile] = engine
        lifecycles[tile] = dependencies.lifecycle(engine)
        return engine
    }

    private func load(_ channel: Channel, in tile: Int, failed: @escaping @MainActor (Int, PlaybackFailure) -> Void) {
        let engine = engines[tile] ?? newEngine(for: tile, muted: true)
        let options = dependencies.options(channel)
        loads[tile]?.cancel()
        loads[tile] = Task {
            do {
                try await engine.load(try await StreamResolver.address(for: channel), options: options)
            } catch let failure as PlaybackFailure {
                return failed(tile, failure)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await engine.play()
        }
    }

    private func end(_ tile: Int) {
        loads.removeValue(forKey: tile)?.cancel()
        lifecycles.removeValue(forKey: tile)?.end()
        guard let engine = engines.removeValue(forKey: tile) else { return }
        Task { await engine.stop() }
    }
}
