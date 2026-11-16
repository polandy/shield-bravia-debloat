#!/usr/bin/env bash
# Debloat the Sony BRAVIA (Android 7.0, 1.5 GB RAM) that serves only as a
# display for the SHIELD. No broadcast TV (antenna/cable/sat), no voice search.
# Packages are disabled for user 0, never uninstalled; `revert` re-enables them.
#
# Kept on purpose: HDMI inputs, picture/sound, remote, heat control, system update,
# Bravia Sync (HDMI-CEC, lets the SHIELD switch the TV on/off), the tuner input
# service and TV player (the system may touch them at boot).
#
# Usage: ./tv-debloat.sh apply|revert|status
# Needs adb (e.g. `nix shell nixpkgs#android-tools`).
set -euo pipefail

# Device address lives in devices.env (gitignored); copy devices.env.example and
# set TV=<ip>:5555. The environment overrides it.
dir=$(dirname "$0")
[ -f "$dir/devices.env" ] && . "$dir/devices.env"
TARGET="${TV:?set TV in devices.env (copy devices.env.example) or the environment, e.g. 192.0.2.11:5555}"
ANDROID_USER=0
# shellcheck source=lib/adb-debloat.sh
source "$(dirname "$0")/lib/adb-debloat.sh"

RECOMMENDATIONS_TRACKING=(
  com.sony.dtv.discovery
  com.sony.dtv.recommendationservice
  com.sony.dtv.irbrecommendation
  com.sony.dtv.woprecommendation
  com.sony.dtv.watchtvrecommendation
  com.sony.dtv.networkrecommendation
  com.sony.dtv.sonyselect
  com.sony.dtv.sonyshelf
  com.sony.dtv.bravialifehack
  android.autoinstalls.config.sony.bravia
  com.qterics.da.product
  com.sony.dtv.da.service
)

TELEMETRY_HELP=(
  com.google.android.feedback
  com.google.android.tv.bugreportsender
  com.sony.dtv.customersupport
  com.sony.dtv.smarthelp
  com.sony.dtv.imanual
  com.sony.dtv.demomode
  com.sony.dtv.touchpad.tutorial
)

# Apps that run on the SHIELD instead.
UNUSED_APPS=(
  com.google.android.youtube.tv
  com.google.android.videos
  com.google.android.music
  com.google.android.play.games
  com.amazon.aiv.eu
  ch.srgssr.playsuisse.tv
  com.zattoo.player
  com.opera.sdk.example
  com.sony.dtv.osat.album
  com.sony.dtv.osat.music
  com.sony.dtv.osat.video
  com.android.printspooler
)

# Cast/DLNA/Miracast: the SHIELD is the cast target.
CASTING=(
  com.google.android.apps.mediashell
  com.sonyericsson.dlna
  com.sonyericsson.dlna.dtcpplayer
  com.sony.huey.dlna.module
  com.sony.huey.dlna.renderersettings
  com.mediatek.wfd
  screnmirroring.com
  com.sony.dtv.networkapp.wifidirect
)

BROADCAST_TV=(
  com.sony.dtv.hbbtvlauncher
  com.sony.dtv.interactivetvplatform
  com.sony.dtv.interactivetvutil
  com.sony.dtv.interactivetvutil.output
  com.sony.dtv.tuningconfirmation_dvbs
  com.sony.dtv.tuningconfirmation_dvbt
  com.sony.dtv.tvx.search.s101.tvprograms.cam
  com.sony.dtv.tvx.search.s101.tvprograms.digital
  com.sony.dtv.tvx.search.s101.tvprograms.gensat
  com.sony.dtv.tvx.search.s101.tvprograms.prefsat
  com.sony.dtv.tvx.search.s101.tvprograms.vt
  com.sony.dtv.tvx.search.s201.netepg
  com.sony.dtv.tvx.search.s301.rec
  com.sony.dtv.tvx.search.s501.psv
  com.sony.dtv.reminderservice
  com.sony.dtv.hddmgr
  com.sony.dtv.youview
  com.youview.tv.servicehost
)

VOICE_ASSISTANT=(
  com.google.android.katniss
  com.google.android.speech.pumpkin
)

# The Play Store only updated Google system apps (GMS, WebView, TTS) here, since
# no user apps run on the TV. Disabling it frees ~90 MB; Sony firmware updates are
# separate and keep working.
PLAY_STORE=(
  com.android.vending
)

ALL=(
  "${RECOMMENDATIONS_TRACKING[@]}" "${TELEMETRY_HELP[@]}" "${UNUSED_APPS[@]}"
  "${CASTING[@]}" "${BROADCAST_TV[@]}" "${VOICE_ASSISTANT[@]}" "${PLAY_STORE[@]}"
)

connect
case "${1:-}" in
  apply)  for_each disable-user "${ALL[@]}" ;;
  revert) for_each enable "${ALL[@]}" ;;
  status) status "${ALL[@]}" ;;
  *) echo "usage: $0 apply|revert|status" >&2; exit 2 ;;
esac
