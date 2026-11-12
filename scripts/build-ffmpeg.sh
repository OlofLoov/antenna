#!/usr/bin/env bash
# Builds FFmpeg.xcframework for the FFmpeg playback path (add-playback-engine,
# design.md "The FFmpeg path").
#
# LGPL 2.1 only: no --enable-gpl, no --enable-nonfree. FFmpeg demuxes; the
# only decoders are MPEG-2 video and MP2 sound, which no Apple device decodes
# in hardware, and DVB subtitles, whose pictures the app draws over the video
# (add-subtitle-preferences). No network protocols: the app feeds bytes through its own AVIO
# callback. The static libraries of each platform are linked into one dynamic
# FFmpeg.framework, so the app links FFmpeg dynamically as the LGPL asks.
#
# Usage: scripts/build-ffmpeg.sh [platform...]
#   platforms: macos ios ios-simulator tvos tvos-simulator (default: all)
#   macos alone builds with the Command Line Tools; the others need Xcode.
# Output: .build/ffmpeg/FFmpeg.xcframework when Xcode is present, and one
# FFmpeg.framework per platform under .build/ffmpeg/frameworks/.
set -euo pipefail

version=7.1.3
sha256=f0bf043299db9e3caacb435a712fc541fbb07df613c4b893e8b77e67baf3adbe
deployment=26.0

root=$(cd "$(dirname "$0")/.." && pwd)
work=${FFMPEG_WORK:-$root/.build/ffmpeg}
platforms=("$@")
if [ ${#platforms[@]} -eq 0 ]; then
    platforms=(macos ios ios-simulator tvos tvos-simulator)
fi

# sdk name and clang target triple per platform
sdk_of() {
    case $1 in
    macos) echo macosx ;;
    ios) echo iphoneos ;;
    ios-simulator) echo iphonesimulator ;;
    tvos) echo appletvos ;;
    tvos-simulator) echo appletvsimulator ;;
    *) echo "unknown platform $1" >&2 && exit 1 ;;
    esac
}

triple_of() {
    case $1 in
    macos) echo "arm64-apple-macos$deployment" ;;
    ios) echo "arm64-apple-ios$deployment" ;;
    ios-simulator) echo "arm64-apple-ios$deployment-simulator" ;;
    tvos) echo "arm64-apple-tvos$deployment" ;;
    tvos-simulator) echo "arm64-apple-tvos$deployment-simulator" ;;
    esac
}

fetch() {
    local tarball=$work/ffmpeg-$version.tar.xz
    mkdir -p "$work"
    if [ ! -f "$tarball" ]; then
        curl -fsSL "https://ffmpeg.org/releases/ffmpeg-$version.tar.xz" -o "$tarball.part"
        mv "$tarball.part" "$tarball"
    fi
    echo "$sha256  $tarball" | shasum -a 256 -c - >/dev/null
    if [ ! -d "$work/src" ]; then
        mkdir -p "$work/src"
        tar -xJf "$tarball" -C "$work/src" --strip-components 1
    fi
}

build() {
    local platform=$1 sdk triple sysroot cc prefix build_dir
    sdk=$(sdk_of "$platform")
    triple=$(triple_of "$platform")
    sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)
    cc=$(xcrun --sdk "$sdk" --find clang)
    prefix=$work/install/$platform
    build_dir=$work/build/$platform
    rm -rf "$build_dir" "$prefix"
    mkdir -p "$build_dir"
    (
        cd "$build_dir"
        "$work/src/configure" \
            --prefix="$prefix" \
            --enable-cross-compile --target-os=darwin --arch=aarch64 \
            --cc="$cc" --sysroot="$sysroot" \
            --extra-cflags="-target $triple" --extra-ldflags="-target $triple" \
            --disable-everything --disable-autodetect \
            --disable-programs --disable-doc --disable-debug --disable-network \
            --disable-avdevice --disable-avfilter --disable-swscale \
            --enable-static --disable-shared --enable-pic \
            --enable-avformat --enable-avcodec --enable-avutil --enable-swresample \
            --enable-demuxer=mpegts,matroska,avi,mov,flv \
            --enable-parser=h264,hevc,mpegvideo,aac,ac3,mpegaudio \
            --enable-decoder=mpeg2video,mp2,dvbsub \
            --enable-bsf=extract_extradata \
            >configure.log
        grep -q "License: LGPL version 2.1 or later" configure.log ||
            { echo "configure did not produce an LGPL 2.1 build" >&2 && exit 1; }
        make -j"$(sysctl -n hw.ncpu)" install >make.log 2>&1 ||
            { tail -40 make.log >&2 && exit 1; }
    )
    package "$platform" "$sysroot" "$triple" "$cc"
}

