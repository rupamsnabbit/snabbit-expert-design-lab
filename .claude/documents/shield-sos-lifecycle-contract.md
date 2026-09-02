---
title: Snabbit Shield — Start/Resume + SOS Lifecycle Contract (core behavior)
scope: /Users/Prabhu/Development/Projects/2-snabbit-runner-app (KMP :shared) + safety-kavach plugin (consumed via includeBuild)
purpose: The authoritative core-behavior contract for STARTING/RESUMING the shield and for the SOS lifecycle — job-coupling of the shield layer vs. job-independence of SOS, the resolved-layer model, and background/killed SOS delivery. Governs SafetyDataSourceImpl.activate, ShieldLayerRestore, SafetyForegroundReconciler, SosCoordinator, triggerSos, and the notification/FCM/reconcile paths.
companions: shield-enablement-consent-autorecord-contract.md (present/auto/consent signals), shield-plugin-integration-client-analysis.md, shield-backend-integration-analysis.md, kavach-kmp-integration-plan.md
produced: 2026-07-13
status: REQUIREMENT — agreed with engineer this session. NOT yet reconciled against code; the gap-analysis (next step) verifies + drives implementation.
---

# Shield Start/Resume + SOS Lifecycle Contract

Two **independent** subsystems with **different job-coupling**. This doc governs *when each may run and how it transitions*; the enablement signals themselves (`present`, `auto`, consent) are defined in `shield-enablement-consent-autorecord-contract.md`.

## 0. Inputs (evaluated at every start/resume)

| Input | Meaning | Source |
|---|---|---|
| `validJob` | an active job exists | `CurrentStateGateway.snapshot().jobId != null` — see §1 fail-closed rule |
| `present` | partner ∧ customer-consent enabled | `shieldProfile.partnerShieldEnabled() ∧ snapshot.customerConsentEnabled` |
| `auto` | auto-record enabled (per-job) | `snapshot.autoEnabled` |

## 1. Master rule — `validJob` gates the SHIELD LAYER only (NOT SOS)

- `jobId` is **fail-closed**: a current-state **fetch/parse failure** counts as **no job** → shield layer OFF. Never fail-open. (`jobId` is also the construct that drives the job-in-progress UI.)
- The **shield layer** (accelerometer / monitoring / recording) is **tightly coupled** to `validJob`. No valid job → the entire shield layer is OFF.
- **SOS is independent** — see §3. SOS is **not** gated by `validJob`.

## 2. Shield layer — resolved-layer model

Layer is a pure function of the three inputs; additive; raise-only.

| `validJob` | `present` | recording trigger | Resolved layer | Plugin state |
|---|---|---|---|---|
| ✗ | — | — | **OFF** | IDLE |
| ✓ | ✗ | — | accelerometer-only | ACCELEROMETER_ONLY |
| ✓ | ✓ | neither | monitoring-only (mlMonitoring **auto-starts**) | MONITORING_ONLY |
| ✓ | ✓ | `auto` ∨ manual "Activate" | recording + monitoring | MONITORING |

