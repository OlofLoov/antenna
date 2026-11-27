#if DEBUG
    import AntennaCore
    import Foundation
    import Network
    import Observation
    import SwiftUI

    /// UI test hooks for Play on (play-on-apple-tv capability).
    ///
    /// On iPhone, iPad and Mac, `-ui-testing-play-on <scenario>` swaps iCloud
    /// and the network for a scripted account and a scripted Apple TV:
    /// `one` lists Living Room, ready now; `two` adds Bedroom, not open;
    /// `refused` lists both with local network access refused; `closed` has
    /// Living Room with Antuna closed; `none` lists no TV.
    /// `-ui-testing-play-on-answer <result>` sets what the scripted TV
    /// answers: `started` (the default), `needsPasscode`, `noLogin`,
    /// `noSource`, `notFound`, `waiting`, `unsupportedVersion` or `silent`,
    /// which never answers, or `offline`, where iCloud cannot be reached
    /// either. A request the network does not carry waits in an in-memory
    /// iCloud queue. The browser's start is counted, so a test sees whether
    /// opening Play on started it.
    ///
    /// On Apple TV, `-ui-testing-play-request <source>/<channel>`, with
    /// `playlist` or `xtream` for the source and a `UITestingShell` channel
    /// id such as `a2`, delivers a request from "Anna's iPhone" once the
    /// shell shows. `playOn.probe` reads the TV's answer.
    @MainActor
    enum UITestingPlayOn {
        static let argument = "-ui-testing-play-on"
        static let answerArgument = "-ui-testing-play-on-answer"
        static let requestArgument = "-ui-testing-play-request"
        /// `-ui-testing-play-offer <source>/<channel>[:old]` leaves a request
        /// for the TV in a scripted iCloud queue, sent now or an hour ago.
        static let offerArgument = "-ui-testing-play-offer"
        /// `-ui-testing-play-on-shared <folder>` keeps the device records as
        /// files in a folder on the Mac, so an iPhone simulator and an Apple
        /// TV simulator share an account and talk over the real listener and
        /// TLS link. The TV writes its port there, which the phone reads in place of Bonjour.
        static let sharedArgument = "-ui-testing-play-on-shared"

        /// The shared folder's store, or nil without the argument.
        static var shared: FilePlayDevices? {
            value(after: sharedArgument).map { FilePlayDevices(folder: URL(fileURLWithPath: $0)) }
        }

        static let livingRoom = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1") ?? UUID()
        static let bedroom = UUID(uuidString: "00000000-0000-0000-0000-0000000000C2") ?? UUID()

        private static func value(after argument: String, in arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
            guard let index = arguments.firstIndex(of: argument), arguments.index(after: index) < arguments.endIndex else { return nil }
            return arguments[arguments.index(after: index)]
        }

        /// The scenario after the argument, or nil without it. On Apple TV a
        /// request to deliver counts as one.
        static var scenario: String? {
            value(after: argument) ?? value(after: requestArgument) ?? value(after: sharedArgument) ?? value(after: offerArgument)
        }

        static func tv(_ id: UUID, _ name: String, created: TimeInterval) -> PlayDeviceInfo {
            PlayDeviceInfo(
                id: id, kind: .tv, name: name, publicKey: Data([4]), keyDate: .now, lastSeen: .now,
                created: Date(timeIntervalSince1970: created))
        }

        #if !os(tvOS)
            /// The scripted destination, or nil outside these tests.
            static var destination: (() -> PlayDestination)? {
                if let shared {
                    return {
                        let device = PlayOnDevice.launching(UserDefaults(suiteName: "ui-testing-play-on") ?? .standard)
                        return PlayDestination(
                            .init(
                                devices: shared, browser: FolderBrowser(store: shared), sender: NetworkPlaySender(device: device),
                                device: device))
                    }
                }
                guard let scenario = value(after: argument) else { return nil }
                return {
                    let tvs: [PlayDeviceInfo] =
                        switch scenario {
                        case "none": []
                        case "one", "closed": [tv(livingRoom, "Living Room", created: 1)]
                        default: [tv(livingRoom, "Living Room", created: 1), tv(bedroom, "Bedroom", created: 2)]
                        }
                    let reachable = scenario != "refused" && scenario != "closed"
                    let browser = Browser(ready: reachable ? [livingRoom] : [], denied: scenario == "refused")
                    let device = PlayOnDevice.launching(UserDefaults(suiteName: "ui-testing-play-on") ?? .standard)
                    var dependencies = PlayDestination.Dependencies(
                        devices: InMemoryPlayDevices(tvs), browser: browser, sender: Sender(answer: answer), device: device)
                    dependencies.defaults = UserDefaults(suiteName: "ui-testing-play-on") ?? .standard
                    dependencies.defaults.removeObject(forKey: PlayDestination.browsingKey)
                    dependencies.answerLimit = .seconds(1)
                    dependencies.queue = InMemoryPlayRequests(failure: value(after: answerArgument) == "offline" ? .offline : nil)
                    return PlayDestination(dependencies)
                }
            }

            private static var answer: PlayAnswer.Result? {
                switch value(after: answerArgument) ?? "started" {
                case "needsPasscode": .needsPasscode
                case "noLogin": .noLogin(source: UUID())
                case "noSource": .noSource(source: UUID())
                case "notFound": .notFound
                case "waiting": .waiting
                case "unsupportedVersion": .unsupportedVersion
                case "silent": nil
                default: .started
                }
            }

            /// A browser that finds the scripted TVs once started.
            @Observable
            final class Browser: PlayOnBrowsing {
                private(set) var endpoints: [UUID: NWEndpoint] = [:]
                private(set) var denied = false
                /// How often the browser started from stopped, which the probe shows.
                private(set) var starts = 0
                @ObservationIgnored private let ready: [UUID]
                @ObservationIgnored private let refuses: Bool
                @ObservationIgnored private var running = false

                init(ready: [UUID], denied: Bool) {
                    self.ready = ready
                    refuses = denied
                }

                func start() {
                    guard !running else { return }
                    running = true
                    starts += 1
                    denied = refuses
                    endpoints = Dictionary(uniqueKeysWithValues: ready.map { ($0, NWEndpoint.hostPort(host: "127.0.0.1", port: 9)) })
                }

                func stop() {
                    running = false
                    endpoints = [:]
                }
            }

            /// A TV that answers every request the same way.
            final class Sender: PlayOnSending {
                private let answer: PlayAnswer.Result?

                init(answer: PlayAnswer.Result?) {
                    self.answer = answer
                }

                func send(_ request: PlayRequest, to _: PlayDeviceInfo, at _: NWEndpoint, within limit: Duration) async -> PlaySendOutcome {
                    guard let answer else {
                        try? await Task.sleep(for: limit)
                        return .noAnswer
                    }
                    return .answered(answer)
                }
            }

            /// Whether the browser ran, for UI tests (`playOn.probe`).
            struct Probe: View {
                let destination: PlayDestination?

                var body: some View {
                    if let browser = destination?.dependencies.browser as? Browser {
                        Text(verbatim: "browser \(browser.starts)")
                            .font(.caption2)
                            .opacity(0.01)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("playOn.probe")
                    }
                }
            }
        #else
            /// The TV's answers to the delivered request, newest last.
            @Observable
            @MainActor final class Answers {
                static let shared = Answers()
                var last: String = "none"
            }

            /// A receiver with an in-memory account that listens without Bonjour,
            /// or with the shared folder's account and Bonjour.
            static var receiver: ((PlayRequestInbox) -> PlayOnReceiver)? {
                guard scenario != nil else { return nil }
                if let shared {
                    return { inbox in
                        let device = PlayOnDevice.launching()
                        let receiver = PlayOnReceiver(inbox: inbox, device: device, devices: shared)
                        Task {
                            while true {
                                try? await Task.sleep(for: .seconds(1))
                                if let port = receiver.port { shared.publish(port: port, of: device.id) }
                            }
                        }
                        return receiver
                    }
                }
                return { inbox in
                    let device = PlayOnDevice.launching(UserDefaults(suiteName: "ui-testing-play-on") ?? .standard)
                    let waiting = value(after: offerArgument).flatMap { request(from: $0, for: device.id) }
                    return PlayOnReceiver(
                        inbox: inbox, device: device, devices: InMemoryPlayDevices(),
                        queue: InMemoryPlayRequests(waiting.map { [$0] } ?? []), advertises: false)
                }
            }

            /// A request from Anna's iPhone for `<source>/<channel>`, sent an
            /// hour ago with `:old` after it, else now.
            private static func request(from spec: String, for target: UUID) -> PlayRequest? {
                let old = spec.hasSuffix(":old")
                let parts = spec.replacingOccurrences(of: ":old", with: "").split(separator: "/").map(String.init)
                guard parts.count == 2 else { return nil }
                let source = parts[0] == "xtream" ? UITestingShell.xtreamID : UITestingShell.playlistID
                return PlayRequest(
                    sender: UUID(), senderName: "Anna's iPhone", target: target, source: source,
                    item: .channel(key: PlayItemKeys.key("fixture/\(parts[1])")), displayTitle: "Channel \(parts[1])",
                    created: old ? .now.addingTimeInterval(-3600) : .now)
            }

            /// Delivers the request after the argument into `inbox` once the
            /// shell has taken over, or does nothing without it.
            static func deliver(into inbox: PlayRequestInbox) async {
                guard let spec = value(after: requestArgument), let request = request(from: spec, for: livingRoom) else { return }
                // The shell shows the first channel before the request, as a TV already open would.
                try? await Task.sleep(for: .seconds(3))
                inbox.receive(request) { result in Answers.shared.last = "\(result)" }
            }

            /// The TV's answer, for UI tests (`playOn.probe`).
            struct Probe: View {
                var body: some View {
                    Text(verbatim: "answer \(Answers.shared.last)")
                        .font(.caption2)
                        .opacity(0.01)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("playOn.probe")
                }
            }
        #endif
    }
#endif
