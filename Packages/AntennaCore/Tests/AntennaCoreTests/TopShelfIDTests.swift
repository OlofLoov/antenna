import Foundation
import Testing

@testable import AntennaCore

@Suite struct TopShelfIDTests {
    private func sha256(_ text: String) -> String { Digest.hex(Digest.sha256(Array(text.utf8))).lowercased() }
    private func sha1(_ text: String) -> String { Digest.hex(Digest.sha1(Array(text.utf8))).lowercased() }

    @Test("top-shelf/no-passwords-or-links-leave-the-app SHA-256 matches the FIPS 180-4 vectors")
    func sha256Vectors() {
        #expect(sha256("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(
            sha256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
                == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
        #expect(
            Digest.hex(Digest.sha256([UInt8](repeating: 0x61, count: 1_000_000))).lowercased()
                == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }

    @Test("top-shelf/no-passwords-or-links-leave-the-app SHA-1 matches the FIPS 180-4 vectors")
    func sha1Vectors() {
        #expect(sha1("") == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
        #expect(sha1("abc") == "a9993e364706816aba3e25717850c26c9cd0d89d")
        #expect(sha1("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq") == "84983e441c3bd26ebaae4aa1f95129e5e54670f1")
    }

    @Test("top-shelf/no-passwords-or-links-leave-the-app version 5 UUIDs match RFC 9562")
    func version5() throws {
        let dns = try #require(UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8"))
        #expect(UUID(version5: "www.example.com", namespace: dns).uuidString.lowercased() == "2ed6657d-e927-568b-95e1-2665a8aea6a2")
        #expect(UUID(version5: "python.org", namespace: dns).uuidString.lowercased() == "886313e1-3b8a-5372-9b90-0c9aee199e5d")
    }

    @Test("top-shelf/select-a-tile-to-watch an item id is stable and hides the channel id")
    func itemID() throws {
        let source = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let id = TopShelfItemID.make(sourceID: source, id: "xtream:7")
        #expect(id.uuidString.lowercased() == "a1738d32-6aeb-58a3-baba-5c58e6781cbe")
        #expect(TopShelfItemID.make(sourceID: source, id: "xtream:7") == id)
        #expect(TopShelfItemID.make(sourceID: sourceA, id: "xtream:7") != id, "the same id in another source is another tile")
        #expect(TopShelfItemID.make(sourceID: source, id: "xtream:8") != id)
        let untagged = Channel(id: "xtream:7", name: "Seven", streamURL: URL(fileURLWithPath: "/7"))
        #expect(TopShelfItemID.channel(untagged) == nil)
    }

    @Test("top-shelf/a-tile-that-no-longer-matches-opens-antenna-as-it-was links round trip and damaged ones read as nothing")
    func links() throws {
        let id = try #require(UUID(uuidString: "a1738d32-6aeb-58a3-baba-5c58e6781cbe"))
        #expect(TopShelfLink.item(id).url.absoluteString == "antenna://topShelf/a1738d32-6aeb-58a3-baba-5c58e6781cbe")
        #expect(TopShelfLink.empty.url.absoluteString == "antenna://topShelf/empty")
        #expect(TopShelfLink(url: TopShelfLink.item(id).url) == .item(id))
        #expect(TopShelfLink(url: TopShelfLink.empty.url) == .empty)
        for damaged in [
            "antenna://topShelf/not-a-uuid", "antenna://topShelf/", "antenna://other/a1738d32-6aeb-58a3-baba-5c58e6781cbe",
            "https://topShelf/empty", "antenna://topShelf/empty/extra", "antenna://topShelf/empty?x=1",
        ] {
            let url = try #require(URL(string: damaged))
            #expect(TopShelfLink(url: url) == nil, "\(damaged)")
        }
    }
}
