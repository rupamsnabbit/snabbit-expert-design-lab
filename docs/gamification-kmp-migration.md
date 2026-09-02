# Gamification: Dart → KMP Migration Spec

Base branch: `expert-v2-shift-jobs`. Working branch: `claude/gamification-kmp-migration-326vyk`.

This doc inventories the gamification system as it exists on the Dart/Flutter side today, maps
what already exists on the KMP (`shared/`) side, and lays out the migration plan. UI redesign is
a follow-up phase on top of this.

> **Out of scope**: the **AWOL breach** and **delayed check-in penalty** surfaces
> (`awol_breach_widget.dart`, `delayed_checkin_penalty_widget.dart`, the AWOL overlay converter,
> and the `AWOL_BREACH_PENALTY` / `DELAYED_CHECKIN_PENALTY` nudge consumers) are **not** part of
> this migration — they stay on the Flutter side. The `LifecycleActionType` values still exist in
> the KMP enum (they arrive in the same envelope and must parse cleanly), but no KMP UI is built
> for them.

---

## 1. What gamification is (behavioural summary)

Gamification is **fully backend-driven** (no Remote Config gates). Two data channels feed it:

1. **Polling envelope** (`runnerAppCurrentState`): carries `pre_action_nudges`, `sheet_warnings`,
   and authoritative balances `gold_coins_total` / `red_cards_total`.
2. **Per-action API responses** (login, logout, accept job, deallocation, early check-in,
   emergency logout, attendance mark, auto-login ack): carry a `post_action_outcome` that drives
   the reward/penalty popup → coin-flight → header-balance-update sequence, or the waiver sheet.

Four surface types:
- **Nudge banners/strips** (pre-action): opportunity / risk / bonus themed banners with optional
  coin/red-card pill and countdown-to-expiry.
- **CTA badges**: coin/red-card chips inline on action buttons (login, accept_job, check_in,
  logout, mark_absent, mark_present, go_back), resolved from `cta_overrides`.
- **Sheet warnings**: per-lifecycle-action CTA overrides for bottom sheets (attendance flows,
  emergency logout, false attendance).
- **Post-action outcome**: full-screen popup (gold coins pulse / red cards) → animated coin
  flight into the home header pill → balance update; `status == waived` short-circuits to the
  "red cards waived off" bottom sheet.

---

## 2. Dart-side inventory (current state)

### 2.1 Models — `lib/models/gamification/`

| File | Type | Fields / values (JSON keys accept BOTH camelCase and snake_case) |
|---|---|---|
| `gamification_constants.dart` | `NudgeKind` | `opportunity`, `risk`, `bonus` (`nudge_kind`) |
| | `OutcomeStatus` | `reward`, `penalty`, `waived` (`status`, case-insensitive) |
| | `LifecycleActionType` | `EARLY_LOGIN`, `LATE_LOGIN`, `EARLY_LOGOUT`, `LONG_DISTANCE`, `DEALLOCATION`, `EARLY_CHECKIN`, `ACCEPT_JOB_PENALTY`, `EMERGENCY_LOGOUT`, `AWOL_BREACH_PENALTY`, `DELAYED_CHECKIN_PENALTY`, `FALSE_ATTENDANCE`, `CONFIRM_MARK_PRESENT`, `PROVISIONAL_MARK_ABSENT` |
| | `CtaId` | `go_back`, `mark_absent`, `mark_present`, `login`, `accept_job`, `logout` (+ live `check_in` used verbatim in job_accepted) |
| `nudge_label.dart` | `NudgeLabel` | `key`, `params`, `default_text`. Legacy plain-string → `key='legacy_literal'`, `params={text}`. Auto-duplicates `red_cards`/`gold_coins`/`deadline_time` params into camelCase for `{{placeholder}}` templating. |
| `pre_action_nudge.dart` | `PreActionNudge` | `lifecycle_action_type`, `nudge_kind`, `icon_url`, `label` (NudgeLabel, legacy `title`), `gold_coins?`, `red_cards?`, `expires_at?` (ISO datetime), `cta_overrides?`. `tryFromMap` drops rows missing lifecycle/kind/icon/valid label. `firstOfType(type)` list extension. |
| `post_action_outcome.dart` | `PostActionOutcome` | `lifecycle_action_type`, `status` (required), `title_label` (legacy `title`), `subtitle_label?`, `gold_coins` (delta), `red_cards` (delta), `gold_coins_total?`, `red_cards_total?` (authoritative balances), `icon_url?`. Getters `isReward`/`isPenalty`/`isWaived`. |
| `sheet_warning.dart` | `SheetWarning` | `lifecycle_action_type`, `cta_overrides?`, `expires_at?`. UI reads only lifecycle (sheet match) + overrides. |
| `cta_override.dart` | `CtaOverride` | `cta_id`, `label?` (NudgeLabel), `gold_coins?`, `red_cards?`. `hasCoinBadge`/`hasRedCardBadge`. Parse errors → Crashlytics non-fatal. |
| `nudge_pill.dart` | `NudgePillDisplay` / `NudgePillKind{none,coin,redCard}` | `deriveNudgePill(goldCoins, redCards)`: coins>0 → coin, else redCards>0 → redCard, else none. |

