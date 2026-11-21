#!/usr/bin/env bash
# Writes the playback test streams into the AntennaTestSupport fixtures folder.
# Every stream is a synthetic test pattern and sine tone made by ffmpeg, so no
# third-party content is ever committed. Set FFMPEG to use another binary.
# Re-run it to replace the files; the output is small enough to commit.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

ffmpeg_bin="${FFMPEG:-ffmpeg}"
out=Packages/AntennaCore/Sources/AntennaTestSupport/Fixtures
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

ff() { "$ffmpeg_bin" -hide_banner -loglevel error -y "$@"; }

video() { printf 'testsrc2=size=%s:rate=%s:duration=%s' "$1" "$2" "$3"; }
tone() { printf 'sine=frequency=%s:sample_rate=48000:duration=%s' "$1" "$2"; }

rm -rf "$out"
mkdir -p "$out/hls"

cat >"$work/en.srt" <<'SRT'
1
00:00:00,500 --> 00:00:02,500
English line one

2
00:00:03,000 --> 00:00:05,500
English line two
SRT

cat >"$work/sv.srt" <<'SRT'
1
00:00:00,500 --> 00:00:02,500
Svensk rad ett

2
00:00:03,000 --> 00:00:05,500
Svensk rad två
SRT

# A 6 second film: H.264 video, English (default) and German sound, English
# and Swedish text subtitles. The second sound track carries a provider title.
ff -f lavfi -i "$(video 320x180 25 6)" -f lavfi -i "$(tone 440 6)" -f lavfi -i "$(tone 660 6)" \
    -i "$work/en.srt" -i "$work/sv.srt" \
    -map 0:v -map 1:a -map 2:a -map 3:s -map 4:s \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 -c:s mov_text \
    -metadata:s:a:0 language=eng -metadata:s:a:1 language=ger -metadata:s:a:1 "title=Sport HD Kommentar" \
    -metadata:s:s:0 language=eng -metadata:s:s:1 language=swe \
    -disposition:a:0 default -disposition:a:1 0 -disposition:s:0 0 -disposition:s:1 0 \
    -movflags +faststart "$out/film.mp4"

# The same film in Matroska for the FFmpeg path, with SubRip subtitles.
ff -f lavfi -i "$(video 320x180 25 6)" -f lavfi -i "$(tone 440 6)" -f lavfi -i "$(tone 660 6)" \
    -i "$work/en.srt" -i "$work/sv.srt" \
    -map 0:v -map 1:a -map 2:a -map 3:s -map 4:s \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 -c:s srt \
    -metadata:s:a:0 language=eng -metadata:s:a:1 language=ger -metadata:s:a:1 "title=Sport HD Kommentar" \
    -metadata:s:s:0 language=eng -metadata:s:s:1 language=swe \
    -disposition:a:0 default -disposition:a:1 0 -disposition:s:0 0 -disposition:s:1 0 "$out/film.mkv"

# The same tracks over HLS: a picture, English (default) and German sound
# renditions and English and Swedish WebVTT subtitles. ffmpeg writes one
# subtitle language per variant, so the renditions are made one by one and
# the multivariant playlist is written here. Segments start at 1.4 seconds
# (MPEG-TS 126000), which the subtitles' timestamp map points at.
tracks="$out/hls-tracks"
mkdir -p "$tracks"
hls_vod() { ff "$@" -f hls -hls_time 2 -hls_playlist_type vod; }
hls_vod -f lavfi -i "$(video 320x180 25 6)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -hls_segment_filename "$tracks/video%d.ts" "$tracks/video.m3u8"
hls_vod -f lavfi -i "$(tone 440 6)" -c:a aac -b:a 48k -ac 2 -hls_segment_filename "$tracks/audio-en%d.ts" "$tracks/audio-en.m3u8"
hls_vod -f lavfi -i "$(tone 660 6)" -c:a aac -b:a 48k -ac 2 -hls_segment_filename "$tracks/audio-de%d.ts" "$tracks/audio-de.m3u8"
for lang in en sv; do
    {
        printf 'WEBVTT\nX-TIMESTAMP-MAP=MPEGTS:126000,LOCAL:00:00:00.000\n\n'
        sed -e 's/\([0-9]\),\([0-9]\)/\1.\2/g' -e '/^[0-9][0-9]*$/d' "$work/$lang.srt"
    } >"$tracks/subs-$lang.vtt"
    printf '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:6\n#EXT-X-PLAYLIST-TYPE:VOD\n#EXTINF:6.0,\nsubs-%s.vtt\n#EXT-X-ENDLIST\n' \
        "$lang" >"$tracks/subs-$lang.m3u8"
