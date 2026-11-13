import AntennaCore
import Foundation
import Testing

/// The references Shortcuts stores and the sentences Siri says.
@Suite struct IntentReferenceTests {
    let source = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF") ?? UUID()

    // MARK: Channel references

    @Test("app-intents/shortcuts-never-hold-a-password a channel reference round-trips")
    func channelRoundTrip() {
        let key = LastChannelKey(sourceID: source, channelID: "xtream:7")
        #expect(key.string == "6F9619FF-8B86-D011-B42D-00C04FC964FF/xtream:7")
        #expect(LastChannelKey(parsing: key.string) == key)
    }

    @Test("app-intents/shortcuts-never-hold-a-password the id may hold slashes and the source id either case")
    func channelSlashes() {
        let parsed = LastChannelKey(parsing: "6f9619ff-8b86-d011-b42d-00c04fc964ff/m3u/abc/2")
        #expect(parsed == LastChannelKey(sourceID: source, channelID: "m3u/abc/2"))
    }

    @Test(
        "app-intents/shortcuts-never-hold-a-password broken or link-holding references are refused",
        arguments: [
            "", "/", "nope/1", "6F9619FF-8B86-D011-B42D-00C04FC964FF", "6F9619FF-8B86-D011-B42D-00C04FC964FF/",
            "6F9619FF-8B86-D011-B42D-00C04FC964FF/http://user:secret@host.tv/live/user/secret/1.ts",
        ])
    func channelRefused(_ text: String) {
        #expect(LastChannelKey(parsing: text) == nil)
    }

    @Test("app-intents/shortcuts-never-hold-a-password an M3U channel with a login in its link gets a reference without it")
    func m3uLoginStaysOut() throws {
        let text = """
            #EXTM3U
            #EXTINF:-1 tvg-id="news.uk",News
            http://alice:hunter2@iptv.example:8080/live/alice/hunter2/1.ts
            #EXTINF:-1,Plain
            http://alice:hunter2@iptv.example:8080/live/alice/hunter2/2.ts
            """
        let channels = Channel.tagged(M3UParser().parse(text).channels, sourceID: source)
        #expect(channels.count == 2)
        for channel in channels {
            let reference = try #require(LastChannelKey(channel)).string
            for secret in ["alice", "hunter2", "iptv.example", "8080", "://"] {
                #expect(!reference.contains(secret))
            }
        }
    }

    // MARK: Title references

    @Test("app-intents/shortcuts-never-hold-a-password a title reference round-trips for movies and series")
    func titleRoundTrip() throws {
        let movie = ShelfTitle(id: "xtream#host.tv#vod#12", kind: .movie, sourceID: source, name: "Harbor")
        let series = ShelfTitle(id: "xtream#host.tv#series#4", kind: .series, sourceID: source, name: "North")
        for title in [movie, series] {
            let parsed = try #require(TitleReference(parsing: TitleReference(title).string))
            #expect(parsed.matches(title))
            #expect(parsed.kind == title.kind)
        }
    }

    @Test("m3u-playlists/playlist-titles-show-on-every-platform: a playlist movie or series reference round-trips")
    func playlistTitleRoundTrip() throws {
        let movie = ShelfTitle(id: "m3u.0123456789abcdef", kind: .movie, sourceID: source, name: "Film A")
        let series = ShelfTitle(id: "m3u.series.00000000000000a1", kind: .series, sourceID: source, name: "Show")
        for title in [movie, series] {
            let parsed = try #require(TitleReference(parsing: TitleReference(title).string))
            #expect(parsed.matches(title))
            #expect(parsed.kind == title.kind)
        }
        #expect(TitleReference(parsing: "\(source.uuidString)/m3u.series.xyz") == nil)
        #expect(TitleReference(parsing: "\(source.uuidString)/m3u.0123") == nil)
    }

    @Test(
        "app-intents/shortcuts-never-hold-a-password live and episode ids are not titles",
        arguments: ["xtream#host.tv#7", "xtream#host.tv#episode#9", "xtream#host.tv#vod#x", "plain"])
    func titleRefused(_ id: String) {
        #expect(TitleReference(parsing: "\(source.uuidString)/\(id)") == nil)
    }

    @Test("app-intents/play-a-movie-or-series two Xtream sources on one host keep their titles apart")
    func sameHostTwoSources() {
        let other = UUID()
        let first = TitleReference(sourceID: source, titleID: "xtream#host.tv#vod#1")
        let second = TitleReference(sourceID: other, titleID: "xtream#host.tv#vod#1")
        #expect(first != second)
        #expect(!first.matches(ShelfTitle(id: "xtream#host.tv#vod#1", kind: .movie, sourceID: other, name: "Harbor")))
    }

    // MARK: Replies

