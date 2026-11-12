import AntennaCore
import Foundation
import Testing

private let source = UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID()
private let other = UUID(uuidString: "00000000-0000-0000-0000-00000000000B") ?? UUID()

private func key(_ position: Int, in sourceID: UUID = source) -> RowKey {
    let channel = Channel(
        id: "c\(position)", name: "C\(position)", streamURL: URL(fileURLWithPath: "/c\(position)"), sourceID: sourceID, position: position)
    guard let key = RowKey(channel) else { preconditionFailure("tagged channel") }
    return key
}

/// The audible tiles after each command, to check two are never heard at once.
private func audibleCounts(_ commands: [MultiViewSession.Command], startingWith audible: Set<Int>) -> [Int] {
    var heard = audible
    return commands.map { command in
        switch command {
        case .unmute(let tile): heard.insert(tile)
        case .mute(let tile), .stop(let tile): heard.remove(tile)
        case .adopt, .load, .keep: break
        }
        return heard.count
    }
}

private func started(_ count: Int = 2, cap: Int = 4) throws -> MultiViewSession {
    var (session, _) = try #require(MultiViewSession.start(playing: key(1), adding: key(2), cap: MultiViewCap(limit: cap)))
    for position in stride(from: 3, through: count, by: 1) { _ = session.add(key(position)) }
    return session
}

@Suite struct MultiViewStartTests {
    @Test("multi-view/start-multi-view-on-apple-tv the playing channel becomes tile 1 with no reload and the new one takes the sound")
    func start() throws {
        let (session, commands) = try #require(MultiViewSession.start(playing: key(1), adding: key(2), cap: MultiViewCap(limit: 4)))
        #expect(commands == [.adopt(tile: 1), .load(tile: 2, channel: key(2)), .mute(tile: 1), .unmute(tile: 2)])
        #expect(session.tiles.map(\.channel) == [key(1), key(2)])
        #expect(session.selected == 2)
        #expect(session.audible == 2)
        #expect(!commands.contains(.load(tile: 1, channel: key(1))))
    }

    @Test("multi-view/start-multi-view-on-apple-tv the playing channel itself is not offered")
    func samePlayingChannel() {
        #expect(MultiViewSession.start(playing: key(1), adding: key(1), cap: MultiViewCap(limit: 4)) == nil)
    }
}

@Suite struct MultiViewSoundTests {
    @Test("multi-view/sound-follows-the-highlighted-tile the old tile goes quiet before the new one is heard")
    func moveHighlight() throws {
        var session = try started(4)
        let commands = session.select(1)
        #expect(commands == [.mute(tile: 4), .unmute(tile: 1)])
        #expect(audibleCounts(commands, startingWith: [4]).allSatisfy { $0 <= 1 })
        #expect(session.audible == 1)
    }

    @Test("multi-view/sound-follows-the-highlighted-tile a failed tile highlighted leaves every tile silent")
    func failedTileSilent() throws {
        var session = try started(3)
        _ = session.failed(2, .notFound)
        #expect(session.select(2) == [.mute(tile: 3)])
        #expect(session.audible == nil)
        #expect(session.select(1) == [.unmute(tile: 1)])
    }

    @Test("multi-view/sound-follows-the-highlighted-tile a run of actions never has two tiles heard")
    func neverTwo() throws {
        let start = try #require(MultiViewSession.start(playing: key(1), adding: key(2), cap: MultiViewCap(limit: 4)))
        var session = start.0
        var heard: Set<Int> = [1]
        var all = start.1
        all += session.add(key(3))
        all += session.select(1)
        all += session.enlarge(2)
        all += session.change(2, to: key(4))
        all += session.remove(2)
        all += session.add(key(5))
        all += session.leave()
        for command in all {
            switch command {
            case .unmute(let tile): heard.insert(tile)
            case .mute(let tile), .stop(let tile): heard.remove(tile)
            case .adopt, .load, .keep: break
            }
            #expect(heard.count <= 1)
        }
    }
}

@Suite struct MultiViewChangeTests {
    @Test("multi-view/change-a-tile-s-channel one reload of that tile and the others untouched")
    func change() throws {
        var session = try started(3)
        _ = session.select(2)
        #expect(session.change(2, to: key(7)) == [.load(tile: 2, channel: key(7))])
        #expect(session.tiles.map(\.channel) == [key(1), key(7), key(3)])
    }

    @Test("multi-view/change-a-tile-s-channel a channel in another tile moves the highlight there, its own channel does nothing")
    func duplicates() throws {
        var session = try started(3)
        _ = session.select(2)
        #expect(session.change(2, to: key(2)).isEmpty)
        #expect(session.change(2, to: key(3)) == [.mute(tile: 2), .unmute(tile: 3)])
        #expect(session.selected == 3)
        #expect(session.tiles.map(\.channel) == [key(1), key(2), key(3)])
    }

