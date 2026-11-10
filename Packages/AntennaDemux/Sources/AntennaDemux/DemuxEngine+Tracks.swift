import AntennaCore
import CoreMedia
import Foundation

extension DemuxEngine {
    // MARK: Sound and subtitles

    /// Plays the sound track `id` from `tracks()` within a moment
    /// (playback-engine/audio-and-subtitle-languages). A reconnect or skip
    /// keeps the pick.
    public func selectAudio(_ id: MediaTrack.ID) async {
        guard var start = current?.start, start.selectedAudio != id, let track = start.audioTracks.first(where: { $0.track.id == id })
        else { return }
        start.selectedAudio = id
        start.audio = track.stream
        current?.start = start
        current?.run.selectAudio(stream: track.stream.index, from: synchronizer.currentTime())
        keepPick(start)
        tracksCast.sendIfChanged(start.trackList)
    }

    /// Shows the subtitle track `id` from `tracks()`, or none with nil.
    public func selectSubtitle(_ id: MediaTrack.ID?) async {
        guard var start = current?.start, start.selectedSubtitle != id else { return }
        if let id, !start.subtitleTracks.contains(where: { $0.track.id == id }) { return }
        start.selectedSubtitle = id
        current?.start = start
        keepPick(start)
        tracksCast.sendIfChanged(start.trackList)
        publishCues(at: synchronizer.currentTime())
    }

    /// Opens the stream again with the languages picked now, as after a
    /// reconnect or a skip.
    private func keepPick(_ start: DemuxStart) {
        request?.options.remembered = LanguagePick(start.trackList)
    }

    func soundSwitched(_ sound: PresentationInfo.Audio, generation mine: Int) {
        guard generation == mine, var start = current?.start else { return }
        start.soundChannels = sound.channels
        start.soundDecodable = sound.isDecodable
        current?.start = start
        guard !isScanning else { return }
        presentationCast.sendIfChanged(start.presentation)
    }

    func cueFound(_ cue: TimedCue, generation mine: Int) {
        guard generation == mine, current != nil else { return }
        current?.cues.append(cue)
    }

    /// Sends the lines of the selected subtitles due at `time`, and forgets
    /// lines that are over.
    func publishCues(at time: CMTime) {
        guard var current, let start = current.start else { return }
        current.cues.removeAll { $0.end < time }
        self.current = current
        let selected = start.subtitleTracks.first { $0.track.id == start.selectedSubtitle }?.stream.index
        let due = current.cues.filter { $0.streamIndex == selected && $0.start <= time }
        cuesCast.sendIfChanged(due.map { SubtitleCue(text: $0.text) })
    }

    /// Hears what `run` finds after its start: subtitle lines, picture
    /// changes, sound switches and a skip that could not be made.
    func listen(to run: DemuxRun, url: URL, generation mine: Int) {
        let log = self.log
        run.seekFailed = { log("demux seek \(redacted(url)) failed, starting from the beginning") }
        run.cueFound = { [weak self] cue in
            Task { @MainActor in self?.cueFound(cue, generation: mine) }
        }
        run.pictureChanged = { [weak self] change in
            Task { @MainActor in self?.pictureChanged(change, generation: mine) }
        }
        run.soundSwitched = { [weak self] sound in
            Task { @MainActor in self?.soundSwitched(sound, generation: mine) }
        }
    }

    // MARK: Picture changes

    func pictureChanged(_ change: PictureChange, generation mine: Int) {
        guard generation == mine, current != nil else { return }
        current?.pictureChanges.append(change)
    }

    /// Reports the picture changes the clock has reached and matches the TV to them.
    func applyPictureChanges(at time: CMTime) {
        guard var current, var start = current.start, current.pictureChanges.first.map({ $0.time <= time }) == true else { return }
        while let change = current.pictureChanges.first, change.time <= time {
            current.pictureChanges.removeFirst()
            start.pictureSize = change.size
            start.dynamicRange = change.dynamicRange
            start.videoFormat = change.format
        }
        current.start = start
        self.current = current
        guard !isScanning else { return }
        publishFormat(start)
        matchDisplay(start)
    }
}
