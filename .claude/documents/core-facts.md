---
description: Internal project-specific facts Claude cannot infer from public sources or existing code. Loaded on every session. Applies to all KMP tasks.
---

# Core Facts — Snabbit Runner KMP

## ViewModel — D1 Decision (new features only)
All new features: `ViewModel` extends `androidx.lifecycle.ViewModel` (artifact: `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel:2.9.0`).
All coroutines run on `viewModelScope` — never inject, construct, or accept a `CoroutineScope`.
NOTE: the old `LanguageViewModel` injected-`CoroutineScope` example was migrated to D1 in the language refactor — don't reintroduce injected scopes in any feature.

## One-Shot Effects — D2 Decision
Scenario determines the pattern. **Navigation goes through the injected `NavigationController` (the
shared KMP nav module), not a per-VM `Channel`** — this is the adopted convention (see note below).

| Scenario | Pattern |
|---|---|
| Navigate to a destination / go back / dismiss a screen | Injected `NavigationController` — the VM calls `nav.navigate(Dest)` / `nav.back()`; the controller owns the back stack |
| Transient UI feedback (error shown, save acknowledged) | Nullable field in `UiState` + dedicated clear intent (`ErrorShown`, `PermissionBlockShown`) |
| A genuine one-shot signal that is neither navigation nor state | `Channel<Unit>(Channel.BUFFERED)` via `receiveAsFlow()` (rare — only when the two rows above don't fit) |

**Convention (adopted with the KMP navigation module).** The Safety/SOS VMs (`SafetyHomeViewModel`,
`SosActiveViewModel`) navigate via `NavigationController` and surface transient feedback via nullable
`UiState` fields + clear-intents — deliberately **NOT** `Channel`-based `SideEffect`. Nav effects route
through the shared controller (which owns the back stack across native destinations), so a per-VM
navigation `Channel` would fragment that ownership. Keep new features consistent with this.

## AppErrorType
Location: `shared/src/commonMain/.../core/network/AppErrorType.kt`
Declaration: `enum class AppErrorType(val wireValue: String)` — **NOT** named `AppError`.
Values: `NONE`, `NO_INTERNET`, `SERVER_DOWN`, `SECURITY_ERROR`, `INVALID_REQUEST`, `OTHER_ERROR`.
Always parse network error responses with `AppErrorType.fromWireValue(value)`.
Always map caught `Throwable` to `AppErrorType` before updating `UiState`.

## SnabbitScreen
Location: `shared/src/commonMain/.../ui/SnabbitScreen.kt`
Every Compose screen must wrap its content in `SnabbitScreen`. It owns: theme, `bgPrimary` background, top nav, window insets, snackbar host.
Never hand-roll theme, background, top bar, or insets inside a screen composable.

## AppDispatchers
Location: `core/AppDispatchers.kt`. Provided by Koin — resolve with `get<AppDispatchers>()`.
Always inject via constructor. Never use `Dispatchers.IO`, `Dispatchers.Main`, or `Dispatchers.Default` directly in `commonMain`.

## Koin
`koin-core` is `api()` in `shared/build.gradle.kts` — consumers get the DSL transitively. Never re-declare it in consuming modules.
Register ViewModels with `viewModel { FeatureViewModel(get(), get()) }` — never `factory { }` for a ViewModel.
