import Foundation

// MARK: - Decode functions

extension XtreamClient {
    /// Decodes a `get_vod_streams` body. Broken and duplicate rows are dropped and counted in `skipped`.
    /// `[]`, `{}`, `false` and `null` give an empty list; any other body that is not an array throws
    /// `XtreamError.decoding(path:)`. Never traps.
    public static func decodeVODList(_ data: Data, host: String) throws -> DecodedList<VODItem> {
        try decodeList(data, row: VODRow.self) { row in
            let id = XtreamTitleID(host: host, kind: .vod, rawID: row.streamID).description
            return VODItem(
                id: id, streamID: row.streamID, name: row.name, posterURL: row.posterURL, added: row.added, rating: row.rating,
                containerExtension: row.containerExtension, categoryID: row.categoryID)
        }
    }

    /// Decodes a `get_series` body with the same row and shape rules as `decodeVODList(_:host:)`.
    public static func decodeSeriesList(_ data: Data, host: String) throws -> DecodedList<Series> {
        try decodeList(data, row: SeriesRow.self) { row in
            let id = XtreamTitleID(host: host, kind: .series, rawID: row.seriesID).description
            return Series(
                id: id, seriesID: row.seriesID, name: row.name, posterURL: row.posterURL, lastModified: row.lastModified,
                categoryID: row.categoryID)
        }
    }

    /// Decodes a `get_vod_info` body. `[]`, `{}`, `false` and `null` give a value with every field empty;
    /// any other body that is not an object throws `XtreamError.decoding(path:)`.
    public static func decodeVODInfo(_ data: Data, host: String) throws -> VODInfo {
        guard try isObjectBody(data) else { return VODInfo() }
        let wire = try decode(VODInfoWire.self, from: data)
        let info = wire.info ?? InfoFields()
        return VODInfo(
            plot: info.plot, year: info.year, duration: info.duration, genre: info.genre, ageRating: info.ageRating,
            backdropURLs: info.backdropURLs, containerExtension: wire.containerExtension)
    }

    /// Decodes a `get_series_info` body. Episodes come out flat and sorted by season then number, nil
    /// first, ties in server order. Broken and duplicate episodes are counted in `skippedEpisodes`.
    public static func decodeSeriesInfo(_ data: Data, host: String) throws -> SeriesInfo {
        guard try isObjectBody(data) else { return SeriesInfo() }
        let wire = try decode(SeriesInfoWire.self, from: data)
        let info = wire.info ?? InfoFields()
        let (episodes, skipped) = flatten(wire.episodes, host: host)
        return SeriesInfo(
            plot: info.plot, year: info.year, genre: info.genre, ageRating: info.ageRating, backdropURLs: info.backdropURLs,
            episodes: episodes, skippedEpisodes: skipped)
    }
}

// MARK: - Shape handling

extension XtreamClient {
    static func decodeList<Row: Decodable & ListRow, Item: Sendable & Hashable>(
        _ data: Data, row: Row.Type, map: (Row) -> Item
    ) throws -> DecodedList<Item> {
        guard firstByte(of: data) == UInt8(ascii: "[") else {
            try requireEmptyShape(data)
            return DecodedList(items: [], skipped: 0)
        }
        let rows = try decode([Lossy<Row>].self, from: data)
        var seen = Set<Int>()
        var items: [Item] = []
        items.reserveCapacity(rows.count)
        var skipped = 0
        for lossy in rows {
            guard let row = lossy.value, seen.insert(row.rawID).inserted else {
                skipped += 1
                continue
            }
            items.append(map(row))
        }
        return DecodedList(items: items, skipped: skipped)
    }

    /// True for a JSON object body. False for the empty shapes `[]`, `{}`, `false` and `null`.
    /// Throws `XtreamError.decoding(path: "")` for anything else.
    static func isObjectBody(_ data: Data) throws -> Bool {
        let shape = try decode(RootShape.self, from: data)
        switch shape {
        case .object: return true
        case .empty: return false
        case .other: throw XtreamError.decoding(path: "")
        }
    }

    /// Returns for `{}`, `false`, `null` and `[]`; throws `XtreamError.decoding(path: "")` otherwise.
    static func requireEmptyShape(_ data: Data) throws {
        guard try decode(RootShape.self, from: data) == .empty else { throw XtreamError.decoding(path: "") }
    }

    static func firstByte(of data: Data) -> UInt8? {
        data.first { !($0 == 0x20 || $0 == 0x09 || $0 == 0x0A || $0 == 0x0D) }
    }

