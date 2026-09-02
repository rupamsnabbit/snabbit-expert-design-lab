---
description: Canonical CMP project + per-feature folder structure (MVI + Clean Architecture + Navigation + composeResources) for the :shared module. The single source of truth for folder/file layout and responsibility boundaries. Loaded by build-feature and the review-changes agents; feature-template.md defers here for the tree.
---

# CMP Architecture & Structure — Snabbit Runner KMP

**Canonical folder/file layout** for `:shared` features. Cross-cutting *rules* are **cited** from the recorded docs, never restated here:
- Architecture / MVI / **AppErrorType** / **D1** ViewModel / **D2** side-effects / Koin → `core-facts.md` + `feature-template.md`
- Design System (SnabbitScreen, components, tokens) → `component-catalog.md`
- Platform (CmpHostActivity **[TARGET, not yet built]**, StoreManager, background) → `platform-rules.md`
- Pinned versions / commonMain blocklist / iOS gate → `library-guide.md`

## Dependency rule
```
Data  ──►  Domain  ◄──  Presentation
```
Domain is pure Kotlin — zero knowledge of Compose, Android, iOS, or Ktor. Outer layers depend inward, never the reverse.

## MVI flow (per feature)
```
User action → Intent (sealed) → ViewModel.onIntent() → UseCase → UiState (data class) → Screen recomposes
```
- **Side-effects follow D2 (`core-facts.md`):** **navigate / go-back / dismiss via the injected `NavigationController`** (`nav.navigate(Dest)` / `nav.back()` — the controller owns the back stack, so no per-VM nav `Channel`); a **nullable `UiState` field + clear-intent** for transient feedback (error shown, save acknowledged). A `Channel(BUFFERED).receiveAsFlow()` is only for a one-shot signal that is neither nav nor state (rare). Do not route transient feedback through a Channel.
- ViewModel = `androidx.lifecycle.ViewModel` + `viewModelScope` only (D1). Errors mapped to `AppErrorType`.
- **Contract in one file (feature-first):** `ui/contracts/<Feature>Contract.kt` holds Intent (sealed) + UiState (immutable; transient feedback as nullable fields per D2). Navigation is via `NavigationController`, not a Contract `SideEffect` — add a `SideEffect` (Channel) only for the rare non-nav one-shot.

## Canonical layout (`com.snabbit.runner.shared`)
```
shared/src/
├── commonMain/
│   ├── composeResources/
│   │   ├── values/  strings.xml (fallback) · strings_<feature>.xml · errors.xml   ← keys globally unique, feature-prefixed
│   │   ├── values-<locale>/  (e.g. values-ar, values-en-rUS) — mirror only overridden files
│   │   ├── font/  drawable/  files/
│   └── kotlin/com/snabbit/runner/shared/
│       ├── App.kt                         ← root composable: Theme + NavGraph (no screen UI / no logic)
│       ├── core/
│       │   ├── navigation/  AppNavGraph · AppRoutes · DeepLinkHandler · NavExtensions   ← [PROPOSED — see Navigation below]
│       │   ├── network/     HttpClientFactory · interceptors · NetworkConstants
│       │   ├── theme/        wraps SnabbitTheme (do NOT hand-roll MaterialTheme; DS owns tokens)
│       │   ├── analytics/    AnalyticsTracker (interface) · AnalyticsEvent
│       │   ├── storage/      StoreManager seam (per platform-rules.md)
│       │   └── di/           AppModule · KoinInitializer (initKoin) · PlatformModule (expect/actual)
│       └── features/
│           └── <feature>/                 ← full shape below; auth/, home/, … follow the same
│               ├── navigation/  <Feature>NavGraph · <Feature>Routes   ← [PROPOSED]
│               ├── domain/      model/ · repository/ (interface) · usecase/
│               ├── data/        remote/ (Api + dto/) · mapper/ · repository/ (Impl)
│               ├── ui/          screens/ · components/ · viewmodel/ · contracts/ (Intent+UiState+SideEffect)
│               └── di/          <Feature>Module.kt
├── androidMain/kotlin/com/snabbit/runner/shared/
│   ├── MainActivity.kt                     ← setContent { App() }, nothing else
│   └── core/{network,storage}/ + di/       ← actual HttpClientEngine (OkHttp), StoreManager, Android Koin
└── iosMain/kotlin/com/snabbit/runner/shared/
    ├── MainViewController.kt                ← ComposeUIViewController { App() }
    └── core/{network,storage}/ + di/       ← actual HttpClientEngine (Darwin), Keychain, iOS Koin
```

