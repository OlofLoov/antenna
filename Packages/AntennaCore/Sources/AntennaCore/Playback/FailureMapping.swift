import Foundation

/// Whether an address can be a stream at all, decided without contacting
/// any server.
public enum StreamAddress {
    /// The schemes either engine opens.
    public static let schemes: Set<String> = ["http", "https"]

    /// Throws `PlaybackFailure.unreadable` for an address that cannot be a
    /// stream: another scheme (`rtsp`, `rtmp`, `udp`, `mms`, `file`), no
    /// host, or a host with spaces or other characters a host cannot have.
    public static func check(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased(), schemes.contains(scheme) else { throw PlaybackFailure.unreadable }
        guard let host = url.host(percentEncoded: false), !host.isEmpty else { throw PlaybackFailure.unreadable }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-:[]_%"))
        guard host.unicodeScalars.allSatisfy(allowed.contains) else { throw PlaybackFailure.unreadable }
    }

    /// True for a host on the home network: a private or link-local IPv4
    /// address, an IPv6 unique-local or link-local address, or a `.local` name.
    public static func isLocal(_ host: String) -> Bool {
        let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host.hasSuffix(".local") { return true }
        if host.hasPrefix("fe80:") || host.hasPrefix("fc") || host.hasPrefix("fd") { return host.contains(":") }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        switch (parts[0], parts[1]) {
        case (10, _), (192, 168), (169, 254): return true
        case (172, 16...31): return true
        default: return false
        }
    }
}

extension PlaybackFailure {
    /// The reason for an HTTP status, nil for a success.
    public init?(httpStatus status: Int) {
        switch status {
        case 200..<300: return nil
        case 401, 403: self = .notAllowed
        case 404, 410: self = .notFound
        case 429: self = .serverBusy
        case 500..<600: self = .serverError
        default: self = .refused(status: status)
        }
    }

    /// The reason for a network error. `host` lets a refused local network
    /// prompt, which the system reports as no internet, fail like an
    /// unreachable server.
    public init(_ error: URLError, host: String? = nil) {
        switch error.code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff, .callIsActive:
            self = host.map(StreamAddress.isLocal) == true ? .unreachable : .offline
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            self = .unreachable
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
            .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected,
            .clientCertificateRequired, .appTransportSecurityRequiresSecureConnection:
            self = .secureConnectionFailed
        case .timedOut:
            self = .timedOut
        case .networkConnectionLost, .zeroByteResource, .cannotParseResponse, .badServerResponse:
            self = .stoppedSendingData
        case .userAuthenticationRequired, .userCancelledAuthentication, .noPermissionsToReadFile:
            self = .notAllowed
        case .fileDoesNotExist, .resourceUnavailable:
            self = .notFound
        default:
            self = .unreadable
        }
    }

    /// The reason for an error from Apple's player. Only domains and codes
    /// are read, down the chain of underlying errors; nothing else in the
    /// error, which can hold the address, is kept.
    public static func fromPlayerError(_ error: any Error, host: String? = nil) -> PlaybackFailure {
        var current: NSError? = error as NSError
        var depth = 0
        while let nsError = current, depth < 8 {
            if let failure = reason(domain: nsError.domain, code: nsError.code, userInfo: nsError.userInfo, host: host) {
                return failure
            }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return .unreadable
    }

    private static func reason(domain: String, code: Int, userInfo: [String: Any], host: String?) -> PlaybackFailure? {
        switch domain {
        case NSURLErrorDomain:
            return PlaybackFailure(URLError(URLError.Code(rawValue: code)), host: host)
        case "AVFoundationErrorDomain":
            switch code {
            case -11833:
                let types = (userInfo["AVErrorMediaSubTypeKey"] as? [NSNumber])?.map(\.uint32Value) ?? []
                return .cannotDecode(codec: types.first.map(CodecName.name) ?? "unknown")
            case -11839: return .noDecoderFree
            case -11835, -11831: return .notAllowed
            case -11828, -11850, -11853, -11864, -11838, -11863: return .unreadable
            default: return nil
            }
        case "CoreMediaErrorDomain":
            switch code {
            case -12938: return .notFound
            case -12660: return .notAllowed
            case -12889: return .timedOut
            default: return nil
            }
        default:
            return nil
        }
    }
}

/// Short codec names for the four-character codes streams use.
public enum CodecName {
    public static func name(_ fourCC: UInt32) -> String {
        let code =
            String(
                bytes: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: fourCC >> $0) }, encoding: .ascii
            ) ?? ""
        switch code {
        case "avc1", "avc3": return "h264"
        case "hvc1", "hev1": return "hevc"
        case "dvh1", "dvhe": return "dolby vision"
        case "mp2v": return "mpeg2video"
        case "mp4v": return "mpeg4"
        case "mp4a", "aac ": return "aac"
        case "ac-3": return "ac3"
        case "ec-3": return "eac3"
        case "dtsc", "dtsh", "dtsl": return "dts"
        case ".mp3": return "mp3"
        case "opus": return "opus"
        default: return code.trimmingCharacters(in: .whitespaces)
        }
    }
}
