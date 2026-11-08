#!/bin/bash
# Capture Pocket Republic with xcrun simctl io screenshot.
# Apple documents this as: xcrun simctl io booted screenshot [file]
# https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/iOS_Simulator_Guide/InteractingwiththeiOSSimulator/InteractingwiththeiOSSimulator.html
#
# The app is the simulator build of this branch. Scenes come from
# --pocket-republic-screenshot-fixture, which is not an ordinary play session
# and is not a physical iPhone Duo.

set -uo pipefail

out="${1:-$GITHUB_WORKSPACE/simulator-screenshots}"
mkdir -p "$out"
manifest="$out/manifest.txt"
: > "$manifest"

log() { printf '%s\n' "$*" | tee -a "$manifest"; }

log "base_commit=$(git rev-parse HEAD)"
log "capture=xcrun simctl io <udid> screenshot"
log "fixture_flag=--pocket-republic-screenshot-fixture"
log "world=WorldGenerator.generate(seed: 2026) plus capture-only overwrites"
log "not_physical_hardware=true"
log "not_ordinary_gameplay=true"

app=$(find "$RUNNER_TEMP/sim-dd/Build/Products" -type d -name 'PocketRepublic.app' -path '*iphonesimulator*' | head -1)
if [[ -z "${app}" || ! -d "$app" ]]; then
  log "error=app bundle missing"
  exit 1
fi
log "app=$app"
bundle=$(plutil -extract CFBundleIdentifier raw -o - "$app/Info.plist")
log "bundle=$bundle"
log "device_family=$(plutil -extract UIDeviceFamily json -o - "$app/Info.plist" 2>/dev/null || echo missing)"

pick_device() {
  local kind="$1"
  xcrun simctl list devices available -j | python3 -c '
import json, re, sys
kind = sys.argv[1]
data = json.load(sys.stdin)
prefs = {
  "iPhone": ["iPhone 17 Pro", "iPhone 17", "iPhone 16 Pro", "iPhone 16", "iPhone 15", "iPhone"],
  "iPad": ["iPad Pro 13", "iPad Pro 11", "iPad Air 13", "iPad Air", "iPad mini", "iPad"],
}[kind]

def version(runtime):
    return tuple(int(n) for n in re.findall(r"\d+", runtime))

found = []
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        name = device.get("name") or ""
        if device.get("isAvailable") and name.startswith(kind):
            rank = next((i for i, prefix in enumerate(prefs) if name == prefix or name.startswith(prefix + " ")), 50)
            found.append((version(runtime), -rank, name, runtime, device["udid"]))
if not found:
    sys.exit(1)
found.sort(reverse=True)
_version, _rank, name, runtime, udid = found[0]
print(udid + "\t" + name + "\t" + runtime)
' "$kind"
}

boot_device() {
  local udid="$1"
  xcrun simctl shutdown all >/dev/null 2>&1 || true
  xcrun simctl boot "$udid" || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl install "$udid" "$app"
}

# simctl io screenshot needs a framebuffer. Open Simulator only if a shot fails.
shoot() {
  local udid="$1"
  local dest="$2"
  local attempt
  for attempt in 1 2 3; do
    if xcrun simctl io "$udid" screenshot "$dest"; then
      local bytes
      bytes=$(stat -f%z "$dest")
      log "shot_bytes $(basename "$dest") attempt=$attempt bytes=$bytes"
      if [[ "$bytes" -gt 50000 ]]; then
        sips -g pixelWidth -g pixelHeight "$dest" | tee -a "$manifest"
        file "$dest" | tee -a "$manifest"
        return 0
      fi
    else
      log "shot_error $(basename "$dest") attempt=$attempt"
    fi
    open -a Simulator --args -CurrentDeviceUDID "$udid" || true
    sleep 8
  done
  return 1
}

capture_scene() {
  local udid="$1"
  local scene="$2"
  local dest="$3"
  xcrun simctl terminate "$udid" "$bundle" >/dev/null 2>&1 || true
  local launched
  if ! launched=$(xcrun simctl launch "$udid" "$bundle" --pocket-republic-screenshot-fixture "$scene"); then
    log "launch_failed scene=$scene"
    return 1
  fi
  log "launched scene=$scene ${launched}"
  sleep 12
  shoot "$udid" "$dest"
}

failures=0

if phone=$(pick_device iPhone); then
  phone_udid=$(printf '%s' "$phone" | cut -f1)
  phone_name=$(printf '%s' "$phone" | cut -f2)
  phone_runtime=$(printf '%s' "$phone" | cut -f3)
  log "iphone_name=$phone_name"
  log "iphone_udid=$phone_udid"
  log "iphone_runtime=$phone_runtime"
  boot_device "$phone_udid"
  capture_scene "$phone_udid" island "$out/01-island-foundation-scaffold.png" || failures=$((failures + 1))
  capture_scene "$phone_udid" event "$out/02-event-choice-card.png" || failures=$((failures + 1))
  capture_scene "$phone_udid" gazette "$out/03-gazette.png" || failures=$((failures + 1))
  xcrun simctl shutdown "$phone_udid" >/dev/null 2>&1 || true
else
  log "error=no available iPhone simulator"
  failures=$((failures + 1))
fi

if pad=$(pick_device iPad); then
  pad_udid=$(printf '%s' "$pad" | cut -f1)
  pad_name=$(printf '%s' "$pad" | cut -f2)
  pad_runtime=$(printf '%s' "$pad" | cut -f3)
  log "ipad_name=$pad_name"
  log "ipad_udid=$pad_udid"
  log "ipad_runtime=$pad_runtime"
  log "wide_layout=iPad simulator window, not a physical Duo. spannedFlat when the view is at least 580 by 500 points."
  boot_device "$pad_udid"
  capture_scene "$pad_udid" wide "$out/04-wide-layout.png" || failures=$((failures + 1))
  xcrun simctl shutdown "$pad_udid" >/dev/null 2>&1 || true
else
  log "error=no available iPad simulator; wide layout was not captured"
  failures=$((failures + 1))
fi

png_count=$(find "$out" -name '*.png' | wc -l | tr -d ' ')
log "png_count=$png_count"
log "scene_failures=$failures"
if [[ "$png_count" -lt 1 ]]; then
  exit 1
fi
exit 0
