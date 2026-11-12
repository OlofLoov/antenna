import Foundation

/// Reading and writing the bits of Jellyfin's HTTP API the client shares.
enum JellyfinWire {
    /// `MediaBrowser Client="Antenna", Device=…, DeviceId=…, Version=…`,
    /// then `Token=…` when there is one. Each value is cleaned to one line
    /// with quotes and backslashes removed.
    static func authorization(device: JellyfinDevice, token: String?) -> String {
        var pairs = [
            ("Client", "Antenna"), ("Device", device.name), ("DeviceId", device.id), ("Version", device.appVersion),
        ]
        if let token { pairs.append(("Token", token)) }
        return "MediaBrowser " + pairs.map { "\($0)=\"\(clean($1))\"" }.joined(separator: ", ")
    }

    /// One line, no quotes or backslashes, spaces at either end trimmed.
    static func clean(_ value: String) -> String {
        let flattened = value.unicodeScalars.map { scalar -> String in
            if CharacterSet.newlines.contains(scalar) || CharacterSet.controlCharacters.contains(scalar) { return " " }
            if scalar == "\"" || scalar == "\\" { return "" }
            return String(scalar)
        }
        return flattened.joined().trimmingCharacters(in: .whitespaces)
    }

    /// Query items, each name and value percent-encoded so `&`, `+` and `=`
    /// survive.
    static func query(_ items: [URLQueryItem]) -> String {
        items.map { "\(XtreamClient.percentEncode($0.name))=\(XtreamClient.percentEncode($0.value ?? ""))" }.joined(separator: "&")
    }

    /// The answer as a JSON object. A web page, an empty body or anything
    /// that is not an object is a reading error that quotes nothing.
    static func object(_ data: Data) throws -> [String: Any] {
        guard let object = json(data) as? [String: Any] else { throw JellyfinClient.JellyfinError.decoding(path: "$") }
        return object
    }

    /// The parsed answer, nil when it is not JSON.
    static func json(_ data: Data) -> Any? {
        try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    /// A string, or a number written as one.
    static func string(_ value: Any?) -> String? {
        switch value {
        case let text as String: text
        case let number as NSNumber where CFGetTypeID(number) != CFBooleanGetTypeID(): number.stringValue
        default: nil
        }
    }

    /// True when the body, past leading spaces, is empty.
    static func isBlank(_ data: Data) -> Bool {
        data.allSatisfy { $0 == 0x20 || $0 == 0x09 || $0 == 0x0A || $0 == 0x0D }
    }

    /// The `Items` list of a paged answer and its `TotalRecordCount`.
    static func items(_ data: Data) throws -> (rows: [Any], total: Int?) {
        let object = try object(data)
        guard let rows = object["Items"] as? [Any] else { throw JellyfinClient.JellyfinError.decoding(path: "Items") }
        let total = (object["TotalRecordCount"] as? NSNumber).flatMap { Int(exactly: $0.doubleValue) }
        return (rows, total)
    }

    /// A channel number made of digits only, such as "101". "5.1" and
    /// "BBC" give nil.
    static func wholeNumber(_ value: Any?) -> Int? {
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() { return Int(exactly: number.doubleValue) }
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespaces), !text.isEmpty,
            text.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 })
        else { return nil }
        return Int(text)
    }

    /// `ImageTags.Primary`, nil when absent or empty.
    static func primaryTag(_ object: [String: Any]) -> String? {
        guard let tag = string((object["ImageTags"] as? [String: Any])?["Primary"]), !tag.isEmpty else { return nil }
        return tag
    }

    /// A string trimmed of spaces, nil when absent or blank.
    static func text(_ value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    /// `yyyy-MM-ddTHH:mm:ss`, with any number of fraction digits and `Z`,
    /// `+HH:mm` or no zone, which reads as UTC. Nil for anything else or an
    /// impossible date.
    static func date(_ text: String) -> Date? {
        var text = text
        return text.withUTF8 { bytes in
            var reader = DateReader(bytes: bytes)
            return reader.read()
        }
    }

    /// Reads one date from UTF-8 bytes, front to back.
    private struct DateReader {
        let bytes: UnsafeBufferPointer<UInt8>
        var index = 0

        mutating func digits(_ count: Int) -> Int? {
            guard index + count <= bytes.count else { return nil }
            var value = 0
            for offset in index..<index + count {
                let byte = bytes[offset]
                guard byte >= 0x30, byte <= 0x39 else { return nil }
                value = value * 10 + Int(byte - 0x30)
            }
            index += count
            return value
        }

        mutating func take(_ byte: UInt8) -> Bool {
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
            return true
        }

        mutating func read() -> Date? {
            guard let year = digits(4), take(0x2D), let month = digits(2), take(0x2D), let day = digits(2),
                take(0x54) || take(0x20), let hour = digits(2), take(0x3A), let minute = digits(2), take(0x3A),
                let second = digits(2), (1...12).contains(month), (1...31).contains(day), hour < 24, minute < 60, second < 61
            else { return nil }
            var fraction = 0.0
            if take(0x2E) {
                var scale = 0.1
                let first = index
                while index < bytes.count, bytes[index] >= 0x30, bytes[index] <= 0x39 {
                    fraction += Double(bytes[index] - 0x30) * scale
                    scale /= 10
                    index += 1
                }
                guard index > first else { return nil }
            }
            var offset = 0
            if !take(0x5A), index < bytes.count, bytes[index] == 0x2B || bytes[index] == 0x2D {
                let sign = bytes[index] == 0x2B ? 1 : -1
                index += 1
                guard let hours = digits(2) else { return nil }
                _ = take(0x3A)
                guard let minutes = digits(2), hours < 24, minutes < 60 else { return nil }
                offset = (hours * 3600 + minutes * 60) * sign
            }
            guard index == bytes.count else { return nil }
            let days = JellyfinWire.daysFromCivil(year: year, month: month, day: day)
            let seconds = days * 86_400 + hour * 3600 + minute * 60 + second - offset
            return Date(timeIntervalSince1970: TimeInterval(seconds) + fraction)
        }
    }

    /// Days from 1970-01-01 to the given day of the proleptic Gregorian
    /// calendar.
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let shifted = month <= 2 ? year - 1 : year
        let era = (shifted >= 0 ? shifted : shifted - 399) / 400
        let yearOfEra = shifted - era * 400
        let dayOfYear = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
