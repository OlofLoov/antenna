#if os(tvOS)
    import AntennaCore
    import Foundation
    import Observation

    /// Typing a channel number on a hardware keyboard (tv-zap-bar-and-number-entry capability).
    /// Digits show in a box with the channel they match; two seconds after
    /// the last digit, or on Return or select, the typed number tunes, or
    /// the box reads "No channel n" for a second. Key events and the clock
    /// are injected, since UI tests cannot type into a non-text view.
    @MainActor @Observable
    final class NumberEntryModel {
        enum Phase: Equatable {
            case closed
            case typing
            /// "No channel <digits>", for one second.
            case noChannel(String)
        }

        static let waitAfterDigit = Duration.seconds(2)
        static let noChannelFor = Duration.seconds(1)

        private(set) var phase: Phase = .closed
        private(set) var digits = ""
        /// The name of the channel the digits match so far, nil when none.
        private(set) var matchName: String?

        /// Digits past this many are ignored: the longest channel number, never fewer than four.
        var maxDigits = 4
        /// The channel whose number starts with the digits, lowest number first.
        @ObservationIgnored var lookup: @MainActor (String) -> (channel: Channel, number: Int)? = { _ in nil }
        @ObservationIgnored var tune: @MainActor (Channel) -> Void = { _ in }

        @ObservationIgnored private let sleep: @MainActor (Duration) async throws -> Void
        @ObservationIgnored private var timer: Task<Void, Never>?

        init(sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
            self.sleep = sleep
        }

        var isOpen: Bool { phase != .closed }

        /// A digit typed (tv-zap-bar-and-number-entry/typing-a-number-shows-the-match).
        func type(_ digit: Character) {
            guard digit.isASCII, digit.isNumber else { return }
            if case .noChannel = phase { digits = "" }
            guard digits.count < maxDigits else { return }
            digits.append(digit)
            phase = .typing
            refreshMatch()
            waitThenCommit()
        }

        /// Backspace removes the last digit and gives two more seconds; an
        /// emptied box closes (tv-zap-bar-and-number-entry/correct-or-cancel-a-number).
        func backspace() {
            guard phase == .typing, !digits.isEmpty else { return }
            digits.removeLast()
            guard !digits.isEmpty else { return close() }
            refreshMatch()
            waitThenCommit()
        }

        /// Menu or Escape: closes without tuning.
        func cancel() {
            close()
        }

        /// Two seconds passed, or Return or select: tunes the typed number,
        /// or shows "No channel n" for a second
        /// (tv-zap-bar-and-number-entry/the-typed-channel-tunes,
        /// tv-zap-bar-and-number-entry/no-channel-with-that-number).
        func commit() {
            guard phase == .typing else { return }
            timer?.cancel()
            let typed = Int(digits)
            if let match = lookup(digits), match.number == typed {
                close()
                tune(match.channel)
                return
            }
            phase = .noChannel(digits)
            matchName = nil
            timer = Task { [weak self, sleep] in
                do {
                    try await sleep(Self.noChannelFor)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self?.close()
            }
        }

        private func refreshMatch() {
            matchName = lookup(digits)?.channel.name
        }

        private func waitThenCommit() {
            timer?.cancel()
            timer = Task { [weak self, sleep] in
                do {
                    try await sleep(Self.waitAfterDigit)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self?.commit()
            }
        }

        private func close() {
            timer?.cancel()
            timer = nil
            phase = .closed
            digits = ""
            matchName = nil
        }
    }
#endif
