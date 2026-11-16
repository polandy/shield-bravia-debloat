#!/usr/bin/env bash
# Debloat an NVIDIA SHIELD Android TV via network ADB.
# Packages are only disabled for user 0 (pm disable-user), never uninstalled;
# `revert` re-enables everything. A factory reset also restores all packages.
#
# Usage: ./shield-debloat.sh apply|revert|status
# Needs adb (e.g. `nix shell nixpkgs#android-tools`).
set -euo pipefail

# Device address lives in devices.env (gitignored); copy devices.env.example and
# set SHIELD=<ip>:5555. The environment overrides it.
dir=$(dirname "$0")
[ -f "$dir/devices.env" ] && . "$dir/devices.env"
TARGET="${SHIELD:?set SHIELD in devices.env (copy devices.env.example) or the environment, e.g. 192.0.2.10:5555}"
ANDROID_USER=0
# shellcheck source=lib/adb-debloat.sh
source "$(dirname "$0")/lib/adb-debloat.sh"

# NOTE: the stock launcher (com.google.android.tvlauncher, tvrecommendations,
# backdrop) cannot be kept disabled: SHIELD firmware re-enables it on every boot,
# and `pm uninstall --user 0` crashes the package service and restores it.
# Ads are avoided instead by Projectivy's "Override current launcher"
# accessibility service (see PROJECTIVY_A11Y), which takes over the Home button.
PROJECTIVY_A11Y=com.spocky.projengmenu/.services.ProjectivyAccessibilityService

TELEMETRY=(
  com.nvidia.stats
  com.nvidia.feedback
  com.google.android.feedback
  com.nvidia.diagtools
)

FACTORY=(
  com.nvidia.factory
  com.nvidia.factorybundling
  com.nvidia.factorysyschecker
  com.nvidia.tegraprofiler.security
  com.nvidia.inputviewer
  com.nvidia.developerwidget
)

PROMO=(
  com.nvidia.shield.beta
  com.nvidia.shieldbeta
  com.nvidia.shield.registration
  com.nvidia.shield.welcome
  android.autoinstalls.config.nvidia
)

UNUSED_APPS=(
  com.google.android.videos
  com.google.android.play.games
  com.google.android.youtube.tvmusic
  com.google.android.youtube.tv
  com.amazon.amazonvideo.livingroom.nvidia
  com.neoyantra.airplaymirror.airplaymirrorappdemo
  com.android.gallery3d
  com.android.printspooler
)

VOICE_ASSISTANT=(
  com.google.android.katniss
  com.google.android.speech.pumpkin
  com.android.hotwordenrollment.okgoogle
  com.android.hotwordenrollment.xgoogle
  com.nvidia.shield.ask
  com.nvidia.hotwordsetup
)

NAS_SERVER=(
  com.nvidia.shield.nas
  com.nvidia.shield.smbserver
  com.nvidia.shield.smbauth
)

ALL=(
  "${TELEMETRY[@]}" "${FACTORY[@]}" "${PROMO[@]}"
  "${UNUSED_APPS[@]}" "${VOICE_ASSISTANT[@]}" "${NAS_SERVER[@]}"
)

connect

case "${1:-}" in
  apply)
    for_each disable-user "${ALL[@]}"
    shell settings put secure enabled_accessibility_services "$PROJECTIVY_A11Y"
    shell settings put secure accessibility_enabled 1
    ;;
  revert) for_each enable "${ALL[@]}" ;;
  status) status "${ALL[@]}" ;;
  *) echo "usage: $0 apply|revert|status" >&2; exit 2 ;;
esac