done
cat >"$tracks/index.m3u8" <<'M3U8'
#EXTM3U
#EXT-X-VERSION:4
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",LANGUAGE="en",NAME="English",DEFAULT=YES,AUTOSELECT=YES,URI="audio-en.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",LANGUAGE="de",NAME="Sport HD Kommentar",DEFAULT=NO,AUTOSELECT=YES,URI="audio-de.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",LANGUAGE="en",NAME="English",DEFAULT=NO,AUTOSELECT=YES,URI="subs-en.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",LANGUAGE="sv",NAME="Svenska",DEFAULT=NO,AUTOSELECT=YES,URI="subs-sv.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=250000,CODECS="avc1.4d400c,mp4a.40.2",RESOLUTION=320x180,AUDIO="aud",SUBTITLES="subs"
video.m3u8
M3U8

# A channel whose picture grows from 320x180 to 640x360 after 2 seconds.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 -f mpegts "$work/small.ts"
ff -f lavfi -i "$(video 640x360 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 300k \
    -c:a aac -b:a 48k -ac 2 -output_ts_offset 2 -f mpegts "$work/large.ts"
cat "$work/small.ts" "$work/large.ts" >"$out/resize.ts"

# HLS with 2 second segments, ending with an end tag (a film over HLS).
ff -f lavfi -i "$(video 320x180 25 6)" -f lavfi -i "$(tone 440 6)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 \
    -f hls -hls_time 2 -hls_playlist_type vod -hls_segment_filename "$out/hls/segment%d.ts" "$out/hls/index.m3u8"

# Raw broadcast stream (MPEG-TS) with a keyframe every second.
ff -f lavfi -i "$(video 320x180 25 6)" -f lavfi -i "$(tone 440 6)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 -f mpegts "$out/channel.ts"

# DVB picture subtitles in raw MPEG-TS: German sound, and German and English
# subtitle streams. ffmpeg cannot draw text into pictures, so
# make-pgs-subtitles.py writes picture subtitles (a white bar with a dark
# band) and ffmpeg turns them into DVB subtitles. German shows from 0.5 to 2
# seconds, English from 0.5 to 2 and from 3 to 4.5.
python3 -I scripts/make-pgs-subtitles.py "$work/de.sup" 720x576 0.5-2
python3 -I scripts/make-pgs-subtitles.py "$work/en.sup" 720x576 0.5-2,3-4.5
ff -f lavfi -i "$(video 320x180 25 6)" -f lavfi -i "$(tone 440 6)" \
    -fix_sub_duration -i "$work/de.sup" -fix_sub_duration -i "$work/en.sup" \
    -map 0:v -map 1:a -map 2:s -map 3:s \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 -c:s dvbsub \
    -metadata:s:a:0 language=ger -metadata:s:s:0 language=ger -metadata:s:s:1 language=eng \
    -max_interleave_delta 0 -f mpegts "$out/dvb-subtitles.ts"