    static let everyFailure: [IntentFailure] = [
        .notUnlocked, .noSources, .offline, .stillLoading, .sourceFailed(source: "Cabin"), .loginMissing(source: "Cabin"),
        .channelSourceGone, .titleSourceGone, .channelGone(channel: "Sport One", source: "Cabin"),
        .channelGone(channel: nil, source: "Cabin"),
        .titleGone(title: "Harbor", source: "Cabin"), .titleGone(title: nil, source: "Cabin"), .locked(channel: "Sport One"),
        .nothingPlaying, .alreadyFavorite(channel: "Sport One"), .notFavorite(channel: "Sport One"), .needsUnlock(.iPhone),
        .needsUnlock(.iPad), .needsUnlock(.mac),
    ]

    @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play the replies read as written")
    func wording() {
        #expect(IntentFailure.offline.description == "You're offline. Connect to the internet and try again.")
        #expect(IntentFailure.stillLoading.description == "Antenna is still loading your library. Try again in a moment.")
        #expect(IntentFailure.sourceFailed(source: "Cabin").description == "Antenna couldn't reach Cabin. Try again later.")
        #expect(
            IntentFailure.loginMissing(source: "Cabin").description == "The login for Cabin hasn't synced from iCloud to this device yet.")
        #expect(IntentFailure.channelSourceGone.description == "That channel's source is no longer in Antenna.")
        #expect(IntentFailure.channelGone(channel: "Sport One", source: "Cabin").description == "Sport One is no longer in Cabin.")
        #expect(IntentFailure.channelGone(channel: nil, source: "Cabin").description == "That channel is no longer in Cabin.")
        #expect(IntentFailure.locked(channel: "Kids").description == "Kids is in a locked group. Unlock it in Antenna first.")
        #expect(IntentFailure.titleGone(title: "Harbor", source: "Cabin").description == "Harbor is no longer available from Cabin.")
        #expect(IntentText.whichChannel == "Which channel?")
    }

    @Test("app-intents/change-a-favorite-without-opening-the-app the favorite replies read as written")
    func favoriteWording() {
        #expect(IntentText.added("Sport One") == "Added Sport One to favorites.")
        #expect(IntentText.removed("Sport One") == "Removed Sport One from favorites.")
        #expect(IntentFailure.alreadyFavorite(channel: "Sport One").description == "Sport One is already a favorite.")
        #expect(IntentFailure.notFavorite(channel: "Sport One").description == "Sport One isn't a favorite.")
        #expect(IntentFailure.nothingPlaying.description == "Antenna isn't playing a channel right now. Say which channel instead.")
        #expect(IntentFailure.needsUnlock(.iPad).description == "Unlock your iPad once and try again.")
    }

    @Test("app-intents/nothing-works-until-antenna-is-unlocked-and-set-up the two refusals read as written")
    func gateWording() {
        #expect(IntentFailure.notUnlocked.description == "Antenna isn't unlocked on this device yet. Open Antenna to continue.")
        #expect(IntentFailure.noSources.description == "Antenna has no sources yet. Open Antenna to add one.")
    }

    @Test("app-intents/shortcuts-never-hold-a-password no reply holds a link, port, status or code")
    func noTechnicalWords() {
        let pattern = /:\/\/|@|:\d|\b(HTTP|http|status|error|code|404|401|500|-?\d{3,})\b/
        for failure in Self.everyFailure {
            #expect(failure.description.firstMatch(of: pattern) == nil, "\(failure)")
            #expect(failure.debugDescription == failure.description)
            #expect(String(reflecting: failure) == failure.description)
        }
    }

    @Test("app-intents/shortcuts-never-hold-a-password a source named with a link is called your source")
    func linkNames() {
        let names = ["http://alice:hunter2@iptv.example/get.php", "alice:hunter2@iptv.example", "iptv.example:8080", "  "]
        for name in names {
            #expect(IntentFailure.sourceFailed(source: name).description == "Antenna couldn't reach your source. Try again later.")
            #expect(IntentText.channelSubtitle(number: 7, group: name, source: name) == "7 · your source")
        }
        #expect(IntentText.channel("http://a:b@c/1.ts") == "This channel")
        #expect(IntentText.channel("Cinema 16:9") == "Cinema 16:9")
    }

    @Test("app-intents/siri-asks-which-when-two-channels-match each channel is described by number, group and source")
    func subtitles() {
        #expect(
            IntentText.channelSubtitle(number: ChannelNumber(major: 6, minor: 1), group: "Sport", source: "Cabin") == "6.1 · Sport · Cabin")
        #expect(IntentText.channelSubtitle(number: nil, group: nil, source: "Cabin") == "Cabin")
        #expect(IntentText.titleSubtitle(.movie, source: "Cabin") == "Movie · Cabin")
        #expect(IntentText.titleSubtitle(.series, source: "Cabin") == "Series · Cabin")
    }
}