## Collapse rules (kept — start lean, expand with complexity)
The full tree above is the **target shape**, not a mandate to create empty folders. Omit any layer that carries no logic:
- **`domain/`** — add only when a UseCase has real logic or a Repository combines sources/caching. A UseCase that forwards one Repository method → delete it; ViewModel calls the DataSource/Repository directly.
- **`data/repository/`** — collapse into the DataSource when there is no mapping/cache/fallback.
- **`navigation/`** — never; the built `NavigationController` replaces per-feature nav folders (see Navigation below).
A minimal feature is `ui/` + `data/` + `di/`. Never ship an empty wrapper layer.

## Expand rules — split a large feature into vertical slices
The inverse of Collapse. When one feature grows concerns that each own a full stack, split it into **vertical slices** instead of one bloated `<feature>/{data,domain,ui}`. Reference (built): `features/kavach/{sos, shield, shared}/`. Slicing a single-concern feature is over-engineering (**G8**, `engineering-guardrails.md`).
| Trigger | Action |
|---|---|
| ≥2 independently-stateful concerns (e.g. `sos`, `shield`) | one slice each: `features/<feature>/<slice>/{data,domain,ui}` |
| A concern is pure data/domain (no screen of its own) | omit its `ui/` — asymmetric slices are fine (`kavach/shield/` has no `ui/`) |
| Slices share glue (host screen, DataSource facade, DI) | put it in a `shared/` slice; the feature's **single `di/`** lives here |

- **Name `shared/` glue by ROLE, off the feature prefix** (`SafetyDataSource`, `SafetyHomeViewModel`, `SafetyModule` — not `Kavach*`) so the name states its job across slices.
- **Reserved names:** a local type must not reuse the simple name of a plugin/platform type imported in the same file. The local protection enum is `ProtectionState`, **not** `SafetyState` (that is `com.safetykavach.shield.core.model.SafetyState`, used in the same VM). Never resolve a collision by import alias.
- **Cross-slice dependency direction** — intra-feature wiring, *not* the cross-feature leak of the boundary table:

| From | May import | Never |
|---|---|---|
| `shared/` (orchestrator) | any sibling slice's public API — data/domain seam + leaf-slice `ui/` components it composes into the host | — |
| a leaf slice (`sos`,`shield`) | a sibling leaf's public data/domain **seam** when it needs the data (`sos/domain/SosCoordinator` → `shield/data/gateway/CurrentStateGateway`) | a sibling leaf's `ui/` internals |
| any slice | `core/*`, DS, another **feature's** public API | another **feature's** `data/`/`ui/` (the real cross-feature leak) |

