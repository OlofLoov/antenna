import Foundation

/// The TV's answer to one `play`.
public struct PlayAnswer: Sendable, Hashable {
    /// What happened to the request on the TV
    /// (play-on-apple-tv/the-phone-says-why-the-tv-cannot-play).
    public enum Result: Sendable, Hashable {
        /// The TV started tuning or loading it.
        case started
        /// The item sits behind a lock or hidden adult content; the TV asks for the passcode.
        case needsPasscode
        /// The source has no login on the TV.
        case noLogin(source: UUID)
        /// The source has not reached the TV yet.
        case noSource(source: UUID)
        /// The source has no such channel, film or episode.
        case notFound
        /// The TV shows the paywall or "Who's watching?" and keeps the request until it goes.
        case waiting
        /// The request came from a newer Antuna than the TV runs.
        case unsupportedVersion
    }

    public var requestID: UUID
    public var result: Result

    public init(requestID: UUID, result: Result) {
        self.requestID = requestID
        self.result = result
    }
}

/// What the TV plays, sent to a connected phone on every change and every
/// five seconds. It names the item by key and the art by `artworkKey`, so no
/// image or link crosses the network.
public struct PlayStatus: Sendable, Hashable {
    public enum State: String, Sendable, Hashable, Codable {
        case playing, paused, stopped
    }

    public var state: State
    /// The request this plays, when it came from a phone.
    public var requestID: UUID?
    public var source: UUID?
    public var item: PlayRequest.Item?
    /// The channel or title name.
    public var title: String
    /// The programme on now, or the episode's name.
    public var subtitle: String?
    public var position: TimeInterval?
    public var duration: TimeInterval?
    /// Names the channel or title whose art the phone already has.
    public var artworkKey: String?

    public init(
        state: State, requestID: UUID? = nil, source: UUID? = nil, item: PlayRequest.Item? = nil, title: String, subtitle: String? = nil,
        position: TimeInterval? = nil, duration: TimeInterval? = nil, artworkKey: String? = nil
    ) {
        self.state = state
        self.requestID = requestID
        self.source = source
        self.item = item
        self.title = title
        self.subtitle = subtitle
        self.position = position
        self.duration = duration
        self.artworkKey = artworkKey
    }
}

/// What a connected phone asks of the TV.
public enum PlayControl: String, Sendable, Hashable, Codable {
    case play, pause
    /// The TV stops and answers with a `status` holding its position.
    case handOff
    /// The TV keeps playing and forgets this phone.
    case disconnect
}

/// One frame on the link between a phone and an Apple TV: a JSON object
/// with a `type` and a version `v`, sent after a four-byte big-endian length.
public enum PlayMessage: Sendable, Hashable {
    /// Phone to TV.
    case play(PlayRequest)
    /// TV to phone.
    case answer(PlayAnswer)
    /// TV to phone.
    case status(PlayStatus)
    /// Phone to TV.
    case control(PlayControl)

    /// The frame version this build writes and reads.
    public static let currentVersion = 1

    /// Why a frame could not be read.
    public enum DecodeError: Error, Sendable, Hashable {
        /// From a newer Antuna; the request's id when the frame carried one.
        case unsupportedVersion(requestID: UUID?)
        /// A type this build does not know.
        case unknownType
        /// Not a frame at all.
        case malformed
        /// Longer than `PlayFrames.maximumLength`.
        case tooLong
    }
}

// MARK: Coding

extension PlayMessage {
    private struct Envelope: Codable {
        var type: String
        var version: Int
        var request: PlayRequest?
        var answer: AnswerBody?
        var status: StatusBody?
        var control: PlayControl?

        enum CodingKeys: String, CodingKey {
            case type, request, answer, status, control
            case version = "v"
        }
    }

    fileprivate struct AnswerBody: Codable {
        var request: UUID
        var result: String
        var source: UUID?
    }

    private struct StatusBody: Codable {
        var state: PlayStatus.State
        var request: UUID?
        var source: UUID?
        var item: PlayRequest.Item?
        var title: String
        var subtitle: String?
        var position: Double?
        var duration: Double?
        var artwork: String?
    }

