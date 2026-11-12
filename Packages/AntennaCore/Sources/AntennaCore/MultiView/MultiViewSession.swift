import Foundation

/// One multi-view session (multi-view capability): its tiles, the tile
/// with the highlight, the one tile with sound, the tile shown full screen
/// and the tile limit.
///
/// Every action changes the session and returns the commands that make the
/// players match, in the order they must run. A tile goes quiet before
/// another one is heard, so running the commands in order never has two
/// tiles unmuted. Commands name channels by `RowKey`, never by address.
public struct MultiViewSession: Sendable, Equatable {
    public struct Tile: Sendable, Equatable, Identifiable {
        /// Stable for the tile's life and never reused in the session.
        public let id: Int
        public var channel: RowKey
        /// The tile's stream gave up. It stays silent until the user tries
        /// again, changes its channel or removes it.
        public var failed: Bool
    }

    /// What the players do, in order.
    public enum Command: Sendable, Equatable {
        /// The single player that was playing becomes this tile, with no reload.
        case adopt(tile: Int)
        /// Open the channel in this tile's player, starting muted for a new tile.
        case load(tile: Int, channel: RowKey)
        case mute(tile: Int)
        case unmute(tile: Int)
        case stop(tile: Int)
        /// Multi-view ends and this tile's player plays on alone, with no reload.
        case keep(tile: Int)
    }

    public private(set) var tiles: [Tile]
    /// The highlighted tile on Apple TV, the selected one on a Mac.
    public private(set) var selected: Int
    /// The tile shown full screen, nil while the grid shows.
    public private(set) var enlarged: Int?
    /// The one tile with sound: the selected tile unless it failed.
    public private(set) var audible: Int?
    public private(set) var cap: MultiViewCap
    /// False once multi-view ended.
    public private(set) var isOpen = true
    private var nextID = 1

    /// Starts multi-view with the channel playing as tile 1 and `adding` as
    /// tile 2, selected and audible. Nil when `adding` is the playing
    /// channel, or the cap allows fewer than two tiles.
    public static func start(playing: RowKey, adding: RowKey, cap: MultiViewCap) -> (MultiViewSession, [Command])? {
        guard playing != adding, cap.limit >= 2 else { return nil }
        var session = MultiViewSession(tiles: [], selected: 0, cap: cap)
        let first = session.newTile(playing)
        session.selected = first.id
        session.audible = first.id
        var commands: [Command] = [.adopt(tile: first.id)]
        commands += session.add(adding)
        return (session, commands)
    }

    private init(tiles: [Tile], selected: Int, cap: MultiViewCap) {
        self.tiles = tiles
        self.selected = selected
        self.cap = cap
    }

    // MARK: Reading

    /// True while another tile fits under the cap.
    public var canAdd: Bool { isOpen && tiles.count < cap.limit }

    /// The tile showing `channel`, nil when no tile does.
    public func tile(showing channel: RowKey) -> Tile? {
        tiles.first { $0.channel == channel }
    }

    public func tile(_ id: Int) -> Tile? {
        tiles.first { $0.id == id }
    }

    /// The tile's place counted from 1, as "tile 2 of 3" names it.
    public func number(of id: Int) -> Int? {
        tiles.firstIndex { $0.id == id }.map { $0 + 1 }
    }

    /// True when another tile than `id` shows a channel of `source`.
    public func othersShare(source: UUID, besides id: Int) -> Bool {
        tiles.contains { $0.id != id && $0.channel.sourceID == source }
    }

    // MARK: Actions

    /// Adds `channel` as the next tile with the highlight and the sound. A
    /// channel already in a tile moves the highlight there instead; at the
    /// cap nothing changes.
    public mutating func add(_ channel: RowKey) -> [Command] {
        if let existing = tile(showing: channel) { return select(existing.id) }
        guard canAdd else { return [] }
        let tile = newTile(channel)
        selected = tile.id
        enlarged = nil
        return [.load(tile: tile.id, channel: channel)] + retarget()
    }

