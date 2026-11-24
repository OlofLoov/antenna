#!/usr/bin/env bash
# Builds the app icons from the SVG sources in design/icon: the Icon Composer layers (tips, letter, glow), the Apple TV asset catalog, the six alternates and the board previews.
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
rm -f "$icon/Assets/"*.svg
cp "$src/tips.svg" "$src/letter.svg" "$src/glow.svg" "$icon/Assets/"

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

# name, letters, tips, ground
alternates=(
  "Mono F2F4F8 F2F4F8 0B0E13"
  "Light 0B0E13 119C8F F2F4F8"
  "Blue F2F4F8 5BB8FF 0B0E13"
  "Amber F2F4F8 FFB454 0B0E13"
  "Pink F2F4F8 F472B6 0B0E13"
  "Violet F2F4F8 C084FC 0B0E13"
)

srgb() {
  local hex=$1 parts=() at
  for at in 0 2 4; do
    parts+=("$(awk -v n="$((16#${hex:at:2}))" 'BEGIN { printf "%.5f", n / 255 }')")
  done
  printf 'srgb:%s,%s,%s,1.00000' "${parts[@]}"
}

recolor() {
  sed -e "s/#F2F4F8/#$2/g" -e "s/#4FD1C5/#$3/g" "$1"
}

# One glass layer group of an alternate's Icon Composer file.
group() {
  cat <<EOF
    {
      "layers" : [
        {
          "glass" : true,
          "image-name" : "$1.svg",
          "name" : "$1"
        }
      ],
      "name" : "$2",
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.5
      },
      "translucency" : {
        "enabled" : false,
        "value" : 0.5
      }
    }
EOF
}

# An alternate's Icon Composer file: the tips and the letter on a plain
# ground, which turns black in dark mode when it is dark.
alternate_json() {
  local fill=$1 dark=$2
  printf '{\n  "fill" : {\n    "solid" : "%s"\n  },\n' "$fill"
  if [[ $dark == yes ]]; then
    printf '  "fill-specializations" : [\n    {\n      "appearance" : "dark",\n'
    printf '      "value" : {\n        "solid" : "srgb:0.00000,0.00000,0.00000,1.00000"\n      }\n    }\n  ],\n'
  fi
  printf '  "groups" : [\n%s,\n%s\n  ],\n' "$(group tips Tips)" "$(group letter Letter)"
  printf '  "supported-platforms" : {\n    "squares" : "shared"\n  }\n}\n'
}

rm -rf Apps/Mobile/AppIcon-*.icon
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
for entry in "${alternates[@]}"; do
  read -r name ink tip ground <<<"$entry"
  alt="Apps/Mobile/AppIcon-$name.icon"
  mkdir -p "$alt/Assets" "$scratch/$name"
  for layer in tips letter; do
    recolor "$src/$layer.svg" "$ink" "$tip" >"$alt/Assets/$layer.svg"
  done
  dark=no
  [[ $ground == 0B0E13 ]] && dark=yes
  alternate_json "$(srgb "$ground")" "$dark" >"$alt/icon.json"
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="768" viewBox="0 0 1280 768"><rect width="1280" height="768" fill="#%s"/></svg>\n' \
    "$ground" >"$scratch/$name/tv-back.svg"
  for layer in middle front; do
    recolor "$src/tv-$layer.svg" "$ink" "$tip" >"$scratch/$name/tv-$layer.svg"
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