# The same channel with six video packets lost in the middle of a GOP, as a
# stream that lost data on the way arrives: FFmpeg marks the picture corrupt.
python3 -I scripts/drop-ts-packets.py "$out/channel.ts" "$out/damaged.ts" 400 6
# An off-air channel: the program lists H.264 video but only its sound
# arrives, 4 seconds of it.
ff -f lavfi -i "$(video 320x180 25 4)" -f lavfi -i "$(tone 440 4)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 -f mpegts "$work/with-picture.ts"
python3 -I scripts/drop-ts-packets.py "$work/with-picture.ts" "$out/no-picture.ts" 0 1000000

# Live channels whose timestamps jump, as at an ad break, a feed switch or
# an encoder restart. splice-ts.py joins two parts the way a splicer does,
# with continuity counters that carry on, so only the timestamps change.
# jump-forward: 2 seconds at 1.4 s, then 2 seconds at 61.4 s.
# jump-back: 2 seconds at 31.4 s, then 2 seconds at 1.4 s.
# pts-wrap: 5 seconds starting 2.3 s before the 33-bit PTS wraps.
part() { # name, offset, extra arguments
    local name=$1 offset=$2
    shift 2
    ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" "$@" \
        -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
        -c:a aac -b:a 48k -ac 2 -output_ts_offset "$offset" -f mpegts "$work/$name.ts"
}
part early 0
part late 60
part back 30
python3 -I scripts/splice-ts.py "$out/jump-forward.ts" "$work/early.ts" "$work/late.ts"
python3 -I scripts/splice-ts.py "$out/jump-back.ts" "$work/back.ts" "$work/early.ts"
ff -f lavfi -i "$(video 320x180 25 5)" -f lavfi -i "$(tone 440 5)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 -output_ts_offset 95440 -f mpegts "$out/pts-wrap.ts"

# Live channels whose sound PID changes. late-audio: 2 seconds of picture
# only, then picture and sound on a PID the first PMT did not list.
# audio-pid-change: the sound moves from PID 0x101 to 0x102 after 2 seconds.
ff -f lavfi -i "$(video 320x180 25 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k -f mpegts "$work/mute.ts"
part sound-moved 2 -streamid 1:0x102
part sound-follows 2
python3 -I scripts/splice-ts.py "$out/late-audio.ts" "$work/mute.ts" "$work/sound-follows.ts"
python3 -I scripts/splice-ts.py "$out/audio-pid-change.ts" "$work/early.ts" "$work/sound-moved.ts"

# A channel whose first sound is audio description (ISO 639 audio type 3)
# and whose second is the main English sound. MPEG-TS has no default mark.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" -f lavfi -i "$(tone 660 2)" \
    -map 0:v -map 1:a -map 2:a \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 -metadata:s:a:0 language=eng -metadata:s:a:1 language=eng \
    -disposition:a:0 visual_impaired -disposition:a:1 0 -f mpegts "$out/audio-description.ts"

# The same picture in Matroska and AVI.
ff -i "$out/channel.ts" -c copy "$out/channel.mkv"
# The same Matroska film with no index (Cues), as a muxer writing to a pipe
# leaves it; a skip has to read forward to its keyframe.
"$ffmpeg_bin" -hide_banner -loglevel error -i "$out/channel.mkv" -c copy -f matroska - >"$out/film-no-index.mkv"
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v mpeg4 -q:v 10 -c:a libmp3lame -b:a 48k "$out/channel.avi"

# An old SD channel in MPEG-2 video.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v mpeg2video -b:v 300k -c:a mp2 -b:a 64k -f mpegts "$out/mpeg2.ts"

# HDR10 (PQ) and HLG pictures in HEVC, 10-bit, 2 seconds each.
for kind in hdr10 hlg; do
    transfer=smpte2084
    [[ "$kind" == hlg ]] && transfer=arib-std-b67
    ff -f lavfi -i "$(video 320x180 25 2)" \
        -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le -tag:v hvc1 \
        -x265-params "log-level=error:colorprim=bt2020:transfer=$transfer:colormatrix=bt2020nc" \
        -color_primaries bt2020 -color_trc "$transfer" -colorspace bt2020nc \
        -movflags +faststart "$out/$kind.mp4"
    # The same picture as a raw broadcast stream, where HEVC arrives in Annex B.
    ff -i "$out/$kind.mp4" -c copy -f mpegts "$out/$kind.ts"
