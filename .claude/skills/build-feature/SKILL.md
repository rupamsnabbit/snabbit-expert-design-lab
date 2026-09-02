---
name: build-feature
description: Scaffold or extend a Compose Multiplatform feature in the :shared KMP module — a full feature module or a single screen — enforcing MVI, the Snabbit Design System, Koin wiring, iOS compilation, and tests. Use when the engineer asks to build, add, create, scaffold, or extend a feature, screen, module, or UI in the shared module, or to migrate a Flutter screen to Compose Multiplatform. Not for reviewing a diff, non-shared Flutter/Dart work, or backend code.
---

# Build Feature — Snabbit Runner KMP (Compose Multiplatform)

The one standard way to build a feature or screen in `:shared`. It **absorbs all screen-building rules** — there is no separate build-screen skill.

## Modes
- `new <feature-name>` — full module: folders, seams, ViewModel, screen, Koin, navigation, tests
- `screen <feature-name>` — screen only: add to an existing module; skip Koin + navigation

## When to use
The engineer asks to build / add / create / scaffold / extend a feature, screen, module, or UI in `shared/src/commonMain`, or to migrate a Flutter screen to Compose Multiplatform.

## When NOT to use
- Reviewing a diff / pre-PR review → **review-changes**.
- Non-shared Flutter/Dart screens, or backend / non-UI work outside `:shared`.
- A one-line change the engineer has already fully specified → just make it.

## Before writing any file — read these (do not skip)
1. `.claude/documents/core-facts.md` — ViewModel (D1), one-shot effects (D2), AppErrorType, SnabbitScreen, AppDispatchers, Koin
2. `.claude/documents/cmp-architecture-structure.md` — feature layout (incl. **vertical-slice Expand rules**), boundaries, collapse rules, i18n, navigation (**BUILT** — `NavigationController`)
3. `.claude/documents/feature-template.md` — MVI contract (`Contract.kt`) + collapse summary
4. `.claude/documents/platform-rules.md` — CmpHostActivity (**TARGET, not yet built** — screens use per-screen `ComponentActivity` today), StoreManager, background work
5. `.claude/documents/library-guide.md` — pinned versions, commonMain blocklist, iOS gate
6. `.claude/documents/component-catalog.md` — canonical DS component reference (all UI uses it)
7. `.claude/documents/engineering-guardrails.md` — no-over-engineering rules (G1–G8), enforced at Gate 7

## Design-system rules — UI is built ONLY this way
1. **Wrap every screen in `SnabbitScreen`** (`com.snabbit.runner.shared.ui.SnabbitScreen`) — it owns theme, `bgPrimary` background, top nav, window insets, snackbar host. Never hand-roll any of them.
2. **Design tokens only** — `SnabbitTheme.colors|typography|spacing|borderRadius.*`. Never a raw `Color(0x…)` or a hardcoded text style.
3. **DS components only for anything visible** (see `component-catalog.md`). material3 is allowed ONLY for layout primitives — `LazyColumn`, `Box`, `Row`, `Column`, `CircularProgressIndicator`. Never raw `Text`/`Button`/`Card`/`TopAppBar`. **No DS component fits → STOP and flag it; never hand-roll or drop to material3.**

---

## GATE 1 — Confirm scope
State: feature name · mode (`new`/`screen`) · what the screen does (user-facing) · seams needed (DataSource methods, Strings keys, analytics events).
**STOP — create nothing until the engineer confirms scope.**

## GATE 2 — Write the plan
Before touching files: full file list + paths · every DataSource method signature (`suspend fun name(): ReturnType`) · every UiState field + type · every UiIntent entry · Koin snippet (`new`) · navigation route (`new`).
**STOP — create nothing until the plan is reviewed.**

## GATE 3 — Create folders (`new` only)
Per `cmp-architecture-structure.md` (feature-first): `features/<feature>/{ui, data, di}` always; add `domain/` only when a UseCase/Repository carries real logic (collapse rules). **Default flat; split into `<feature>/<slice>/{data,domain,ui}` + one `<feature>/shared/{…,di}` ONLY for ≥2 stateful concerns (Expand rules) — never slice a single-concern feature (G8).** State any collapse/slice justification; never create an empty wrapper layer.

