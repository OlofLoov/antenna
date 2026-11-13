import Foundation

/// A short reason for a failed provider request, safe to log in public:
/// an HTTP status, a transport error code or a coding path, never an
/// address, login or response body
/// (title-detail-and-episode-picker/when-details-or-episodes-do-not-load).
public enum LoadFailureReason {
    /// "status 404", "transport -1001", "unauthorized", "decoding at episodes.1[0]",
    /// "decoding body" for a body that is not JSON, "cancelled", or the error's type name.
    public static func text(for error: any Error) -> String {
        switch error {
        case let xtream as XtreamClient.XtreamError:
            switch xtream {
            case .badStatus(let status): return "status \(status)"
            case .unauthorized: return "unauthorized"
            case .transport(let code): return "transport \(code.rawValue)"
            case .decoding(let path): return path.isEmpty ? "decoding body" : "decoding at \(path)"
            }
        case let url as URLError:
            return "transport \(url.code.rawValue)"
        case let decoding as DecodingError:
            let path = XtreamClient.codingPath(of: decoding)
            return path.isEmpty ? "decoding body" : "decoding at \(path)"
        case is CancellationError:
            return "cancelled"
        default:
            return String(describing: type(of: error))
        }
    }

    /// True for the transport codes that mean the device is offline.
    public static func isOffline(_ error: any Error) -> Bool {
        let offline: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed]
        switch error {
        case XtreamClient.XtreamError.transport(let code): return offline.contains(code)
        case let url as URLError: return offline.contains(url.code)
        default: return false
        }
    }
}