    @Test("multi-view/change-a-tile-s-channel a full-screen tile is full screen again after its channel changes")
    func changeEnlarged() throws {
        var session = try started(3)
        _ = session.enlarge(2)
        _ = session.change(2, to: key(9))
        #expect(session.enlarged == 2)
    }
}

@Suite struct MultiViewAddTests {
    @Test("multi-view/add-more-tiles-up-to-the-limit a new tile joins last with the highlight and sound")
    func add() throws {
        var session = try started(2)
        #expect(session.add(key(3)) == [.load(tile: 3, channel: key(3)), .mute(tile: 2), .unmute(tile: 3)])
        #expect(session.number(of: 3) == 3)
    }

    @Test("multi-view/add-more-tiles-up-to-the-limit at the limit nothing is added and a channel already in a tile is not added twice")
    func limitAndDuplicates() throws {
        var session = try started(2, cap: 2)
        #expect(!session.canAdd)
        #expect(session.add(key(3)).isEmpty)
        #expect(session.add(key(1)) == [.mute(tile: 2), .unmute(tile: 1)])
        #expect(session.tiles.count == 2)
    }

    @Test("multi-view/add-more-tiles-up-to-the-limit a device out of decoders lowers the limit to the tiles still playing")
    func decoderDrop() throws {
        var session = try started(4)
        _ = session.failed(4, .noDecoderFree)
        #expect(session.cap.limit == 3)
        #expect(!session.canAdd)
        _ = session.remove(4)
        #expect(!session.canAdd)
        _ = session.remove(3)
        #expect(session.canAdd)
        _ = session.add(key(8))
        #expect(!session.canAdd)
    }
}

@Suite struct MultiViewCapacityTests {
    @Test(
        "multi-view/add-more-tiles-up-to-the-limit two tiles on Apple TV HD and Intel Macs, four elsewhere",
        arguments: [
            (MultiViewCapacity.Device.appleTV(model: "AppleTV5,3"), 2), (.appleTV(model: "AppleTV6,2"), 4),
            (.appleTV(model: "AppleTV11,1"), 4),
            (.appleTV(model: "AppleTV14,1"), 4), (.mac(appleSilicon: false), 2), (.mac(appleSilicon: true), 4),
        ])
    func capacity(device: MultiViewCapacity.Device, tiles: Int) {
        #expect(MultiViewCapacity.tiles(on: device) == tiles)
    }

    @Test("multi-view/add-more-tiles-up-to-the-limit the limit never drops below 2 and never rises in the session")
    func cap() {
        var cap = MultiViewCap(device: .mac(appleSilicon: true))
        cap.decoderRefused(stillDecoding: 1)
        #expect(cap.limit == 2)
        cap.decoderRefused(stillDecoding: 3)
        #expect(cap.limit == 2)
        #expect(cap.count(tiles: 3) == "3 of 3")
        #expect(MultiViewCap(limit: 4).count(tiles: 2) == "2 of 4")
    }
}

@Suite struct MultiViewEnlargeTests {
    @Test("multi-view/one-tile-full-screen-and-back a tile enlarges with no reload and the grid comes back")
    func enlarge() throws {
        var session = try started(4)
        #expect(session.enlarge(4).isEmpty)
        #expect(session.enlarged == 4)
        session.shrink()
        #expect(session.enlarged == nil)
    }

    @Test("multi-view/one-tile-full-screen-and-back choosing another tile or adding one brings the grid back")
    func otherTileShrinks() throws {
        var session = try started(3)
        _ = session.enlarge(3)
        _ = session.select(1)
        #expect(session.enlarged == nil)
        _ = session.enlarge(1)
        _ = session.add(key(4))
        #expect(session.enlarged == nil)
    }
}

@Suite struct MultiViewRemoveTests {
    @Test("multi-view/remove-a-tile removing the audible tile of three moves the sound to the tile now in its place")
    func removeAudible() throws {
        var session = try started(3)
        _ = session.select(2)
        #expect(session.remove(2) == [.stop(tile: 2), .unmute(tile: 3)])
        #expect(session.tiles.map(\.id) == [1, 3])
        #expect(session.selected == 3)
    }

    @Test("multi-view/remove-a-tile removing an unselected tile keeps the sound where it was")
    func removeOther() throws {
        var session = try started(3)
        _ = session.select(1)
        #expect(session.remove(3) == [.stop(tile: 3)])
        #expect(session.audible == 1)
    }

    @Test("multi-view/remove-a-tile removing one of two ends multi-view and the other plays on alone")
    func removeOfTwo() throws {
        var session = try started(2)
        #expect(session.remove(2) == [.stop(tile: 2), .unmute(tile: 1), .keep(tile: 1)])
        #expect(!session.isOpen)
    }