### 2.2 Services

- **`lib/services/gamification_manager.dart`** — singleton, parse-only, never throws:
  - `parseNudges(widgetData, envelope)` — `pre_action_nudges` from widget data first, else envelope.
  - `parseSheetWarnings(raw)` — parses top-level `sheet_warnings`, **drops stale rows** (past `expires_at`).
  - `resolveCtaOverridesFromNudges(...)` / `resolveCtaOverrides(...)` — flatten to
    `Map<ctaId.lowercase, CtaOverride>`, last-wins.
- **`lib/services/gamification/post_action_overlay_controller.dart`** — singleton orchestrator:
  `showFromResponse(responseData, actionType)` parses `post_action_outcome` and runs:
  waived → `WaiverBottomSheet`; otherwise popup (`PostActionPopup` DialogRoute) → measure asset
  centers → `CoinFlightOverlay` OverlayEntry flying into `HomeRewardsHeaderPillKeys`
  coin/red-card icon targets (5s timeout) → `RunnerRtDataProvider.applyPostActionBalance(deltas, totals)`.
  Re-entrancy guarded; errors → Crashlytics non-fatal.

### 2.3 Widgets — `lib/widgets/gamification/` (+ satellites)

| Widget | Purpose / visuals (Figma refs in source) |
|---|---|
| `NudgeBanner` / `NudgeBannerList` / `NudgeStripTile` (`nudge_banner.dart`) | Themed banner per nudge. risk: `#F9FAFB→#FECACA` gradient, `#FECACA` border; bonus: `#1D4ED8→#3B82F6`, `#93C5FD`, white text; opportunity: `#FFFBEB→#FFF4C7`, `#FDE68A`. `**bold**` markdown in label. Trailing pill via `deriveNudgePill`. 1s countdown timer; on expiry triggers `fetchDataNow()`. Figma 5510:15594. |
| `NudgePillBadge` (`nudge_pill_badge.dart`) | Coin/red-card count pill. Exports CDN icon URLs (`assets-expert.snabbit.com/payouts/nudges/gold_coin.png`, `red_card_straight.png`). |
| `CtaBadgeChip` (`cta_badge.dart`) | Inline chip on CTA buttons from a `CtaOverride`; red preferred when both present. Figma 7114:113392 / 6705:140052. |
| `PostActionPopup` (`post_action_popup.dart`) | Blur+dim full screen; 1–9 pulsing coin/red-card assets (count clamp, size scales 120→65 by count, 3/row, overlap); parallelogram title ribbon (reward `#B45309`, penalty `#B91C1C`); starburst + ellipse bloom backdrops; fires `onReadyForFlight(centers)`. Figma 5510:15060/15214. |
| `PostActionSoftStarburst` / `PostActionEllipseBloom` | Rotating 10-ray starburst (8s) and blurred glow ellipse; reward warm / penalty red palettes. Figma 6705:144671/144672. |
| `CoinFlightOverlay` (`coin_flight_overlay.dart`) | Staggered tween of each asset from popup position to header target, size →18. |
| `WaiverBottomSheet` (`waiver_bottom_sheet.dart`) | Non-dismissible; warning pill, 40 %-alpha red-card cluster, "I will not repeat" green gradient CTA. Figma 6705:143542. |
| `RedCardIllustration` / `SingleRedCard` / `ShimmerStripes` (`shared_red_card_widgets.dart`) | Red-card cluster (clamp 1..9), 69×98 `red_card_display.png`, diagonal shimmer. |
| `resolveNudgeLabel` (`resolve_nudge_label.dart`) | `NudgeLabel` → localized string: legacy literal → server `default_text` via `LanguageProvider.getFormattedMessage` → client English fallback map (7 `nudge_*` keys). |
| `sheet_warning_attendance.dart` | Helpers: `filterSheetWarnings`, `ctaOverridesForSheet`, `attendanceButtonLabelFromCta`, `attendanceSheetCtaButtonChild`. |
| `NudgeTheme` (`lib/widgets/awol/nudge_theme.dart`) | risk/opportunity/bonus color bundle from `AppColors.nudge*` tokens (`lib/utils/colors.dart:75-90`). |
| `HomeRewardsHeaderPill` (`lib/widgets/partner_home/home_rewards_header_pill.dart`) | Dual coin/red-card header segment with rolling-digit animation; global keys are coin-flight landing targets; taps route to `v1/payouts/rewards?type=gold_coins|red_cards` webviews. Figma 5510:12881. |

