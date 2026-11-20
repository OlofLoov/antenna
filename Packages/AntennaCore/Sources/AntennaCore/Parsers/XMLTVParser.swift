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

    /// Parses a whole XMLTV document. A bare `&` and common HTML named
    /// entities such as `&nbsp;` are read as text. Any other well-formedness
    /// error throws `XMLTVError.malformed` and returns nothing.
    public func parse(_ data: Data) throws(XMLTVError) -> Result {
        let delegate = Delegate()
        let parser = XMLParser(data: XMLEntitySanitizer.sanitize(data))
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            throw .malformed(line: parser.lineNumber, column: parser.columnNumber)
        }
        return Result(channelNames: delegate.channelNames, programmes: delegate.programmes)
    }

    /// Parses a document read from `stream` and hands each programme to
    /// `each` as its element ends, keeping none, so memory does not grow with
    /// the document. Entities are not rewritten: callers pass a document that
    /// `XMLEntitySanitizer` has already seen. Throws as `parse(_:)` does.
    /// Returns the channels' display names by id.
    @discardableResult
    func parseSanitized(_ stream: InputStream, each: (Programme) -> Void) throws(XMLTVError) -> [String: String] {
        let parser = XMLParser(stream: stream)
        parser.shouldProcessNamespaces = false
        let delegate = Delegate()
        let succeeded = withoutActuallyEscaping(each) { each -> Bool in
            delegate.each = each
            parser.delegate = delegate
            defer {
                delegate.each = nil
                parser.delegate = nil
            }
            return parser.parse()
        }
        guard succeeded else {
            throw .malformed(line: parser.lineNumber, column: parser.columnNumber)
        }
        return delegate.channelNames
    }

    /// The only error `parse` throws. No Foundation error reaches the caller.
    public enum XMLTVError: Error, Sendable, Equatable {
        /// The document is not well-formed XML. `line` and `column` are where
        /// the XML parser stopped; `line` is 1-based.
        case malformed(line: Int, column: Int)
    }

    static let utcFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyyMMddHHmmss"
        return f
    }()

    /// The first 14 characters of `s` read as `yyyyMMddHHmmss` in UTC.
    /// A valid stamp from 1900 on is computed directly; anything else
    /// goes to the formatter, so both give the same answer.
    static func utcDate(_ s: String) -> Date? {
        if let seconds = stampSeconds(s) { return Date(timeIntervalSince1970: TimeInterval(seconds)) }
        return utcFormatter.date(from: String(s.prefix(14)))
    }

    /// Seconds since 1970 for 14 ASCII digits forming a valid date and
    /// time in 1900 or later, when the 15th byte, if any, is ASCII too.
    /// Nil otherwise.
    static func stampSeconds(_ s: String) -> Int? {
        let utf8 = s.utf8
        var index = utf8.startIndex
        func number(_ width: Int) -> Int? {
            var value = 0
            for _ in 0..<width {
                guard index != utf8.endIndex else { return nil }
                let byte = utf8[index]
                guard byte >= 0x30, byte <= 0x39 else { return nil }
                value = value * 10 + Int(byte - 0x30)
                utf8.formIndex(after: &index)
            }
            return value
        }
        guard let year = number(4), let month = number(2), let day = number(2), let hour = number(2),
            let minute = number(2), let second = number(2)
        else { return nil }
        if index != utf8.endIndex, utf8[index] >= 0x80 { return nil }
        guard year >= 1900, (1...12).contains(month), hour < 24, minute < 60, second < 60 else { return nil }
        let leap = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
        let length =
            switch month {
            case 2: leap ? 29 : 28
            case 4, 6, 9, 11: 30
            default: 31
            }
        guard day >= 1, day <= length else { return nil }
        // Days from 1970-01-01 to the civil date, after Howard Hinnant's days_from_civil.
        let y = month <= 2 ? year - 1 : year
        let era = y / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        let days = era * 146_097 + dayOfEra - 719_468
        return days * 86_400 + hour * 3_600 + minute * 60 + second
    }

    // MARK: - SAX delegate

    private final class Delegate: NSObject, XMLParserDelegate {
        var channelNames: [String: String] = [:]
        var programmes: [Programme] = []
        /// When set, receives each programme instead of `programmes`.
        var each: ((Programme) -> Void)?

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

        /// Reads the first 14 characters as UTC, then applies a `±HHMM` or
        /// `±HH:MM` offset that follows, with or without spaces before it.
        /// An offset over 14 hours, or any other suffix, is ignored.
        static func date(_ s: String?) -> Date? {
            guard let s, let utc = XMLTVParser.utcDate(s) else { return nil }
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

        /// Runs `body` in its own autorelease pool, so the bridged strings and
        /// dates Foundation hands back for each element are freed as the parse
        /// goes rather than when it ends.
        private func drained(_ body: () -> Void) {
            #if canImport(ObjectiveC)
                autoreleasepool(invoking: body)
            #else
                body()
            #endif
        }

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
            attributes: [String: String] = [:]
        ) {
            drained { start(name, attributes: attributes) }
        }

        private func start(_ name: String, attributes: [String: String]) {
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
            drained { end(name) }
        }

        private func end(_ name: String) {
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
                    let programme = Programme(
                        channelID: ch, start: start, stop: stop, title: title,
                        subtitle: subtitle.isEmpty ? nil : subtitle,
                        summary: desc.isEmpty ? nil : desc,
                        category: category.isEmpty ? nil : category,
                        iconURL: icon
                    )
                    if let each { each(programme) } else { programmes.append(programme) }
                }
                progChannel = nil
            default:
                break
            }
        }
    }
}
