import Foundation

/// The link as a log line may show it: scheme, host, port and path, then each
/// query name with its value replaced by "…". A query item with no value (no
/// "=" or nothing after it) is replaced whole, since it may be a token. The
/// user name, password and fragment are dropped. No query value ever appears
/// in the result.
public func redacted(_ url: URL) -> String {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "…" }
    var result = ""
    if let scheme = components.scheme { result += scheme + "://" }
    result += components.percentEncodedHost ?? ""
    if let port = components.port { result += ":\(port)" }
    result += components.percentEncodedPath
    if let items = components.percentEncodedQueryItems {
        result += "?" + items.map { ($0.value ?? "").isEmpty ? "…" : "\($0.name)=…" }.joined(separator: "&")
    }
    return result
}
