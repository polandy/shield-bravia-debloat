# shellcheck shell=bash
# Shared helpers for the *-debloat.sh scripts. Source it after setting TARGET
# (host:port of the device) and ANDROID_USER.
# Packages are only disabled for one user (pm disable-user), never uninstalled.

# Run a shell command on the target device.
shell() { adb -s "$TARGET" shell "$@"; }

# Connect to the target; fails if the device is unreachable or unauthorized.
connect() {
  adb connect "$TARGET" >/dev/null
  local state
  state=$(adb -s "$TARGET" get-state 2>&1) || { echo "$TARGET: $state" >&2; return 1; }
}

# Run `pm <verb>` for each package; print one result line each, report failures.
for_each() {
  local verb="$1"; shift
  local pkg out rc=0
  for pkg in "$@"; do
    if out=$(shell pm "$verb" --user "$ANDROID_USER" "$pkg" 2>&1) && [[ $out != *Exception* ]]; then
      echo "ok    $pkg: $out"
    else
      echo "FAIL  $pkg: $out" >&2; rc=1
    fi
  done
  return $rc
}

# Print disabled/ENABLED per package.
status() {
  local disabled pkg
  disabled=$(shell pm list packages -d | tr -d '\r' | sed 's/^package://')
  for pkg in "$@"; do
    grep -qx "$pkg" <<<"$disabled" && echo "disabled  $pkg" || echo "ENABLED   $pkg"
  done
}