    /// The frame's JSON, without the length.
    public func encoded() throws -> Data {
        var envelope = Envelope(type: "", version: Self.currentVersion)
        switch self {
        case .play(let request):
            envelope.type = "play"
            envelope.request = request
        case .answer(let answer):
            envelope.type = "answer"
            envelope.answer = AnswerBody(answer)
        case .status(let status):
            envelope.type = "status"
            envelope.status = StatusBody(
                state: status.state, request: status.requestID, source: status.source, item: status.item, title: status.title,
                subtitle: status.subtitle, position: status.position, duration: status.duration, artwork: status.artworkKey)
        case .control(let control):
            envelope.type = "control"
            envelope.control = control
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(envelope)
    }

    /// Reads one frame's JSON. A frame or request from a newer version
    /// throws `.unsupportedVersion` with the request's id when it has one,
    /// so the TV can answer it.
    public init(decoding data: Data) throws(DecodeError) {
        let head: Head
        do {
            head = try JSONDecoder().decode(Head.self, from: data)
        } catch {
            throw .malformed
        }
        let requestVersion = head.request?.version ?? Self.currentVersion
        guard head.version <= Self.currentVersion, requestVersion <= PlayRequest.currentVersion else {
            throw .unsupportedVersion(requestID: head.request?.id)
        }
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw head.isKnown ? .malformed : .unknownType
        }
        switch envelope.type {
        case "play":
            guard let request = envelope.request else { throw .malformed }
            self = .play(request)
        case "answer":
            guard let body = envelope.answer, let result = body.decodedResult else { throw .malformed }
            self = .answer(PlayAnswer(requestID: body.request, result: result))
        case "status":
            guard let body = envelope.status else { throw .malformed }
            self = .status(
                PlayStatus(
                    state: body.state, requestID: body.request, source: body.source, item: body.item, title: body.title,
                    subtitle: body.subtitle, position: body.position, duration: body.duration, artworkKey: body.artwork))
        case "control":
            guard let control = envelope.control else { throw .malformed }
            self = .control(control)
        default:
            throw .unknownType
        }
    }

    /// The fields read before the rest, so a newer frame is recognized
    /// even when its body would not decode.
    private struct HeadRequest: Decodable {
        var version: Int?
        var id: UUID?

        enum CodingKeys: String, CodingKey {
            case id
            case version = "v"
        }
    }

    private struct Head: Decodable {
        var type: String
        var version: Int
        var request: HeadRequest?

        enum CodingKeys: String, CodingKey {
            case type, request
            case version = "v"
        }

        var isKnown: Bool { ["play", "answer", "status", "control"].contains(type) }
    }
}

extension PlayMessage.AnswerBody {
    init(_ answer: PlayAnswer) {
        request = answer.requestID
        switch answer.result {
        case .started: result = "started"
        case .needsPasscode: result = "needsPasscode"
        case .noLogin(let id):
            result = "noLogin"
            source = id
        case .noSource(let id):
            result = "noSource"
            source = id
        case .notFound: result = "notFound"
        case .waiting: result = "waiting"
        case .unsupportedVersion: result = "unsupportedVersion"
        }
    }

    var decodedResult: PlayAnswer.Result? {
        switch result {
        case "started": .started
        case "needsPasscode": .needsPasscode
        case "noLogin": source.map { .noLogin(source: $0) }
        case "noSource": source.map { .noSource(source: $0) }
        case "notFound": .notFound
        case "waiting": .waiting
        case "unsupportedVersion": .unsupportedVersion
        default: nil
        }
    }
}

/// Length-prefixed frames on a byte stream.
public enum PlayFrames {
    /// No frame is longer than this; a longer one ends the connection.
    public static let maximumLength = 64 * 1024

    /// The message as the link sends it: a four-byte big-endian length, then the JSON.
    public static func frame(_ message: PlayMessage) throws -> Data {
        let body = try message.encoded()
        var length = UInt32(body.count).bigEndian
        var data = Data(bytes: &length, count: 4)
        data.append(body)
        return data
    }

    /// Collects bytes as they arrive and hands back each whole frame.
    public struct Reader: Sendable {
        private var buffer = Data()

        public init() {}

        /// Adds `bytes` and returns the frames now complete, in order. A
        /// frame that does not decode comes back as its error; a length over
        /// `maximumLength` returns `.tooLong` and the caller ends the link.
        public mutating func append(_ bytes: Data) -> [Result<PlayMessage, PlayMessage.DecodeError>] {
            buffer.append(bytes)
            var out: [Result<PlayMessage, PlayMessage.DecodeError>] = []
            while buffer.count >= 4 {
                let start = buffer.startIndex
                let length = buffer[start..<start + 4].reduce(0) { $0 << 8 | Int($1) }
                guard length <= maximumLength else {
                    buffer.removeAll()
                    out.append(.failure(.tooLong))
                    break
                }
                guard buffer.count >= 4 + length else { break }
                let body = Data(buffer[start + 4..<start + 4 + length])
                buffer = Data(buffer[(start + 4 + length)...])
                do {
                    out.append(.success(try PlayMessage(decoding: body)))
                } catch {
                    out.append(.failure(error))
                }
            }
            return out
        }
    }
}