# Headers FFmpeg installs that need SDKs or libraries the app does not use.
unused_headers() {
    find "$1/libavutil" -name 'hwcontext_*.h' ! -name 'hwcontext.h'
    find "$1/libavcodec" \( -name 'd3d11va.h' -o -name 'dxva2.h' -o -name 'qsv.h' -o -name 'vdpau.h' \
        -o -name 'videotoolbox.h' -o -name 'mediacodec.h' -o -name 'jni.h' -o -name 'dirac.h' -o -name 'dv_profile.h' \
        -o -name 'vorbis_parser.h' -o -name 'xvmc.h' \)
}

package() {
    local platform=$1 sysroot=$2 triple=$3 cc=$4 prefix framework bundle
    prefix=$work/install/$platform
    framework=$work/frameworks/$platform/FFmpeg.framework
    rm -rf "$framework"
    if [ "$platform" = macos ]; then
        bundle=$framework/Versions/A
        mkdir -p "$bundle/Resources"
    else
        bundle=$framework
        mkdir -p "$bundle"
    fi

    local install_name=@rpath/FFmpeg.framework/FFmpeg
    [ "$platform" = macos ] && install_name=@rpath/FFmpeg.framework/Versions/A/FFmpeg
    "$cc" -target "$triple" -isysroot "$sysroot" -dynamiclib \
        -install_name "$install_name" \
        -Wl,-all_load "$prefix/lib/libavformat.a" "$prefix/lib/libavcodec.a" \
        "$prefix/lib/libswresample.a" "$prefix/lib/libavutil.a" \
        -framework CoreFoundation -lm \
        -o "$bundle/FFmpeg"

    # Headers, with FFmpeg's "libavutil/x.h" includes made framework-relative
    # so the module builds without extra header search paths.
    mkdir -p "$bundle/Headers"
    cp -R "$prefix/include/." "$bundle/Headers/"
    unused_headers "$bundle/Headers" | xargs rm -f
    find "$bundle/Headers" -name '*.h' -exec sed -i '' -E \
        's#^([[:space:]]*\#[[:space:]]*include[[:space:]]+)"(libav[a-z]+|libsw[a-z]+)/([^"]+)"#\1<FFmpeg/\2/\3>#' {} +
    (
        cd "$bundle/Headers"
        echo "// The FFmpeg headers the app may import. Generated by scripts/build-ffmpeg.sh."
        find . -name '*.h' | sed 's#^\./##' | sort | sed 's#.*#\#include <FFmpeg/&>#'
    ) >"$work/FFmpeg.h"
    mv "$work/FFmpeg.h" "$bundle/Headers/FFmpeg.h"
    mkdir -p "$bundle/Modules"
    cat >"$bundle/Modules/module.modulemap" <<'EOF'
framework module FFmpeg {
    umbrella header "FFmpeg.h"
    export *
    module * { export * }
}
EOF

    local plist=$bundle/Info.plist
    [ "$platform" = macos ] && plist=$bundle/Resources/Info.plist
    cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>FFmpeg</string>
    <key>CFBundleIdentifier</key><string>org.ffmpeg.FFmpeg</string>
    <key>CFBundleName</key><string>FFmpeg</string>
    <key>CFBundlePackageType</key><string>FMWK</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$version</string>
    <key>MinimumOSVersion</key><string>$deployment</string>
</dict>
</plist>
EOF

    if [ "$platform" = macos ]; then
        ln -sfh A "$framework/Versions/Current"
        for item in FFmpeg Headers Modules Resources; do
            ln -sfh "Versions/Current/$item" "$framework/$item"
        done
    fi
}

xcframework() {
    local args=() platform
    for platform in "${platforms[@]}"; do
        args+=(-framework "$work/frameworks/$platform/FFmpeg.framework")
    done
    rm -rf "$work/FFmpeg.xcframework"
    xcodebuild -create-xcframework "${args[@]}" -output "$work/FFmpeg.xcframework" >/dev/null
}

fetch
for platform in "${platforms[@]}"; do
    echo "building $platform"
    build "$platform"
done
if xcodebuild -version >/dev/null 2>&1; then
    xcframework
    echo "built $work/FFmpeg.xcframework"
else
    echo "no Xcode: built frameworks under $work/frameworks, skipped the xcframework"
fi