    /// Decodes with `JSONDecoder` and turns any failure into `XtreamError.decoding(path:)`.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw XtreamError.decoding(path: codingPath(of: error))
        } catch {
            throw XtreamError.decoding(path: "")
        }
    }

    /// The dotted coding path of a decoding failure, `[3].stream_id` style. Never includes values.
    static func codingPath(of error: DecodingError) -> String {
        let keys: [any CodingKey]
        switch error {
        case .keyNotFound(let key, let context): keys = context.codingPath + [key]
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context): keys = context.codingPath
        @unknown default: keys = []
        }
        var path = ""
        for key in keys {
            if let index = key.intValue, key.stringValue == "Index \(index)" {
                path += "[\(index)]"
            } else {
                path += path.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return path
    }
}

enum RootShape: Decodable, Equatable {
    case object, empty, other

    init(from decoder: any Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: AnyCodingKey.self) {
            self = keyed.allKeys.isEmpty ? .empty : .object
        } else if let unkeyed = try? decoder.unkeyedContainer() {
            self = unkeyed.isAtEnd ? .empty : .other
        } else {
            let single = try decoder.singleValueContainer()
            if single.decodeNil() {
                self = .empty
            } else if let flag = try? single.decode(Bool.self) {
                self = flag ? .other : .empty
            } else {
                self = .other
            }
        }
    }
}

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Decodes `T` or records that the element was unusable, so one bad row does not fail its list.
struct Lossy<T: Decodable>: Decodable {
    var value: T?
    init(from decoder: any Decoder) throws { value = try? T(from: decoder) }
}

protocol ListRow {
    var rawID: Int { get }
}

// MARK: - Loose values

enum Loose {
    /// An integer from a JSON integer, an integral in-range float, or a string holding either.
    static func int(_ double: Double) -> Int? { Int(exactly: double) }

    static func int(_ string: String) -> Int? {
        Int(string) ?? Double(string).flatMap(int)
    }

    static func double(_ string: String) -> Double? {
        Double(string).flatMap { $0.isFinite ? $0 : nil }
    }

    /// Seconds since 1970 when the value is a positive integer.
    static func date(_ seconds: Int?) -> Date? {
        guard let seconds, seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    /// Only `http` and `https` URLs with a non-empty host.
    static func webURL(_ string: String?) -> URL? {
        guard let string, let url = URL(string: string), let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https", let host = url.host(), !host.isEmpty
        else { return nil }
        return url
    }

    /// `duration_secs` when positive, else `duration` as `hh:mm:ss` or `mm:ss` when positive.
    static func duration(seconds: Double?, clock: String?) -> TimeInterval? {
        if let seconds, seconds > 0 { return seconds }
        guard let clock else { return nil }
        let parts = clock.split(separator: ":", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.count == 2 || parts.count == 3, parts.allSatisfy({ ($0 ?? -1) >= 0 }) else { return nil }
        let total = parts.compactMap { $0 }.reduce(0.0) { $0 * 60 + Double($1) }
        return total > 0 ? total : nil
    }

    /// The year at the start of a date string, nil for "0000" or when it does not start with four digits.
    static func year(_ string: String?) -> Int? {
        guard let string else { return nil }
        let prefix = string.utf8.prefix(4)
        guard prefix.count == 4, prefix.allSatisfy({ (0x30...0x39).contains($0) }) else { return nil }
        let year = prefix.reduce(0) { $0 * 10 + Int($1 - 0x30) }
        return year > 0 ? year : nil
    }
}

extension KeyedDecodingContainer {
    /// An integer from a JSON number or a numeric string. `stringFirst` tries the string form first,
    /// which saves a thrown error per row for fields panels usually send as strings.
    func looseInt(_ key: Key, stringFirst: Bool = false) -> Int? {
        if stringFirst, let value = try? decodeIfPresent(String.self, forKey: key) { return Loose.int(value) }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if !stringFirst, let value = try? decodeIfPresent(String.self, forKey: key) { return Loose.int(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Loose.int(value) }
        return nil
    }

    /// A finite number from a JSON number or a numeric string, string form tried first.
    func looseDouble(_ key: Key) -> Double? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Loose.double(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value.isFinite ? value : nil }
        return nil
    }

    /// A string, or a number as its text. Nil when absent, null, empty or another type.
    func looseString(_ key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value.isEmpty ? nil : value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite { return String(value) }
        return nil
    }

    /// A non-empty JSON string, or nil.
    func nonEmptyString(_ key: Key) -> String? {
        guard let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty else { return nil }
        return value
    }
}
