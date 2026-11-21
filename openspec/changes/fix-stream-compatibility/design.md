# Design

## Context

The findings come from the red-route stream review of 2026-11-21: items 1, 3, 4, 5, 9 and 10 of the playback review and item 4 of the compatibility review. Each one is reproduced here with an ffmpeg-made stream before it is fixed, and each fix gets a test on that stream. No provider stream is used. The new fixtures come from `scripts/make-stream-fixtures.sh` and are committed like the others.

No screen changes, so no board applies.

## Decisions

### Picture shape and colors on the FFmpeg path

Pictures reach the video renderer three ways. Progressive H.264 and HEVC go compressed, and VideoToolbox inside the renderer reads the shape and colors from the stream; that path was already right. MPEG-2 is decoded by FFmpeg in `SoftwareDecoder`, and interlaced pictures come out of `Deinterlacer`; both make new `CVPixelBuffer`s and set no attachments, so the renderer showed them at their stored size in its default colors.

- `SoftwareDecoder.picture` sets `kCVImageBufferPixelAspectRatioKey` from the frame's `sample_aspect_ratio`, and the YCbCr matrix, primaries and transfer function from `colorspace`, `color_primaries` and `color_trc`, through CoreVideo's code point functions (FFmpeg uses the same ISO/IEC 23091-2 numbers).
- `Deinterlacer.render` copies the source picture's attachments with `CVBufferPropagateAttachments`, then sets the field count to 1 and removes the field detail, since the output is progressive.
- A picture with no matrix after that is tagged by size: up to 576 lines gets BT.601 (primaries EBU 3213 at 576 lines, SMPTE C below) and anything larger BT.709. That is what broadcast SD uses when it says nothing, and what VLC and FFmpeg's own players assume.
- Attachments are set before the format description is made from the buffer, so the description carries them as extensions too.
- VideoToolbox tags the pictures of a stream that names no colors BT.709 whatever their size. `VideoDecoder`, which decodes interlaced H.264 for the deinterlacer, removes those tags when the stream's format names no YCbCr matrix, so the size rule above applies. A Matroska film's H.264 format comes from its avcC with no color extensions, so an interlaced SD film there that names BT.709 is shown in BT.601; that is rare enough to leave.
- Progressive H.264 and HEVC that name no colors still reach the renderer compressed, and the renderer picks their colors. Tagging their format descriptions is left out: whether the renderer prefers the description or the stream's own VUI was not tested.

Options considered: scaling the picture to its display shape on the GPU (rejected; it costs a copy per frame and the renderer already honors the pixel aspect), and setting only the format description's extensions (rejected; the renderer reads the image buffer's attachments).

### Apple's player hands over a file it cannot decode

Once an item is ready, `AVPlayerEngine.open` loads the asset's video and audio tracks with `isDecodable`. When the address is not HLS and the first video track cannot be decoded, or there is sound and no audio track can be, it throws `EngineHandoff.toDemuxer`. `RoutedEngine` already loads the address on the FFmpeg path for that.

HLS never hands over: the FFmpeg build has no HLS reader, and an HLS rendition Apple's player cannot decode is a provider problem the FFmpeg path cannot fix.

### Radio goes to Apple's player

`StreamSniff` gains `.audio`: an ID3 tag at the start, or two MPEG audio or ADTS frame headers in a row within the first bytes, the second where the first one's length says. Two headers make a false match on other data unlikely, and a live radio stream that starts mid-frame still matches at its next frame. `DemuxRun.prepare` throws `EngineHandoff.toSystemPlayer` for `.audio`, and for `.other` when the response's Content-Type is `audio/*`. Apple's player then plays it with AirPlay.

Options considered: building FFmpeg's LGPL `mp3` and `aac` demuxers (rejected for now; the stream would lose AirPlay and use more power for no gain over Apple's player).

### Raw MPEG-TS at an HLS address

`AVPlayerEngine.open` threw `.unreadable` for it, on purpose. It now falls through to the existing `needsDemuxer` handoff. The spec's list of failure causes drops "raw video at an HLS address".

### A listed picture that never comes

`DemuxRun` holds sound until the first picture so the two start together. When the video stream has sent no packet at all and the sound held spans `DemuxRun.pictureWait` (2 s), the run drops the video builder and starts with sound only; the start reports no video and the engine hides the layer. A stream whose video sends packets but no keyframe yet keeps waiting, as before, because a channel with a long GOP would otherwise lose its picture. Video that starts later in a run started without it is not taken up; that needs the late stream work of `keep-live-playing-across-timestamp-jumps` for video and is left out.

### Retrying a refusal right after a switch

`RetryPolicy` gains `retriesOnce`, failures tried once more on top of `retries`, and `RetryPolicy.tune(afterSwitch:)`. With `afterSwitch` true, `retriesOnce` takes "not allowed", any other refusal except "not found", and "timed out", and the first wait is 1 s. Each engine notes when it last closed a stream that had started, and on which host. A load on the same host within `RetryPolicy.switchWindow` (3 s) uses the switch policy. A first start, or a start on another server, keeps the old policy, so a revoked password still fails at once there and after one retry at most during zapping.

Options considered: retrying every 403 (rejected; a revoked password would spin), and waiting before every connect after a switch (rejected; it slows every zap for the few accounts with one connection). A switch between the two paths is not counted, since each engine only knows its own streams; Xtream live goes through the FFmpeg path for both channels.

### The Mac display

`AVSampleBufferDisplayLayer.preventsDisplaySleepDuringVideoPlayback` defaults to false on macOS and true elsewhere. `DemuxEngine.set` sets it on macOS to whether the new state is playing or buffering, so a paused, ended, failed or stopped channel lets the display sleep. `AVPlayer` already keeps the display on while it plays.

## Not verified here

No device and no real provider. The 2 s wait for a picture, the 1 s retry after a switch and the 3 s window are guesses from the review, not measured against a panel. Whether Apple TV's renderer honors the pixel aspect on an HDMI output was not checked; the tests read the attachments the renderer gets.
