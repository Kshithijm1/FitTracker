#!/usr/bin/env bash
# One-off generator for FitTrack's Assets.xcassets color tokens.
# Not part of the app bundle; run manually if the token table changes.
set -euo pipefail

ROOT="ios/FitTrack/Resources/Assets.xcassets"
mkdir -p "$ROOT"

cat > "$ROOT/Contents.json" <<'EOF'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

hex_to_rgb() {
  local hex=$1
  echo "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

make_color() {
  local name=$1 light=$2 dark=$3
  local dir="$ROOT/${name}.colorset"
  mkdir -p "$dir"
  read -r lr lg lb <<< "$(hex_to_rgb "$light")"
  read -r dr dg db <<< "$(hex_to_rgb "$dark")"
  cat > "$dir/Contents.json" <<EOF
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0x${dark:4:2}",
          "green" : "0x${dark:2:2}",
          "red" : "0x${dark:0:2}"
        }
      },
      "idiom" : "universal",
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ]
    },
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0x${light:4:2}",
          "green" : "0x${light:2:2}",
          "red" : "0x${light:0:2}"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
}

# name          light#     dark#
make_color Background   FAFAF9   0C0C0E
make_color Surface       FFFFFF   17171A
make_color Surface2      F0F0EE   202024
make_color Separator     E2E2E0   2A2A2E
make_color TextPrimary   14141A   F5F5F0
make_color TextSecondary 5A5A62   A0A0A8
make_color TextTertiary  8B8B92   6B6B72
make_color Accent        C8F04A   C8F04A
make_color OnAccent      14210A   14210A
make_color Success       1FA463   34D399
make_color Warning       C97A00   F5A623
make_color Error         D64545   FF6B6B
make_color RingTrack     E5E5E2   232326

echo "Generated $(ls "$ROOT" | grep -c colorset) colorsets."