### 2.4 State & integration points

- **`lib/providers/runner_rt_data.dart`** holds `preActionNudges`, `ctaOverrideMap`,
  `sheetWarnings`, `gamificationCoins`, `gamificationRedCards`; populated from the polling
  envelope; `applyPostActionBalance(...)` applies deltas/totals post-flight.
- **Consumers** (element ← data):
  - `partner_home.dart` — header pill (totals); AWOL overlay config + `AWOL_BREACH_PENALTY` nudge.
  - `job_login.dart` / `auto_login_bottom_action_button.dart` / `selfie_preview.dart` /
    `runner_logout.dart` — `login` CTA badge; `FALSE_ATTENDANCE` sheet warnings; outcome popup on
    login/logout/auto-login responses.
  - `job_start_flow/job_accepted.dart` — `check_in` CTA badge; non-penalty `NudgeBannerList`;
    `DELAYED_CHECKIN_PENALTY` nudge → `DelayedCheckinPenaltyWidget`; early-checkin outcome.
  - `job_start_flow/new_job_assigned(.dart|_v1.dart)` — `accept_job` CTA badge; nudge banners;
    `LONG_DISTANCE` / `DEALLOCATION` outcomes.
  - `attendance_flow/*` — `PROVISIONAL_MARK_ABSENT` / `FALSE_ATTENDANCE` / `CONFIRM_MARK_PRESENT`
    sheet warnings; CTA buttons `mark_absent`/`mark_present`/`go_back`; outcome on mark.
  - `emergency_logout/emergency_logout_confirmation.dart` + `drawer/drawer_menu.dart` —
    `EMERGENCY_LOGOUT` sheet warnings; `logout`/`go_back` CTAs; red-card count; outcome popup.
  - `awol/awol_breach_widget.dart`, `delayed_checkin/delayed_checkin_penalty_widget.dart` —
    red-card pills + penalty nudge strips. **(Out of scope — stays Flutter.)**
  - `common_widgets/job_payout_card.dart` / `models/payout/payout_info.dart` — payout line
    titles/subtitles are `NudgeLabel`s.
- **Tests**: `test/unit/models/gamification/{pre_action_nudge,sheet_warning,post_action_outcome}_test.dart`,
  `test/unit/widgets/gamification/{resolve_nudge_label,sheet_warning_attendance}_test.dart`.
  No tests for popup/flight/waiver widgets.
