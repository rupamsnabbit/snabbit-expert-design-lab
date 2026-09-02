# KMP Navigation — Integration Guide

How to navigate to/from **native Compose screens** during the Flutter → KMP migration.
The module renders native screens with **Jetpack Navigation 3** and lets Flutter and
native screens coexist. Task-oriented: pick the flow, copy the example.

> Runner-app specifics: a native screen's **UI + ViewModel live in `:shared/commonMain`**; a
> thin **`:app`** layer maps it into the Nav3 host. The back stack is owned by a pure-Kotlin
> **`NavigationController` — a plain state holder, *not* MVI** (direct methods, no intents /
> reducer / effects). One host Activity renders it. `build-screen` (`SnabbitScreen` +
> design-system) is the **optional** convention for screen UI — navigation doesn't depend on
> it. The module renders **no error UI of its own**; failures are **surfaced to the consumer**.

> **If anything here is unclear — read the actual module code; it is the source of truth.**
> The [Wiring reference](#wiring-reference) lists exactly where each piece lives.

## At a glance

| Flow | Who triggers it | Call |
|------|-----------------|------|
| Flutter → native | Dart | `await …openNativeDestination('key', {...})` → `bool` (false = not opened) |
| Native → native | A native screen's ViewModel | `nav.navigate(dest)` (also `back`/`replace`/`resetTo`/`popUntil`/`pushAndRemoveUntil`/`maybePop`) |
| Native → native, await result | native VM ↔ native VM | `await nav.navigateForResult(dest)` ↔ `nav.popWithResult(mapOf(...))` |
| Native → Flutter (terminal handoff) | A native screen's ViewModel | `nav.requestFlutterRoute("/route", mapOf(...))` |
| Native → Flutter, **keep native alive** (round trip) | A native screen's ViewModel | `nav.requestFlutterRouteKeepingHost("/route", …, recreateKey, recreateArgs)` |
| Flutter → native, await result | Dart awaits ↔ native VM returns | Dart `await …openNativeDestinationForResult(...)` ↔ VM `nav.finishWithResult(mapOf(...))` |
| Deep link → native | Automatic once a `DeeplinkMapping` is bound | `DeepLinkRouter` delegates to the bridge |
| Back / return to Flutter | System / predictive back, or empty stack | `nav.back()` → at root → empty stack → host finishes |
| Dialog / bottom sheet | `Presentation` on the screen registration | `nativeScreen<D>(Presentation.Dialog) { … }` |
| Tabs / bottom-nav | A `TabbedContainer` mounted as one destination | see [Tabs](#tabs--bottom-navigation) |

Running example: a native **Job Detail** screen, opened by key `job_detail` / deep-link
value `job_detail`, that opens a native **Profile** and hands off to Flutter **/chat**.

---

## Navigation flows

### 1. Flutter → native
```dart
import 'package:snabbit_runner/services/navigation/kmp_navigation_bridge.dart';

final opened = await KmpNavigationBridge.instance
    .openNativeDestination('job_detail', {'id': '42'});
if (!opened) { /* no native screen owns the key — handle it however you like */ }
```
KMP builds the `Destination` for that key, pushes it, and launches the native host. Returns
`false` if no screen owns the key (the module shows no error UI — the caller decides). Works
once the screen + factory are registered ([Add a native screen](#add-a-native-screen)).

### 2. Native → native
A native screen's **ViewModel** calls the injected `NavigationController` (a Koin singleton)
with **direct methods** — no intents:
```kotlin
class JobDetailViewModel(
    private val jobId: String,
    private val nav: NavigationController,   // Koin-injected
) : ViewModel() {                            // androidx.lifecycle.ViewModel (multiplatform)
    fun openProfile(userId: String) = nav.navigate(Profile(userId)) // push
    fun up() = nav.back()                                            // pop

    // Native→native result (Flutter's `await push` ↔ `pop(result)`):
    fun pickDate() = viewModelScope.launch {
        val result = nav.navigateForResult(DatePicker())   // suspends until popped
        result?.let { /* it["date"] */ }                   // null if backed out
    }
}
// …and in the DatePicker's VM: nav.popWithResult(mapOf("date" to iso))
```
Full `Navigator` parity: `navigate` (push), `back` (pop), `replace` (pushReplacement),
`resetTo`, `popUntil { … }`, `pushAndRemoveUntil(dest) { … }`, `maybePop()`, `canGoBack`
(canPop), and `navigateForResult`/`popWithResult` above. Nav3 animates the transition; the
back stack is `nav.backStack`. The VM is **scoped to the nav entry** (step 3) — that's what
makes A→B→back keep A's state (see [State & lifecycle](#state--lifecycle)).

### 3. Native → Flutter (hand off to a Flutter route)
```kotlin
nav.requestFlutterRoute("/chat", mapOf("jobId" to jobId))
```
The host forwards this over the event channel and finishes (yielding to Flutter); Dart runs
`Navigator.pushNamed("/chat", arguments: {...})`. No Dart code to write —
`KmpNavigationBridge.instance.start()` (already in `main.dart`) handles it.

### 4. Deep link → native
No call-site code. The Dart `DeepLinkRouter` asks the bridge first for every resolved
deep-link value; a value owned by a native screen routes natively. To claim a value, give
`nativeDestination<D>(…)` a `deeplinkValue` (step below).

### 5. Flutter → native, awaiting a result
```dart
final result = await KmpNavigationBridge.instance.openNativeDestinationForResult(
  'date_picker', {'initial': '2026-01-01'},
);
if (result != null) { /* use result['date'] */ }   // Map<String,String>?; null if dismissed
```
The native VM returns its result:
```kotlin
nav.finishWithResult(mapOf("date" to selectedIso))
```
That clears the native stack, finishes the host, and completes the future. Backing out or a
native→Flutter handoff completes it with `null`, so the caller never hangs.

### 6. Native → Flutter, keeping the native host alive (round trip)
Flow #3 is a **terminal** handoff — the host finishes, native B is gone. When the user must
come **back to the same native screen** after a Flutter detour —
`Flutter A → native B → Flutter C → back → native B → back → Flutter A`, with **B preserved** —
use the keep-host variant:
```kotlin
nav.requestFlutterRouteKeepingHost(
    route = "/chat",
    args = mapOf("jobId" to jobId),
    recreateKey = "job_detail",                 // how to rebuild B if the OS reclaims it
    recreateArgs = mapOf("id" to jobId),        // …its open-by-key args
)
```
This does **not** finish the host and does **not** touch `nav.backStack` (B stays alive). It
reorders the Flutter surface to the front (Android task reordering — both Activities share one
task via `taskAffinity=""`) and pushes **C** there as a `HostBackedRoute`. No Dart call-site
code: `start()` already routes the `pushHostBackedRoute` command.

**Returning** is automatic. Backing out of C (system / predictive back) is intercepted by the
`HostBackedRoute`'s `PopScope`, which brings the native host back to front **before** removing C
— so A never flashes — and it resumes with its back stack and per-entry state intact. This holds
for a **multi-entry native stack** too: `A → B → C(native) → D(Flutter) → back` returns to **C**
(the top), then native back goes `C → B`, then `B → A`. Sub-routes C itself pushes (`C → C2`) are
ordinary Flutter routes; only the final dismissal of the host-backed route routes back to native.

**Return & reclaim.** The native stack lives in the **process-scoped** `NavigationController`, so
it survives the host Activity being backgrounded *or* reclaimed by the OS. On return the host is
reordered forward (if still alive) or a **fresh instance re-renders the surviving stack** (if
reclaimed) — either way you land on the top native entry, even for a deep `[B, C, …]` stack. Only
full **process death** clears the stack; `recreateKey`/`recreateArgs` are then a last-resort
rebuild of the *single* entry screen (a deep stack is not reconstructed — no-restore contract).

**Known limitations** (reordering approach):
- ~1-frame **A flash** is possible on the A→C forward handoff (mitigated — C is opaque,
  zero-duration — not fully eliminable without a coordinated cross-Activity transition).
- Full **process death** mid-flow loses B → cold start to Flutter A (the module never restores
  the native stack; persisting `recreateKey` across process death is out of scope).
- C **cannot return a for-result value** to B — keep-host is forward navigation, not a result
  handoff. Use flow #5 (`finishWithResult`) when B needs a value back.
- Cross-Activity **predictive-back preview** (B sliding under the swipe gesture) is not wired —
  back *works*, but the animated preview of B during the swipe does not show.

### Back & returning to Flutter
Popping the **last** native screen returns to Flutter. `nav.back()` at the root asks the host
to `finish()` **while the current screen is still composed**, so the OS close animation slides
it out smoothly (no blank-frame flash); the back stack is cleared on teardown. System /
**predictive** back at the root is handled by the OS the same way (Nav3 doesn't consume back at
the root). Only one surface is ever active. (With no host attached — e.g. unit tests — `back()`
at the root instead empties the stack, which is itself the return-to-Flutter signal.) Predictive
back is enabled on the host Activity only (`android:enableOnBackInvokedCallback` in the
manifest), so Flutter's back handling is untouched. Flutter can force a native pop with
`KmpNavigationBridge.instance.back()`.

---

## Presentation: dialog & bottom sheet

A destination renders full-screen by default; pass a `Presentation` at registration to make
it a **dialog** or **bottom sheet** instead:
```kotlin
nativeScreen<ConfirmDialog>(Presentation.Dialog)      { ConfirmDialogScreen(it) }
nativeScreen<FilterSheet>(Presentation.BottomSheet)   { FilterSheetScreen(it) }
```
The host installs the scene strategies (`DialogSceneStrategy` from Nav3; a small app-authored
`BottomSheetSceneStrategy` over `OverlayScene` + material3 `ModalBottomSheet` — Nav3 1.1.2 has
no built-in bottom sheet). Dismiss (swipe / scrim / back) funnels through the controller, so
the back stack stays the single source of truth. **A dialog/sheet must not be a root
destination** — it overlays the screen beneath it, so push it onto an existing native screen.

## Tabs / bottom navigation

> **⚠️ Experimental — not yet wired or tested.** `TabbedContainer` / `TabbedBackStack` ship as
> scaffolding for the tabbed-shell (home) migration but are **not** mounted by any screen yet and
> have **no unit tests**. Treat the API below as provisional; add tests (and verify
> exit-through-home / switch-retention) before the first real tabbed screen depends on it.

Independent per-tab back stacks are a **reusable container** mounted as **one** native
destination (the host stays a linear stack — a tabbed *section* is one entry). The module owns
the plumbing (per-tab stacks, state retention across switches, exit-through-home, back); **you
render the bar** (so it uses the design system):
```kotlin
enum class HomeTab { Feed, Orders, Profile }
data class HomeTabs(val initialTab: String = "Feed") : Destination

nativeScreen<HomeTabs> { dest ->
    val nav = remember { getKoin().get<NavigationController>() }
    val state = remember {
        TabbedBackStack(
            tabs = HomeTab.entries, startTab = HomeTab.valueOf(dest.initialTab),
            initialStacks = mapOf(HomeTab.Feed to listOf(FeedRoot) /* … */),
        )
    }
    // Reuse the same registration for the tab screens.
    val registry = remember { ScreenRegistry(getKoin().getAll(), nav) }
    TabbedContainer(
        state = state,
        onExit = { nav.back() },                       // exits the whole tabbed section
        entryProvider = { registry.entryFor(it) },
        bottomBar = { current, onSelect ->
            // your design-system NavigationBar, wired to current / onSelect
        },
    )
}
```
- **Switch tabs** preserves each tab's history and UI state. **Back** pops within the tab; at a
  non-start tab's root it switches to the start tab (**exit-through-home**); at the start tab's
  root it pops the whole container (`onExit`).
- **Deep link into a tab:** map the deep-link value to `HomeTabs(initialTab="Orders")` and seed
  `initialStacks`.

## Nested flows

No special machinery — two idioms:
- **Wizard / multi-step:** just push each step with `nav.navigate(Step2())`; back pops a step.
- **Self-contained sub-flow:** host a child `NavDisplay` over a local `SnapshotStateList` inside
  one screen (the same mechanism `TabbedContainer` uses, minus the bar), bridging its
  "exhausted" back to `nav.back()`.

## One native session at a time

**Constraint (current model).** The controller owns **one** flat, process-scoped back stack, so the
module supports **at most one native session at a time**. These are fine:
- `Flutter → native → … → back → Flutter` (a native excursion, any depth of native→native).
- `native → Flutter → back → native` (the keep-host round trip — the *same* session resumes).

What is **not** yet supported is **nested** native↔Flutter↔native — opening a **second, different**
native destination from a Flutter screen that itself sits on top of a still-alive native session
(e.g. `native Home → Flutter payout webview → native Job`). Because every entry path appends to the
one stack, the second destination lands on the first session's stack, so native-back from it returns
to the *first* native screen instead of the intervening Flutter screen (a wrong back path), and a
second host can contend for `controller.host`.

Until session-scoped stacks land (tracked as a follow-up), `openByKey` / `handleResolvedDeeplink`
**report a non-fatal** when opening a native destination while a session is already active, so the
case is visible in the dashboard. **Guidance for feature devs:** return to Flutter (empty the native
stack) before opening an unrelated native flow; don't open a native screen from a Flutter screen that
is layered over a live native session.

---

## Add a native screen

End-to-end with `JobDetail`. **Screen UI + VM live in `:shared/commonMain`; the screen mapping
lives in `:app`.** Two one-call helpers across the module boundary:

**1. Destination** — `:shared/commonMain/.../<feature>/`:
```kotlin
@Serializable data class JobDetail(val jobId: String) : Destination
```

**2. Screen** — a `@Composable` taking its `ViewModel` as a **parameter** (stateless over it,
like `LanguageScreen`). The VM extends **`androidx.lifecycle.ViewModel`** (`viewModelScope` for
coroutines) and takes `NavigationController` as a Koin dependency. Must compile for iOS. Style
it however you like; `build-screen` (`SnabbitScreen` + DS) is optional.

**3a. Entry points (commonMain)** — register the destination (open-by-key, optional deep link)
with `nativeDestination<D>(…)`, in a feature module added to `KmpBootstrap.initialize`'s
`modules(...)` list:
```kotlin
val jobModule = module {
    nativeDestination<JobDetail>(key = "job_detail", deeplinkValue = "job_detail") { args ->
        JobDetail(jobId = args["id"].orEmpty())   // parse string args → typed destination
    }
}
```

**3b. Screen mapping (`:app`)** — register the Compose screen with `nativeScreen<D>(…)` and
`loadKoinModules` it after `KmpBootstrap.initialize` (e.g. in `SnabbitRunnerApplication`):
```kotlin
val jobHostModule = module {
    nativeScreen<JobDetail> { dest ->
        // viewModel() scopes the VM to THIS NavEntry (host's ViewModelStore decorator),
        // so it survives A→B→back and is cleared when the entry is popped.
        val vm = viewModel { JobDetailViewModel(jobId = dest.jobId, nav = getKoin().get()) }
        JobDetailScreen(viewModel = vm)
    }
}
// after KmpBootstrap.initialize(...):  loadKoinModules(jobHostModule)
```
Now `openNativeDestination('job_detail', {'id': '42'})` opens it, and deep-link value
`job_detail` routes to it. The controller, host, and bridge never change.

> **Manual (opt-out):** instead of the helpers you can bind a raw `DestinationFactory` /
> `DeeplinkMapping` (commonMain) and a `NativeScreen` returning `NavEntry(dest, metadata = …) { … }`
> (`:app`) — the helpers are just thin wrappers over those.

---

## Arguments
- **Native → native:** pass a typed `Destination` (e.g. `Profile(userId)`) — full type safety.
- **Across the bridge** (Flutter→native, deep link): **strings only** (`Map<String, String?>`).
  Your `nativeDestination` `build` lambda parses them (`args["id"].orEmpty()`, `anyValueToInt(…)`).
  Keys are a contract with the caller / deep-link provider — keep them stable.
- **Native → Flutter** (`requestFlutterRoute`): `Map<String, String>` → `Navigator.pushNamed`.

## Errors & failures

The module renders **no error UI** — failures come back as **return values** the caller checks:
- **Bad / unresolvable open** → `openNativeDestination` returns **`false`** (and
  `openNativeDestinationForResult` returns `null`); logged + non-fatal. The caller decides what
  to show.
- **Deep link not owned by a native screen** → `handleResolvedDeeplink` returns `false` → the
  Dart `DeepLinkRouter` keeps routing it as a Flutter route, unchanged.
- **Bridge error on the Dart side** → `KmpNavigationBridge` logs via `MonitoringServiceHelper`
  and degrades to a `false`/`null` return — never breaks existing Flutter navigation.
- **Pushed destination with no registered screen** (a programming error) → **debug: fail-fast**
  (throws so you see it); **release:** logged + non-fatal + the offending entry is popped — no
  broken/blank native screen, no module error UI. (In-native failures have no caller to return
  to, so they are log-only.)

## State & lifecycle
- **Entry-scoped `ViewModel`** (the main one) — get the screen's VM via `viewModel { … }`; the
  host's `ViewModelStore` decorator scopes it to that `NavEntry`, so it **survives A→B→back** and
  is cleared on pop. Put the screen's real state in the VM.
- **`rememberSaveable { }`** — small pure-UI bits not in the VM. Survives navigation + config change.
- **Tabs** — each tab's stack + UI state are retained across switches (in-memory).
- **Process death** — by design returns to **Flutter's cold start** (the Flutter side doesn't
  restore its own navigation either). Rotation is handled in place (manifest `configChanges`).

## Testing
`nativeDestination` factories/mappings and your screen `ViewModel` are pure Kotlin —
unit-test in `commonTest` (see `NavigationControllerTest`, `NavigationRegistrationTest`,
`DeeplinkResolverTest`). `TabbedBackStack` is pure Kotlin too and unit-testable the same way, but
is **not yet tested** (see the experimental note under [Tabs](#tabs--bottom-navigation)) — add
tests before relying on it.

---

## Wiring reference

| Concern | Where |
|---------|-------|
| Back-stack state holder, `Destination`, resolvers, `NavigationHost`, registration helper | `:shared/commonMain/.../core/navigation/` |
| Koin wiring (`navigationModule`) | registered in `KmpBootstrap.initialize` |
| Native host (Nav3 `NavDisplay` + scene strategies) + `ScreenRegistry` + `Presentation`/`nativeScreen` | `:app/.../navigation/` |
| Bottom-sheet scene strategy | `:app/.../navigation/scene/BottomSheetSceneStrategy.kt` |
| Tabs container + state | `:app/.../navigation/tabs/` |
| Bridge contract (source of truth) | `pigeons/navigation_api.dart` (Pigeon — **kept**; pinned, bump deferred) |
| Bridge impl (Kotlin) + registration | `:app/.../navigation/bridge/NavigationBridgePlugin.kt`, `MainActivity` |
| Bridge client (Dart) + startup | `lib/services/navigation/kmp_navigation_bridge.dart`, `main.dart` |
| Keep-host round-trip route (Dart) | `lib/services/navigation/host_backed_route.dart` (resolves via `appRoutes` in `main.dart`) |
| Deep-link delegation | `lib/services/deeplink/deeplink_router.dart` |

**Regenerate the bridge** after editing `pigeons/navigation_api.dart` (generated `*.g.*` are
committed — don't hand-edit; Pigeon codegen does **not** use build_runner):
```bash
dart run pigeon --input pigeons/navigation_api.dart
```

**Verify:**
```bash
cd android && ./gradlew :shared:testDebugUnitTest :app:compileDebugKotlin
flutter analyze && dart format --set-exit-if-changed lib/
# iOS commonMain purity (needs the Kotlin/Native toolchain — run on CI / a Mac):
cd android && ./gradlew :shared:compileTestKotlinIosArm64
```