    /// Shows `channel` in tile `id` with one reload of that tile. A channel
    /// in another tile moves the highlight there; the tile's own channel
    /// changes nothing. A full-screen tile stays full screen.
    public mutating func change(_ id: Int, to channel: RowKey) -> [Command] {
        guard let index = tiles.firstIndex(where: { $0.id == id }), tiles[index].channel != channel else { return [] }
        if let existing = tile(showing: channel) { return select(existing.id) }
        tiles[index].channel = channel
        tiles[index].failed = false
        return [.load(tile: id, channel: channel)] + retarget()
    }

    /// Moves the highlight and the sound to tile `id`. Choosing another
    /// tile while one is full screen brings the grid back.
    public mutating func select(_ id: Int) -> [Command] {
        guard tile(id) != nil else { return [] }
        selected = id
        if let enlarged, enlarged != id { self.enlarged = nil }
        return retarget()
    }

    /// Shows tile `id` full screen, with the highlight and the sound.
    public mutating func enlarge(_ id: Int) -> [Command] {
        let commands = select(id)
        if tile(id) != nil { enlarged = id }
        return commands
    }

    /// Brings the grid back.
    public mutating func shrink() {
        enlarged = nil
    }

    /// Try again: the failed tile loads its channel once more.
    public mutating func retry(_ id: Int) -> [Command] {
        guard let index = tiles.firstIndex(where: { $0.id == id }) else { return [] }
        tiles[index].failed = false
        return [.load(tile: id, channel: tiles[index].channel)] + retarget()
    }

    /// Removes tile `id`. The others stay as they are; the highlight and
    /// sound move to the tile now in its place, or the one before. With
    /// two tiles, multi-view ends and the other one plays on.
    public mutating func remove(_ id: Int) -> [Command] {
        guard let index = tiles.firstIndex(where: { $0.id == id }) else { return [] }
        guard tiles.count > 2 else {
            guard let other = tiles.first(where: { $0.id != id }) else { return [] }
            selected = other.id
            return leave()
        }
        tiles.remove(at: index)
        if audible == id { audible = nil }
        if enlarged == id { enlarged = nil }
        if selected == id { selected = tiles[min(index, tiles.count - 1)].id }
        return [.stop(tile: id)] + retarget()
    }

    /// Ends multi-view keeping the selected tile's player, which plays on
    /// alone, and stops every other tile.
    public mutating func leave() -> [Command] {
        guard isOpen else { return [] }
        isOpen = false
        enlarged = nil
        var commands = tiles.filter { $0.id != selected }.map { Command.stop(tile: $0.id) }
        if audible != selected { commands.append(.unmute(tile: selected)) }
        audible = selected
        commands.append(.keep(tile: selected))
        tiles.removeAll { $0.id != selected }
        return commands
    }

    /// Tile `id` gave up with `failure`. It goes silent; a device out of
    /// decoders lowers the cap for the rest of the session.
    public mutating func failed(_ id: Int, _ failure: PlaybackFailure) -> [Command] {
        guard let index = tiles.firstIndex(where: { $0.id == id }) else { return [] }
        tiles[index].failed = true
        if failure == .noDecoderFree {
            cap.decoderRefused(stillDecoding: tiles.filter { !$0.failed }.count)
        }
        return retarget()
    }

    /// A source refresh landed. Each tile whose channel `isListed` no
    /// longer finds is removed as if the user removed it; with no tile
    /// left, multi-view ends with everything stopped.
    public mutating func channelsChanged(isListed: (RowKey) -> Bool) -> [Command] {
        let gone = tiles.filter { !isListed($0.channel) }
        guard !gone.isEmpty else { return [] }
        if gone.count == tiles.count {
            isOpen = false
            let commands = tiles.map { Command.stop(tile: $0.id) }
            tiles = []
            audible = nil
            enlarged = nil
            return commands
        }
        return gone.flatMap { remove($0.id) }
    }

    // MARK: Helpers

    private mutating func newTile(_ channel: RowKey) -> Tile {
        let tile = Tile(id: nextID, channel: channel, failed: false)
        nextID += 1
        tiles.append(tile)
        return tile
    }

    /// Mutes the tile that had sound, then unmutes the one that should.
    private mutating func retarget() -> [Command] {
        let target = tiles.first { $0.id == selected && !$0.failed }?.id
        guard target != audible else { return [] }
        var commands: [Command] = []
        if let audible { commands.append(.mute(tile: audible)) }
        if let target { commands.append(.unmute(tile: target)) }
        audible = target
        return commands
    }
}
