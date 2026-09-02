# Suspended Flow → CMP Migration — Spec & Plan

Branch: `feat/expert-v2-suspended` (off `feat/expert-v2-shift`)

Migrates the runner "suspended" experience from the Dart `RunnerSuspended`
widget to Compose Multiplatform, as a **card inside the CMP Home feature**.
Behavioral/data parity with the Dart side is the source of truth; the shared
mockup is used only as the visual skeleton.

## Source (Dart)
- Screen: `lib/widgets/job_in_progress/runner_suspended.dart`
- Action: `RunnerHttp.unsuspend()` → `POST api/v1/runners/me/unsuspend` (`lib/services/runner_http.dart`)
- Trigger: `current_state` returns `widget_name: "RUNNER_SUSPENDED"` (`lib/widgets/widgets_util.dart`); `widget_data` is empty today.
- Aadhaar branch flag: `UserProfileProvider.user.isAadhaarRekyc` (from `runners/me`, **not** `current_state`).

## Locked decisions
| # | Decision |
|---|---|
| 1 | **Placement:** nested in Home — a `HomeCard.Suspended` occupying the hero slot (same takeover pattern as the lunch-break card). Not a full-screen sibling feature. |
| 2 | **Parity rules content:** the image is layout-only. Anything with no Dart equivalent (Reason box, Contact Support, avatar photo, "Temporarily Suspended" title) is **not** built. |
| 3 | **Both variants built.** `isAadhaarRekyc` is read from the bridge-fed `RunnerProfileStore` (`runners/me` → `is_aadhaar_rekyc`), the same source Dart uses; degrades to `false` until Dart pushes a profile. (Previously hardcoded `false` — closed for parity.) |
| 4 | **Gating:** reuses `expert_cmp_home_screen_enabled` (default-ON). No new RC flag. |
| 5 | **Secondary CTA:** Go to Earnings → keep-host bridge to Dart. Mirrors `navigateToEarningsPage`: `isRateCardV2Effective` (from `runners/me`) → monthly-summary webview (`/app-web-view`, `webviewPath=v1/payouts/monthly-summary`), else native Payout Home (`/payout-home`). System-back returns to the suspended takeover. |
| 6 | **Copy:** exact Dart strings + i18n keys (below). |

## Two variants (Dart parity)

Both share the layout (circular warning icon → centered title → filled primary
→ outlined secondary) and the **Go to Earnings** secondary.

| | `isAadhaarRekyc == false` | `isAadhaarRekyc == true` |
|---|---|---|
| Title key | `account_suspended` — "Your documents are being verified" | `account_suspended_aadhaar` — "Your account is suspended as Aadhaar verification is incomplete" |
| Primary CTA key | `come_back_to_work` — "Come Back to Work" | `update_aadhaar` — "Update Aadhaar" |
| Primary action | `unsuspend()` POST (status mapping below) | Bridge → `/aadhaar-reverification` (no unsuspend call) |
| Post-tap CTA | `request_submitted` — "Request submitted" (locked + check) | n/a (navigates away) |
| Secondary CTA | `go_to_earnings` — "Go to Earnings" → Dart earnings | same |

### `unsuspend()` status mapping (false variant)
| HTTP | `UnsuspendResult` | UI + analytics (`expert_wants_to_join_back`) |
|---|---|---|
| 200 / 409 | `Reactivated` | lock "Request submitted" + check; `runnerStateStore.requestRefresh()`; `success` |
| 400 | `Denied(reason, message)` | lock "Request submitted"; `denied` + warning log |
| else / transport | `Failed(statusCode?)` | snackbar ("Something went wrong"); CTA stays tappable; `failed` |

## File layout
```
features/home/
  domain/model/HomeCard.kt                 # + Suspended(isAadhaarRekyc: Boolean)
  suspended/                               # nested data/domain seam
    domain/model/UnsuspendResult.kt        # Reactivated | Denied(reason,message) | Failed(statusCode?)
    domain/repository/SuspendedRepository.kt
    data/remote/SuspendedRemoteDataSource.kt   # POST unsuspend (raw result)
    data/remote/dto/UnsuspendDeniedDto.kt      # 400 body {status,message}
    data/repository/SuspendedRepositoryImpl.kt # 409/400-aware mapping
    di/SuspendedModule.kt
  presentation/
    HomeContract.kt   # + RequestComeBack, UpdateAadhaar, TapGoToEarnings intents;
                      #   suspendRequestSubmitted state; NavigateToEarnings, NavigateToAadhaarReKyc effects
    HomeViewModel.kt  # intent handling via launchAction
    HomeStrings.kt    # + 5 suspended keys/fallbacks
    ui/cards/SuspendedCard.kt              # stateless; renders both variants off state.isAadhaarRekyc
    ui/HomeCardRenderer.kt                  # + Suspended branch
  data/ShiftProjector.kt (or small mapper) # RUNNER_SUSPENDED → HomeCard.Suspended(isAadhaarRekyc = false)
commonTest/features/home/
  suspended/SuspendedRepositoryImplTest.kt
  presentation/HomeViewModelTest.kt        # + suspended branches
```

## Phased plan (PR-sized)
1. **Data + domain** — `UnsuspendResult`, remote (raw) + impl, repository (409/400-aware) + impl, DTO, DI + registration, repository unit test.
2. **Projector + model** — `HomeCard.Suspended(isAadhaarRekyc)` + `RUNNER_SUSPENDED` branch (hardcoded false) + mapper test.
3. **VM wiring** — 3 intents, submit-lock state, analytics, 2 nav effects; `HomeViewModel` tests (both variants).
4. **UI** — `SuspendedCard` (both variants) + renderer branch; effects → `KmpNavigationBridge` in `HomeTabContent`.

Verify each phase: `./gradlew :shared:testDebugUnitTest :shared:compileTestKotlinIosArm64`.

## Deferred (additive later)
Real `isAadhaarRekyc` source (profile bridge / BE field); Reason box; avatar
photo; Contact Support; native earnings / Aadhaar screens; a dedicated
kill-switch.
