#if os(tvOS)
    import Foundation

    extension ShellSource {
        /// The loading screen's row for this source (`TV-Shell-Loading`).
        var loadingRow: ShellLoading.Row {
            let detail: String
            let indicator: ShellLoading.Row.Indicator
            switch state {
            case .loading:
                (detail, indicator) = ("Loading channels", .working)
            case .loaded(let count):
                detail = count == 1 ? "1 channel" : "\(count) channels"
                indicator = .done
            case .offline:
                (detail, indicator) = ("Offline", .none)
            case .failed:
                (detail, indicator) = ("Could not load channels", .none)
            case .waitingForLogin where waitsForICloud:
                (detail, indicator) = ("Waiting for its playlist to sync from iCloud", .none)
            case .waitingForLogin:
                (detail, indicator) = ("Waiting for its login to sync from iCloud", .none)
            }
            return .init(id: id, name: name, detail: detail, indicator: indicator, value: value)
        }

        /// The empty screen's line for this source (`TV-Shell-Empty`).
        var emptyLine: ShellEmpty.Line {
            let reason =
                switch state {
                case .loading: "loading"
                case .loaded: "no channels"
                case .offline: "offline"
                case .failed: "could not load its channels"
                case .waitingForLogin: "waiting for its \(waitsForICloud ? "playlist" : "login") to sync from iCloud"
                }
            return .init(id: id, text: "\(name): \(reason)", value: value)
        }

        /// What UI tests and VoiceOver read: `loading`, `loaded:<n>`,
        /// `offline`, `failed`, `waitingForLogin`.
        var value: String {
            switch state {
            case .loading: "loading"
            case .loaded(let count): "loaded:\(count)"
            case .offline: "offline"
            case .failed: "failed"
            case .waitingForLogin: "waitingForLogin"
            }
        }
    }
#endif