Construct (the ONLY correct sequence):
```
if (validJob) {
    startAccelerometerOnly()                                    // floor
    if (present) startMonitoringOnly()                          // mlMonitoring auto-starts → MONITORING_ONLY
    if (present && (auto || manualActivate)) startRecording()   // → MONITORING (enables BOTH); records on EITHER path
}
```
- `startRecording()` from `MONITORING_ONLY` transitions straight to `MONITORING` (recording **and** monitoring). It is the single "enable both" call — **do NOT also call `startMonitoring()`** (redundant no-op; `startMonitoring` exists only for the `RECORDING_ONLY → MONITORING` edge, not used by this construct).
- **mlMonitoring auto-starts** on `present` (monitoring-only); it also supports the manual path.
- **recording = `auto ∨ manualActivate`** — BOTH paths record. `auto` = the auto-record flag (auto-escalation, no user tap); `manualActivate` = the user tapped **"Activate Kavach"**, which enables BOTH mlMonitoring + recording.
- **Manual recording persists across resume, keyed by `jobId`.** The "Activate Kavach" tap persists the manual intent for the current job (`ShieldManualMonitoringStore`, keyed by `jobId`), so `restore()` re-records it after a resume/restart **while the same valid job is active**; it is cleared when there is no valid job (and a job change does not match, so it won't leak into another job).

## 3. SOS — independent subsystem

- **Not** job-gated. SOS can initiate/confirm/escalate with **no active job** (an emergency must always work). Separate state machine from the shield layer.
- SOS phases: `IDLE → INITIATING → ALERT → ACTIVE → (resolved→IDLE)`.
- **Drivers (both feed one state machine):**
  - **UI touch points:** SOS button → initiate; confirmation bottom sheet → confirm/deny; escalation view → escalate/end.
  - **Plugin signals:** ML/shake detection → initiate (`ShieldEvent.SoSTriggered`); FGS notification buttons → confirm/deny/escalate (`ShieldEvent.NotificationAction`).
- **Two-way sync:** a UI action also drives the plugin (`shield.confirmSoS()` etc.); a plugin signal also updates the SOS UI. Plugin state ↔ SOS UI must never diverge.
- `jobId` is attached to SOS network calls as **metadata when available**, but is **never required** (best-effort; a null job still proceeds — on a null `sosId` from a failed initiate, keep the ALERT and fire `sos_initiate_failed`, do NOT reset).

## 4. Background / killed delivery — DECISION (a)

SOS network calls must fire in background **and** killed state. **All SOS network calls go through the KMP `SosApi`; the plugin makes NO API calls.**

| App state | Mechanism |
|---|---|
| Foreground / backgrounded (process alive) | KMP `SosApi` runs directly in-process |
| **Killed** (process dead) | native notification receiver **revives the process** → KMP `SosApi` makes the call |
| Truly-dead gap | **backend reconciliation** — `syncActiveSosState` on next foreground + FCM push drives backend-side confirm/escalate |

## 5. Lifecycle — applied WITHOUT FAIL on every transition

Every transition re-evaluates `{validJob, present, auto}` and drives the shield layer to the §2 resolved layer; SOS follows §3/§4.

| Transition | Requirement |
|---|---|
| activate (Activate tap) | §2 construct, job-gated (fail-closed) |
| foreground restore / reconcile (resume) | re-evaluate + drive to resolved layer; job ended during pause → layer OFF |
| pause → resume | never resume a layer whose precondition dropped; recording re-establishes iff `auto ∨ persistedManual(jobId)` — a manually-activated recording survives resume within the SAME valid job; a job change / no-job clears it |
| app start/stop, process restart | same re-evaluation; raise-only, never-downgrade |

## 6. Implementation status (runner-app, Stages 1–3 re-aligned to §2)

- `SafetyDataSourceImpl.activate()` — job-gated first (fail-closed `snapshot()`). The "Activate Kavach" tap is the MANUAL path → records whenever `present` (enables BOTH mlMonitoring + recording) and **persists the manual intent keyed by `jobId`**. Redundant `startMonitoring()` dropped.
- `ShieldLayerRestore.restore()` — job early-return (clears the manual flag on no-job); records iff `present ∧ (auto ∨ persistedManual == jobId)`. Redundant `startMonitoring()` dropped.
- `ShieldManualMonitoringStore` — persists the manual-activated `jobId` (keyed, not a global boolean); `restore()` re-records only when the stored id matches the current job.
- `SosCoordinator` / `triggerSos()` — job-INDEPENDENT (SOS works with no job); killed-state notification actions reconcile-before-dispatch (§4). Verified compliant otherwise.
- Plugin (safety-kavach) — mechanical state engine; validated separately for transition/emission/teardown/restart/parity (the plugin has no `jobId`/`present`/`auto` concept; the app job-gates).
