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

# Video with Opus sound, which no Apple decoder on the FFmpeg path takes.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a libopus -b:a 48k -ac 2 -f mpegts "$out/undecodable-sound.ts"

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

# Surround sound: 5.1 Dolby Digital and Dolby Digital Plus under the same picture.
# ffmpeg cannot encode Atmos; that is checked on a receiver.
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a ac3 -b:a 384k -ac 6 -f mpegts "$out/surround-ac3.ts"
ff -f lavfi -i "$(video 320x180 25 2)" -f lavfi -i "$(tone 440 2)" \
    -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p -g 25 -b:v 150k \
    -c:a eac3 -b:a 384k -ac 6 -f mpegts "$out/surround-eac3.ts"

# Interlaced broadcasts, top field first: 1080i H.264 and 576i MPEG-2. The
# pattern moves at 50 frames a second, so each field shows a different moment.
ff -f lavfi -i "$(video 1920x1080 50 1)" -f lavfi -i "$(tone 440 1)" \
    -vf "interlace=scan=tff,setfield=tff" \
    -c:v libx264 -preset veryfast -profile:v high -pix_fmt yuv420p -flags +ildct+ilme -x264opts tff=1 -g 25 -b:v 1M \
    -c:a aac -b:a 48k -ac 2 -f mpegts "$out/interlaced-1080i.ts"
ff -f lavfi -i "$(video 720x576 50 1)" -f lavfi -i "$(tone 440 1)" \
    -vf "interlace=scan=tff,setfield=tff" \
    -c:v mpeg2video -flags +ildct+ilme -b:v 1M -g 12 -c:a mp2 -b:a 128k -f mpegts "$out/interlaced-576i.ts"

# Radio: sound with no picture.
ff -f lavfi -i "$(tone 440 6)" -c:a aac -b:a 48k -f adts "$out/radio.aac"
ff -f lavfi -i "$(tone 440 6)" -c:a libmp3lame -b:a 48k "$out/radio.mp3"

# Things that are not video: a web page and bytes that mean nothing.
printf '<!doctype html>\n<html><head><title>Login</title></head><body><p>Please log in.</p></body></html>\n' >"$out/page.html"
LC_ALL=C awk 'BEGIN { srand(7); for (i = 0; i < 4096; i++) printf "%c", 1 + int(rand() * 250) }' >"$out/garbage.bin"

ls -l "$out" "$out/hls"
