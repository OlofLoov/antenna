import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// An imported file source on Apple TV: it waits for its playlist to sync,
/// then loads without a relaunch, and the app offers no way to import.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct FileSourceShellTests {
    let engine = RecordingEngine()
    let loader = ScriptedLoader()
    let arrived = Arrived()
    let model: ShellModel
    let file = SourceDescriptor(name: "home-playlist", kind: .m3uFile, url: URL(string: "antenna-file:home") ?? URL(fileURLWithPath: "/"))

    @MainActor
    final class Arrived {
        var playlist = false
    }

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: "file-shell-\(UUID().uuidString)"))
        let loader = loader
        let arrived = arrived
        var dependencies = ShellModel.Dependencies(
            engine: engine,
            load: { try await loader.load($0) },
            hasLogin: { _ in arrived.playlist },
            recents: RecentsStore(defaults: defaults),
            sleep: { _ in },
            guide: nil)
        dependencies.waitsForICloud = { _ in !arrived.playlist }
        model = ShellModel(dependencies)
    }

    private func wait(_ condition: () -> Bool) async {
        for _ in 0..<5000 {
            if condition() { return }
            await Task.yield()
        }
        Issue.record("timed out")
    }

    @Test("tvos-shell/a-file-source-waiting-for-icloud: waits for its playlist, then loads when it arrives")
    func contentsArriveLater() async {
        model.sourcesChanged([file])
        await wait { model.sources.first?.state == .waitingForLogin }
        #expect(model.sources.first?.waitsForICloud == true)
        #expect(model.sources.first?.emptyLine.text == "home-playlist: waiting for its playlist to sync from iCloud")
        #expect(model.sources.first?.loadingRow.detail == "Waiting for its playlist to sync from iCloud")
        #expect(loader.calls.isEmpty)

        arrived.playlist = true
        await model.becameActive()
        await wait { loader.isWaiting(file.id) }
        loader.finish(file.id, with: [.fixture("f1")])
        await wait { model.sources.first?.state == .loaded(channels: 1) }
        #expect(model.sources.first?.waitsForICloud == false)
    }

    @Test("local-m3u-file-import/no-import-on-apple-tv: the Apple TV app registers no document type")
    func noDocumentTypes() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDocumentTypes") == nil)
    }
}
