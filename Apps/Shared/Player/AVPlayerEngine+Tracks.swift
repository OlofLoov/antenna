import AVFoundation
import AntennaCore
import CoreMedia
import Foundation

#if os(tvOS)
    import AVKit
#endif

/// The sound and subtitle options of one item, in the order `tracks()`
/// reports them.
struct MediaSelection {
    let audioGroup: AVMediaSelectionGroup?
    let subtitleGroup: AVMediaSelectionGroup?
    let audio: [(track: MediaTrack, option: AVMediaSelectionOption)]
    let subtitles: [(track: MediaTrack, option: AVMediaSelectionOption)]
    var selectedAudio: MediaTrack.ID?
    var selectedSubtitle: MediaTrack.ID?

    var trackList: TrackList {
        TrackList(
            audio: audio.map(\.track), subtitles: subtitles.map(\.track), selectedAudio: selectedAudio, selectedSubtitle: selectedSubtitle)
    }
}

/// Hands the subtitle lines Apple's player decodes to the engine, which
/// draws them itself (playback-engine/audio-and-subtitle-languages).
final class LegibleRelay: NSObject, AVPlayerItemLegibleOutputPushDelegate {
    let lines: @MainActor ([String]) -> Void

    init(lines: @escaping @MainActor ([String]) -> Void) {
        self.lines = lines
    }

    nonisolated func legibleOutput(
        _ output: AVPlayerItemLegibleOutput, didOutputAttributedStrings strings: [NSAttributedString],
        nativeSampleBuffers nativeSamples: [Any], forItemTime itemTime: CMTime
    ) {
        let texts = strings.map(\.string)
        MainActor.assumeIsolated { lines(texts) }
    }
}

extension AVPlayerEngine {
    // MARK: Sound and subtitles

    /// Plays the sound track `id` from `tracks()`. A reconnect keeps the pick.
    func selectAudio(_ id: MediaTrack.ID) async {
        guard var selection, let group = selection.audioGroup, let pick = selection.audio.first(where: { $0.track.id == id }) else {
            return
        }
        player.currentItem?.select(pick.option, in: group)
        selection.selectedAudio = id
        self.selection = selection
        request?.options.remembered = LanguagePick(selection.trackList)
        stream?.options.remembered = LanguagePick(selection.trackList)
        tracksCast.sendIfChanged(selection.trackList)
    }

    /// Shows the subtitle track `id` from `tracks()`, or none with nil.
    func selectSubtitle(_ id: MediaTrack.ID?) async {
        guard var selection, let group = selection.subtitleGroup else { return }
        let pick = id.flatMap { id in selection.subtitles.first { $0.track.id == id } }
        if id != nil, pick == nil { return }
        player.currentItem?.select(pick?.option, in: group)
        selection.selectedSubtitle = pick?.track.id
        self.selection = selection
        if pick == nil { cuesCast.sendIfChanged([]) }
        request?.options.remembered = LanguagePick(selection.trackList)
        stream?.options.remembered = LanguagePick(selection.trackList)
        tracksCast.sendIfChanged(selection.trackList)
    }

    /// Lists the item's sound and text subtitle options and selects the
    /// ones `TrackChoice` picks.
    func chooseTracks(for item: AVPlayerItem, options: PlaybackOptions, generation mine: Int) async throws {
        let asset = item.asset
        let audioGroup = try? await asset.loadMediaSelectionGroup(for: .audible)
        let subtitleGroup = try? await asset.loadMediaSelectionGroup(for: .legible)
        guard generation == mine else { throw CancellationError() }
        let sounds = audioGroup?.options ?? []
        // Text subtitles, forced ones included and marked; closed captions
        // inside the video are not offered
        // (playback-engine/forced-subtitles-in-your-language-show).
        let texts = (subtitleGroup?.options ?? []).filter { option in
            option.mediaType == .subtitle || option.mediaType == .text
        }
        var audio: [(track: MediaTrack, option: AVMediaSelectionOption)] = []
        for (number, option) in zip(sounds.indices, sounds) {
            audio.append((await Self.track("audio-\(number)", .audio, option, group: audioGroup), option))
        }
        var subtitles: [(track: MediaTrack, option: AVMediaSelectionOption)] = []
        for (number, option) in zip(texts.indices, texts) {
            subtitles.append((await Self.track("subtitle-\(number)", .subtitle, option, group: subtitleGroup), option))
        }
        guard generation == mine else { throw CancellationError() }
        var selection = MediaSelection(
            audioGroup: audioGroup, subtitleGroup: subtitleGroup, audio: audio, subtitles: subtitles, selectedAudio: nil,
            selectedSubtitle: nil)
        let chosen = TrackChoice.initial(audio: selection.audio.map(\.track), subtitles: selection.subtitles.map(\.track), options: options)
        if let audioGroup, let pick = selection.audio.first(where: { $0.track.id == chosen.audio }) {
            item.select(pick.option, in: audioGroup)
            selection.selectedAudio = pick.track.id
        }
        if let subtitleGroup {
            let pick = selection.subtitles.first { $0.track.id == chosen.subtitle }
            item.select(pick?.option, in: subtitleGroup)
            selection.selectedSubtitle = pick?.track.id
        }
        self.selection = selection
        tracksCast.sendIfChanged(selection.trackList)
    }

