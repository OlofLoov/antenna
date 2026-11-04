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

    /// Parses a whole XMLTV document. Throws `XMLTVError.malformed` when the
    /// bytes are not well-formed XML, and returns nothing in that case.
    public func parse(_ data: Data) throws(XMLTVError) -> Result {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            throw .malformed(line: parser.lineNumber, column: parser.columnNumber)
        }
        return Result(channelNames: delegate.channelNames, programmes: delegate.programmes)
    }

    /// The only error `parse` throws. No Foundation error reaches the caller.
    public enum XMLTVError: Error, Sendable, Equatable {
        /// The document is not well-formed XML. `line` and `column` are where
        /// the XML parser stopped; `line` is 1-based.
        case malformed(line: Int, column: Int)
    }

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

        private static let utcFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyyMMddHHmmss"
            return f
        }()

        /// Reads the first 14 characters as UTC, then applies a `±HHMM` or
        /// `±HH:MM` offset that follows, with or without spaces before it.
        /// An offset over 14 hours, or any other suffix, is ignored.
        static func date(_ s: String?) -> Date? {
            guard let s, let utc = utcFormatter.date(from: String(s.prefix(14))) else { return nil }
            let suffix = s.dropFirst(14).trimmingCharacters(in: .whitespaces)
            guard let offset = offsetSeconds(suffix) else { return utc }
            return utc.addingTimeInterval(-TimeInterval(offset))
        }

        static func offsetSeconds(_ suffix: String) -> Int? {
            let chars = Array(suffix)
            guard let sign = chars.first, sign == "+" || sign == "-" else { return nil }
            let digits = chars.dropFirst().filter { $0 != ":" }
            let hasValidColon = chars.count == 5 || (chars.count == 6 && chars[3] == ":")
            guard hasValidColon, digits.count == 4, digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber),
                let hours = Int(String(digits.prefix(2))), let minutes = Int(String(digits.suffix(2))),
                hours <= 14, minutes < 60
            else { return nil }
            let seconds = hours * 3600 + minutes * 60
            return sign == "-" ? -seconds : seconds
        }

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
            attributes: [String: String] = [:]
        ) {
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
                    programmes.append(
                        Programme(
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
