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

# HLS with 2 second segments, ending with an end tag (a film over HLS).
ff -f lavfi -i "$(video 320x180 25 6)" -f lavfi -i "$(tone 440 6)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 \
    -f hls -hls_time 2 -hls_playlist_type vod -hls_segment_filename "$out/hls/segment%d.ts" "$out/hls/index.m3u8"

# Raw broadcast stream (MPEG-TS) with a keyframe every second.
ff -f lavfi -i "$(video 320x180 25 6)" -f lavfi -i "$(tone 440 6)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a aac -b:a 48k -ac 2 -f mpegts "$out/channel.ts"

# The same picture in Matroska and AVI.
ff -i "$out/channel.ts" -c copy "$out/channel.mkv"
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
done

# Radio: sound with no picture.
ff -f lavfi -i "$(tone 440 6)" -c:a aac -b:a 48k -f adts "$out/radio.aac"
ff -f lavfi -i "$(tone 440 6)" -c:a libmp3lame -b:a 48k "$out/radio.mp3"

# Things that are not video: a web page and bytes that mean nothing.
printf '<!doctype html>\n<html><head><title>Login</title></head><body><p>Please log in.</p></body></html>\n' >"$out/page.html"
LC_ALL=C awk 'BEGIN { srand(7); for (i = 0; i < 4096; i++) printf "%c", 1 + int(rand() * 250) }' >"$out/garbage.bin"

ls -l "$out" "$out/hls"
