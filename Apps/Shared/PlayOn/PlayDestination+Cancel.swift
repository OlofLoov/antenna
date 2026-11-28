import AntennaCore
import Foundation

/// The request the "Sent" line's Cancel takes back, with its TV and whether
/// it went through iCloud (play-on-apple-tv/the-phone-can-take-a-request-back).
struct PlayPending {
    var request: PlayRequest
    var tv: PlayTV
    var queued: Bool
}

extension PlayDestination {
    /// The TV answered: stay connected when it took the request, and say what happened.
    func answered(_ result: PlayAnswer.Result, link: (any PlayOnLinking)?, request: PlayRequest, item: PlayOnItem, tv: PlayTV) {
        if let link {
            if Self.connects(after: result) { connect(link, to: tv) } else { link.close() }
        }
        var line = Self.notice(for: result, tv: tv.name, item: item, locale: dependencies.locale, connected: connection != nil)
        if result == .waiting {
            // Kept behind the TV's paywall or "Who's watching?": the phone can take it back.
            line?.cancel = request.id
            notice = line
            pending = PlayPending(request: request, tv: tv, queued: false)
        } else {
            notice = line
        }
    }

    /// Cancel on the "Sent" line (play-on-apple-tv/the-phone-can-take-a-request-back):
    /// deletes the request from iCloud while it still waits there, else
    /// tells the TV over the network to drop it, and says which worked.
    func cancel() async {
        guard let pending else { return }
        self.pending = nil
        let request = pending.request
        let tv = pending.tv
        var canceled = false
        if pending.queued, let queue = dependencies.queue {
            do {
                if try await queue.waiting(for: tv.id)?.id == request.id {
                    try await queue.delete(request)
                    canceled = true
                }
            } catch {
                PlayOnLog.failure("cancel request", error)
            }
        }
        if !canceled {
            let quick = PlaySendLimits(reach: dependencies.limits.reach, answer: dependencies.limits.reach)
            if let connection, connection.tv.id == tv.id {
                canceled = await connection.cancel(request.id, within: quick.answer)
            } else if !dependencies.browser.denied, let endpoint = dependencies.browser.endpoints[tv.id] {
                canceled = await dependencies.sender.cancel(request.id, on: tv.device, at: endpoint, limits: quick)
            }
        }
        let locale = dependencies.locale
        notice = PlayOnNotice(text: canceled ? PlayOnText.canceled(locale) : PlayOnText.alreadyHas(tv.name, locale: locale), kind: .sent)
    }

    /// A TV that took the request, or asks for its passcode, keeps the phone connected.
    static func connects(after result: PlayAnswer.Result) -> Bool {
        switch result {
        case .started, .needsPasscode: true
        case .noLogin, .noSource, .notFound, .waiting, .unsupportedVersion, .canceled: false
        }
    }
}
