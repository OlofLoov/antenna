#!/usr/bin/env bash
# Draws Apps/Shared/Debug/StorePicture.mp4, the clip the store screenshots
# show in the player: 12 seconds of a made-up evening landscape, a sun rising
# over two rows of hills that drift sideways, 1280x720 H.264 with no sound.
# Every pixel comes from the expressions below, so no third-party picture is
# ever committed. The Release build leaves the clip out (Config/Shared.xcconfig).
# Takes about two minutes. Set FFMPEG to use another binary.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

ffmpeg_bin="${FFMPEG:-ffmpeg}"
out=Apps/Shared/Debug/StorePicture.mp4

back='(470+30*sin((X+20*T)/170)+18*sin((X+20*T)/61+1))'
front='(560+26*sin((X+45*T)/130+2)+12*sin((X+45*T)/43))'
glow='hypot(X-(820+6*T),Y-(430-4*T))'
sun="lt($glow,70)"
sky='(Y/720)'
red="if(gt(Y,$front),14,if(gt(Y,$back),40,if($sun,255,min(255,20+235*$sky*$sky+60*exp(-$glow/180)))))"
green="if(gt(Y,$front),18,if(gt(Y,$back),44,if($sun,226,min(255,30+120*$sky*$sky+50*exp(-$glow/180)))))"
blue="if(gt(Y,$front),30,if(gt(Y,$back),70,if($sun,170,min(255,70+40*$sky-30*$sky*$sky+20*exp(-$glow/180)))))"

"$ffmpeg_bin" -hide_banner -loglevel error -y \
    -f lavfi -i "color=black:size=1280x720:rate=25:duration=12,format=gbrp,geq=r='$red':g='$green':b='$blue',format=yuv420p" \
    -c:v libx264 -preset veryslow -profile:v main -g 50 -crf 24 -an \
    -movflags +faststart -fflags +bitexact -map_metadata -1 "$out"
