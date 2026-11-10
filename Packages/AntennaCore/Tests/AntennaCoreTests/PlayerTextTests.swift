import AntennaCore
import Foundation
import Testing

@Suite struct StreamLineTests {
    static let broadcast = PresentationInfo(
        video: .init(width: 1920, height: 1080, frameRate: 50, dynamicRange: .sdr, codec: "h264"),
        audio: .init(codec: "aac", channels: 6, isDecodable: true))

    @Test(
        "player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv the stream line names container, picture, sound and player"
    )
    func streamLine() {
        #expect(
            StreamLine.text(container: "MPEG-TS", presentation: Self.broadcast, route: .demuxer)
                == "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna player")
        let interlaced = PresentationInfo(
            video: .init(width: 720, height: 576, frameRate: 50, dynamicRange: .sdr, codec: "mpeg2video", isInterlaced: true),
            audio: .init(codec: "mp2", channels: 2, isDecodable: true))
        #expect(
            StreamLine.text(container: "MPEG-TS", presentation: interlaced, route: .demuxer)
                == "MPEG-TS · MPEG-2 576i · MP2 Stereo · Antenna player")
        let radio = PresentationInfo(video: nil, audio: .init(codec: "mp4a", channels: 2, isDecodable: true))
        #expect(StreamLine.text(container: "HLS", presentation: radio, route: .system) == "HLS · AAC Stereo · Apple player")
        #expect(StreamLine.text(container: nil, presentation: Self.broadcast, route: .system) == "H.264 1080p · AAC 5.1 · Apple player")
    }

    @Test(
        "player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv before the first frame the line says details are not available"
    )
    func loading() {
        #expect(StreamLine.text(container: "MPEG-TS", presentation: nil, route: .demuxer) == "Stream details not available yet")
    }

    @Test(
        "player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv codecs read by their common names",
        arguments: [
            ("h264", "H.264"), ("avc1", "H.264"), ("hevc", "HEVC"), ("hvc1", "HEVC"), ("hev1", "HEVC"),
            ("mpeg2video", "MPEG-2"), ("aac", "AAC"), ("mp4a", "AAC"), ("ac3", "AC-3"), ("eac3", "E-AC-3"),
            ("ec-3", "E-AC-3"), ("vp9", "VP9"), ("opus", "OPUS"),
        ])
    func codecNames(codec: String, display: String) {
        #expect(CodecName.display(codec) == display)
    }

    @Test(
        "player-controls-and-playback-errors/choose-audio-and-subtitles sound formats read codec then layout",
        arguments: [(1, "AAC Mono"), (2, "AAC Stereo"), (6, "AAC 5.1"), (8, "AAC 7.1"), (4, "AAC 4 channels"), (0, "AAC")])
    func soundFormats(channels: Int, display: String) {
        #expect(SoundFormat.display(codec: "aac", channels: channels) == display)
    }
}

@Suite struct TrackNameTests {
    func track(_ language: String?, _ name: String? = nil, kind: MediaTrack.Kind = .audio) -> MediaTrack {
        MediaTrack(id: "audio-0", kind: kind, languageCode: language, name: name, isDefault: false)
    }

