#!/usr/bin/env bash
# G0 test 2 — kill recovery: force-stop the app, restart the service (stands in
# for the FCM wake, which is WS7 scope), measure time to CONNECTED and to the
# retained snapshot. Threshold (D4 default): snapshot < 5s on wifi.
set -euo pipefail
source "$(dirname "$0")/env.sh"
[ -n "$TIMEOUT" ] || { echo "need 'timeout' (Linux) or 'gtimeout' (macOS: brew install coreutils)"; exit 1; }
echo "== ensuring a retained snapshot exists =="
"$(dirname "$0")/publish_snapshot.sh" >/dev/null
echo "== force-stopping $PKG =="
adb shell am force-stop "$PKG"
sleep 2
adb logcat -c
echo "== restarting service (simulated wake) =="
"$(dirname "$0")/start_service.sh" >/dev/null
echo "== waiting for markers (30s timeout) =="
"$TIMEOUT" 30 adb logcat -s "$TAG" | while read -r line; do
  echo "$line"
  case "$line" in
    *"event=applied"*"source=MQTT"*)
      echo "PASS: snapshot applied via socket — see elapsedMs above (threshold: <5000 on wifi)"; pkill -P $$ adb 2>/dev/null; exit 0;;
  esac
done || echo "FAIL: no retained snapshot within 30s"
