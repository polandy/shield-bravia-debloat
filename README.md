# NVIDIA Shield – kill the ads, disable services

Scripts and notes for stripping the ads and unused services from an NVIDIA SHIELD
Android TV, and for easing the memory pressure on the Sony BRAVIA it is plugged
into. Nothing is uninstalled — packages are only disabled for user 0 and can be
re-enabled, and a factory reset restores everything.

## Devices

| | |
|---|---|
| SHIELD | NVIDIA SHIELD Android TV (Android 11) |
| Display | Sony BRAVIA 4K (Android 7.0, ~1.5 GB RAM), used only as screen/speakers |
| Access | network ADB on port 5555 (enable in Developer options → Network debugging / ADB debugging) |

The device ADB addresses are **not** in this repo. Copy the example config and
fill in your own:

```sh
cp devices.env.example devices.env
# edit devices.env: SHIELD=<ip>:5555 and TV=<ip>:5555
```

`devices.env` is gitignored, so your real addresses never land in git. Every
script reads it; you can also override with the `SHIELD` / `TV` environment
variables.

`adb` itself is not installed here — it runs on demand via Nix:

```sh
nix shell nixpkgs#android-tools -c adb connect "$SHIELD"   # after sourcing devices.env
```

## Ads on the home screen

The ads come from the Google TV launcher (`com.google.android.tvlauncher`).
Replaced by **Projectivy Launcher** (`com.spocky.projengmenu`, from the Play Store).

**The stock launcher cannot be disabled:**

- `pm disable-user` only holds until the next reboot. The firmware re-scans the
  launcher at boot (`Relax SCAN_REQUIRE_KNOWN`) and re-enables it together with
  `tvrecommendations` and `backdrop`, resetting the default-launcher choice too.
- `pm uninstall -k --user 0` crashes the package service (`Broken pipe` /
  `Can't find service: package`). The SHIELD soft-reboots and restores the
  launcher. **Do not repeat.**

**Solution:** Projectivy takes over the Home button through its accessibility
service:

```sh
adb shell settings put secure enabled_accessibility_services com.spocky.projengmenu/.services.ProjectivyAccessibilityService
adb shell settings put secure accessibility_enabled 1
```

`shield-debloat.sh apply` does this for you. From Projectivy 4.73 on this is
enough; the old "Override current launcher" switch is gone. After a reboot
Projectivy comes up directly, and Home returns to it from inside Kodi. The Google
launcher still runs briefly in the background at boot but is never visible.

## Disabled packages (SHIELD)

[`shield-debloat.sh`](shield-debloat.sh) disables 32 packages with
`pm disable-user --user 0`. Nothing is deleted, and they stay disabled across
reboots.

| Group | Packages |
|---|---|
| Telemetry/feedback | `com.nvidia.stats`, `com.nvidia.feedback`, `com.google.android.feedback`, `com.nvidia.diagtools` |
| Factory/test | `com.nvidia.factory`, `com.nvidia.factorybundling`, `com.nvidia.factorysyschecker`, `com.nvidia.tegraprofiler.security`, `com.nvidia.inputviewer`, `com.nvidia.developerwidget` |
| Beta/registration/promo | `com.nvidia.shield.beta`, `com.nvidia.shieldbeta`, `com.nvidia.shield.registration`, `com.nvidia.shield.welcome`, `android.autoinstalls.config.nvidia` (otherwise re-installs promo apps) |
| Unused apps | Play Movies, Play Games, YouTube, YouTube Music, Prime Video, AirPlay Mirror demo, Gallery, Print Spooler |
| Assistant/voice | `com.google.android.katniss`, `com.google.android.speech.pumpkin`, `com.android.hotwordenrollment.okgoogle`, `com.android.hotwordenrollment.xgoogle`, `com.nvidia.shield.ask`, `com.nvidia.hotwordsetup` |
| File sharing (NAS/SMB) | `com.nvidia.shield.nas`, `com.nvidia.shield.smbserver`, `com.nvidia.shield.smbauth` |

Consequences:
- The remote's microphone button does nothing anymore.
- The SHIELD no longer shares files on the LAN. Kodi and Jellyfin still reach
  their servers.

**Deliberately left alone:**
- the apps in use: Kodi, Jellyfin, and the regional streaming apps, plus Zattoo, Moonlight, Steam Link
- Chromecast (`com.google.android.apps.mediashell`)
- Play Services and Play Store
- remote and Bluetooth
- OTA updater (`com.nvidia.ota`)
- Dolby/audio/AV-sync
- WebView

```sh
nix shell nixpkgs#android-tools -c ./shield-debloat.sh status   # check state
nix shell nixpkgs#android-tools -c ./shield-debloat.sh apply    # (re)apply, incl. Projectivy accessibility service
nix shell nixpkgs#android-tools -c ./shield-debloat.sh revert   # re-enable everything
```

