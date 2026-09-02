# WS0 — Doze/OEM Soak Spike (Gate G0)

Validates the two claims the whole client design rests on (LLD §6.10, §10.3):

1. **Keepalive survival:** with `SnabbitForegroundService` alive, the process is
   exempt from Doze network suspension, so HiveMQ's in-process keepalive keeps
   the socket (and deliveries) live through screen-off deep Doze — including on
   OEM skins (Xiaomi / Vivo / Oppo / Samsung) that throttle beyond stock Android.
2. **Kill recovery:** after a force-stop (stand-in for an OEM battery-kill), a
   service restart (stand-in for the FCM wake — real FCM is WS7/M2 scope)
   reconnects and receives the **retained snapshot** fast.

What ships here is **seed code, not throwaway**: the transport contract
(`core/realtime` in commonMain), the HiveMQ wrapper and the FGS are the first
increments of WS2/WS4 per the LLD structure. Only this `spike/` folder
(broker + scripts) is disposable.

## G0 thresholds (D4 defaults — ratify at kickoff)

| Check | Threshold |
|---|---|
| Deep-Doze delivery | 100% of soak cycles delivered over the live socket, ≥30 min, screen off |
| Kill → snapshot | retained snapshot `elapsedMs` < 5000 on wifi after service restart |
| Reconnect churn | no reconnect loop >6/min in logs during either test |
| Matrix | all of: 1× Xiaomi (MIUI/HyperOS), 1× Vivo, 1× Oppo, 1× Samsung |

Fail on any OEM ⇒ record model/skin/OS, then G0 review decides per LLD §5.6
(fallback = Paho-v5 fork path).

## Prerequisites

- Device(s) via adb, developer options on. Docker on the laptop.
- Build the debug APK (per team setup notes: copy `android/gradlew`,
  `local.properties`, `android/app/google-services.json` from a working
  checkout if this is a fresh one):
  ```
  GITHUB_ACTOR=<user> GITHUB_TOKEN=$(gh auth token) flutter build apk --debug
  adb install -r build/app/outputs/flutter-apk/app-debug.apk
  ```

## Run

For the full OEM matrix run, use [`G0_RUNBOOK.md`](./G0_RUNBOOK.md) — a per-device
checklist with the pass/fail fields to record as you go.

```bash
cd spike
docker compose up -d                # broker on :1883 (dashboard :18083)
export HOST=<laptop LAN IP>         # as seen FROM THE PHONE (emulator: 10.0.2.2)

./scripts/start_service.sh          # start FGS; adb logcat -s MqttSoakSpike
./scripts/publish_snapshot.sh       # should log: SPIKE_MARKER event=applied seq=... source=MQTT
./scripts/kill_recovery.sh          # G0 test 2
./scripts/soak_doze.sh 6 300        # G0 test 1: 6 cycles x 5 min
```

Markers (`adb logcat -s MqttSoakSpike`):
`event=start` → `event=status status=Connected elapsedMs=…` →
`event=applied seq=… source=MQTT elapsedMs=…`, plus `event=status
state=Disconnected(reason=…)` exercising the §6.1 reason-code mapping.

## Notes / scope cuts

- **Plaintext :1883 locally** — TLS is exercised against staging (WS9); the
  production requirement (LLD §8) is unchanged.
- The service is **exported in debug builds only** (app debug-manifest
  override) so adb can drive it, and it additionally refuses intents on
  non-debuggable builds.
- OEM battery-killer behaviour differs from `force-stop`; on lab devices also
  test the OEM's own "kill" affordances (MIUI locked-app toggle off, battery
  saver aggressive mode) and record results per device.