done

# HEVC in MP4 tagged hev1, ffmpeg's default, which Apple's player opens but
# cannot decode.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx265 -preset ultrafast -tag:v hev1 -x265-params "log-level=error:bframes=0" -b:v 100k \
    -c:a aac -b:a 48k -ac 2 -movflags +faststart "$out/hev1.mp4"

# Surround sound: 5.1 Dolby Digital and Dolby Digital Plus under the same picture.
# ffmpeg cannot encode Atmos; that is checked on a receiver.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a ac3 -b:a 384k -ac 6 -f mpegts "$out/surround-ac3.ts"
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a eac3 -b:a 384k -ac 6 -f mpegts "$out/surround-eac3.ts"

# Sound that changes format partway, as a channel does between programmes:
# AAC and AC-3 from stereo to 5.1, MP2 from stereo to mono. Two 2 second
# streams on the same PIDs, the second timed after the first.
for codec in aac ac3 mp2; do
    case "$codec" in
    mp2) first=(-ac 2 -b:a 128k) second=(-ac 1 -b:a 64k) ;;
    *) first=(-ac 2 -b:a 128k) second=(-ac 6 -b:a 384k) ;;
    esac
    ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
        -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
        -c:a "$codec" "${first[@]}" -f mpegts "$work/before.ts"
    ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
        -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
        -c:a "$codec" "${second[@]}" -output_ts_offset 2 -f mpegts "$work/after.ts"
    cat "$work/before.ts" "$work/after.ts" >"$out/sound-change-$codec.ts"
done

# HE-AAC in a raw broadcast stream, a 15 kHz tone that only the SBR layer
# carries. Needs ffmpeg's AudioToolbox encoder, so it is made on a Mac.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "sine=frequency=15000:sample_rate=48000:duration=2" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac_at -profile:a 4 -b:a 48k -ac 2 -f mpegts "$out/he-aac.ts"

# A film with 7.1 AAC, written with channel configuration 12.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 256k -ac 8 "$out/aac-7.1.mkv"

# A film whose default sound is DTS, which FFmpeg decodes on the device, with
# a second Dolby Digital track in another language.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" -f lavfi -i "$(tone 660 2)" \
    -map 0:v -map 1:a -map 2:a \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a:0 dca -strict -2 -ac:a:0 2 -b:a:0 320k -c:a:1 ac3 -b:a:1 128k -ac:a:1 2 \
    -metadata:s:a:0 language=eng -metadata:s:a:1 language=ger \
    -disposition:a:0 default -disposition:a:1 0 "$out/dts-and-ac3.mkv"

# The same choice with a default no device decodes: Windows Media Audio,
# then Dolby Digital in another language. A picture with only Windows
# Media Audio sound. And a picture with Vorbis sound.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" -f lavfi -i "$(tone 660 2)" \
    -map 0:v -map 1:a -map 2:a \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a:0 wmav2 -b:a:0 64k -ac:a:0 2 -c:a:1 ac3 -b:a:1 128k -ac:a:1 2 \
    -metadata:s:a:0 language=eng -metadata:s:a:1 language=ger \
    -disposition:a:0 default -disposition:a:1 0 "$out/wma-and-ac3.mkv"
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a wmav2 -b:a 64k -ac 2 "$out/undecodable-sound.mkv"
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a vorbis -strict -2 -ac 2 "$out/vorbis.mkv"

