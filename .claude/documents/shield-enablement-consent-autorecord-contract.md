---
title: Snabbit Shield — Enablement + Consent + Auto-Record Contract (verified from Flutter impl)
scope: /Users/Prabhu/Development/Projects/2-snabbit-runner-app (Flutter/Dart) — the live implementation. Verified by deep read, file:line throughout.
purpose: The authoritative contract KMP must reproduce for turning the shield ON — partner/customer enablement, runner consent, and auto-record. Resolves plan decision D-5.
companions: shield-backend-integration-analysis.md, shield-plugin-integration-client-analysis.md, kavach-kmp-integration-plan.md
produced: 2026-07-10
status: verified as-implemented (facts). Native `safety_shield` plugin internals out of scope where noted.
---

# Shield Enablement / Consent / Auto-Record Contract

Everything that decides whether the shield turns on, records, and auto-starts — verified against the Flutter code. Three independent backend signals + runner consent + one RC gate combine to drive it.

## 1. The signals (source of truth = backend)

| Signal | Backend source | JSON path | Type / default | In-repo binding | file:line |
|---|---|---|---|---|---|
| **Partner enablement** `safetyShieldEnabled` | `GET /api/v1/runners/me` | `safety_shield.enabled` | `bool`, default **false** | `UserProfile.safetyShieldEnabled` | user_profile.dart:681,793,1008 |
| **Runner consent** `consentGiven` | `GET /api/v1/runners/me` | `safety_shield.consent_given` | `bool?`, default **null** | `UserProfile.consentGiven` | user_profile.dart:680,792,1009 |
| **Consent timestamp** `consentAt` | `GET /api/v1/runners/me` | `safety_shield.consent_at` | `String?` | parsed + serialized but **never read (dead)** | user_profile.dart:682,1010,873 |
| **Customer consent (per-job)** | `GET /api/v1/runners/me/app/current_state` | `widget_data.snabbit_shield_consent_enabled` | dynamic `== true`, absent→false | raw map read (no typed model) | safety_shield_adapter.dart:316; job_accepted.dart:882 |
| **Auto-enable (per-job)** | `GET /api/v1/runners/me/app/current_state` | `widget_data.snabbit_shield_auto_enabled` | dynamic `== true`, absent→false | raw map read | safety_shield_adapter.dart:317; job_accepted.dart:884 |
| **ML detection (RC)** | Firebase Remote Config | key `expert_shield_ml_detection_enabled` | `bool`, default **false** | fed into `ShieldConfig.mlDetectionEnabled` | remote_config_keys.dart:95; adapter:940-973,865 |

**`widget_data` origin (verified chain):** `RunnerHttp.runnerAppCurrentState()` (`GET /api/v1/runners/me/app/current_state?lat&lng&battery&is_fg`, runner_http.dart:169,327-329) → `RunnerRtDataProvider._fetchData` → `WidgetInfo.fromMap` (`name=widget_name`, `data=widget_data`, runner_rt_data.dart:41-43) → `partner_home.dart:334-336` passes into `adapter.onWidgetChanged(widgetName, widgetData)`. The two `snabbit_shield_*` booleans have NO typed Dart model (read off the untyped map). **Server side is now traced — see §9 (backend `snabbit-tech/maestro-core`).** Same envelope also arrives via FCM-cached `current_state` (runner_rt_data.dart:426-429).

## 2. Combination logic (quoted, verified)

`safety_shield_adapter.dart:314-320`:
```dart
final partnerShieldEnabled = _userProfile.user?.safetyShieldEnabled == true;
final customerConsentGiven = widgetData?['snabbit_shield_consent_enabled'] == true;
final autoEnabled          = widgetData?['snabbit_shield_auto_enabled'] == true;
_isShieldEnabled = partnerShieldEnabled && customerConsentGiven;   // :319
_autoEnabled     = autoEnabled;                                     // :320
```

