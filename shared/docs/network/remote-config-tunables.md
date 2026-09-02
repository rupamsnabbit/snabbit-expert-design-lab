# KMP Remote-Config tunables

What is Remote-Config-driven in `:shared` today, what is next, and the pattern to
follow when adding a knob.

---

## 1. Shipped keys

All read through the **native** `core.config.RemoteConfigGateway` (Android: Firebase
RC via the official SDK; iOS: the host-provided Swift provider, else defaults) — not
the Pigeon mirror in `core/remoteconfig`. No Dart-side key list has to be kept in
sync; these are live Firebase values on both platforms. **Every key must be created
in the Firebase console before it does anything**; until then each read resolves to
the shipped default, which is the pre-change behaviour.

### Network — timeouts, retry, 401 debounce

Implementation: `core/network/NetworkTuning.kt`. Applies to **every** `:shared` HTTP
call.

| Key | Unit | Default | Clamp |
|---|---|---|---|
| `expert_kmp_network_connect_timeout_secs` | seconds | **30** | 5–120 s |
| `expert_kmp_network_receive_timeout_secs` | seconds | **30** | 5–180 s |
| `expert_kmp_network_max_retries` | count | 2 | 0–5 |
| `expert_kmp_network_retry_base_delay_ms` | ms | 500 | 100–5 000 ms |
| `expert_kmp_network_retry_max_delay_ms` | ms | 5 000 | 500–30 000 ms |
| `expert_kmp_network_401_debounce_ms` | ms | 2 000 | 500–30 000 ms |

**The 30 s timeout default is a behaviour change from the 60 s constants it replaced.**
Dart already budgets 30 s for the same current-state endpoint
(`current_state_http_timeout_seconds`), so KMP at 60 s meant one call had two budgets
depending on which client issued it. 30 s is now the shipped floor for both.

### Realtime — post-action recovery ladder

Implementation: `core/realtime/PostActionLadder.kt`, applied in `RealtimeHost`.

| Key | Format | Default | Clamp |
|---|---|---|---|
| `expert_post_action_retry_ladder_secs` | `[3,5,10,15]` or `3,5,10,15` | `[3,5,10,15]` | ≤6 rungs, each 1–120 s |

The waits **between** post-action `current_state` fetches after the first deadline
miss — the recovery path when MQTT was connected but never published the transition.
Note the first rung is `postActionDeadlineMs`, not a member of this list.

Authored as a **string**, not a JSON array: the gateway's `getStringList` decodes
strictly, so a natural `[3,5,10,15]` would fail to decode (numbers are not strings)
and silently fall back — an operator would have to know to write `["3","5",…]`. The
tolerant bracket/CSV parse matches `expert_job_audio_*_excluded_durations`.

### Semantics that apply to all of the above

- **Durations revert on non-positive.** Zero or negative restores the shipped default
  rather than clamping to the floor — the same convention `runner_http.dart` uses, so
  zeroing a key gets shipped behaviour back on both sides. Same for the ladder: an
  all-zero or unparseable value returns the shipped ladder, because an *empty* ladder
  would mean "one fetch, then give up" — a behaviour change wearing a tuning value's
  clothes.
- **`max_retries` is the exception: `0` is meaningful** ("stop retrying" — the whole
  reason the knob exists during an outage). Only a **negative** value reverts it.
- **These are per-phase budgets, not a total for the call.** `SnabbitHttpClientImpl`
  spends the connect budget **twice** — once awaiting the Dart-pushed `NetworkConfig`,
  once on token hydration — before a socket opens, and Ktor then applies the receive
  budget to *each* retried attempt. At the shipped values, the worst case for a
  retried GET is roughly `30 + 30 + 3 × 30 + backoff` ≈ **150 s**. That improves on
  the 60 s constants (~300 s), but neither key is a wall-clock ceiling on a request.
  If you need a hard per-call bound, that is a separate change — wrap `execute()` in
  one `withTimeout`.
