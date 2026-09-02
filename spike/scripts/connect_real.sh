#!/usr/bin/env bash
# End-to-end against the REAL backend: fetch mqtt_config from runners/me,
# then drive the on-device service with it. Requires: adb, python3, curl.
#
#   BASE_URL=https://<staging-host> JWT=<login access token> ./connect_real.sh
#
# Then watch:  adb logcat -s MqttSoakSpike
# Expect:      event=status status=Connected  ->  event=applied seq=... source=MQTT
# (event=applied requires a retained snapshot on your topic — trigger any state
#  change, or ask backend to run the enrolment seed / call current_state once.)
set -euo pipefail
: "${BASE_URL:?set BASE_URL to the backend base url}"
: "${JWT:?set JWT to a runner login access token}"
source "$(dirname "$0")/env.sh"

ME_JSON=$(curl -sf -H "Authorization: Bearer $JWT" "$BASE_URL/api/v1/runners/me")
eval "$(python3 - "$ME_JSON" <<'PYEOF'
import json, sys, random
me = json.loads(sys.argv[1])
cfg = me.get("mqtt_config")
if not cfg:
    print('echo "mqtt_config is null/absent — runner not enrolled (or mqtt_kmp_enabled off). Polling cohort."; exit 1')
    raise SystemExit
if cfg.get("mqtt_kmp_enabled") is False:
    print('echo "mqtt_kmp_enabled=false — kill-switch is on for this runner."; exit 1')
    raise SystemExit
cid = f'{cfg.get("client_id_prefix", "runner_x_")}spike{random.randint(1000,9999)}'
print(f'RHOST={json.dumps(cfg.get("broker_host",""))}')
print(f'RPORT={cfg.get("broker_port", 1883)}')
print(f'RTLS={"true" if cfg.get("use_tls") else "false"}')
print(f'RUSER={json.dumps(cfg.get("username",""))}')
print(f'RTOPIC={json.dumps(cfg.get("state_topic",""))}')
print(f'RCID={json.dumps(cid)}')
PYEOF
)"
echo "config: $RHOST:$RPORT tls=$RTLS user=$RUSER topic=$RTOPIC clientId=$RCID"
adb shell cmd deviceidle tempwhitelist "$PKG" >/dev/null 2>&1 || true
adb shell am start-foreground-service \
  -n "$SERVICE" \
  -a com.snabbit.runner.realtime.START_SPIKE \
  --es host "$RHOST" --ei port "$RPORT" --ez tls "$RTLS" \
  --es username "$RUSER" --es jwt "$JWT" \
  --es clientId "$RCID" --es topic "$RTOPIC"
echo "started against REAL broker -> adb logcat -s $TAG"
echo "note: self-signed staging certs will fail sslWithDefaultConfig (LLD §8 cert posture — expected until decided)"