    @Test("multi-view/remove-a-tile a tile whose channel leaves the source is removed, and none left ends everything")
    func refresh() throws {
        var session = try started(3)
        _ = session.select(1)
        #expect(session.channelsChanged { $0 != key(2) } == [.stop(tile: 2)])
        #expect(session.channelsChanged { _ in false } == [.stop(tile: 1), .stop(tile: 3)])
        #expect(!session.isOpen)
        #expect(session.tiles.isEmpty)
    }

    @Test("multi-view/remove-a-tile a refresh that leaves one channel ends multi-view keeping it")
    func refreshToOne() throws {
        var session = try started(3)
        let commands = session.channelsChanged { $0 == key(1) }
        #expect(commands.last == .keep(tile: 1))
        #expect(!session.isOpen)
    }
}

@Suite struct MultiViewLeaveTests {
    @Test("multi-view/leave-multi-view every other tile stops and the selected tile plays on")
    func leave() throws {
        var session = try started(4)
        _ = session.select(2)
        #expect(session.leave() == [.stop(tile: 1), .stop(tile: 3), .stop(tile: 4), .keep(tile: 2)])
        #expect(session.leave().isEmpty)
    }

    @Test("multi-view/leave-multi-view a failed selected tile is unmuted as it becomes the single player")
    func leaveFailed() throws {
        var session = try started(2)
        _ = session.failed(2, .notFound)
        #expect(session.leave() == [.stop(tile: 1), .unmute(tile: 2), .keep(tile: 2)])
    }
}

@Suite struct MultiViewFailureTests {
    @Test("multi-view/a-tile-that-fails-says-why try again loads the tile once and gives back its sound")
    func retry() throws {
        var session = try started(2)
        _ = session.failed(2, .timedOut)
        #expect(session.retry(2) == [.load(tile: 2, channel: key(2)), .unmute(tile: 2)])
    }

    @Test(
        "multi-view/a-tile-that-fails-says-why a provider refusing another stream says so in plain words",
        arguments: [PlaybackFailure.serverBusy, .serverError])
    func providerRefused(failure: PlaybackFailure) {
        let message = MultiViewFailureText.message(failure, sharesSource: true, source: "Acme TV", device: .appleTV)
        #expect(message.title == "Your provider refused another stream")
        #expect(message.explanation == "Many providers allow one or two streams per account at a time.")
    }

    @Test("multi-view/a-tile-that-fails-says-why a 403 adds a hint to check the login")
    func refused403() {
        let tv = MultiViewFailureText.message(.notAllowed, sharesSource: true, source: "Acme TV", device: .appleTV)
        #expect(tv.title == "Your provider refused another stream")
        #expect(tv.explanation.hasSuffix("If the login changed, sign in again on this Apple TV."))
        let mac = MultiViewFailureText.message(.notAllowed, sharesSource: true, source: "Acme TV", device: .other)
        #expect(mac.explanation.hasSuffix("If the login changed, check it in Settings."))
    }

    @Test("multi-view/a-tile-that-fails-says-why a device that cannot decode another stream names itself")
    func decoderBusy() {
        let tv = MultiViewFailureText.message(.noDecoderFree, sharesSource: false, source: "Acme TV", device: .appleTV)
        #expect(
            tv
                == FailureMessage(
                    title: "This Apple TV can't play another stream", explanation: "Remove a tile or pick a lower-resolution channel."))
        let mac = MultiViewFailureText.message(.noDecoderFree, sharesSource: false, source: "Acme TV", device: .other)
        #expect(mac.title == "This Mac can't play another stream")
    }

    @Test("multi-view/a-tile-that-fails-says-why other failures, and a refusal with no other tile on the source, use the player's wording")
    func otherFailures() {
        for failure in [PlaybackFailure.offline, .notFound, .serverError] {
            let message = MultiViewFailureText.message(failure, sharesSource: false, source: "Acme TV", device: .appleTV)
            #expect(message == FailureMessage(failure, source: "Acme TV", device: .appleTV))
        }
    }

    @Test("multi-view/a-tile-that-fails-says-why a tile sharing a source with another knows it")
    func sharing() throws {
        var session = try started(2)
        _ = session.add(key(3, in: other))
        #expect(session.othersShare(source: source, besides: 1))
        #expect(!session.othersShare(source: other, besides: 3))
    }

    @Test("multi-view/sound-follows-the-highlighted-tile each tile's spoken label says whether it has sound")
    func spokenLabel() {
        #expect(MultiViewText.spokenLabel(number: 104, name: "Sport One", audible: true) == "104, Sport One, sound on")
        #expect(MultiViewText.spokenLabel(number: nil, name: "Radio", audible: false) == "Radio, muted")
    }
}
