# G0 Runbook — WS0 Doze/OEM Soak

Operator checklist for the two G0 tests defined in [`README.md`](./README.md).
Fill in one **Device result** block per OEM as you go; the matrix passes only
when **all four** OEMs pass both tests. On any failure, record model/skin/OS and
raise it at G0 review (fallback = Paho-v5 fork path, LLD §5.6).

> The Android emulator is fine for a 2a smoke but is **not valid for G0** — it
> does not model OEM Doze/battery throttling. Every row below must be a physical
> device.

## Thresholds (D4 defaults — ratify at kickoff)

| Check | Pass bar |
|---|---|
| Deep-Doze delivery | **all** soak cycles delivered over the live socket, ≥30 min, screen off |
| Kill → snapshot | retained snapshot `elapsedMs` **< 5000** on wifi after service restart |
| Reconnect churn | no reconnect loop **> 6/min** in logcat during either test |

## Matrix (all required)

- [ ] Xiaomi (MIUI / HyperOS)
- [ ] Vivo (Funtouch / OriginOS)
- [ ] Oppo (ColorOS)
- [ ] Samsung (One UI)

---

## One-time laptop setup

```bash
cd /Users/mehar/Desktop/snabbit-runner-app
git switch feat/mqtt-ws0-soak-spike

# design-system dependency auth (token needs read:packages)
export GITHUB_ACTOR=alkalox-snabbit
export GITHUB_TOKEN=$(gh auth token)

# build the debug APK once; reuse the artifact on every device
flutter build apk --debug

# start the broker (leave running for the whole session)
cd spike
docker compose up -d          # :1883, dashboard http://localhost:18083
docker compose ps             # confirm mqtt-spike-emqx is up

# HOST = laptop LAN IP as seen from the phones (same wifi)
ipconfig getifaddr en0        # -> use this value below
export HOST=<laptop-LAN-IP>
export RUNNER_ID=0            # topic: maestro/user/0/state
```

macOS note: `publish_snapshot.sh` auto-selects `host.docker.internal` on Darwin,
so the publisher reaches the broker without `--network host`. Ensure macOS
firewall allows incoming connections so the phones can reach `HOST:1883`.

## Per-device procedure

Run with **one** device attached at a time (the scripts call bare `adb`), or
pin every `adb` to a serial:

```bash
adb devices -l                       # note the serial
export ANDROID_SERIAL=<device-serial># all adb/scripts now target this device

adb install -r ../build/app/outputs/flutter-apk/app-debug.apk

# Test 2 — kill recovery (do first; it's quick)
./scripts/kill_recovery.sh           # PASS line + record elapsedMs from event=applied

# Test 1 — deep-Doze keepalive survival (~30 min)
./scripts/soak_doze.sh 6 300         # ends with "RESULT: N/6 cycles delivered"

# OEM-specific kill (force-stop != OEM battery-kill): disable the OEM's
# app-lock / enable aggressive battery saver, then repeat:
./scripts/kill_recovery.sh
```

Watch markers in a second terminal: `adb logcat -s MqttSoakSpike`
Expected: `event=start` → `event=status status=Connected elapsedMs=…` →
`event=applied seq=… source=MQTT elapsedMs=…`

---

## Device results

### Device 1 — Xiaomi
- Model / skin / OS: `__________________`  (e.g. Redmi Note 13, HyperOS 1.0, Android 14)
- Kill→snapshot `elapsedMs`: `______`  → [ ] PASS (<5000) [ ] FAIL
- Soak cycles delivered: `___ / 6`  → [ ] PASS (all) [ ] FAIL
- OEM-kill (app-lock off / battery saver): [ ] recovers [ ] FAIL
- Reconnect churn ≤ 6/min: [ ] yes [ ] no
- Notes: `__________________________________________`

### Device 2 — Vivo
- Model / skin / OS: `__________________`
- Kill→snapshot `elapsedMs`: `______`  → [ ] PASS (<5000) [ ] FAIL
- Soak cycles delivered: `___ / 6`  → [ ] PASS (all) [ ] FAIL
- OEM-kill (app-lock off / battery saver): [ ] recovers [ ] FAIL
- Reconnect churn ≤ 6/min: [ ] yes [ ] no
- Notes: `__________________________________________`

### Device 3 — Oppo
- Model / skin / OS: `__________________`
- Kill→snapshot `elapsedMs`: `______`  → [ ] PASS (<5000) [ ] FAIL
- Soak cycles delivered: `___ / 6`  → [ ] PASS (all) [ ] FAIL
- OEM-kill (app-lock off / battery saver): [ ] recovers [ ] FAIL
- Reconnect churn ≤ 6/min: [ ] yes [ ] no
- Notes: `__________________________________________`

### Device 4 — Samsung
- Model / skin / OS: `__________________`
- Kill→snapshot `elapsedMs`: `______`  → [ ] PASS (<5000) [ ] FAIL
- Soak cycles delivered: `___ / 6`  → [ ] PASS (all) [ ] FAIL
- OEM-kill (app-lock off / battery saver): [ ] recovers [ ] FAIL
- Reconnect churn ≤ 6/min: [ ] yes [ ] no
- Notes: `__________________________________________`

---

## Gate decision

- [ ] **G0 PASS** — all four OEMs pass both tests → MQTT keepalive architecture confirmed.
- [ ] **G0 FAIL** — one or more OEMs failed (recorded above) → G0 review per LLD §5.6.

Teardown: `docker compose down`.

Operator: `__________`  Date: `__________`  Build (git sha): `__________`
