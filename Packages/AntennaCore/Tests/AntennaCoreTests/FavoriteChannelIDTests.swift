import Foundation
import Testing

@testable import AntennaCore

/// A favorite stores a channel id. These tests reload a source with unchanged
/// content and check the id the favorite holds still resolves.
@Suite struct FavoriteChannelIDTests {
    @Test("0005/AC-3 M3U entry with tvg-id keeps its id across reloads")
    func m3uReload() throws {
        let text = """
            #EXTM3U
            #EXTINF:-1 tvg-id="bbc1.uk",BBC One
            http://s/bbc1.ts
            #EXTINF:-1 tvg-id="itv.uk",ITV
            http://s/itv.ts
            """
        let favorite = try #require(M3UParser().parse(text).channels.first).id
        #expect(favorite == "bbc1.uk#http://s/bbc1.ts")
        let reloaded = M3UParser().parse(text).channels
        #expect(reloaded.filter { $0.id == favorite }.map(\.name) == ["BBC One"])
    }

    @Test("0005/AC-3 Xtream stream keeps its id across reloads")
    func xtreamReload() throws {
        let credentials = XtreamCredentials(server: try #require(URL(string: "http://panel:8080")), username: "u", password: "p")
        let json = Data(#"[{"name":"BBC One","stream_id":42},{"name":"ITV","stream_id":43}]"#.utf8)
        let first = try JSONDecoder().decode([XtreamLiveStream].self, from: json)
        let favorite = XtreamClient(credentials: credentials).channel(from: try #require(first.first), categoryName: "UK").id
        #expect(favorite == "xtream#panel#42")

        // A reload builds a new client from the stored credentials.
        let reloadClient = XtreamClient(credentials: credentials)
        let reloaded = try JSONDecoder().decode([XtreamLiveStream].self, from: json)
            .map { reloadClient.channel(from: $0, categoryName: "UK") }
        #expect(reloaded.filter { $0.id == favorite }.map(\.name) == ["BBC One"])
    }
}
