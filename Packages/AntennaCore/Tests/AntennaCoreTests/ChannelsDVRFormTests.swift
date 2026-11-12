import Foundation
import Testing

@testable import AntennaCore

@Suite struct ChannelsDVRFormTests {
    private func fields(_ url: String, username: String = "", password: String = "") -> SourceFields {
        SourceFields(kind: .channelsDVR, url: url, username: username, password: password)
    }

    @Test("first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting a Channels DVR server address")
    func checksAddress() {
        #expect(fields("").check() == .missingField(.server))
        #expect(fields("nas.local").check() == nil)
        #expect(fields("nas.local").link?.absoluteString == "http://nas.local:8089")
        #expect(fields("nas.local").host == "nas.local")
        #expect(fields("ftp://nas.local").check() == .invalidServer)
        #expect(fields("fe80::1").check() == .invalidServer)
        #expect(fields("http://alice:secret@nas.local").check() == .addressHasLogin)
        #expect(fields("alice@nas.local/channels").check() == .addressHasLogin)
        #expect(fields("nas.local", username: "alice").check() == .missingField(.password))
        #expect(fields("nas.local", password: "secret").check() == .missingField(.username))
        #expect(fields("nas.local", username: "al:ice", password: "x").check() == .invalidUsername)
        #expect(fields("nas.local", username: "alice", password: "x").check() == nil)
    }

    @Test("first-run-onboarding/a-failed-connection-says-why-and-saves-nothing each Channels DVR failure has its sentence")
    func wording() {
        let host = "nas.local"
        let cases: [(ChannelsDVRError, String)] = [
            (.unreachable(.cannotConnectToHost), "Could not reach nas.local. Check the address and try again."),
            (.transport(.secureConnectionFailed), "Could not reach nas.local. Check the address and try again."),
            (.offline, "You're offline. Connect to the internet and try again."),
            (.httpStatus(502), "The server answered with an error (502). Check the address and try again."),
            (.malformed, "The server replied with something Antenna could not read."),
            (.notAChannelsServer, "No Channels DVR server at nas.local."),
            (.starting, "Channels DVR is starting. Try again in a moment."),
            (.unauthorized, "This server asks for a username and password, which Antenna cannot send yet."),
        ]
        for (error, sentence) in cases {
            #expect(ConnectFailure(error, host: host).message == sentence)
        }
        #expect(ConnectFailure.invalidServer.message == "Enter a valid server address.")
    }

    @Test("first-run-onboarding/a-failed-connection-says-why-and-saves-nothing the local network hint follows the host")
    func localNetworkHint() {
        let unreachable = ConnectFailure.unreachable(host: "x")
        for host in ["192.168.1.20", "10.0.0.4", "172.16.0.1", "172.31.255.1", "nas.local", "NAS.Local", "fe80::1", "[fe80::1]"] {
            #expect(unreachable.wantsLocalNetworkHint(host: host), "\(host)")
            #expect(ConnectFailure.offline.wantsLocalNetworkHint(host: host), "\(host)")
        }
        for host in ["172.32.0.1", "8.8.8.8", "home.example.net", "abc.u.channelsdvr.net", "fe80"] {
            #expect(!unreachable.wantsLocalNetworkHint(host: host), "\(host)")
        }
        #expect(!ConnectFailure.starting.wantsLocalNetworkHint(host: "nas.local"))
    }
}
