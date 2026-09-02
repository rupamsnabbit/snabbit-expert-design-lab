#!/usr/bin/env bash
# Start (or restart) the spike service on the connected device.
set -euo pipefail
source "$(dirname "$0")/env.sh"
# Lift background-start restrictions for the shell-initiated FGS start (API 31+ / OEMs).
adb shell cmd deviceidle tempwhitelist "$PKG" >/dev/null 2>&1 || true
adb shell am start-foreground-service \
  -n "$SERVICE" \
  -a com.snabbit.runner.realtime.START_SPIKE \
  --es host "$HOST" --ei port "$PORT" --ez tls false \
  --es topic "$TOPIC"
echo "started -> watch: adb logcat -s $TAG"