# AV1 and VP9 films, which decode only where the device has the hardware:
# VP9 in WebM and MP4, AV1 in Matroska and MP4.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libvpx-vp9 -b:v 150k -deadline realtime -cpu-used 8 -g 25 -c:a libopus -b:a 48k "$out/vp9.webm"
ff -i "$out/vp9.webm" -c copy -movflags +faststart "$out/vp9.mp4"
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libsvtav1 -preset 12 -b:v 150k -g 25 -svtav1-params "verbosity=0" -c:a aac -b:a 48k -ac 2 "$out/av1.mkv"
ff -i "$out/av1.mkv" -c copy -movflags +faststart "$out/av1.mp4"

# Sound only, 2 seconds of tone each, in the formats films and channels
# carry beyond AAC and Dolby: 5.1 DTS in Blu-ray MPEG-TS (m2ts mode writes
# the HDMV registration FFmpeg needs to read DTS), 5.1 TrueHD in Matroska,
# 5.1 Opus in Matroska and stereo Opus in MPEG-TS, 24-bit 5.1 FLAC in
# Matroska and stereo FLAC in MP4, and half a second of SMPTE 302M PCM in
# MPEG-TS.
ff -f lavfi -i "$(tone 440 2)" -c:a dca -strict -2 -ac 6 -b:a 768k -mpegts_m2ts_mode 1 -f mpegts "$out/dts-5.1.m2ts"
ff -f lavfi -i "$(tone 440 2)" -c:a truehd -strict -2 -ac 6 "$out/truehd-5.1.mkv"
ff -f lavfi -i "$(tone 440 2)" -c:a libopus -b:a 192k -ac 6 "$out/opus-5.1.mkv"
ff -f lavfi -i "$(tone 440 2)" -c:a libopus -b:a 48k -ac 2 -f mpegts "$out/opus.ts"
ff -f lavfi -i "$(tone 440 2)" -c:a flac -sample_fmt s32 -bits_per_raw_sample 24 -ac 6 "$out/flac-5.1.mkv"
ff -f lavfi -i "$(tone 440 2)" -c:a flac -ac 2 -movflags +faststart "$out/flac.mp4"
ff -f lavfi -i "$(tone 440 0.5)" -c:a s302m -strict -2 -ac 2 -f mpegts "$out/s302m.ts"

# Half a second of uncompressed PCM, one track per sample format:
# little-endian in Matroska, big-endian and one little-endian in QuickTime.
ff -f lavfi -i "$(tone 440 0.5)" -ac 2 -map 0:a -map 0:a -map 0:a -map 0:a \
    -c:a:0 pcm_s16le -c:a:1 pcm_s24le -c:a:2 pcm_s32le -c:a:3 pcm_f32le "$out/pcm.mkv"
ff -f lavfi -i "$(tone 440 0.5)" -ac 2 -map 0:a -map 0:a -map 0:a -map 0:a -map 0:a \
    -c:a:0 pcm_s16be -c:a:1 pcm_s24be -c:a:2 pcm_s32be -c:a:3 pcm_f32be -c:a:4 pcm_s16le \
    -movflags +faststart "$out/pcm.mov"

# AAC whose four speakers are named in a program config element (channel
# configuration 0), in ADTS and in Matroska; HE-AAC v2 (parametric stereo)
# in ADTS, which needs ffmpeg's AudioToolbox encoder; and AAC in LATM
# framing, as some DVB channels send it.
ff -f lavfi -i "$(tone 440 2)" -af aformat=channel_layouts=quad -c:a aac -b:a 128k -f mpegts "$out/aac-pce.ts"
ff -f lavfi -i "$(tone 440 2)" -af aformat=channel_layouts=quad -c:a aac -b:a 128k "$out/aac-pce.mkv"
ff -f lavfi -i "$(tone 440 2)" -c:a aac_at -profile:a 28 -b:a 32k -ac 2 -f mpegts "$out/he-aac-v2.ts"
ff -f lavfi -i "$(tone 440 2)" -c:a aac -b:a 96k -ac 2 -mpegts_flags latm -f mpegts "$out/latm.ts"

