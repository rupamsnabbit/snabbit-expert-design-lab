#!/usr/bin/env bash
# drive_login.sh — adb-driven automation for the snabbit-runner-app login flow.
#
# Target backend: staging maestro-core (https://maestro-core.stg.snabbit.net/),
# selected in-app via Debug Menu -> CUSTOM (already persisted in this emulator's
# FlutterSharedPreferences). No adb reverse needed (remote URL).
#
# NOTE ON SCREENSHOTS: this emulator uses the Impeller/OpenGLES backend by default,
# whose framebuffer `screencap` cannot read back (it returns the launcher layer).
# Run the app with `flutter run --no-enable-impeller` so screencap captures real frames.
#
# Usage: ./drive_login.sh            # run the whole flow
#        PHONE=1212126666 OTP=9999 ./drive_login.sh
set -euo pipefail

SERIAL="${SERIAL:-emulator-5554}"
PKG="com.snabbit.runner"
SHOTS="${SHOTS:-$(cd "$(dirname "$0")" && pwd)/shots}"
mkdir -p "$SHOTS"
ADB=(adb -s "$SERIAL")

log() { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

# Capture display 0 to an on-device file then pull (avoids the "Multiple displays"
# warning that corrupts a piped `exec-out screencap`).
shot() { # shot <name>
  # Default display only: the emulator's HWC display ids are unstable across app
  # restarts, so a hard-coded `-d N` intermittently errors "Display Id not valid".
  # The default-display warning is harmless; 2>/dev/null drops it.
  "${ADB[@]}" shell screencap -p /sdcard/_ss.png 2>/dev/null
  "${ADB[@]}" pull /sdcard/_ss.png "$SHOTS/$1.png" >/dev/null
  echo "  shot -> $SHOTS/$1.png"
}

dump() { # refresh the UI hierarchy into $UIXML
  "${ADB[@]}" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  UIXML="$("${ADB[@]}" shell cat /sdcard/ui.xml 2>/dev/null)"
}

# Tap the centre of the first node whose text or content-desc contains $1.
tap_text() { # tap_text <substring>
  dump
  local bounds
  bounds="$(printf '%s' "$UIXML" | tr '>' '\n' \
    | grep -iE "(text|content-desc)=\"[^\"]*$1[^\"]*\"" \
    | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1)"
  if [[ -z "$bounds" ]]; then echo "  !! node not found: $1"; return 1; fi
  local x1 y1 x2 y2
  read -r x1 y1 x2 y2 < <(echo "$bounds" | grep -oE '[0-9]+' | tr '\n' ' ')
  local cx=$(((x1 + x2) / 2)) cy=$(((y1 + y2) / 2))
  echo "  tap '$1' @ $cx,$cy"
  "${ADB[@]}" shell input tap "$cx" "$cy"
}

type_text() { "${ADB[@]}" shell input text "$1"; }  # no spaces
wait_ui() { sleep "${1:-2}"; }

# ---------------------------------------------------------------------------
# VERIFIED FLOW (staging maestro-core, runner "PallaviRunner", 2026-07-13)
#
# PREREQUISITES (one-time, done via the in-app Debug Menu on getting_started):
#   1. Launch with Skia:   flutter run -d emulator-5554 --debug --no-enable-impeller
#      (Impeller/OpenGLES on this emulator's virtio-gpu makes screencap return the
#       launcher layer instead of the app.)
#   2. getting_started -> "Debug Menu":
#        - Select Environment  -> STAGING-ENV3   (= https://maestro-core.stg.snabbit.net/)
#        - Select Debug OTP Provider -> edumarc   (Apply; forces 1234 to verify against
#          staging instead of OTPless cloud)
#        - "Apply and Restart" only writes the pref; it does NOT re-init the HTTP base
#          URL. Force a real cold restart so startup re-reads the env:
#             adb shell am force-stop com.snabbit.runner
#             adb shell am start -n com.snabbit.runner/.MainActivity
#          Verify staging is live:
#             adb logcat -d | grep -oE 'https://[a-z.-]+/api' | sort | uniq -c
#          (should be dominated by maestro-core.stg, not runner-apis.snabbit.com)
#   3. Grant runtime perms up-front to avoid system dialogs mid-flow:
#        for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION ACCESS_BACKGROUND_LOCATION \
#                 POST_NOTIFICATIONS CAMERA RECORD_AUDIO READ_CONTACTS GET_ACCOUNTS; do
#          adb -s emulator-5554 shell pm grant com.snabbit.runner android.permission.$p
#        done
#
# TEST CREDENTIALS (staging, hardcoded bypass): phone 8296198196 / OTP 1234
PHONE="${PHONE:-8296198196}"
OTP="${OTP:-1234}"