- **A too-small connect value fails cold starts.** Because it gates the config push
  and token hydration, shrinking it does not merely fail slow requests faster — it
  starts failing cold-start requests that would have succeeded, on every KMP surface
  at once. That is what the 5 s floor is for.
- **A per-request `connectTimeoutMs`/`receiveTimeoutMs` opts that call out of the
  lever.** Both are `null` by default and should stay that way.
- **Every clamp, revert and truncation is logged** (tag `NetworkTuning`, and via
  `RealtimeHost`'s logger for the ladder), naming the key, the authored value and what
  it became. A value inside its band logs nothing. If you push a value and behaviour
  does not change, check logcat before assuming the key is wrong.
- **`retry_max_delay_ms` is a real ceiling**: `respectRetryAfterHeader` is set to
  `false`, so a server `Retry-After` cannot outrank it. The trade-off is that we no
  longer honour that header — deliberate, since this client talks only to Snabbit
  hosts and an unbounded server-controlled delay parks a runner mid-job.
- **Ktor's `maxRetries` is installed at the clamp ceiling, not the RC value.** The
  plugin reads it once at install time and Koin holds the client as a process-lived
  `single`, so the live limit is enforced inside `retryIf`/`retryOnExceptionIf`, which
  Ktor evaluates per attempt. `SnabbitHttpClientRetryTuningTest` pins every limit from
  0 to the ceiling by observed attempt count.
- **Refresh timing.** `KmpBootstrap` reads RC into `NetworkTuningStore` immediately
  after the launch `fetchAndActivate()`. The store ships with defaults already in
  place, so a request firing before that refresh uses them rather than blocking. The
  hot-path read is non-suspending; timeouts are resolved once per request, while the
  retry policy and debounce are read per attempt/response and so pick up a mid-flight
  refresh.
- **Not covered:** the image loader owns a separate `HttpClient` with its own
  `HttpTimeout` (`core/image/SnabbitImageLoader.kt`) — image fetches have different
  characteristics and are deliberately outside this lever.

---

## 2. Remaining plan

### Phase 3 — shield upload retention (next)

Extend the existing `features/kavach/shield/data/ShieldConfigFactory.kt`, which
already reads ~21 keys off the native gateway in exactly this shape — additions to a
factory, not new plumbing.

| Proposed key | Default | Clamp | Replaces |
|---|---|---|---|
| `expert_shield_upload_max_retries` | 5 | 1–10 | `ShieldUploadQueue.kt:270` |
| `expert_shield_upload_base_backoff_secs` | 5 | 1–60 | `:271` |
| `expert_shield_upload_max_backoff_secs` | 1 800 | 60–7 200 | `:272` |
| `expert_shield_upload_max_pending` | 20 | 5–200 | `:273` |
| `expert_shield_upload_max_age_hours` | 168 | 24–720 | `:274` |

The one phase where the downside is not just a slow app: during a storage or backend
incident the correct move is to *widen* pending + age so safety clips queue instead of
being dropped, then narrow again. Dropped evidence is not recoverable.

### Phase 4 — device-tail knobs: instrument before wiring

Candidates: `core/location/TrackingConfig.kt:19` (5 s interval / 30 s fix timeout),
`core/camera/ui/CameraScreen.kt:584,587` (15 s capture / 10 s init watchdogs),
`core/camera/ui/CameraViewModel.kt:558` (10 s permission check),
`core/camera/CaptureRegistry.kt:155` (15 min TTL / 5 min sweep),
`features/kavach/shared/domain/JobKavachCoordinator.kt:170` (5 × 500 ms arm retry),
`features/kavach/shield/domain/upload/ShieldUploadCoordinator.kt:124` (3 × 300 ms).

**These should not be wired next, and the reason is measurability, not effort.**

A knob is only useful if you can tell whether turning it helped. For most of these we
currently cannot: when the capture watchdog fires, `CameraViewModel.onCaptureTimeout`
converts it into `CameraResult.Error(INTERNAL_ERROR, "Capture timed out…")` — which is
indistinguishable in analytics from every other camera internal error. So we do not
know today whether that 15 s budget fires once a week or a thousand times a day, on
which devices, or whether widening it would convert failures into successes or just
make users wait longer before the same failure. Shipping an RC key there buys the
ability to change a number during an incident with no feedback on whether the change
worked.

The ordered plan:

1. **Instrument the timeout paths first.** Emit a distinct event when a watchdog fires
   — not a generic error — carrying device model, Android version, and the elapsed
   time. The cheapest version is a dedicated `CameraErrorCode`/event name for the
   timeout branches plus the equivalent for the location fix timeout, so they stop
   hiding inside `INTERNAL_ERROR`.
2. **Read the data for one release.** The question each knob must answer: does this
   timeout fire at a rate that matters, and is it concentrated in a device or OS
   cohort? A knob is justified when the answer is yes to both.
3. **Wire only what step 2 identifies**, using the Section 3 pattern, with the clamp
   band derived from the observed distribution rather than a round number.

**One exception, ready now.** `JobKavachCoordinator` already emits
`expert_shield_arm_retry_exhausted` with the attempt count when its 5 × 500 ms budget
is spent. That knob has its feedback loop already, so if that metric is non-trivial it
can skip straight to step 3 — and it is a safety path, which raises the value of
being able to widen it quickly.

### Explicitly not config-driven

Animation and presentation timings (`PULSE_MS`, `HOLD_MS`, `EXIT_MS`,
`URGENT_BLINK_MILLIS`, `WASH_*`, toast durations, `SUCCESS_DWELL_MS`,
`REFRESH_SPINNER_MILLIS`), values pinned to an asset (`ACTIVATION_LOTTIE_MS` is op 256
@ 25 fps — it tracks the Lottie file, not a preference), layout constants
(`HALO_MIN_RADIUS_DP`, `RATING_COUNT`, `MAX_FLAGS`), and unit conversions
(`SECONDS_PER_MIN`, `MILLIS_PER_SEC`). Also the 10 MiB response ceiling
(`core/network/SnabbitHttpClientImpl.kt`), which sits ~200× above the realistic worst
response — there is nothing to tune.

Not everything that is a number wants to be a flag.

---

## 3. Pattern to follow when adding a knob

`NetworkTuning.kt` is the reference. The parts that matter:

1. **Read through the native `core.config.RemoteConfigGateway`** — typed getters, live
   Firebase values, no Dart mirror to keep in sync. Use the Pigeon mirror
   (`core/remoteconfig`) only when Dart already owns the value.
2. **Clamp every value into a band**, and pick the band from what breaks if the value
   is wrong — not from a round number.
3. **Decide what "revert" looks like, and make it obvious.** Non-positive → shipped
   default for durations; for a count where zero is meaningful, use negative instead.
   Never make the revert value clamp to the floor.
4. **Snapshot into a store; never read RC on a hot path.** The gateway is `suspend` and
   touches disk. Refresh at bootstrap after `fetchAndActivate()`.
5. **The shipped default must equal the pre-RC behaviour**, so a process with no RC
   (iOS without a host provider, a fetch that never landed, a cold first launch)
   behaves exactly as it did before the knob existed. If you deliberately change the
   default — as the 30 s timeout did — say so in the KDoc and pin it with a test.
6. **Check whether the value is read once or per use.** A value captured at
   construction cannot be refreshed; one read per attempt can. Ktor's `maxRetries` is
   the cautionary case.
7. **Name the key for who owns the value.** The network keys are `expert_kmp_network_*`
   because the Dart `dio` client keeps its own separate configuration — an un-scoped
   `expert_network_*` would imply a reach they do not have.