# Interlaced broadcasts, top field first: 1080i H.264 and 576i MPEG-2. The
# pattern moves at 50 frames a second, so each field shows a different moment.
ff -f lavfi -i "$(video 1920x1080 50 1)" -f lavfi -i "$(tone 440 1)" \
    -vf "interlace=scan=tff,setfield=tff" \
    -c:v libx264 -preset veryfast -profile:v high -pix_fmt yuv420p -flags +ildct+ilme -x264opts tff=1 -g 25 -b:v 1M \
    -c:a aac -b:a 48k -ac 2 -f mpegts "$out/interlaced-1080i.ts"
ff -f lavfi -i "$(video 720x576 50 1)" -f lavfi -i "$(tone 440 1)" \
    -vf "interlace=scan=tff,setfield=tff" \
    -c:v mpeg2video -flags +ildct+ilme -b:v 1M -g 12 -c:a mp2 -b:a 128k -f mpegts "$out/interlaced-576i.ts"

# Widescreen SD as DVB sends it: 720x576 pictures marked 16:9 (pixels 64:45
# wide) and no color tags, progressive in MPEG-2 and interlaced in H.264.
ff -f lavfi -i "$(video 720x576 25 1)" -f lavfi -i "$(tone 440 1)" \
    -aspect 16:9 -c:v mpeg2video -b:v 400k -g 12 -c:a mp2 -b:a 64k -f mpegts "$out/anamorphic-576.ts"
ff -f lavfi -i "$(video 720x576 50 1)" -f lavfi -i "$(tone 440 1)" \
    -vf "interlace=scan=tff,setfield=tff" -aspect 16:9 \
    -c:v libx264 -preset veryfast -profile:v high -pix_fmt yuv420p -flags +ildct+ilme -x264opts tff=1 -g 25 -b:v 400k \
    -c:a aac -b:a 48k -ac 2 -f mpegts "$out/anamorphic-576i.ts"

# Films encoded with open GOPs, as UHD films are: HEVC whose keyframes after
# the first are CRAs led by RASL pictures, and H.264 whose keyframes after the
# first are led by B-frames. 3 seconds, a keyframe every 0.96 seconds.
ff -f lavfi -i "$(video 320x180 25 3)" \
    -c:v libx265 -preset fast -tag:v hvc1 \
    -x265-params "log-level=error:open-gop=1:b-adapt=0:bframes=3:keyint=24:min-keyint=24" "$out/open-gop-hevc.mkv"
ff -f lavfi -i "$(video 320x180 25 3)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -bf 2 -b:v 150k \
    -x264-params "open-gop=1:keyint=24:min-keyint=24:scenecut=0" "$out/open-gop-h264.mkv"

# A second HEVC picture at another size, which the Dolby Vision tests put
# into the hdr10 stream as an enhancement layer: ffmpeg cannot encode Dolby
# Vision.
ff -f lavfi -i "$(video 640x360 25 2)" \
    -c:v libx265 -preset ultrafast -x265-params "log-level=error:bframes=0" -b:v 100k -f mpegts "$out/hevc-640x360.ts"

# Radio: sound with no picture.
ff -f lavfi -i "$(tone 440 6)" -c:a aac -b:a 48k -f adts "$out/radio.aac"
ff -f lavfi -i "$(tone 440 6)" -c:a libmp3lame -b:a 48k "$out/radio.mp3"

# Things that are not video: a web page and bytes that mean nothing.
printf '<!doctype html>\n<html><head><title>Login</title></head><body><p>Please log in.</p></body></html>\n' >"$out/page.html"
LC_ALL=C awk 'BEGIN { srand(7); for (i = 0; i < 4096; i++) printf "%c", 1 + int(rand() * 250) }' >"$out/garbage.bin"

ls -l "$out" "$out/hls"