# Tap a node's centre by exact content-desc (CR-safe bounds parse).
tap_desc() { # tap_desc <content-desc>
  dump
  local b
  b="$(printf '%s' "$UIXML" | tr -d '\r' | tr '>' '\n' \
        | grep -F "content-desc=\"$1\"" \
        | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]' | head -1)"
  [ -z "$b" ] && { echo "  !! not found: $1"; return 1; }
  local x1 y1 x2 y2
  x1=${b%%,*}; x1=${x1#[}
  y1=$(echo "$b" | sed -E 's/\[[0-9]+,([0-9]+)\].*/\1/')
  x2=$(echo "$b" | sed -E 's/.*\]\[([0-9]+),.*/\1/')
  y2=$(echo "$b" | sed -E 's/.*,([0-9]+)\]$/\1/')
  echo "  tap '$1' @ $(((x1+x2)/2)),$(((y1+y2)/2))"
  "${ADB[@]}" shell input tap $(((x1+x2)/2)) $(((y1+y2)/2))
}

edittext_center() { # echoes "cx cy" of the first EditText
  dump
  local b
  b="$(printf '%s' "$UIXML" | tr -d '\r' | tr '>' '\n' \
        | grep 'class="android.widget.EditText"' \
        | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]' | head -1)"
  local x1 y1 x2 y2
  x1=${b%%,*}; x1=${x1#[}
  y1=$(echo "$b" | sed -E 's/\[[0-9]+,([0-9]+)\].*/\1/')
  x2=$(echo "$b" | sed -E 's/.*\]\[([0-9]+),.*/\1/')
  y2=$(echo "$b" | sed -E 's/.*,([0-9]+)\]$/\1/')
  echo "$(((x1+x2)/2)) $(((y1+y2)/2))"
}

run_login() {
  log "getting_started"; shot 01_getting_started
  # dismiss the in-app background-location prompt if present
  tap_desc "Yes" || true; wait_ui 1

  log "Get Started -> phone form"
  tap_desc "Get Started"; wait_ui 3; shot 02_phone_form

  log "Enter phone $PHONE"
  read -r FCX FCY < <(edittext_center)
  "${ADB[@]}" shell input tap "$FCX" "$FCY"; wait_ui 1
  "${ADB[@]}" shell input text "$PHONE"; wait_ui 1
  "${ADB[@]}" shell input keyevent KEYCODE_BACK   # hide keyboard so Continue is tappable
  wait_ui 1; shot 03_phone_entered
  tap_desc "Continue"; wait_ui 5

  log "Enter OTP $OTP"
  read -r OCX OCY < <(edittext_center)   # first OTP box / hidden pin field
  "${ADB[@]}" shell input tap "${OCX:-326}" "${OCY:-1200}"; wait_ui 1
  "${ADB[@]}" shell input text "$OTP"; wait_ui 1; shot 04_otp_entered
  tap_desc "Confirm"; wait_ui 6; shot 05_after_confirm

  log "Grant post-login permission dialogs (contacts / mic+location)"
  for r in 1 2 3 4; do tap_desc "Allow" || tap_desc "While using the app" || break; wait_ui 2; done
  wait_ui 2; shot 06_home
  log "Done — expect the runner home ('Hi <name>')."
}

# Run the flow unless sourced for helpers only.
[ "${BASH_SOURCE[0]}" = "$0" ] && run_login
