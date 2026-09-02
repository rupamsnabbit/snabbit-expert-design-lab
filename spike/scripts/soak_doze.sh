#!/usr/bin/env bash
# G0 test 1 — deep-Doze keepalive survival with the FGS alive.
# Protocol: start service -> screen off -> force deep idle -> every cycle,
# publish a fresh retained snapshot and require delivery over the LIVE socket
# while dozing. Threshold (D4 default): all cycles delivered across >=30 min.
# Usage: ./soak_doze.sh [cycles=6] [interval_s=300]
set -euo pipefail
source "$(dirname "$0")/env.sh"
[ -n "$TIMEOUT" ] || { echo "need 'timeout' (Linux) or 'gtimeout' (macOS: brew install coreutils)"; exit 1; }
CYCLES="${1:-6}"; INTERVAL="${2:-300}"
"$(dirname "$0")/start_service.sh"
sleep 8
adb shell input keyevent KEYCODE_SLEEP || true
adb shell dumpsys battery unplug
adb shell dumpsys deviceidle force-idle deep || adb shell dumpsys deviceidle force-idle
echo "device in (forced) deep doze; $CYCLES cycles x ${INTERVAL}s"
PASS=0
for i in $(seq 1 "$CYCLES"); do
  adb logcat -c
  SEQ="$(date +%s)"
  "$(dirname "$0")/publish_snapshot.sh" "$SEQ" >/dev/null
  # grep -m1 exits on first match and SIGPIPEs the upstream logcat; guard so
  # `set -o pipefail` doesn't surface that 141 as a false MISS. (Verified on a
  # Samsung S24 Ultra: 3/3 delivered while the unguarded script reported 0/3.)
  set +o pipefail
  if "$TIMEOUT" 60 adb logcat -s "$TAG" | grep -q -m1 "event=applied"; then
    echo "cycle $i/$CYCLES: DELIVERED while dozing"; PASS=$((PASS+1))
  else
    echo "cycle $i/$CYCLES: MISSED (socket suspended? OEM throttle?)"
  fi
  set -o pipefail
  # step idle forward to keep doze deep between cycles
  adb shell dumpsys deviceidle step deep >/dev/null 2>&1 || true
  sleep "$INTERVAL"
done
adb shell dumpsys battery reset
adb shell dumpsys deviceidle unforce || true
echo "RESULT: $PASS/$CYCLES cycles delivered  (G0 pass = all cycles; record device model + OS skin)"