## Responsibility boundaries (owns / never owns)
| File / folder | Owns | Never owns |
|---|---|---|
| `App.kt` | Theme + NavController wiring | screen UI · business logic |
| `core/navigation/` | root NavHost · feature-graph composition · deep-link constants | feature routes · screen UI |
| `core/network/` · `core/storage/` · `core/analytics/` | Ktor client · StoreManager seam · tracker interface | business logic · UI |
| `core/theme/` | SnabbitTheme wrapper / tokens | feature UI |
| `feature/domain/usecase/` | one business operation | Compose · Android · Ktor |
| `feature/domain/repository/` | interface contract | implementation |
| `feature/data/{remote,mapper,repository}/` | Ktor calls · DTO↔domain · fetch/cache | domain logic · UI |
| `feature/ui/contracts/` | Intent · UiState · SideEffect | business logic |
| `feature/ui/viewmodel/` | state (`viewModelScope`) · use-case calls | UI · NavController |
| `feature/ui/screens/` | layout (in `SnabbitScreen`, DS components) · collect state · fire intents | direct navigation · business logic |
| `feature/ui/components/` | feature-scoped reusable UI (DS-based) | state · navigation |
| `feature/di/` | Koin bindings for one feature | cross-feature bindings |
| `feature/shared/` (multi-slice only) | cross-slice glue: host Screen+VM+Contract, DataSource facade, the feature's single `di/`, reconcilers | slice-specific data/domain |
| `*/MainActivity` · `MainViewController` | platform entry · mount `App()` | navigation · ViewModels |

## i18n — server-driven labels with a composeResources fallback [FORWARD STANDARD]
- **Runtime labels are server-driven** (via the feature's Strings seam). **composeResources holds the compile-time DEFAULT FALLBACK** rendered when the server omits a key — the UI never shows a blank/missing label.
- `composeResources/` is the exact folder name (**VERIFY** for the CMP version). `values/` files merge at build — keys must be **globally unique**, so **prefix by feature** (`sos_`, `auth_`, `home_`, `error_`). `Res.string.xxx` is generated (a missing key is a compile error, not a runtime crash). Mirror only overridden files into `values-<locale>/`.
- **Legacy note:** the existing `language` feature uses a **data-object Strings seam** (`LanguageStrings.kt`, explicitly *"never CMP `Res`/`stringResource`"*) and there is **no `composeResources/` dir in the repo yet**. That is the **pre-existing** pattern — **new features follow the composeResources fallback above**; do not copy the data-object approach. `composeResources/` is **not yet created** — add it with the first feature that adopts this standard.

## Navigation — BUILT (use the integration guide)
The `App.kt` NavHost / in-`shared` `navigation/` folders above were a **PROPOSED** approach that was **superseded**. The **actual, built** navigation is: a pure-Kotlin `core/navigation/NavigationController` (owns `SnapshotStateList<Destination>`) rendered by a Nav3 `NavDisplay` in the `:app` host (`NavigationHostActivity`), with a Pigeon Flutter↔native bridge. **Do not create `App.kt`/`navigation/` NavHost folders.** To add a screen/sheet follow **`docs/KMP_NAVIGATION_INTEGRATION_GUIDE.md`**: `Destination` at the feature root (or the **slice** root for a multi-slice feature — e.g. `kavach/sos/SosActive.kt`, `kavach/shared/SafetyHome.kt`) + `nativeDestination<D>(key){…}` in the feature `di/` (the `shared/` slice `di/` when sliced, commonMain) + `nativeScreen<D>{…}` in `:app`. Sheets: state-driven `SnabbitBottomSheet` in the host screen's UiState, or `nativeScreen<D>(Presentation.BottomSheet)`.

## VERIFY before implementing (version-sensitive)
- [ ] `composeResources/` + `values-<locale>` qualifier format — your CMP version
- [ ] type-safe nav (`composable<T>` / `navigation<T>` / `toRoute`) — only once a nav dep is chosen (PROPOSED)
- [ ] `collectAsStateWithLifecycle()` — from `lifecycle-runtime-compose` (commonMain; APIs moved to common per kotlinlang lifecycle docs). In the build at `2.9.0`
- [ ] `koinViewModel()` — `koin-compose-viewmodel 4.2.1` (in the build)
- [ ] `ComposeUIViewController` — `androidx.compose.ui.window`
- [ ] `enableEdgeToEdge()` — `androidx.activity 1.8.0+` (Android app module)