- **Debug stubs**: `lib/debug/runner_app_current_state_stubs.dart` has representative payloads.
- **No dedicated analytics events**; only `delayed_checkin_tracking.dart` emits `received_red_cards`.

---

## 3. What already exists on the KMP side

Package root: `shared/src/commonMain/kotlin/com/snabbit/runner/shared/`.

**Already present (reusable as-is or nearly):**
- **State feed**: `core/runnerstate/RunnerStateStore.kt` receives the full `current_state`
  envelope from Dart via `RunnerStatePlugin` (`com.snabbit.runner/runner_state`); gamification
  fields ride in the raw `widget_data`/envelope JSON. `requestRefresh()` calls back into Dart —
  the KMP analogue of `fetchDataNow()` for nudge-expiry refresh.
- **Red-card visual primitives**: `ui/nudges/SnabbitRedCard.kt` (`SnabbitRedCard`,
  `SnabbitRedCardGroup`, defaults), `ui/nudges/SnabbitRedCardNudge.kt`,
  `features/home/presentation/ui/sheets/RedCardClusterPlaceholder.kt`.
- **Sheets**: `WaiverSheet.kt` (waived outcome, Figma 1597:6691), `EarningLossSheet.kt`,
  `ChangeAttendanceConfirmSheet.kt` (non-penalty variant), `AttendanceSheetShell.kt` shell.
- **Emergency logout**: full flow in `features/shift/presentation/emergencylogout/` incl.
  `EmergencyConsequenceCards.kt` — but `redCardCount` is hardcoded to 1 and the "Lose ₹X" tile is
  deferred pending this port.
- **Assets bundled** in `commonMain/composeResources/drawable/`: `snabbit_red_card.png`,
  `red_card_display.png`, `full_shift_card.png`, `money_jar.png`, `header_coin.png`,
  `rupee_circle.png`, etc.
- **Infra**: Ktor `SnabbitHttpClient` + auth interceptors, Koin DI, `Result<Ok,Err>` +
  `RunnerActionError`, MVI Contract/ViewModel/Screen conventions, `SnabbitScreen` scaffold,
  design-system tokens, detekt-enforced build-screen rules.

**Explicitly missing (deferred in code comments as "gamification port"):**
- Typed decoding of `pre_action_nudges`, `sheet_warnings`, `cta_overrides`, `post_action_outcome`
  (`EmergencyLogoutAvailabilityDto` deliberately drops them).
- Waived/penalty/reward routing (what decides WaiverSheet vs popup).
- Penalty / red-card-cluster variants of the attendance sheets.
- Post-action popup + coin flight + balance surface (no coin/points UI beyond `header_coin.png`).
- A `features/gamification/` package — nothing exists yet.

---

## 4. Migration mapping (Dart → KMP)

New package: `features/gamification/` following the `shift` feature template
(DTO → `toDomain()` → repository/projector → Contract/VM → composables → Koin module).

### 4.1 Domain + data (commonMain, iOS-pure)

