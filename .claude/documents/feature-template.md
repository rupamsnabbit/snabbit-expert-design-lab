---
description: Feature MVI contract + pointer to the canonical folder structure. Loaded by build-feature and review-changes.
---

# Feature Template — Snabbit Runner KMP

## Folder structure & collapse rules
**Canonical layout, responsibility boundaries, and collapse rules → [`cmp-architecture-structure.md`](cmp-architecture-structure.md)** (single source of truth). In brief:
- Full per-feature shape: `<feature>/{domain, data, ui, di}` under `shared/src/commonMain/kotlin/com/snabbit/runner/shared/features/` (navigation is **BUILT** — `NavigationController`, no per-feature `navigation/` folder; a large feature may split into `<feature>/<slice>/…` + `shared/` per the Expand rules — see that doc).
- **Start lean, keep collapse:** omit any layer that carries no logic — a minimal feature is `ui/` + `data/` + `di/`. Never create a pass-through `Repository`/`UseCase` (forwards one method → delete it; the ViewModel uses the DataSource directly).
- Tests in `commonTest/.../<feature>/`: one `Fake<Seam>` per seam (no mocks) + `<Feature>ViewModelTest` (load success, load failure, each intent).
- **Sliced feature (Expand rules, `cmp-architecture-structure.md`):** `*Test.kt` mirror the slice path (`commonTest/.../<feature>/<slice>/…Test.kt`); fakes shared across ≥2 slices live once at the **feature-root** `commonTest/.../<feature>/` — never duplicate a fake per slice.

## MVI Contract
- `<Feature>Screen.kt` — stateless; wrapped in `SnabbitScreen`; receives `UiState` + intent lambdas, **never** the ViewModel.
- `<Feature>ViewModel.kt` — `androidx.lifecycle.ViewModel`; one public `fun onIntent(intent)` with exhaustive `when`, handlers `private`; `viewModelScope` only.
- **State exposure (UDF):** exactly one `private val _uiState = MutableStateFlow(UiState())`, exposed read-only as `val uiState: StateFlow<UiState> = _uiState.asStateFlow()`. Mutate ONLY via `_uiState.update { }` — never `_uiState.value =`, never a public `MutableStateFlow`/setter/`var` state field. Screen collects via `collectAsStateWithLifecycle()`.
- `ui/contracts/<Feature>Contract.kt` — Intent (sealed, one entry per user action) + UiState (immutable; derived booleans like `canConfirm`; list fields `ImmutableList<T>`; transient feedback as nullable fields) — one file, feature-first. **Navigation via the injected `NavigationController` (not a Channel SideEffect); add a `SideEffect` (Channel) only for a rare non-nav one-shot** (per D2, `core-facts.md`).
- `<Feature>DataSource.kt` (`data/`) — `suspend`, main-safe by contract; impl handles dispatchers.
- Errors → `AppErrorType`; one-shot effects per **D2** (both `core-facts.md`).
- i18n: server-driven labels via the feature's Strings seam; composeResources `strings_<feature>.xml` is the **default fallback** — the **forward standard** for new features (the legacy `language` data-object seam is exempt; per `cmp-architecture-structure.md`).
