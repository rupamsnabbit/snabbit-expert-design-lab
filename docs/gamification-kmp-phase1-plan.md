# Gamification KMP Migration — Implementation Plan

Working branch: `claude/gamification-kmp-migration-326vyk` (off `expert-v2-shift-jobs`).
Companion to `docs/gamification-kmp-migration.md` (the inventory). This doc is the **executable
plan** — file-by-file, with acceptance tied to four Figma screens.

**Out of scope**: AWOL breach + delayed check-in penalty (stay on Flutter). Their
`LifecycleActionType` values still parse (same envelope) but get no KMP UI.

## Design references (Figma `Shift - Job Lifecycle DS`, file `WEUPV9q19eAqRbkZSBj6OY`)

| Screen | Node | What it is | Phase |
|---|---|---|---|
| Early Login reward popup | `76:44003` | Post-action reward: gold coin "10" + starburst + "EARLY LOGIN AT 7:45 AM" ribbon; login card shows coin ×1 badge | 3 |
| No Show countdown strip | `969:56763` | Home login card + "No Show in 25:12 min" risk strip + red-card ×5 pill | 2 |
| Emergency Logout sheet | `220:38847` | "Shift ending" pill + 3 consequence tiles (Red Card / Miss Full Shift / **Lose ₹250**) + Logout chip | 2 |
| Waiver bottom sheet | `222:42121` | "Warning" pill, faded −50 card, "No red card applied", green "I will not repeat again" | 3 |

Confirmed on Dart: No Show strip is the pre-action nudge system (`job_login.dart:156`
`NudgeBannerList`), not a bespoke widget — **in scope**.

---

## Phase 1 — Data layer (immediate deliverable; no UI)

New package `shared/src/commonMain/kotlin/com/snabbit/runner/shared/features/gamification/`.
Follows the `shift` feature template. iOS-pure (commonMain only).

### Files to create

```
features/gamification/
├── domain/model/
│   ├── GamificationEnums.kt        # NudgeKind, OutcomeStatus, LifecycleActionType, CtaId
│   ├── NudgeLabel.kt               # key, params: Map<String,String>, defaultText?
│   ├── PreActionNudge.kt
│   ├── SheetWarning.kt
│   ├── CtaOverride.kt
│   ├── PostActionOutcome.kt
│   └── NudgePill.kt                # NudgePillKind{None,Coin,RedCard} + deriveNudgePill()
├── domain/
│   ├── GamificationState.kt        # nudges, sheetWarnings, ctaOverrides, coinsTotal, redCardsTotal
│   └── SheetWarningSelectors.kt    # filterSheetWarnings(), ctaOverridesForSheet()
├── data/remote/dto/
│   ├── NudgeLabelDto.kt            # custom serializer: object OR legacy string
│   ├── PreActionNudgeDto.kt
│   ├── SheetWarningDto.kt
│   ├── CtaOverrideDto.kt
│   └── PostActionOutcomeDto.kt
├── data/
│   ├── GamificationParser.kt       # pure JsonObject -> lists; never throws; bad rows dropped + reported
│   └── GamificationProjector.kt    # folds RunnerStateStore.state -> StateFlow<GamificationState>
└── di/
    └── GamificationModule.kt       # Koin single { GamificationProjector(get(), get()) }
```

### DTO field map (each accepts BOTH camelCase and snake_case via `@JsonNames`)

- **PreActionNudgeDto** → `lifecycle_action_type`, `nudge_kind`, `icon_url`, `label`
  (NudgeLabelDto, legacy `title`), `gold_coins?`, `red_cards?`, `expires_at?` (Instant),
  `cta_overrides?`. `toDomain()` returns null if lifecycle/kind/icon empty or label invalid.
- **SheetWarningDto** → `lifecycle_action_type`, `cta_overrides?`, `expires_at?`.
- **CtaOverrideDto** → `cta_id`, `label?`, `gold_coins?`, `red_cards?`.
- **PostActionOutcomeDto** → `lifecycle_action_type`, `status` (required), `title_label`
  (legacy `title`), `subtitle_label?`, `gold_coins`, `red_cards`, `gold_coins_total?`,
  `red_cards_total?`, `icon_url?`. Deltas vs `*Total` balances preserved.
- **NudgeLabelDto** → `key`, `params: Map<String,String>?`, `default_text` (alias `defaultText`);
  legacy plain string → `key="legacy_literal", params={text}`. Duplicate `red_cards→redCards`,
  `gold_coins→goldCoins`, `deadline_time→deadlineTime` into camelCase for `{{placeholder}}`.

### Enum values (with `unknown` fallback so future BE values parse)

