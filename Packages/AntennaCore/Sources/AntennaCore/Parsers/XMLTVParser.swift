import Foundation

/// Streaming XMLTV parser built on Foundation's `XMLParser` so a 50 MB guide
/// does not need to be held as a DOM. Only `<programme>` elements and the
/// `<channel>` display names are extracted.
public struct XMLTVParser: Sendable {
    public struct Result: Sendable, Equatable {
        public var channelNames: [String: String]
        public var programmes: [Programme]
        public init(channelNames: [String: String] = [:], programmes: [Programme] = []) {
            self.channelNames = channelNames
            self.programmes = programmes
        }
    }

    public init() {}

    public func parse(_ data: Data) throws -> Result {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            throw parser.parserError ?? XMLTVError.malformed
        }
        return Result(channelNames: delegate.channelNames, programmes: delegate.programmes)
    }

    public enum XMLTVError: Error { case malformed }

    // MARK: - SAX delegate

    private final class Delegate: NSObject, XMLParserDelegate {
        var channelNames: [String: String] = [:]
        var programmes: [Programme] = []

        private var currentChannelID: String?
        private var inChannel = false

        private var progChannel: String?
        private var progStart: Date?
        private var progStop: Date?
        private var title = ""
        private var subtitle = ""
        private var desc = ""
        private var category = ""
        private var icon: URL?
        private var text = ""
        private var capturing = false

        private static let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyyMMddHHmmss Z"
            return f
        }()
        private static let dateFormatterNoZone: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyyMMddHHmmss"
            return f
        }()

        static func date(_ s: String?) -> Date? {
            guard let s else { return nil }
            return dateFormatter.date(from: s) ?? dateFormatterNoZone.date(from: String(s.prefix(14)))
        }

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            switch name {
            case "channel":
                inChannel = true
                currentChannelID = attributes["id"]
            case "programme":
                progChannel = attributes["channel"]
                progStart = Self.date(attributes["start"])
                progStop = Self.date(attributes["stop"])
                title = ""; subtitle = ""; desc = ""; category = ""; icon = nil
            case "icon":
                if progChannel != nil, let src = attributes["src"] { icon = URL(string: src) }
            case "display-name", "title", "sub-title", "desc", "category":
                text = ""; capturing = true
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if capturing { text += string }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            switch name {
            case "display-name":
                if inChannel, let id = currentChannelID, channelNames[id] == nil {
                    channelNames[id] = text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                capturing = false
            case "title": if title.isEmpty { title = text.trimmingCharacters(in: .whitespacesAndNewlines) }; capturing = false
            case "sub-title": if subtitle.isEmpty { subtitle = text.trimmingCharacters(in: .whitespacesAndNewlines) }; capturing = false
            case "desc": if desc.isEmpty { desc = text.trimmingCharacters(in: .whitespacesAndNewlines) }; capturing = false
            case "category": if category.isEmpty { category = text.trimmingCharacters(in: .whitespacesAndNewlines) }; capturing = false
            case "channel":
                inChannel = false
                currentChannelID = nil
            case "programme":
                if let ch = progChannel, let start = progStart, let stop = progStop, stop > start {
                    programmes.append(Programme(
                        channelID: ch, start: start, stop: stop, title: title,
                        subtitle: subtitle.isEmpty ? nil : subtitle,
                        summary: desc.isEmpty ? nil : desc,
                        category: category.isEmpty ? nil : category,
                        iconURL: icon
                    ))
                }
                progChannel = nil
            default:
                break
            }
        }
    }
}