| Dart | KMP target | Notes |
|---|---|---|
| `gamification_constants.dart` | `features/gamification/domain/model/GamificationTypes.kt` | Kotlin enums with `unknown` fallback: `NudgeKind`, `OutcomeStatus`, `LifecycleActionType`, `CtaId` — keep the raw string alongside so unknown values pass through. |
| `nudge_label.dart` | `domain/model/NudgeLabel.kt` + `data/remote/dto/NudgeLabelDto.kt` | Custom `KSerializer` (accepts object or legacy string). Keep snake→camel param duplication for `{{placeholder}}` templating. |
| `pre_action_nudge.dart` | `PreActionNudge.kt` + `PreActionNudgeDto.kt` | `@Serializable` with `@JsonNames` covering both casings (`Json { ignoreUnknownKeys; isLenient }` per existing DTO convention). `expiresAt` via kotlinx-datetime `Instant`. `tryFromMap` semantics → mapper returns null for invalid rows, list mapper drops them. |
| `sheet_warning.dart` | `SheetWarning.kt` + dto | Stale-row filtering (`expiresAt < now`) in the mapper/projector, injected `Clock` (project `TimeProviders`) for testability. |
| `cta_override.dart` | `CtaOverride.kt` + dto | Parse-error logging via `CrashReporter` (KMP analogue of the Crashlytics non-fatal). |
| `post_action_outcome.dart` | `PostActionOutcome.kt` + dto | Deltas vs `*Total` balance distinction preserved. |
| `nudge_pill.dart` | `domain/model/NudgePill.kt` | Pure function `deriveNudgePill(goldCoins, redCards)`. |
| `GamificationManager` | `data/GamificationProjector.kt` (+ small pure `GamificationParser`) | Projector folds `RunnerStateStore` envelope stream → `StateFlow<GamificationState>` (`nudges`, `sheetWarnings`, `ctaOverrides` map lowercase-last-wins, `coinsTotal`, `redCardsTotal`) — same pattern as `ShiftProjector`/`LunchProjector`. Parsing never throws; bad rows dropped + reported. |
| `RunnerRtDataProvider.applyPostActionBalance` | method on the projector/state holder | Totals win over deltas; drives the header/balance UI. |

**Per-action responses**: KMP actions that already exist (shift login/logout, emergency logout,
attendance, job accept/check-in as they migrate) get `post_action_outcome` decoding added to their
response DTOs (e.g. extend `ShiftRemoteDataSource` responses and
`EmergencyLogoutAvailabilityDto` with the deferred `sheet_warnings` / gamification fields).
Repository impls surface the parsed `PostActionOutcome?` alongside the action result.

### 4.2 UI components (commonMain Compose, DS-token based)

| Dart widget | KMP target | Status |
|---|---|---|
| `NudgeBanner`/`NudgeBannerList` | `features/gamification/presentation/ui/NudgeBanner.kt` | New. Theme from DS tokens (map the `AppColors.nudge*` hexes to `SnabbitTheme.colors`; flag any missing token to DS instead of raw `Color(...)` — raw colors are detekt-blocked outside `core/designsystem`). Countdown via `kotlinx.coroutines` ticker; on expiry → `RunnerStateStore.requestRefresh()`. `**bold**` label segments — note existing DS gap: `SnabbitText` is plain-string; needs an annotated-string variant (same gap already flagged in `WaiverSheet`). |
| `NudgePillBadge` | `ui/NudgePillBadge.kt` | New; use bundled drawables (`header_coin.png`, red-card assets) instead of CDN URLs where possible. |
| `CtaBadgeChip` | `ui/CtaBadgeChip.kt` | New; compose into `SnabbitButtonWithSpinner`-based CTAs. |
| `PostActionPopup` + starburst + bloom + `CoinFlightOverlay` | `presentation/postaction/` | New; single Compose overlay (one `Box` layer) replaces the Dart Navigator-dialog + OverlayEntry choreography — pulse/flight as `Animatable` stages in one host, no global-key measurement needed within a Compose root. |
| `WaiverBottomSheet` | reuse `features/home/.../WaiverSheet.kt` | Exists; wire real `PostActionOutcome` (currently placeholder). |
| `RedCardIllustration` cluster | reuse `RedCardClusterPlaceholder` / `SnabbitRedCardGroup` | Exists. |
| `resolveNudgeLabel` | `presentation/ResolveNudgeLabel.kt` | Port templating + the 7-key English fallback map; server `default_text` first. Localization provider seam (Strings pattern) instead of `LanguageProvider`. |
| `sheet_warning_attendance.dart` helpers | `domain/SheetWarningSelectors.kt` | Pure functions: `filterSheetWarnings`, `ctaOverridesForSheet`, label/badge helpers. |
| `NudgeTheme` | `ui/NudgeTheme.kt` | Mirrors existing Kotlin `OverlayNudgeTheme` (already referenced by Dart comment). |
| `HomeRewardsHeaderPill` | `presentation/ui/RewardsHeaderPill.kt` | New, needed once the KMP home/shift surfaces show balances; rolling-digit animation in Compose; tap → rewards webview route via nav bridge (`openFlutterRoute`). |

