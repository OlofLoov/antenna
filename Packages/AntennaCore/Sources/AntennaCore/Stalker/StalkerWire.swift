import Foundation

extension URLSessionConfiguration {
    /// The configuration Stalker clients use: no cookies, no URL cache,
    /// 30 s per request and 10 minutes per load.
    public static var stalker: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 600
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        return configuration
    }
}

/// Follows a redirect only to the same scheme, host and port, so the MAC
/// cookie and the session key never reach another server. A refused
/// redirect hands back the 3xx answer.
final class StalkerRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        guard let from = task.originalRequest?.url, let to = request.url else { return nil }
        return StalkerWire.sameOrigin(from, to) ? request : nil
    }
}

/// Request building and answer reading shared by every Stalker call.
enum StalkerWire {
    /// What one answer turned out to be.
    enum Reply {
        /// The value under `js`, as `JSONSerialization` reads it.
        case payload(Any)
        /// 401, 403, a body of `Authorization failed.`, or JSON whose `js`
        /// is null, "" or absent.
        case rejected
    }

    static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        func port(_ url: URL) -> Int? { url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80) }
        return lhs.scheme?.lowercased() == rhs.scheme?.lowercased() && lhs.host()?.lowercased() == rhs.host()?.lowercased()
            && port(lhs) == port(rhs)
    }

    /// The query items in order, then `JsHttpRequest=1-xml`, each value
    /// percent-encoded outside the RFC 3986 unreserved set.
    static func url(endpoint: URL, items: [(String, String)]) -> URL {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { return endpoint }
        let all = items + [("JsHttpRequest", "1-xml")]
        components.percentEncodedQuery = all.map { "\($0)=\(XtreamClient.percentEncode($1))" }.joined(separator: "&")
        return components.url ?? endpoint
    }

    /// A GET with the headers every MAG box sends, and the session key when
    /// there is one.
    static func request(
        url: URL, portal: StalkerPortal, mac: MACAddress, device: StalkerDevice, timeZone: TimeZone, token: String?,
        timeout: TimeInterval = 30
    ) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpShouldHandleCookies = false
        request.setValue("mac=\(mac.cookieValue); stb_lang=en; timezone=\(timeZone.identifier)", forHTTPHeaderField: "Cookie")
        request.setValue(device.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(device.xUserAgent, forHTTPHeaderField: "X-User-Agent")
        request.setValue(portal.url.absoluteString + "/c/", forHTTPHeaderField: "Referer")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    /// Reads one answer after sign-in. Throws `.serverError` for a status
    /// outside 200 to 299 that is not a rejection, and `.unreadable` for a
    /// body that is not a JSON object.
    static func read(status: Int, data: Data) throws(StalkerError) -> Reply {
        if status == 401 || status == 403 { return .rejected }
        let body = trimmed(data)
        if body.elementsEqual("Authorization failed.".utf8) { return .rejected }
        guard (200..<300).contains(status) else { throw .serverError(status: status) }
        guard let object = json(body) as? [String: Any] else { throw .unreadable }
        guard let js = object["js"], !(js is NSNull), (js as? String)?.isEmpty != true else { return .rejected }
        return .payload(js)
    }

    /// The body without leading whitespace, as some portals send a newline
    /// before the JSON.
    static func trimmed(_ data: Data) -> Data {
        guard let first = data.firstIndex(where: { !($0 == 0x20 || $0 == 0x09 || $0 == 0x0A || $0 == 0x0D) }) else { return Data() }
        return first == data.startIndex ? data : data[first...]
    }

    static func json(_ data: Data) -> Any? {
        guard !data.isEmpty else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    /// True when the body starts like an HTML page.
    static func looksLikeHTML(_ data: Data) -> Bool {
        let head = String(decoding: trimmed(data).prefix(64), as: UTF8.self).lowercased()
        return head.hasPrefix("<!doctype html") || head.hasPrefix("<html")
    }

    // MARK: Loose JSON values

    static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String: string
        case let number as NSNumber where CFGetTypeID(number) != CFBooleanGetTypeID(): number.stringValue
        default: nil
        }
    }

    static func int(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber where CFGetTypeID(number) != CFBooleanGetTypeID(): Loose.int(number.doubleValue)
        case let string as String: Loose.int(string.trimmingCharacters(in: .whitespaces))
        default: nil
        }
    }

    /// `text` with every spelling of the MAC, and each other secret given,
    /// replaced by "…".
    static func redact(_ text: String, mac: MACAddress, secrets: [String]) -> String {
        var result = text
        let all = (mac.spellings + secrets).filter { !$0.isEmpty }.sorted { $0.count > $1.count }
        for secret in all { result = result.replacingOccurrences(of: secret, with: "…", options: .caseInsensitive) }
        return result
    }
}
