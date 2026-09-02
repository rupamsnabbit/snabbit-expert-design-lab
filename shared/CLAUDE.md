# `:shared` — Compose Multiplatform module

UI here is Kotlin Multiplatform (Android + iOS). Keep `commonMain` **pure** — no
Android-only APIs. Verify with `:shared:compileTestKotlinIosArm64`.

## Building or editing a screen? Follow the `build-screen` skill.
`.claude/skills/build-screen/SKILL.md` is the standard (with a DS component
catalog beside it). In short:

1. **Wrap every screen in `SnabbitScreen`** (`com.snabbit.runner.shared.core.designsystem`) — it
   owns SnabbitTheme, the background, the top nav, window insets, and the snackbar
   host. Never hand-roll those.
2. **Design tokens only** — `SnabbitTheme.colors|typography|spacing|borderRadius.*`.
   No raw `Color(...)` or hardcoded text styles.
3. **DS components only** for anything visible (`com.snabbit.design.*`). material3
   is for layout primitives only (`LazyColumn`/`Box`/`Row`/`Column`/progress) —
   never raw `Text`/`Button`/`TopAppBar`. No DS fit? Flag it, don't hand-roll.

Golden reference: `features/language/LanguageScreen.kt` + `core/designsystem/SnabbitScreen.kt`.

## Module structure — `core/` + `features/`

Top level under `…/shared/` is exactly two packages:

- **`core/`** — cross-cutting infra with **no** dependency on any feature: analytics,
  network, storage, di, location, permissions, result, deeplink, `runnerstate`, and
  **`core/designsystem`** — the app-side design-system layer (`SnabbitScreen`,
  `OutfitFontFamily`, + `components/` DS extensions) built on top
  of the external `com.snabbit.design.*` library. It is the **only** place raw `Color`
  / material3 chrome is allowed (detekt excludes it); `features/` must use tokens.
- **`features/`** — one package per feature. A feature is layered
  `presentation → domain → data` (dependencies point **inward**; `domain/` imports no
  `data`/DTO/Compose). Features may depend on `core` and, acyclically, on other
  features; never the reverse.

**Nest vs sibling.** A sub-capability that is meaningless without its parent and rides
the parent's data/lifecycle is **nested** (e.g. `shift/lunch`, `shift/attendance` —
both facets of the shift work-day, fed by the same status stream). An independent
context with its own lifecycle stays a **sibling** feature.

## Presentation layer (MVI)

- **MVI machinery follows behaviour, not files.** Only a *behavioural unit* — a screen
  or a stateful modal flow — gets a `ViewModel` + `Contract`. Cards, rows, sheets and
  overlays are **stateless composables** (state hoisted to the screen/VM): `@Composable
  fun Foo(state, onX: () -> Unit)`. Number of MVI sets in a feature = number of
  behavioural units, never number of composables.
- **`XxxScreen`** is the entry composable for a presentation unit — routed page *or*
  `ModalBottomSheet` overlay alike (matches NiA: even the VM-wired entry is `*Screen`).
  Don't rename by render style.
- **Contract file.** State + Intent + Effect live together in one `XxxContract.kt`
  (`XxxUiState` / `XxxUiIntent` / `XxxUiEffect`), not three files.
- **Package per presentation unit** when a feature has **≥2** units — e.g.
  `shift/presentation/login/` + `shift/presentation/emergencylogout/`, each holding its
  Screen · ViewModel · Contract · Strings + its **private** composables. A single-unit
  feature stays flat.
- **Composables flat until noisy.** Keep private composables flat in the unit package;
  promote to a `ui/` subfolder only past ~6, or when families emerge (that's why
  `home/presentation/ui/{cards,sheets}` exists — it earned it).
- **Read-side projections** are `XxxProjector` (e.g. `ShiftProjector` — folds the
  widget-envelope stream into current shift/attendance status; read-only, replaceable
  by a real query endpoint).

Verify: `./gradlew :shared:testDebugUnitTest :shared:compileTestKotlinIosArm64`