### 4.3 Orchestration

`PostActionOverlayController` → `presentation/postaction/PostActionCoordinator.kt`:
plain class (Koin single) exposing `suspend fun show(outcome)` consumed by feature ViewModels as a
one-shot `UiEffect`; renders through a host-level overlay composable in the KMP nav host.
Waived → `WaiverSheet`; else popup → flight → `applyPostActionBalance`. Re-entrancy via a Mutex.
Callers `await` it before `RunnerStateStore.requestRefresh()` (same "block refresh until animation
done" contract as Dart).

### 4.4 Split-world constraint (important)

Until home moves to KMP, the **header pill lives in Flutter** while actions increasingly complete
in the KMP activity. The Dart coin-flight lands on Flutter global keys — that cannot cross into
`NavigationHostActivity`. Plan:
- **Actions completing in KMP screens**: run the full popup+flight inside the KMP host, landing on
  a KMP header/balance target (or a screen-local target); push updated totals back via
  `RunnerStateStore`-triggered refresh.
- **Actions still completing in Flutter**: keep the existing Dart pipeline untouched until each
  flow migrates. Dart side is only deleted flow-by-flow, never wholesale.

### 4.5 Tests (commonTest)

Mirror the Dart suites: DTO/mapper tests for dual-casing + invalid-row dropping
(`PreActionNudge`, `SheetWarning` staleness with fake clock, `PostActionOutcome` status rules,
`CtaOverride` list parsing), `GamificationProjectorTest` (envelope precedence widget-data-first,
override last-wins lowercase keys), `ResolveNudgeLabelTest` (templating + fallbacks), plus
ViewModel tests per build-screen convention (Fake seams).
Verify: `./gradlew :shared:testDebugUnitTest :shared:compileTestKotlinIosArm64`.

---

## 5. Phasing

1. **Phase 1 — data layer** (no UI): `features/gamification/` DTOs, domain models, mappers,
   `GamificationProjector`, Koin module, commonTest suite. Un-defer the gamification fields in
   `EmergencyLogoutAvailabilityDto` / shift responses.
2. **Phase 2 — components**: NudgeBanner, NudgePillBadge, CtaBadgeChip, NudgeTheme,
   ResolveNudgeLabel, sheet-warning selectors; wire real red-card counts into
   `EmergencyConsequenceCards` (drop the hardcoded 1) and the earning-loss tile; penalty variants
   of attendance sheets.
3. **Phase 3 — post-action pipeline**: PostActionCoordinator + popup/flight/waiver routing in the
   KMP host; hook into emergency logout + shift login/logout first (already KMP).
4. **Phase 4 — per-flow adoption**: as each Flutter flow (attendance, job accept/check-in, home)
   migrates, consume the gamification feature and delete the corresponding Dart widgets.
5. **Phase 5 — UI update**: apply the new design on the KMP components (this is the "update UI
   after" step — new Figma refs to be supplied).

## 6. Open questions / risks

- **DS gap**: no annotated/highlighted-text `SnabbitText` variant for `**bold**` and highlighted
  substrings (needed by NudgeBanner and WaiverSheet). Needs a DS extension in
  `core/designsystem/components/` or a DS library ask.
- **Nudge color tokens**: verify `SnabbitTheme.colors` covers the `nudge*` palette
  (`#FEF2F2/#FCA5A5/#DC2626`, `#FFFBEB/#FDE68A/#D97706`, `#1D4ED8/#93C5FD/#3B82F6`); otherwise DS ask.
- **Icon URLs**: nudges carry CDN `icon_url`s → needs an async-image component in commonMain
  (check DS/coil3 availability) or a bundled-asset mapping.
- **Localization**: Dart resolves labels through `LanguageProvider` localization files; KMP needs
  the equivalent seam (server `default_text` covers most cases; English fallback map ports as-is).
- **Coin-flight landing target during the split-world period** (see §4.4).
- **`check_in` cta_id** is used in code but absent from Dart's `CtaId` constants — include it in
  the KMP enum.
