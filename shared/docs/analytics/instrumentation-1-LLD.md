# LLD — expert-v2 analytics instrumentation (batch 1)

Branch: `expert-v2/instrumentation-1` · Module: `:shared` (KMP) · Providers: Mixpanel + CleverTap

## 1. Goal & non-goals

Add the expert-v2 event dictionary (M2 Home, M4 Login/Logout, M5 Attendance, M6 Lunch) as
**net-new** events on the KMP side. Every event routes to **both Mixpanel and CleverTap**.
Existing legacy events are untouched (they keep flowing for non-KMP users).

Non-goals: no renames, no CleverTap profile-property API, no `$add`/`$setOnce`, no Flutter/
MethodChannel changes, no backend work. Increments are server-derived (off this branch's path).

## 2. Reality of scope (grounded in code)

Only surfaces whose VM/intent exists today can be instrumented. Verified in code:

**In this batch (screens exist):**
- `ShiftLoginViewModel` — selfie intro/capture/retake/check, login success.
- `EmergencyLogoutViewModel` — emergency logout sheet, confirm, waiver.
- `HomeViewModel` — home load/CTA, top-bar, banner tap, seva, hotspot, **mark/change attendance,
  red-card waiver (M5), end-break (M6)** (attendance+lunch are Home facets, no own VM).
- `AwolViewModel` — AWOL penalty/breach (background coordinator).

**Deferred (no VM/screen/trigger in KMP yet — fire when built):**
- no-show popup + `no_show_marked` (no client timer; backend-decided, read-side only).
- `logout_success_screen_load` (no logout VM; logout is `HomeUiIntent.TapLogout` → backend; earnings
  props unavailable here).
- `lunch_upcoming_nudge_screen_load` (server-driven; no client ~15-min trigger).
- v2 home widgets (contextual nudge / LMS / shortcuts / updates), `bottom_nav_cta_click`,
  `home_screen_scrolled` (banner impression) — widgets not built.

## 3. Architecture decision (matches existing convention)

Use the established flat wrapper pattern, **not** a domain-port/data-adapter split (that would be an
interface-with-one-impl — over-engineering vs the codebase norm; see `DelayedCheckinAnalytics`,
`CameraAnalyticsEmitter`).

- One concrete `XxxAnalytics(private val tracker: AnalyticsTracker)` per new VM/coordinator.
  Event-name + prop-key strings are `private companion object const val`.
- Injected into the VM/coordinator constructor; registered `single { XxxAnalytics(tracker = get()) }`.
- `HomeViewModel` already injects `analytics: AnalyticsTracker` and defines event consts inline in its
  companion — new Home/attendance/lunch events follow that in-file style (match the file).
- **Placement rule holds:** UI events fire in the VM intent handler; outcomes fire on the async
  continuation (e.g. selfie check result, login success); background outcomes fire in the coordinator
  (`AwolViewModel.recompute`/`onSnapshot`).
- **Routing:** add each name to `AnalyticsRoutesConfig.SEED.table` as
  `"name" to setOf(ProviderKeys.MIXPANEL, ProviderKeys.CLEVERTAP)`. `default = emptySet()` is strict —
  an unlisted event is dropped + alerted via `onUnrouted`. This is the single required central edit.
- **User properties:** the 4 `$set` writes (`current_home_state`, `next_shift_attendance`,
  `last_no_show_at`, `last_login_at`) via existing `setUserProperties` — Mixpanel-only today
  (CleverTap profile API intentionally skipped). No new user-property infra.

## 4. Instrumentation map (grounded)

### 4.1 ShiftLogin — `features/shift/presentation/login/` (new `ShiftLoginAnalytics`)
VM is hand-constructed in `ShiftLoginScreenModule.kt` (`nativeScreen<ShiftLogin>` block), not `viewModel {}`.

| Event | Fire point (ShiftLoginViewModel) |
|---|---|
| `selfie_intro_bs_load` | on `IntroSheet` phase entry (init) |
| `selfie_intro_bs_cta_click` | intent `AcknowledgeIntro` |
| `selfie_capture_screen_load` | on `Camera` phase entry |
| `selfie_capture_screen_cta_click` | intent `CameraCompleted` (CapturedMedia) / `Retake` |
| `selfie_check_result` | `startUpload()` Ok vs Validation vs Error branch |
| `selfie_retake_bs_load` | on `Validation` phase entry |
| `selfie_retake_bs_cta_click` | intent `Retake` |
| `login_success_screen_load` | `startUpload()` Ok branch (before `onShiftLoggedIn`) |

`$set last_login_at` on login success.

### 4.2 EmergencyLogout — `features/shift/presentation/emergencylogout/` (new `EmergencyLogoutAnalytics`)
VM hand-constructed in `profile/ProfileTabContent.kt`.

| Event | Fire point |
|---|---|
| `emergency_logout_bs_load` | intent `Load` |
| `emergency_logout_bs_cta_click` | intents `Confirm` / `TogglePeriodLeave` / `Dismiss` |
| `emergency_logout_confirmed` | `confirm()` Ok branch |
| `emergency_logout_waiver_bs_load` / `_cta_click` | `pendingOutcome` present / intent `AcknowledgeTakeCare` |

### 4.3 Home / Attendance / Lunch — `features/home/presentation/HomeViewModel.kt` (in-file consts)
`analytics` already injected. Add in `onIntent` branches:

| Event | Intent / point |
|---|---|
| `home_screen_load` | `Load` handler / `init` — `home_primary_state` computed from `phase`+`heroCards`+`sheet` (see `projectHomeStateFrom`); `load_trigger` initial vs refresh |
| `home_screen_cta_click` | `TapLogin`, `TapLogout`, `ConfirmMarkProvisional`, `TapChangeAttendance`, `TapHotspot/Map`, `TapSeva`, banner, end-break, etc. (one event, `cta_text` param) |
| `top_bar_cta_click` | `TapSos`, `TapSaathi`, `TapCoins` (`TapBell` is no-op — bell removed) |
| `home_banner_cta_click` | `TapBanner` |
| `mark_attendance_bs_cta_click` | `ConfirmMarkProvisional` (post-logout `MarkTomorrowAttendance` sheet) — `marking_context` distinguishes home-inline vs post_logout |
| `absent_confirmation_bs_*` | `TapAbsentTomorrow` (EarningLoss sheet) / `ConfirmMarkProvisional(false)` |
| `change_attendance_bs_*` | `TapChangeAttendance` / `ConfirmChangeAttendance` |
| `change_attendance_red_card_waiver_bs_*` | `ShowRedCardsWaived` / `AcknowledgeWaiver` |
| `end_break_confirmation_bs_cta_click` | `ConfirmEndBreak` (already fires legacy `break_confirm_end_button_clicked` — keep both) |

`$set current_home_state` on home load; `$set next_shift_attendance` on mark/change.

### 4.4 AWOL — `features/awol/` (new `AwolAnalytics`; inject into `AwolViewModel` + `AwolModule`)

| Event | Fire point (AwolViewModel) |
|---|---|
| `awol_penalty_applied` | `recompute()` expiry branch (`expired && !refreshRequestedForAnchor`) / new episode in `onSnapshot` |

## 5. Route-config additions
Add ~all batch event names to `AnalyticsRoutesConfig.SEED.table` (alphabetical), each
`to setOf(ProviderKeys.MIXPANEL, ProviderKeys.CLEVERTAP)`. Note `change_attendance_bs_load` and
`emergency_logout_bs_load` are already present — reuse, don't duplicate.

## 6. Tests
Per convention (no wrapper-only tests; cover via VM tests with `FakeAnalyticsTracker`):
- `commonTest` mirrors package. Inject canonical `core.analytics.FakeAnalyticsTracker`.
- Assert `trackedNames` / `events` for representative intents per VM (`AutoOtViewModelTest` style).
- New: `ShiftLoginViewModelTest`, `EmergencyLogoutViewModelTest`, `AwolViewModel` analytics assertions,
  and extend `HomeViewModelTest` for the new events.

## 7. Verify
`./gradlew :shared:testDebugUnitTest :shared:compileTestKotlinIosArm64`
Also confirm on-device (Mixpanel + CleverTap debug view) that events land on **both** and no event hits
`onUnrouted` — Phase 3.

## 8. Phasing
- **Phase 1:** central route lines (batch) + `ShiftLoginAnalytics` reference (class + wiring + test).
- **Phase 2:** clone across `EmergencyLogout`, `Home`(+attendance+lunch), `AwolViewModel`.
- **Deferred:** the §2 blocked list, when their screens land.

## 9. Known prop/enum gaps — deferred (PR #501 review follow-ups)

Fired but with a reduced/adjusted payload; each is an intentional deferral, not a miss:

- **`awol_penalty_applied.red_cards_received`** — sent under the spec key, but the value is the
  running `red_cards_total` (the per-penalty delta is server-owned, not on the envelope). Real delta
  needs the backend to add it to `widget_data.awol`.
- **`home_primary_state` — `idle` / `suspended`** are KMP-only states not in the M2 dictionary. They
  still ride the `home_screen_load` event attribute, but are **excluded from the `current_home_state`
  `$set`** so the profile property stays dictionary-clean. Needs a PM call to add-or-map.
- **`no_show_marked`** — fired off the home `no_show_today` **state edge** (a proxy), not the M4.1
  login-window-expiry the spec describes (no client no-show timer exists). `red_cards_count` /
  `penalty_amount` deferred (server-owned).
- **`change_attendance_bs_load` / `_cta_click`** — ship `current_status` / `new_status`; deferred:
  `change_window` (pre/post-midnight — needs IST time-of-day logic), `earn_amount`, `red_cards_at_risk`,
  `penalty_applied`, `red_cards_count`, `false_present_flagged` (server penalty data).
- **`selfie_check_result.liveness_status`** — deferred (server returns no liveness signal in the code
  list). `failure_codes` is a KMP-only triage extra, kept deliberately.
- **`selfie_intro_bs_cta_click` `dismiss` variant** — not separable: one `AcknowledgeIntro` intent
  covers both OK and scrim-dismiss (per the contract), so only `okay` is emitted.
- **Scalar completeness (deferred):** `home_banner_cta_click.banner_position`,
  `home_screen_scrolled.referral_banner_amount`, `mark_attendance_bs_load.{shift_date,non_dismissable}`,
  `lunch_upcoming_nudge_screen_load.lead_time_minutes`, `emergency_logout_confirmed.prorated_min_g`,
  `change_attendance_red_card_waiver_bs_load.{waiver_type,repeat_violation_threshold}`.
- **All `people.increment` / `set_once` profile writes are deferred** pending an increment/`$setOnce`
  primitive on `AnalyticsTracker` (`setUserProperties` is `$set`-only): `red_cards`, `total_logins`,
  `gold_coins`, `total_leaves_applied`, `attendance_waivers_used`, `emergency_logout_waivers_used`,
  `first_login_intro_seen_at`. The three writes that **did** ship (`current_home_state`,
  `next_shift_attendance`, `last_no_show_at`) are all `$set` semantics — correctly matched.
