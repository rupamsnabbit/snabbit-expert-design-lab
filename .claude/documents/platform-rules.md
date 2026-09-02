---
description: Android platform and CMP host integration rules — internal patterns not derivable from public sources. Loaded by build-feature skill.
---

# Platform Rules — Snabbit Runner

## Navigation host — BUILT (reuse; do not rebuild)

**Reality (verified 2026-07-09):** the native navigation stack is fully built and wired. Do **not** create a new host or nav layer — extend the existing one (guardrail G4).
- Host Activity: `:app/.../navigation/NavigationHostActivity.kt` (implements `NavigationHost`, renders the Nav3 `NavDisplay` over `NavigationController.backStack`).
- Nav3 is in the build: `androidx.navigation3:navigation3-runtime/-ui:1.1.2` + `androidx.lifecycle:lifecycle-viewmodel-navigation3:2.10.0` (Google AndroidX, **stable**) in `android/app/build.gradle`.
- Back stack owner: `:shared/.../core/navigation/NavigationController.kt` (plain state holder — `SnapshotStateList<Destination>`, not MVI).
- Flutter↔native bridge: `NavigationBridgePlugin` + Pigeon `NavigationApi` (`pigeons/navigation_api.dart`) — Flutter opens native by **key** (`openNativeDestination('key', {...})`), no URI scheme needed.

**To add a native screen / sheet:** follow `docs/KMP_NAVIGATION_INTEGRATION_GUIDE.md` — `Destination` + screen + VM in `:shared/commonMain`; `nativeDestination<D>(key, deeplinkValue){…}` (commonMain Koin) + `nativeScreen<D>{ vm = viewModel{…}; Screen(vm) }` (`:app`). Sheets/dialogs: `nativeScreen<D>(Presentation.BottomSheet)` (never a root destination), or state-driven `SnabbitBottomSheet` in the host screen's UiState. ViewModels are NavEntry-scoped via the host `ViewModelStore` (survives A→B→back).

## Storage

Use `StoreManager` (`core/storage/StoreManager.kt`) for all token and sensitive data storage.
Never use `SharedPreferences` directly for sensitive values — `StoreManager` wraps DataStore + Tink AES-256-GCM (see `androidMain` dependencies in `shared/build.gradle.kts`).

## Background Work

- Foreground services: declare `android:foregroundServiceType` in `AndroidManifest.xml` — required from API 34
- Implement `onTimeout()` for long-running foreground services on API 34+
- Deferrable background work: `WorkManager` only — not raw threads, not plain `Service`
