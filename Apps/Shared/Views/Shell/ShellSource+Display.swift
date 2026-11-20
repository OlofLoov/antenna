#if os(tvOS)
    import Foundation

    extension ShellSource {
        /// The loading screen's row for this source (`TV-Shell-Loading`).
        var loadingRow: ShellLoading.Row {
            let detail: LocalizedStringResource =
                switch state {
                case .loading: "Loading channels"
                case .loaded(let count): "\(count) channels"
                case .offline: "Offline"
                case .failed: "Could not load channels"
                case .waitingForLogin where waitsForICloud: "Waiting for its playlist to sync from iCloud"
                case .waitingForLogin: "Waiting for its login to sync from iCloud"
                }
            let indicator: ShellLoading.Row.Indicator =
                switch state {
                case .loading: .working
                case .loaded: .done
                case .offline, .failed, .waitingForLogin: .none
                }
            return .init(id: id, name: name, detail: detail, indicator: indicator, value: value)
        }

        /// The empty screen's line for this source (`TV-Shell-Empty`).
        var emptyLine: ShellEmpty.Line {
            let text: LocalizedStringResource =
                switch state {
                case .loading: "\(name): loading"
                case .loaded: "\(name): no channels"
                case .offline: "\(name): offline"
                case .failed: "\(name): could not load its channels"
                case .waitingForLogin where waitsForICloud: "\(name): waiting for its playlist to sync from iCloud"
                case .waitingForLogin: "\(name): waiting for its login to sync from iCloud"
                }
            return .init(id: id, text: text, value: value)
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