    private static func track(
        _ id: String, _ kind: MediaTrack.Kind, _ option: AVMediaSelectionOption, group: AVMediaSelectionGroup?
    ) async -> MediaTrack {
        // The provider's own name: the title in the file, or HLS's NAME.
        let item = AVMetadataItem.metadataItems(from: option.commonMetadata, filteredByIdentifier: .commonIdentifierTitle).first
        let title = try? await item?.load(.stringValue)
        return MediaTrack(
            id: id, kind: kind, languageCode: option.extendedLanguageTag ?? option.locale?.identifier, name: title,
            isDefault: group?.defaultOption == option, isForced: option.hasMediaCharacteristic(.containsOnlyForcedSubtitles))
    }

    /// Takes the item's subtitle lines as text and keeps Apple's player
    /// from drawing them.
    func addLegibleOutput(to item: AVPlayerItem) {
        let output = AVPlayerItemLegibleOutput(mediaSubtypesForNativeRepresentation: [])
        output.suppressesPlayerRendering = true
        let relay = LegibleRelay { [weak self] lines in
            guard let self, self.selection?.selectedSubtitle != nil else { return }
            self.cuesCast.sendIfChanged(lines.map { SubtitleCue(text: $0) })
        }
        output.setDelegate(relay, queue: .main)
        item.add(output)
        legibleRelay = relay
    }

    // MARK: Picture and sound format

    /// Reports the format again when the picture changes size or the tracks change.
    func observePresentation(of item: AVPlayerItem) {
        let changed: @Sendable (AVPlayerItem, Any) -> Void = { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.state == .playing || self.state == .buffering || self.state == .paused else { return }
                await self.publishPresentation()
            }
        }
        presentationObservations = [
            item.observe(\.presentationSize) { item, change in changed(item, change) },
            item.observe(\.tracks) { item, change in changed(item, change) },
        ]
    }

    /// Sends the picture and sound format of the item that plays and, on
    /// Apple TV, matches the TV to it
    /// (playback-engine/the-screen-learns-the-picture-and-sound-format).
    func publishPresentation() async {
        guard let item = player.currentItem else { return }
        let mine = generation
        var video: PresentationInfo.Video?
        var audio: PresentationInfo.Audio?
        var videoFormat: CMFormatDescription?
        for track in item.tracks where track.isEnabled {
            guard let asset = track.assetTrack else { continue }
            let format = try? await asset.load(.formatDescriptions).first
            guard generation == mine else { return }
            if asset.mediaType == .video, video == nil {
                let size = item.presentationSize
                let nominal = (try? await asset.load(.nominalFrameRate)) ?? 0
                guard generation == mine else { return }
                let rate = track.currentVideoFrameRate > 0 ? Double(track.currentVideoFrameRate) : Double(nominal)
                let code = format.map { CMFormatDescriptionGetMediaSubType($0) }
                video = PresentationInfo.Video(
                    width: Int(size.width), height: Int(size.height), frameRate: rate > 0 ? rate : nil,
                    dynamicRange: Self.dynamicRange(format), codec: code.map(Self.videoCodec) ?? "video")
                videoFormat = format
            } else if asset.mediaType == .audio, audio == nil {
                let channels = format.flatMap(CMAudioFormatDescriptionGetStreamBasicDescription).map { Int($0.pointee.mChannelsPerFrame) }
                let playable = (try? await asset.load(.isPlayable)) ?? true
                guard generation == mine else { return }
                audio = PresentationInfo.Audio(
                    codec: format.map { CodecName.name(CMFormatDescriptionGetMediaSubType($0)) } ?? "audio", channels: channels ?? 0,
                    isDecodable: playable)
            }
        }
        // HLS can report a picture size before its tracks.
        if video == nil, item.presentationSize.width > 0 {
            let size = item.presentationSize
            video = PresentationInfo.Video(
                width: Int(size.width), height: Int(size.height), frameRate: nil, dynamicRange: .sdr, codec: "video")
        }
        guard video != nil || audio != nil else { return }
        presentationCast.sendIfChanged(PresentationInfo(video: video, audio: audio))
        #if os(tvOS)
            if let video, let mode = DisplayMode(video) {
                let assetCriteria = try? await item.asset.load(.preferredDisplayCriteria)
                guard generation == mine else { return }
                display.match(mode) {
                    videoFormat.map { AVDisplayCriteria(refreshRate: Float(mode.frameRate), formatDescription: $0) } ?? assetCriteria
                }
            }
        #endif
    }

    private static func videoCodec(_ code: FourCharCode) -> String {
        let name = CodecName.name(code)
        return name == "dolby vision" ? "hevc" : name
    }

    private static func dynamicRange(_ format: CMFormatDescription?) -> PresentationInfo.DynamicRange {
        guard let format else { return .sdr }
        if CodecName.name(CMFormatDescriptionGetMediaSubType(format)) == "dolby vision" { return .dolbyVision }
        let transfer = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_TransferFunction) as? String
        if transfer == kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ as String { return .hdr10 }
        if transfer == kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG as String { return .hlg }
        return .sdr
    }

    // MARK: The last picture

    /// Puts the picture on screen into `hold` before the item goes, so the
    /// screen is not black while the next one opens
    /// (playback-engine/starting-a-channel-replaces-the-old-one-cleanly).
    func holdPicture() {
        guard let item = player.currentItem, let videoOutput, item.status == .readyToPlay else { return }
        hold.hold(videoOutput.copyPixelBuffer(forItemTime: item.currentTime(), itemTimeForDisplay: nil))
    }
}
