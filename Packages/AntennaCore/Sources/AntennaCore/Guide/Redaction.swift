import Foundation

/// The link as a log line may show it: scheme, host and port, then "/…"
/// followed by the last path component's extension, then each query name
/// with its value replaced by "…". A query item with no value (no "=" or
/// nothing after it) is replaced whole, since it may be a token. The user
/// name, password, path, stream number and fragment never appear in the
/// result, and neither does any query value.
public func redacted(_ url: URL) -> String {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "…" }
    var result = ""
    if let scheme = components.scheme { result += scheme + "://" }
    result += components.percentEncodedHost ?? ""
    if let port = components.port { result += ":\(port)" }
    let path = components.percentEncodedPath
    if path == "/" {
        result += "/"
    } else if !path.isEmpty {
        let ext = (path as NSString).pathExtension
        result += "/…" + (ext.isEmpty || ext.contains("%") ? "" : "." + ext)
    }
    if let items = components.percentEncodedQueryItems {
        result += "?" + items.map { ($0.value ?? "").isEmpty ? "…" : "\($0.name)=…" }.joined(separator: "&")
    }
    return result
}