- `NudgeKind`: opportunity, risk, bonus
- `OutcomeStatus`: reward, penalty, waived (case-insensitive)
- `LifecycleActionType`: EARLY_LOGIN, LATE_LOGIN, EARLY_LOGOUT, LONG_DISTANCE, DEALLOCATION,
  EARLY_CHECKIN, ACCEPT_JOB_PENALTY, EMERGENCY_LOGOUT, AWOL_BREACH_PENALTY,
  DELAYED_CHECKIN_PENALTY, FALSE_ATTENDANCE, CONFIRM_MARK_PRESENT, PROVISIONAL_MARK_ABSENT
- `CtaId`: go_back, mark_absent, mark_present, login, accept_job, logout, **check_in**

### Projector behaviour (port of `GamificationManager`)

- `nudges`: parse `pre_action_nudges` from `widget_data` first, else top-level envelope.
- `sheetWarnings`: parse top-level `sheet_warnings`; **drop rows with `expires_at < clock.now()`**
  (inject `Clock` from `core` TimeProviders for testability).
- `ctaOverrides`: flatten nudges' overrides → `Map<ctaId.lowercase, CtaOverride>`, last-wins.
- `coinsTotal` / `redCardsTotal`: `gold_coins_total` / `red_cards_total` from envelope.
- Parsing never throws; malformed rows dropped + `CrashReporter` non-fatal (mirrors Dart's
  Crashlytics `tryFromMap`).

### Wiring

- Register `GamificationModule` in `KmpBootstrap.initialize` module list (androidMain).
- Un-defer gamification fields in `EmergencyLogoutAvailabilityDto` / shift response DTOs
  (currently `ignoreUnknownKeys` drops them — decode `sheet_warnings` + earning-loss).

### Tests (`commonTest/.../features/gamification/`)

- `PreActionNudgeDtoTest` — dual-casing, `deadline_time→deadlineTime` param dup, invalid-row null.
- `SheetWarningDtoTest` — stale-row drop with fake clock.
- `PostActionOutcomeDtoTest` — status required/empty→null, deltas vs totals, `icon_url`.
- `CtaOverrideDtoTest` — list parse, non-map drop.
- `GamificationProjectorTest` — widget-data-first precedence, override last-wins lowercase keys.
- `NudgeLabelDtoTest` — object vs legacy-string, param duplication.

**Verify**: `./gradlew :shared:testDebugUnitTest :shared:compileTestKotlinIosArm64`
(the iOS compile step enforces commonMain purity).

**Phase 1 done when**: envelope decodes to typed `GamificationState`; tests green; iOS compiles.
No visible UI change yet — but the four hardcoded seams below become swappable.

---

## Phase 2 — Components + wire annotated seams

New composables (`presentation/ui/`): `NudgeBanner`/`NudgeBannerList` (risk/bonus/opportunity
themes, `**bold**` label, countdown → `RunnerStateStore.requestRefresh()`), `NudgePillBadge`,
`CtaBadgeChip`, `NudgeTheme`, `ResolveNudgeLabel` (templating + 7-key English fallback).

Wire the four seams the KMP code comments already point at:
- **Emergency Logout** (`220:38847` / `EmergencyLogoutSheet.kt:139`): real count from
  `ctaOverrides["logout"].redCards`; add "Lose ₹X" tile; "Shift ending" pill; Logout CTA chip.
- **Attendance change** (`HomeViewModel.kt:522`): penalty / red-card-cluster variant (was `0`).
- **No Show strip** (`969:56763`): NudgeBanner risk + red-card pill + countdown in the login card.

**DS gap to raise**: highlighted/annotated `SnabbitText` variant (bold in NudgeBanner, red
"N red cards" substring in WaiverSheet) — `DS_GAPS.md` already notes this.

## Phase 3 — Post-action pipeline

`presentation/postaction/`: `PostActionCoordinator` (Koin single, Mutex re-entrancy), one
`PostActionOverlayHost` Box in the nav-host root, `PostActionPopup` (reward `76:44003` + penalty
−50 variants), starburst + ellipse-bloom backdrops, `CoinFlight`. Waived (`222:42121`) →
`WaiverSheet` (exists; needs real `PostActionOutcome` + fallback copy aligned to "No red card
applied"). Hook emergency logout + shift login/logout first. Callers `await` the coordinator
before `requestRefresh()`.

## Phase 4 — Per-flow adoption

As each Flutter flow migrates (attendance, job accept/check-in, home header pill), consume the
gamification feature and delete the Dart widgets. `RewardsHeaderPill` lands with the KMP balance
surface.

## Phase 5 — UI update

New design pass on the KMP components (the "update UI after" step).

---

## Split-world caveat

During migration the coin-flight lands only inside the KMP activity. KMP-completing actions run
the full popup+flight there; Flutter-completing flows keep the Dart pipeline until migrated. The
Flutter home header updates via normal state refresh, not a cross-activity animation.