**After every SHIELD update** run `status`, since updates can re-enable packages.
A factory reset also restores everything.

## Wallpapers

Projectivy's bundled wallpapers are blurry. Replaced with own photos:

- Originals live in `wallpapers/` and are never modified (gitignored — keep them
  out of the repo).
- [`shield-wallpapers.sh`](shield-wallpapers.sh) converts them into `wallpapers-tv/`:
  3840×2160, center-cropped to 16:9, EXIF rotation applied, metadata such as GPS
  stripped. Then it copies them to `/sdcard/Pictures/Wallpapers` on the SHIELD.
- Projectivy config: gear → Wallpaper → **Launcher wallpaper: "User-defined
  folder"**, Uri `content://com.android.externalstorage.documents/tree/primary%3APictures`.
  Images rotate after the *refresh delay (min)*.
- "Show wallpapers" is only a preview. Clicking there pins Projectivy to a single
  image.

### Adding more images

1. Copy photos (any size, landscape works best) into `wallpapers/`.
2. Convert and push to the SHIELD. Already-converted images are skipped:

   ```sh
   nix shell nixpkgs#android-tools nixpkgs#imagemagick -c ./shield-wallpapers.sh
   ```

3. Done. Projectivy picks up the new images at the next rotation.

An image already in TV format can be copied directly, without conversion (source
`devices.env` first so `$SHIELD` is set):

```sh
nix shell nixpkgs#android-tools -c bash -c '. ./devices.env && adb connect "$SHIELD" && adb push IMG.jpg /sdcard/Pictures/Wallpapers/ && adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/Wallpapers/IMG.jpg'
```

Remove an image: `adb shell rm /sdcard/Pictures/Wallpapers/IMG.jpg`

**Folder-picker gotcha:** the "Use this folder" button in the Android file dialog
could not be pressed on the TV with either the remote or a mouse. Over ADB the tap
worked:

```sh
adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml   # find bounds of "USE THIS FOLDER"
adb shell input tap <x> <y>                                                  # then "ALLOW" the same way
```

## App order

In Projectivy select the app, **long-press OK**, choose "Move" and shift it with
the arrow keys. The same menu can also hide apps.

## Sony BRAVIA (display only)

The SHIELD is plugged into an **older Sony BRAVIA 4K** that serves only as screen
and speakers — all apps run on the SHIELD.

**Problem:** the TV was very sluggish. The cause is tight memory: of 1.5 GB RAM
only ~140 MB was free, so it constantly evicted and reloaded apps. The high load
average (~40) comes instead from MediaTek kernel threads waiting on hardware and
cannot be changed.

**Solution:** [`tv-debloat.sh`](tv-debloat.sh) disables 60 packages with
`pm disable-user --user 0` (recommendations/tracking, telemetry, the apps that run
on the SHIELD, cast/DLNA/Miracast, the whole tuner/HbbTV stack since there is no
antenna TV, voice search, Play Store). Reboot once afterwards. Result: free memory
(free + cache) roughly doubled, from ~330–410 MB to **~630–660 MB**.

```sh
nix shell nixpkgs#android-tools -c ./tv-debloat.sh status   # check state
nix shell nixpkgs#android-tools -c ./tv-debloat.sh apply    # (re)apply
nix shell nixpkgs#android-tools -c ./tv-debloat.sh revert   # re-enable everything
```

**Deliberately left alone:** HDMI inputs, picture/sound, remote, fan/thermal
control, software update, the tuner input service (the system touches it at boot)
and **Bravia Sync** (HDMI-CEC, lets the SHIELD switch the TV on/off).

**Known leftovers:**
- **Samba TV** (`tv.samba.ssm`, ACR/usage tracking) is disabled but still runs:
  Android 7 starts persistent system apps even when disabled. Removing it would
  need `pm uninstall --user 0`, but Android 7 lacks `install-existing` to restore
  it — only a factory reset would. Better: block the Samba servers at your
  network's DNS blocker (e.g. Blocky, Pi-hole).
- **Play Store** is disabled here only (frees ~90 MB); on the SHIELD it stays
  enabled. Sony firmware updates run separately and keep working.

**Rooting is not worth it:** Sony does not unlock the bootloader (Verified Boot +
SELinux enforcing), so root would only be possible via an exploit with a real
brick risk. It would not fix the memory shortage and buys nothing over the ADB
debloat.

**Passing the TV on:** nothing is deleted, only disabled. `./tv-debloat.sh revert`
re-enables everything, but for giving the set away a **factory reset** on the TV is
the right move — it restores everything and wipes accounts and Wi-Fi at the same
time.