    @Test(
        "player-controls-and-playback-errors/choose-audio-and-subtitles tracks read as their language",
        arguments: [("en", "English"), ("eng", "English"), ("swe", "Swedish"), ("sv", "Swedish"), ("pt-BR", "Portuguese (Brazil)")])
    func languages(code: String, display: String) {
        #expect(TrackName.display(track(code), position: 0) == display)
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles a provider name that says more goes in brackets")
    func providerName() {
        #expect(TrackName.display(track("en", "Commentary"), position: 0) == "English (Commentary)")
        #expect(TrackName.display(track("en", "audio description"), position: 1) == "English (audio description)")
        #expect(TrackName.display(track("en", "English"), position: 0) == "English")
        #expect(TrackName.display(track("en", "  "), position: 0) == "English")
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles a track with no language reads Track n")
    func noLanguage() {
        #expect(TrackName.display(track(nil), position: 3) == "Track 4")
        #expect(TrackName.display(track("und"), position: 0) == "Track 1")
        #expect(TrackName.display(track(nil, "Director"), position: 2) == "Director")
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles forced subtitles with no language read Forced")
    func forced() {
        #expect(TrackName.display(track(nil, kind: .subtitle), position: 0, isForced: true) == "Forced")
        #expect(TrackName.display(track("en", "Forced", kind: .subtitle), position: 0, isForced: true) == "English (Forced)")
        #expect(TrackName.display(track(nil), position: 0, isForced: true) == "Track 1")
    }
}

@Suite struct FailureMessageTests {
    static let reasons: [PlaybackFailure] = [
        .offline, .unreachable, .secureConnectionFailed, .loginNotOnDevice, .notAllowed, .notFound, .serverBusy,
        .serverError, .refused(status: 451), .timedOut, .stoppedSendingData, .unreadable, .cannotDecode(codec: "vc1"),
        .noDecoderFree,
    ]

    func message(_ failure: PlaybackFailure, _ device: FailureMessage.Device = .other) -> FailureMessage {
        FailureMessage(failure, source: "Acme TV", device: device)
    }

    @Test("player-controls-and-playback-errors/error-messages-for-each-reason offline")
    func offline() {
        #expect(
            message(.offline)
                == FailureMessage(
                    title: "You're offline",
                    explanation: "Connect to the internet and try again. Playback resumes on its own when the connection returns."))
    }

    @Test("player-controls-and-playback-errors/error-messages-for-each-reason unreachable or failed secure connection")
    func unreachable() {
        #expect(message(.unreachable).title == "Could not reach Acme TV")
        #expect(message(.unreachable).explanation == "The connection failed. Check the network, or a VPN if one is on.")
        #expect(
            FailureMessage(.unreachable, source: "Acme TV", device: .other, connectionDetail: "server not found").explanation
                == "The connection failed (server not found). Check the network, or a VPN if one is on.")
        #expect(message(.secureConnectionFailed).title == "Could not reach Acme TV")
        #expect(message(.secureConnectionFailed).explanation == "The secure connection failed. Check the network, or a VPN if one is on.")
    }

    @Test("player-controls-and-playback-errors/error-messages-for-each-reason login not on this device or Apple TV")
    func loginMissing() {
        #expect(
            message(.loginNotOnDevice)
                == FailureMessage(
                    title: "Waiting for login", explanation: "The login for Acme TV has not reached this device from iCloud Keychain yet."))
        #expect(
            message(.loginNotOnDevice, .appleTV)
                == FailureMessage(title: "Sign in needed", explanation: "Sign in to Acme TV on this Apple TV to play its channels."))
    }

    @Test("player-controls-and-playback-errors/error-messages-for-each-reason login rejected")
    func loginRejected() {
        #expect(message(.notAllowed).title == "Sign-in refused")
        #expect(
            message(.notAllowed).explanation
                == "Acme TV rejected the login. Check the username and password in Settings, or ask the provider whether the account has expired."
        )
        #expect(
            message(.notAllowed, .appleTV).explanation
                == "Acme TV rejected the login. Sign in again on this Apple TV, or ask the provider whether the account has expired.")
    }

    @Test("player-controls-and-playback-errors/error-messages-for-each-reason provider refusals")
    func refusals() {
        #expect(
            message(.notFound)
                == FailureMessage(
                    title: "Stream not found",
                    explanation: "Acme TV returned 404 for this channel. The channel may have moved or been removed by the provider."))
        #expect(
            message(.serverBusy) == FailureMessage(title: "Provider busy", explanation: "Acme TV is busy right now. Try again in a moment.")
        )
        #expect(message(.serverError).title == "Provider error")
        #expect(message(.serverError).explanation.hasSuffix("Its server is having trouble. Try again in a moment."))
        #expect(
            message(.refused(status: 451))
                == FailureMessage(title: "Stream unavailable", explanation: "Acme TV returned 451 for this channel."))
    }

    @Test("player-controls-and-playback-errors/error-messages-for-each-reason nothing arrived or data stopped")
    func stopped() {
        #expect(message(.timedOut) == FailureMessage(title: "Stream stopped", explanation: "Acme TV did not send any data for 8 seconds."))
        #expect(
            FailureMessage(.timedOut, source: "Acme TV", device: .other, silentSeconds: 15).explanation
                == "Acme TV did not send any data for 15 seconds.")
        #expect(message(.stoppedSendingData) == FailureMessage(title: "Stream stopped", explanation: "Acme TV stopped sending data."))
    }

    @Test("player-controls-and-playback-errors/error-messages-for-each-reason not a stream, unsupported codec, no decoder free")
    func unplayable() {
        #expect(
            message(.unreadable)
                == FailureMessage(
                    title: "Stream could not be read",
                    explanation: "Acme TV sent data that is not a playable stream. The address may point to a web page or an empty file."))
        #expect(
            message(.cannotDecode(codec: "hevc"))
                == FailureMessage(
                    title: "Format not supported",
                    explanation:
                        "This stream uses HEVC, which this device cannot play. Trying again will not help. Pick another channel or ask the provider for a stream in a supported format."
                ))
        #expect(
            message(.noDecoderFree)
                == FailureMessage(
                    title: "Can't play another stream", explanation: "This device is already playing as many streams as it can."))
    }

    @Test("player-controls-and-playback-errors/error-messages-for-each-reason every reason names the source or the device")
    func everyReasonHasText() {
        for reason in Self.reasons {
            for device in [FailureMessage.Device.appleTV, .other] {
                let text = message(reason, device)
                #expect(!text.title.isEmpty && !text.explanation.isEmpty, "\(reason)")
            }
        }
    }

    @Test("player-controls-and-playback-errors/error-messages-for-each-reason no secrets anywhere")
    func noSecrets() {
        let url = URL(string: "https://olof77:hunter2pw@panel.acme-iptv.example:8443/live/olof77/hunter2pw/12345.ts?token=abc987")!
        let secrets = [url.absoluteString, "panel.acme-iptv.example", "acme-iptv", "olof77", "hunter2pw", "12345", "abc987"]
        var strings: [String] = [
            PlayerStatusText.slowSource("Acme TV"), PlayerStatusText.reconnecting(attempt: 2, of: 8),
            PlayerStatusText.attempted(source: "Acme TV", at: "21:34"), PlayerStatusText.changeChannelHint,
        ]
        for reason in Self.reasons {
            for device in [FailureMessage.Device.appleTV, .other] {
                let text = message(reason, device)
                strings += [text.title, text.explanation]
            }
        }
        strings.append(StreamLine.text(container: "MPEG-TS", presentation: StreamLineTests.broadcast, route: .demuxer))
        for string in strings {
            for secret in secrets {
                #expect(!string.contains(secret), "\(string) contains \(secret)")
            }
        }
    }
}