| Derived gate | Expression | file:line |
|---|---|---|
| Shield enabled | `partnerShieldEnabled && customerConsentGiven` | :319 |
| Auto-start | `_isShieldEnabled && _autoEnabled && _currentJobId != null` | :354 |
| Card visible | `_isShieldEnabled && _currentWidgetName == 'RUNNER_JOB_IN_PROGRESS'` | :167 |
| SOS allowed | `consentGiven == true` (runner's own consent, separate) | :725 |

**Note the two distinct "consents":** `customerConsentGiven` (per-job widget flag) gates `_isShieldEnabled`; `consentGiven` (runner's own, from profile) gates SOS + shield-start `ensureConsent`. Nothing enforces consistency between them.

## 3. Runner-consent activation API (contract)

`ShieldHttp.activateSnabbitShield()` — shield_http.dart:185-216.

| Field | Value |
|---|---|
| Method / path | `POST api/v1/runners/me/safety-shield/consent` (via `GlobalState().serverPath`) |
| Headers | `{}` — auth injected by `HttpService` interceptor |
| **Request body** | `{ 'consent': true, 'consent_version': '1.0' }` — **both hardcoded** (shield_http.dart:191) |
| Response | **not parsed** — raw `Response?` returned; no body field read |
| Success | strictly `statusCode == 200` → caller sets `UserProfileProvider.consentGiven = true` (consent_provider.dart:124) + `expertShieldConsentGiven` |
| Failure | logs `activate_consent {non_200 \| null_response \| exception}`; returns false |

### `consent_version` — VERDICT (resolves prior conflict + plan D-5)
**Sent: YES, hardcoded `'1.0'` at shield_http.dart:191.** But: never read back, never stored, never compared. `needsConsent` keys only off `consentGiven != true` (consent_provider.dart:35) — **version-blind**. If the backend bumps the required version, the app does **not** detect staleness or re-prompt. So: the *field is part of the contract*; *version-drift re-prompt is NOT implemented*.

### Revoke — VERDICT
**No in-app revoke.** Only writer of `consentGiven` is the setter (user_profile.dart:583), only caller writes `true` (consent_provider.dart:124). No `= false`, no deactivate endpoint anywhere. Consent is **write-once-true** from the app; backend can un-set via `/runners/me` → `consent_given` returning non-true, reflected on next fetch.

## 4. Consent gating + prompt

| Aspect | Rule | file:line |
|---|---|---|
| `needsConsent` | `user?.consentGiven != true` (both null and false → needs) | consent_provider.dart:35 |
| Null semantics | null = no backend decision → **needs consent** (deliberate privacy fix) | :29-34 |
| Widget blocklist | `blockedShieldConsentWidgets` (appConfig) else fallback `[RUNNER_JOB_POST_ACCEPT, RUNNER_JOB_CHECK_IN, RUNNER_NEW_JOB, RUNNER_SUSPENDED]` | :20-27,37-38 |
| Opportunistic prompt | `showConsentIfNeeded` — needs `safetyShieldEnabled`, respects dismiss | :42-51 |
| Hard-gate prompt | `ensureConsent` — ignores dismiss, awaits open sheet | :57-72 |
| Gated until consent | SOS trigger (adapter:725); shield-start (Gate 1 `ensureConsent`) | — |

## 5. Persistence + source of truth

- **Backend `/runners/me` is authoritative.** `safetyShieldEnabled` + `consentGiven` re-hydrate on every `UserProfile.fromMap` (user_profile.dart:213,374,452,528,562). No local persistence; no restart survival — flags are false/null until the next profile fetch. `toMap()` is a PATCH-back for registration, not local storage.
- Enablement (`_isShieldEnabled`, `_autoEnabled`) recomputed **every** `onWidgetChanged` tick from live `current_state` (volatile).

## 6. Auto-record (auto-start) contract

**Flow:** `current_state` change → `partner_home.onWidgetChanged` → adapter computes gates → **auto branch** (adapter:350-358, post-frame + `context.mounted`): `onJobStartedAndAutoStart(context)` → `onJobStarted()` → `updateStorageStatus()` → `startShield(trigger: auto)` → `syncActiveSosState`. Gate chain identical to the precondition chain (consent→mic→battery→storage→encryptor→queue) documented in the client-integration doc §4a.

**Trigger enum** (`enums.dart:982-989`): `auto`, `manual`, `sos` — **no `resume`** (resume reuses auto/manual; "resume" is only an analytics string).

| Trigger | Mic behaviour | Persistence | Cadence pair |
|---|---|---|---|
| `auto` | **never requests mic** — `trigger != auto` guard (controller:220-221); silent degrade to accel/monitoring-only if denied | none | `recordingDurationSec`/`recordingIntervalSec` |
| `manual` | requests mic | writes `shield_manual_monitoring_active` pref (adapter:392,982-995) | `monitoringDurationSec`/`monitoringIntervalSec` |
| `sos` | requests mic | none | `sosRecordingDurationSec`/`sosRecordingIntervalSec` |

**Pre-check-in mic hard gate** — `job_accepted.dart:881-898` `_checkShieldMicBeforeCheckIn`: when **both** `snabbit_shield_consent_enabled && snabbit_shield_auto_enabled` (:886) and mic not granted → non-dismissible `hardGate:true` dialog before OTP (called :974,:1109). The one place auto forces mic — at check-in, before the job.

**Recording cadence config** (all supplied to native in one `ShieldConfig`; native picks per `activeTrigger`): duration/interval defaults — auto/default 5s/5s, manual 5s/5s, SOS 10s/1s, SOS-pending 5s/5s (adapter:815-897; RC keys in the enablement table + client doc §10).

## 7. Gaps (verified — carry into KMP as decisions)

| # | Gap | Evidence |
|---|---|---|
| E1 | `consent_version` sent (`'1.0'`) but never validated → **no re-prompt on version drift** | shield_http.dart:191; consent_provider.dart:35 |
| E2 | **No in-app consent revoke** — write-once-true; backend-only un-set | user_profile.dart:583; consent_provider.dart:124 |
| E3 | `consent_at` parsed + serialized but **dead** (never read) | user_profile.dart:682,873,1010 |
| E4 | `widget_data` shield flags have **no typed model** in the app; absent key silently = false. (Backend now traced — §9.) | adapter:316-317 |
| E5 | Auto silently degrades to no-recording on mic-denied (no prompt during auto-start; only pre-check-in gate covers it) | controller:220-226 |
| E6 | **Auto vs manual restart divergence** — only manual persists a breadcrumb; if `snabbit_shield_auto_enabled` flips false mid-shift, an auto session is NOT restored on resume (drops to monitoring-only) | adapter:391-393,606 |
| E7 | Resume-after-mic-revoked hardcodes `trigger: auto` — relabels a manual session as auto | adapter:513-523 |
| E8 | `_autoEnabled` volatile — a transient malformed `current_state` omitting the key silently disables auto for that tick | adapter:317,320 |
| E9 | Two "consent" concepts (`customerConsentGiven` widget flag vs runner `consentGiven`) gate different things with no consistency enforcement | adapter:316,319,725 |

## 8. KMP mapping (fills plan D-5 + CN-* + auto-start)

| Contract element | KMP action | Plan ref |
|---|---|---|
| `safety_shield.{enabled, consent_given, consent_at}` from `/runners/me` | expose via `ProfileGateway`-style seam | D-5 |
| `widget_data.{snabbit_shield_consent_enabled, snabbit_shield_auto_enabled}` from `/current_state` | consume from the current-state seam; combine `_isShieldEnabled = partner && customer`, `autoStart = enabled && auto && jobId` | CN-4, new |
| Consent activate `POST /safety-shield/consent {consent, consent_version}` | implement; **send `consent_version`**; decide whether to ADD re-prompt-on-drift (Flutter does not — E1) | CN-1, CN-2 |
| Revoke | none to build; re-read `consent_given` from profile (E2) | CN-3 |
| Runner-consent gate (SOS + start) vs customer-consent gate (enable) | keep both, distinct (E9) | CN-4 |
| Auto-start trigger chain + trigger enum (auto/manual/sos) | port; auto = no mic prompt + silent degrade; manual persists flag | §2, §P-3/P-7 |
| Cadence config → `ShieldConfig` | feed via RemoteConfigGateway (D-6) | P-2 |

---

## 9. Backend contract (server side of the flags) — VERIFIED in `snabbit-tech/maestro-core`

Chased via GitHub org code search. Backend = **`snabbit-tech/maestro-core`** (FastAPI); generated docs = `snabbit-tech/maestro-core-docs`. The two flags are emitted in the runner **current-state** widget payload.

**Endpoint / schema:** `GET /api/v1/runners/me/app/current_state` → work-in-progress widget. Schema `src/widget/schemas.py`: `snabbit_shield_consent_enabled: bool = False`, `snabbit_shield_auto_enabled: bool = False` (both **default False** — absent ⇒ false, matching the app's `== true` idiom).

**Single config source (ops-controlled):** `get_config_or_default(GetConfig(entity_type="tnc", entity_id="snabbit_shield"))` → `config.value` dict. Keys: `cluster_ids`, `auto_enable_cluster_ids`, `auto_enable_customer_ids`, `auto_enable_job_ids`, `auto_enable_start_time`, `auto_enable_end_time`.

**`snabbit_shield_auto_enabled` rule** — `src/booking/utils.py::is_snabbit_shield_auto_enabled(db_session, customer_id, job)` (called from the runner WIP-widget builder in `src/runner/service.py`, per test patch `src.runner.service.is_snabbit_shield_auto_enabled`). Returns **True if ANY**:
1. `job.id in config.auto_enable_job_ids`, OR
2. `customer_id in config.auto_enable_customer_ids`, OR
3. `job.booking.address.hood.cluster.id in config.auto_enable_cluster_ids`.
Else **False**. NOTE: the `auto_enable_start_time`/`end_time` **time-window check is COMMENTED OUT** (dead — read but not applied). Function is annotated `-> None` but returns bool (harmless annotation bug).

**`snabbit_shield_consent_enabled` rule — CORRECTED (verified in `src/runner/service.py`):** the runner widget does **not** compute it; it is a **pass-through of the persisted Job column** `Job.shield_consent_enabled`:
```python
# src/runner/service.py:6693 (_get_work_in_progress_widget)
"snabbit_shield_consent_enabled": next_job.shield_consent_enabled if next_job.shield_consent_enabled else False,
"snabbit_shield_auto_enabled":    is_snabbit_shield_auto_enabled(db_session, next_job.booking.customer.id, next_job) if next_job else False,
```
- Column: `src/booking/models.py` → `shield_consent_enabled: bool = Field(default=False)` (persisted per Job).
- **Set once at cart/booking creation** — `src/cart/service.py`: `shield_consent_enabled=is_snabbit_shield_enabled`, where **currently** `is_snabbit_shield_enabled = customer_svc.is_latest_tnc_version_accepted(db_session, customer.id)`. The `snabbit_shield_enabled_segment_map` (cluster/segment) lines directly above are **COMMENTED OUT** — so segment/cluster does **not** drive this flag today.
- **Live meaning:** "the job's customer had accepted the latest `snabbit_shield` TnC version when the booking was created," frozen onto the Job → surfaced to the runner. This is the customer-side link to consent versioning.
- `snabbit_shield_enabled_segment_map(db_session, customer_id, cluster_id)` (`src/customer/service.py`: True if `cluster_id in config.cluster_ids` OR customer in `CustomerSegment.SNABBIT_SHIELD_ENABLED`) is used on the **customer-home eligibility** path, NOT for the runner widget flag.

**Contrast — the two flags are populated differently:** `auto_enabled` is computed **live per request** (config rule); `consent_enabled` is a **persisted per-job snapshot** taken at booking creation.

**Operational model:** enabling the shield for a cohort = editing the `tnc/snabbit_shield` config (add cluster/customer/job ids). No code deploy needed to roll out.

**KMP implication:** these rules are **server-side only** — the KMP app must NOT reproduce them. KMP just **consumes** `widget_data.snabbit_shield_{consent,auto}_enabled` from current-state as booleans (plan CN-1). No extra KMP logic.

### Runner consent + `consent_version` reconciliation — RESOLVED (no residuals)

Runner-side consent is a separate flow from the customer widget flag. Endpoint `POST /api/v1/runners/me/safety-shield/consent` → `store_safety_shield_consent` (`src/runner/views.py`) → `store_runner_consent(db, runner_id, consent, consent_version)` (`src/safety_shield/service.py`).

- **Request schema** `SafetyShieldConsentRequest`: `consent: bool`, `consent_version: str = "1.0"` (default matches the app's hardcode). Response `SafetyShieldConsentResponse(success, consent_at)`.
- **Storage:** `RunnerOtherDetails.meta["safety_shield"] = {consent, consent_at, consent_version}` — a single **overwriting blob** (not an append-only log). So `consent_version` **is persisted**.
- **Read (`get_runner_safety_shield_status`, on every `/runners/me`):** `_parse_safety_shield_meta` returns `validated.consent` (bool) + `consent_at` only. **`consent_version` is never read or compared.** `consent_given = the stored bool`.
- **Verdict:** `consent_version` round-trips (client→store) but is **inert** — no runner-side "latest version accepted" reconciliation, so **no re-consent on version bump**. (Contrast the CUSTOMER side, which HAS `is_latest_tnc_version_accepted` comparing accepted vs currently-enabled T&C version.) This is a real gap, now confirmed on both ends.
- **Runner `enabled` correction:** `safety_shield.enabled` (app's `safetyShieldEnabled`) is computed backend-side from **runner cluster ∈ `safety_shield_config.enabled_cluster_ids`** — a **different config** (`entity_type="safety_shield_config"`, cached 60s) than the `tnc/snabbit_shield` config driving auto/customer flags.
- **Backend key rotation (corrects client gap G5):** `get_rsa_private_key` supports `SAFETY_SHIELD_RSA_CURRENT_VERSION` + `SAFETY_SHIELD_RSA_OLD_KEYS` and stores `key_version` per recording — the backend IS rotation-ready; the client is the only part hardcoding `v1`/a bundled key.

(Earlier residual — the exact runner-side `snabbit_shield_consent_enabled` assignment — RESOLVED at `src/runner/service.py:6693`.)
