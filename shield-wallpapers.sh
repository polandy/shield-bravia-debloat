#!/usr/bin/env bash
# Convert photos to 4K 16:9 TV wallpapers and copy them to the SHIELD,
# where Projectivy's user-defined folder (/sdcard/Pictures) picks them up.
#
# Usage: ./shield-wallpapers.sh
# Needs adb + imagemagick (e.g. `nix shell nixpkgs#android-tools nixpkgs#imagemagick`).
set -euo pipefail

SRC_DIR=wallpapers          # originals, never modified
OUT_DIR=wallpapers-tv       # converted copies
DEVICE_DIR=/sdcard/Pictures/Wallpapers
SIZE=3840x2160              # 4K UHD, 16:9
JPEG_QUALITY=90

cd "$(dirname "$0")"
# Device address lives in devices.env (gitignored); copy devices.env.example and
# set SHIELD=<ip>:5555. The environment overrides it.
[ -f devices.env ] && . ./devices.env
SHIELD="${SHIELD:?set SHIELD in devices.env (copy devices.env.example) or the environment, e.g. 192.0.2.10:5555}"
mkdir -p "$OUT_DIR"

# Center-crop to 16:9, apply EXIF rotation, strip metadata (GPS, camera data).
for f in "$SRC_DIR"/*; do
  [ -f "$f" ] || continue
  out="$OUT_DIR/$(basename "${f%.*}").jpg"
  [ -e "$out" ] && continue
  magick "$f" -auto-orient -resize "${SIZE}^" -gravity center -extent "$SIZE" \
    -strip -quality "$JPEG_QUALITY" "$out"
  echo "converted $(basename "$f")"
done

adb connect "$SHIELD" >/dev/null
adb -s "$SHIELD" shell mkdir -p "$DEVICE_DIR"
adb -s "$SHIELD" push "$OUT_DIR/." "$DEVICE_DIR/"

# Register the files with the media scanner so pickers see them immediately.
for f in "$OUT_DIR"/*.jpg; do
  adb -s "$SHIELD" shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
    -d "file://$DEVICE_DIR/$(basename "$f")" >/dev/null
done
echo "$(adb -s "$SHIELD" shell ls "$DEVICE_DIR" | wc -l) wallpapers on the SHIELD"
