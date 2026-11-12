import Foundation
import Testing

@testable import Antenna

/// Which dragged items the window takes.
@Suite struct PlaylistDropRuleTests {
    typealias Item = PlaylistDropRule.Item

    @Test("local-m3u-file-import/drop-a-file-on-the-window: playlist and text files are taken")
    func files() {
        #expect(PlaylistDropRule.accepts(Item(types: ["public.m3u-playlist"], suggestedName: "home.m3u")))
        #expect(PlaylistDropRule.accepts(Item(types: ["public.plain-text"], suggestedName: "list.txt")))
        #expect(PlaylistDropRule.accepts(Item(types: ["public.data"], suggestedName: "list.M3U8")))
        #expect(PlaylistDropRule.accepts(Item(types: ["public.file-url", "public.plain-text"], suggestedName: nil)))
    }

    @Test("local-m3u-file-import/drop-a-file-on-the-window: images, text snippets and web links are not")
    func notFiles() {
        #expect(!PlaylistDropRule.accepts(Item(types: ["public.png"], suggestedName: "photo.png")))
        #expect(!PlaylistDropRule.accepts(Item(types: ["public.utf8-plain-text"], suggestedName: nil)))
        #expect(!PlaylistDropRule.accepts(Item(types: ["public.url"], suggestedName: nil)))
        #expect(!PlaylistDropRule.accepts(Item(types: ["public.url", "public.plain-text"], suggestedName: "tv.m3u")))
    }

    @Test("local-m3u-file-import/drop-a-file-on-the-window: the first file taken wins")
    func first() {
        let items = [Item(types: ["public.png"], suggestedName: "a.png"), Item(types: ["public.m3u-playlist"], suggestedName: "b.m3u")]
        #expect(PlaylistDropRule.first(items) == 1)
    }

    @Test("local-m3u-file-import/drop-a-file-on-the-window: a file's own provider is taken")
    func provider() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "drop-\(UUID().uuidString).m3u")
        try Data("#EXTM3U\n".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let provider = try #require(NSItemProvider(contentsOf: url))
        let item = PlaylistDropRule.Item(provider)
        #expect(PlaylistDropRule.accepts(item), "\(item)")
    }
}
