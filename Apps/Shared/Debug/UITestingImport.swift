#if DEBUG && (os(iOS) || os(macOS))
    import Foundation

    /// The system file picker and the share sheet cannot be driven reliably
    /// from XCUITest, so these arguments feed fixture files through the same
    /// path a picked or shared file takes (local-m3u-file-import capability).
    ///
    /// `-ui-testing-import-file good,big` answers each "Import a file" or
    /// "Choose another file" with the next fixture in the list instead of
    /// opening the picker. `-ui-testing-open-file good` hands one fixture to
    /// the app at launch, as Open With or a share would. Logins stay in
    /// memory. Fixtures are written to the temporary folder.
    enum UITestingImport {
        static let pickArgument = "-ui-testing-import-file"
        static let openArgument = "-ui-testing-open-file"

        enum Fixture: String, CaseIterable {
            /// home-playlist.m3u: three channels in two groups, a guide link and one entry that is not a link.
            case good
            /// home-playlist.m3u again, with a fourth channel.
            case newer
            /// everything.m3u, 41.7 MB, never read.
            case big
            /// channels.txt, text with no entries.
            case empty
            /// link.txt, one playlist link.
            case link
            /// links.txt, two links.
            case links
            /// stream.m3u8, one HLS stream.
            case stream

            var fileName: String {
                switch self {
                case .good, .newer: "home-playlist.m3u"
                case .big: "everything.m3u"
                case .empty: "channels.txt"
                case .link: "link.txt"
                case .links: "links.txt"
                case .stream: "stream.m3u8"
                }
            }

            static let goodText = """
                #EXTM3U url-tvg="http://guide.import.test/epg.xml"
                #EXTINF:-1 tvg-id="file-one" tvg-chno="1" group-title="News",File One
                http://stream.import.test/1.ts
                #EXTINF:-1 tvg-id="file-two" tvg-chno="2" group-title="News",File Two
                http://stream.import.test/2.ts
                #EXTINF:-1 tvg-id="file-three" tvg-chno="3" group-title="Sport",File Three
                http://stream.import.test/3.ts
                #EXTINF:-1,Not a channel
                not a link

                """

            var text: String {
                switch self {
                case .good: Self.goodText
                case .newer:
                    Self.goodText + "#EXTINF:-1 tvg-id=\"file-four\" group-title=\"Sport\",File Four\nhttp://stream.import.test/4.ts\n"
                case .big: ""
                case .empty: "Channels I like\nNews, Sport\n"
                case .link: "http://playlist.import.test/tv.m3u\n"
                case .links: "http://a.import.test/tv.m3u\nhttp://b.import.test/tv.m3u\n"
                case .stream: "#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6.0,\nsegment1.ts\n"
                }
            }

            /// Writes the fixture to its own folder and returns its URL.
            func write() -> URL {
                let folder = FileManager.default.temporaryDirectory.appending(path: "ui-testing-import/\(rawValue)")
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appending(path: fileName)
                try? FileManager.default.removeItem(at: url)
                if self == .big {
                    FileManager.default.createFile(atPath: url.path(), contents: nil)
                    let handle = try? FileHandle(forWritingTo: url)
                    try? handle?.truncate(atOffset: 41_700_000)
                    try? handle?.close()
                } else {
                    try? Data(text.utf8).write(to: url)
                }
                return url
            }
        }

        private static func fixtures(after argument: String, in arguments: [String]) -> [Fixture]? {
            guard let index = arguments.firstIndex(of: argument) else { return nil }
            let next = arguments.index(after: index)
            let value = next < arguments.endIndex ? arguments[next] : ""
            return value.split(separator: ",").map { name in
                guard let fixture = Fixture(rawValue: String(name)) else {
                    fatalError("\(argument) takes \(Fixture.allCases.map(\.rawValue).joined(separator: ", ")), got \(name)")
                }
                return fixture
            }
        }

        /// True when the picker is replaced by fixtures.
        static var replacesPicker: Bool { ProcessInfo.processInfo.arguments.contains(pickArgument) }

        @MainActor private static var picked = 0

        /// The next fixture for "Import a file", nil once the list runs out.
        @MainActor static func nextPick() -> URL? {
            guard let list = fixtures(after: pickArgument, in: ProcessInfo.processInfo.arguments), picked < list.count else { return nil }
            defer { picked += 1 }
            return list[picked].write()
        }

        /// The file handed to the app at launch, as Open With would.
        static func openedAtLaunch() -> URL? {
            fixtures(after: openArgument, in: ProcessInfo.processInfo.arguments)?.first?.write()
        }

        static let dropArgument = "-ui-testing-drop"

        /// `-ui-testing-drop good`, `image` or `text`: the item a drag over
        /// the window carries. The drop target shows for it as during a drag,
        /// and tapping the target drops it. Nil without the argument.
        @MainActor static func draggedItem() -> NSItemProvider? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: dropArgument), arguments.index(after: index) < arguments.endIndex else { return nil }
            switch arguments[arguments.index(after: index)] {
            case "image":
                let provider = NSItemProvider(item: Data([0x89, 0x50, 0x4E, 0x47]) as NSData, typeIdentifier: "public.png")
                provider.suggestedName = "photo.png"
                return provider
            case "text":
                return NSItemProvider(object: "News, Sport" as NSString)
            default:
                let url = Fixture.good.write()
                let provider = NSItemProvider(contentsOf: url)
                provider?.suggestedName = url.lastPathComponent
                return provider
            }
        }

        /// In-memory logins while either argument is present.
        static let credentials: (any CredentialStoring)? = {
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains(pickArgument) || arguments.contains(openArgument) || arguments.contains(dropArgument) else {
                return nil
            }
            return UITestingOnboarding.Credentials()
        }()
    }
#endif
