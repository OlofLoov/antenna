#!/usr/bin/env bash
# Builds the app icons from the SVG sources in design/icon: the Icon Composer layers, the Apple TV asset catalog, the six alternates and the board previews.
set -euo pipefail
cd "$(dirname "$0")/.."

src=design/icon
icon=Apps/Mobile/AppIcon.icon
brand="Apps/TV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
info='"info" : { "author" : "xcode", "version" : 1 }'

render() {
  swift scripts/render-svg.swift "$@"
}

mkdir -p "$icon/Assets"
cp "$src/waves.svg" "$src/mast.svg" "$icon/Assets/"

rm -rf Apps/TV/Assets.xcassets
mkdir -p "$brand"
printf '{\n  %s\n}\n' "$info" >Apps/TV/Assets.xcassets/Contents.json
cat >"$brand/Contents.json" <<EOF
{
  "assets" : [
    { "filename" : "App Icon - App Store.imagestack", "idiom" : "tv", "role" : "primary-app-icon", "size" : "1280x768" },
    { "filename" : "App Icon.imagestack", "idiom" : "tv", "role" : "primary-app-icon", "size" : "400x240" },
    { "filename" : "Top Shelf Image Wide.imageset", "idiom" : "tv", "role" : "top-shelf-image-wide", "size" : "2320x720" },
    { "filename" : "Top Shelf Image.imageset", "idiom" : "tv", "role" : "top-shelf-image", "size" : "1920x720" }
  ],
  $info
}
EOF

stack() {
  local name=$1 width=$2 height=$3 scales=$4 parent=${5:-$brand} from=${6:-$src}
  local dir="$parent/$name.imagestack"
  mkdir -p "$dir"
  cat >"$dir/Contents.json" <<EOF
{
  "layers" : [
    { "filename" : "Front.imagestacklayer" },
    { "filename" : "Middle.imagestacklayer" },
    { "filename" : "Back.imagestacklayer" }
  ],
  $info
}
EOF
  for layer in Front Middle Back; do
    local lower opaque="" images=""
    lower=$(printf '%s' "$layer" | tr '[:upper:]' '[:lower:]')
    [[ $layer == Back ]] && opaque=opaque
    mkdir -p "$dir/$layer.imagestacklayer/Content.imageset"
    printf '{\n  %s\n}\n' "$info" >"$dir/$layer.imagestacklayer/Contents.json"
    for scale in $scales; do
      local file="$lower@${scale}x.png"
      render "$from/tv-$lower.svg" "$dir/$layer.imagestacklayer/Content.imageset/$file" \
        $((width * scale)) $((height * scale)) $opaque
      images+="${images:+,
}    { \"filename\" : \"$file\", \"idiom\" : \"tv\", \"scale\" : \"${scale}x\" }"
    done
    printf '{\n  "images" : [\n%s\n  ],\n  %s\n}\n' "$images" "$info" \
      >"$dir/$layer.imagestacklayer/Content.imageset/Contents.json"
  done
}

shelf() {
  local name=$1 source=$2 width=$3 height=$4
  local dir="$brand/$name.imageset" images=""
  mkdir -p "$dir"
  for scale in 1 2; do
    local file="$source@${scale}x.png"
    render "$src/$source.svg" "$dir/$file" $((width * scale)) $((height * scale)) opaque
    images+="${images:+,
}    { \"filename\" : \"$file\", \"idiom\" : \"tv\", \"scale\" : \"${scale}x\" }"
  done
  printf '{\n  "images" : [\n%s\n  ],\n  %s\n}\n' "$images" "$info" >"$dir/Contents.json"
}

stack "App Icon" 400 240 "1 2"
stack "App Icon - App Store" 1280 768 "1"
shelf "Top Shelf Image" topshelf 1920 720
shelf "Top Shelf Image Wide" topshelf-wide 2320 720

alternates=(
  "Mono F2F4F8 0B0E13"
  "Light 0B0E13 F2F4F8"
  "Teal 4FD1C5 0B0E13"
  "Amber FFB454 0B0E13"
  "Pink F472B6 0B0E13"
  "Violet C084FC 0B0E13"
)

srgb() {
  local hex=$1 parts=() at
  for at in 0 2 4; do
    parts+=("$(awk -v n="$((16#${hex:at:2}))" 'BEGIN { printf "%.5f", n / 255 }')")
  done
  printf 'srgb:%s,%s,%s,1.00000' "${parts[@]}"
}

rm -rf Apps/Mobile/AppIcon-*.icon
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
for entry in "${alternates[@]}"; do
  read -r name mark ground <<<"$entry"
  alt="Apps/Mobile/AppIcon-$name.icon"
  mkdir -p "$alt/Assets" "$scratch/$name"
  for layer in waves mast; do
    sed "s/#5BB8FF/#$mark/" "$src/$layer.svg" >"$alt/Assets/$layer.svg"
  done
  fill=$(srgb "$ground")
  if [[ $ground == 0B0E13 ]]; then
    sed "s/\"solid\" : \"srgb:0.04314,0.05490,0.07451,1.00000\"/\"solid\" : \"$fill\"/" "$icon/icon.json" >"$alt/icon.json"
    sed "s/#5BB8FF/#$mark/" "$src/tv-back.svg" >"$scratch/$name/tv-back.svg"
  else
    awk -v fill="$fill" '
      /"fill-specializations"/ { skip = 1 }
      skip && /^  \],/ { skip = 0; next }
      skip { next }
      { sub(/"solid" : "srgb:0.04314,0.05490,0.07451,1.00000"/, "\"solid\" : \"" fill "\""); print }
    ' "$icon/icon.json" >"$alt/icon.json"
    sed -e "s/#5BB8FF/#$mark/" -e "s/#1A2A44/#FFFFFF/" -e "s/#0B0E13/#$ground/" "$src/tv-back.svg" >"$scratch/$name/tv-back.svg"
  fi
  for layer in middle front; do
    sed "s/#5BB8FF/#$mark/" "$src/tv-$layer.svg" >"$scratch/$name/tv-$layer.svg"
  done
  stack "AppIcon-$name" 400 240 "1 2" Apps/TV/Assets.xcassets "$scratch/$name"
done

mkdir -p "$src/previews"
preview() {
  "$ictool" "$icon" --export-image --output-file "$src/previews/$1.png" \
    --platform "$2" --rendition "$3" --width 512 --height 512 --scale 1 "${@:4}" >/dev/null
}
preview ios-default iOS Default
preview ios-dark iOS Dark
preview ios-tinted iOS TintedDark --tint-color 0.58 --tint-strength 0.8
preview ios-clear iOS ClearDark
preview macos-default macOS Default
for layer in back middle front; do
  render "$src/tv-$layer.svg" "$src/previews/tv-$layer.png" 400 240
done