## GATE 4 — Write files in this order (one at a time)
1. `ui/contracts/<Feature>Contract.kt` — Intent (sealed; one entry per user action) + UiState (immutable `data class`; list fields `ImmutableList<T>`; derived booleans like `canConfirm`; transient feedback as nullable fields); **navigation via the injected `NavigationController`, not a Contract `SideEffect`** — add a `SideEffect` (Channel) only for a rare non-nav one-shot (per `core-facts.md` D2)
2. `data/<Feature>DataSource.kt` (+ `remote/`+`dto/`, `mapper/`, `repository/` only as logic warrants) — `suspend` functions only; main-safe by contract (impl handles dispatchers)
3. i18n — server-driven labels via the feature Strings seam; add the **default fallback** keys to `composeResources/values/strings_<feature>.xml` (feature-prefixed; no hardcoded user-facing strings). This is the **forward standard**; `composeResources/` does not exist yet — create it with this feature. Do **not** copy the legacy `language` data-object Strings pattern (see `cmp-architecture-structure.md` i18n note)
4. `ui/viewmodel/<Feature>ViewModel.kt` — extends `androidx.lifecycle.ViewModel`; `viewModelScope` only (never inject or construct a `CoroutineScope`); one public `fun onIntent(intent)` with exhaustive `when`, handlers `private`; catch `CancellationException` and rethrow, then `Throwable` → error state; map every error to `AppErrorType`
5. `ui/screens/<Feature>Screen.kt` — stateless; wrapped in `SnabbitScreen`; DS components + tokens only; `collectAsStateWithLifecycle()`; receives `UiState` + intent lambdas, **never** the ViewModel. Accessibility: content descriptions on icon-only controls, touch targets ≥ 48dp, labels from the Strings seam, state changes reachable via semantics
6. `ui/components/` — feature-scoped DS-based components (only if reused)
7. `Fake<Seam>.kt` (`commonTest`) — one deterministic fake per seam; no mocks
8. `<Feature>ViewModelTest.kt` — covers load success, load failure, and each intent path

## GATE 5 — Koin + navigation (`new` only)
Register the ViewModel in `features/<feature>/di/<Feature>Module.kt` (the `<feature>/shared/di/` when sliced): `viewModel { FeatureViewModel(get(), get()) }`, wired into the Koin graph. **Navigation is BUILT** — a pure-Kotlin `NavigationController` (owns the back stack) + Nav3 `NavDisplay` in the `:app` host. Add a screen via `docs/KMP_NAVIGATION_INTEGRATION_GUIDE.md`: `Destination` at the feature/slice root + `nativeDestination<D>(key){…}` in `di/` + `nativeScreen<D>{…}` in `:app`. Do **not** hand-roll `App.kt`/`navigation/` NavHost folders.

## GATE 6 — Verify — STOP if either fails
```
./gradlew :shared:testDebugUnitTest
./gradlew :shared:compileTestKotlinIosArm64
```
Fix all failures before declaring done.

## GATE 7 — Self-check before declaring done
- [ ] Feature-first layout per `cmp-architecture-structure.md`; no empty wrapper layer; sliced only per Expand rules (siblings use public seams; single `di/` in `shared/`); contract in `ui/contracts/<Feature>Contract.kt`
- [ ] No `CoroutineScope` injected or constructed — `viewModelScope` only
- [ ] No raw `Dispatchers.IO/Main/Default` in `commonMain`; `AppDispatchers` injected
- [ ] No `android.*` or non-JetBrains `androidx.*` imports in `commonMain`
- [ ] `SnabbitScreen` wraps the screen; DS components + tokens only; no hand-rolled visuals
- [ ] `collectAsStateWithLifecycle()`; screen receives `UiState` + lambdas, not the ViewModel
- [ ] List fields in `UiState` are `ImmutableList<T>`; derived booleans on `UiState`
- [ ] Single `private _uiState` MutableStateFlow exposed read-only via `asStateFlow()`; mutated only via `update{}` (no `.value=`, no public setter/`var`)
- [ ] No local type reuses a same-file plugin/platform type name (`ProtectionState`, not `SafetyState`)
- [ ] Errors mapped to `AppErrorType`; one-shot effects match D2
- [ ] No pinned library version bumped without explicit engineer approval
- [ ] **No over-engineering** — passes `engineering-guardrails.md` G1–G8 (no speculative layers/params/generalization; minimal state; stable deps; no premature slicing)
- [ ] Both Gradle tasks pass (Gate 6)

## Reference
No in-repo feature yet follows this standard end-to-end. The existing `language` feature **predates** it (flat layout, injected `CoroutineScope`, separate `UiState`/`UiIntent` files, data-object strings) — do **not** use it as a structural template. Follow `cmp-architecture-structure.md` + the GATEs above. `shared/src/commonMain/.../ui/SnabbitScreen.kt` is current and is the reference for screen wrapping only.
