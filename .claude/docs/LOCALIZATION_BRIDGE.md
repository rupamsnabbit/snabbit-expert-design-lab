# Localization Bridge (Flutter ↔ KMP) — Handoff & Reference

**Purpose:** mirror the Flutter `LanguageProvider`'s server-driven i18n map
(key → translated string) + current language into the KMP `:shared` module as an
observable `LocalizationStore`, so Compose Multiplatform (Expert App 2.0) screens can
render **localized** copy instead of the hardcoded English defaults their `XxxStrings`
ship today. Dart stays the single source of truth — it owns the HTTP fetch; KMP is a
read model.

- **Channel:** `com.snabbit.runner/localization`
- **Persistence:** each push is cached as one JSON blob (unencrypted `PreferenceStorage`/DataStore) and
  restored on cold start via `seedFromCache()` — Android-first (see *Persistence*).
- **Ungated:** the push is best-effort and carries no dedicated RC flag; the first consumer will gate itself.
- **Ships inert:** no KMP screen reads the store yet — see *Consuming* / *Next steps*.

Modelled on the runner-state bridge (`.claude/docs/RUNNER_STATE_BRIDGE.md`); this one is
**forward-only** (Dart → KMP), because Flutter always knows the current language — there's
no reverse "refresh" call.

---

## TL;DR for a screen author

```kotlin
val l10n: LocalizationStore = KoinPlatform.getKoin().get()   // Koin single

// Build your feature's Strings from the bridged map, English default as fallback:
val strings = JobStrings().localized(l10n)   // ← the .localized() factory is per-feature (follow-on)
// or read ad hoc:
val cta = l10n.getMessage("accept_job", "Accept Job")
```

`getMessage(key, fallback)` mirrors `LanguageProvider.getMessage`; `getFormattedMessage`
mirrors `getFormattedMessage` (double-brace `{{param}}`). Before the first push — or for a
missing key — you get the `fallback`, i.e. the English default. Everything below is detail.

---

## Architecture / data flow (forward only)

```
LanguageProvider.fetchMessages(lang)             (cold-start restore / every language change)
  └─ _publishToKmp(lang)                          // best-effort, ungated
       └─ LocalizationChannel.pushMessages(lang, jsonEncode(_messages))   // MethodChannel
            └─ LocalizationPlugin "pushMessages"  // Android, :app module
                 └─ LocalizationStore.pushMessages(lang, json)  // :shared/commonMain
                      └─ _state.value = LocalizationSnapshot(lang, map)   // MutableStateFlow
                           ├─ persist → PreferenceStorage (one JSON blob)  // cold-start cache
                           └─ store.getMessage(key, fallback)  ──►  consumers

KmpBootstrap (cold start) ─ LocalizationStore.seedFromCache()  // restores the blob → _state (if still EMPTY)
```

`fetchMessages` is the **single choke point** for every language path (Flutter selection
screen, native CMP selection callback, cold-start restore, onboarding), so one hook in it
covers them all. The push fires only on a successful (HTTP 200) fetch.

Why a `MutableStateFlow` (not an event channel): it replays its latest value to new
collectors and coalesces equal snapshots — same rationale as `RunnerStateStore`. In practice
consumers read `getMessage()` once at screen construction (language rarely changes mid-screen).

---

## File map

| File | Role |
|---|---|
| `shared/src/commonMain/.../core/localization/LocalizationStore.kt` | **The utility.** `LocalizationSnapshot` + `LocalizationStore` (StateFlow holder, `pushMessages`, `seedFromCache`, `getMessage`, `getFormattedMessage`); persists each push via `PreferenceStorage`, reports decode failures via `CrashReporter`. Koin `single`. |
| `shared/src/commonTest/.../core/localization/LocalizationStoreTest.kt` | 14 unit tests (lookup, fallback, passthrough, interpolation, malformed-keep-last-+-telemetry, non-string skip, persist round-trip, cold-start seed, seed-no-clobber, no-storage no-op). |
| `shared/src/commonMain/.../core/di/CoreModule.kt` | `single { LocalizationStore(logger = get(), crashReporter = get(), preferenceStorage = getOrNull(), dispatchers = get()) }` |
| `shared/src/androidMain/.../core/KmpBootstrap.kt` | Cold-start seed — calls `LocalizationStore.seedFromCache()` after Koin start (next to `NetworkConfigStore`). |
| `android/app/.../kmp_bridge/LocalizationPlugin.kt` | Android MethodChannel plugin — `pushMessages` in. |
| `android/app/.../com/example/snabbit_runner/MainActivity.kt` | `flutterEngine.plugins.add(LocalizationPlugin())` |
| `lib/services/localization_channel.dart` | Dart side: thin static `pushMessages`, best-effort + PII-safe logging. |
| `lib/providers/language_provider.dart` | Wires it: `_publishToKmp()` after every successful `fetchMessages` (ungated, best-effort). |

No iOS plugin yet — `LocalizationStore` is pure `commonMain` and iOS-ready; only
`LocalizationPlugin` is Android-specific. iOS persistence is also pending (`PreferenceStorage`
isn't bound in the iOS graph yet — the store degrades to in-memory-only there).

---

## The KMP API you consume

```kotlin
data class LocalizationSnapshot(val language: String = "", val messages: Map<String, String> = emptyMap()) {
    companion object { val EMPTY = LocalizationSnapshot() }
}

class LocalizationStore(
    logger: Logger,
    crashReporter: CrashReporter,
    preferenceStorage: PreferenceStorage? = null,              // opt-in; persistence when wired (null on iOS / in tests)
    dispatchers: AppDispatchers? = null,
) {
    val state: StateFlow<LocalizationSnapshot>                  // observe (rarely needed)
    fun snapshot(): LocalizationSnapshot                        // one-shot peek (EMPTY before first push)
    fun pushMessages(language: String, messagesJson: String)   // host-only (Dart writes) — also persists
    suspend fun seedFromCache()                                 // cold-start restore (called from host bootstrap)
    fun getMessage(key: String, fallback: String): String      // ← primary read; pure passthrough
    fun getFormattedMessage(key: String, fallback: String, values: Map<String, String>): String
}
```

`getMessage()` is a **pure passthrough** — it returns the server value verbatim, with **no**
brace/placeholder rewriting. Single-brace (`{amount}`) vs double-brace (`{{loss_amount}}`)
alignment, token-name drift, and currency-symbol doubling are **per-key consumer concerns**,
not the bridge's. `getFormattedMessage` uses Flutter's double-brace convention.

---

## Consuming in a screen (the follow-on pattern — NOT built yet)

The bridge ships inert. To localize a feature, add a per-feature factory and point the host at it:

```kotlin
// In JobStrings.kt (keys move from the // i18n key … comments into code):
fun JobStrings.localized(l10n: LocalizationStore): JobStrings = JobStrings(
    acceptJob = l10n.getMessage("accept_job", acceptJob),   // receiver = English fallback
    deny      = l10n.getMessage("deny", deny),
    // …one line per field
)

// In the host (e.g. ActiveJobOverlay.kt), replace `remember { JobStrings() }`:
val strings = remember { JobStrings().localized(getKoin().get<LocalizationStore>()) }
```

Ship a **per-key placeholder audit** with each feature migration: align KMP token names/braces
to the server copy and convert `.replace("{…}")` sites to `getFormattedMessage`.

---

## Persistence

Each successful push is persisted as **one JSON blob** — the whole `LocalizationSnapshot` (language +
messages together, so a reader never sees a half-updated pair) under a single `PreferenceStorage` key
(`localization_snapshot`; unencrypted DataStore — the i18n map is non-secret UI copy). On cold start,
`KmpBootstrap` calls `seedFromCache()` (async, off-main on `AppDispatchers.io`) to restore it, so a KMP
surface coming up before Flutter is alive shows the last-known localized copy. Both the write and the seed
are fire-and-forget — **nothing gates the UI on IO**. A fresh Dart push always wins over the seeded value
(atomic `update`, guarded on `EMPTY`). Modelled on `NetworkConfigStore.seedFromCache`.

**Android-first.** iOS binds no `PreferenceStorage` yet (`iosStorageModule` isn't in the iOS bootstrap),
so the store degrades to in-memory-only there — `CoreModule` resolves it with `getOrNull()` so this is a
safe no-op, not a crash. Wiring iOS persistence is a follow-on (see *Next steps*).

> No dedicated RC flag: the push is ungated (best-effort, inert until a consumer exists). The first
> consumer to read the store will carry its own feature flag.

---

## Conventions & gotchas

- **Cold-start restores the last-known copy.** On an FCM wake from a fully terminated app, the store
  seeds from disk (`seedFromCache`, async on `io`) so a KMP surface shows the last-persisted localized
  copy — English only on a fresh install or while the async seed is still in flight. A **reactive**
  consumer (`state.collectAsState()`) picks up the seeded value when it lands; a one-shot `getMessage()`
  reader benefits only if the seed completed first. The seed is off-main, so nothing is gated on IO —
  which is what made persistence worth adding (the earlier concern was IO latency on the accept/deny path).
- **`getMessage()` never rewrites placeholders** — see the KMP API note above.
- **PII discipline.** `LocalizationStore.pushMessages` logs the pushed key *count*, never
  contents; `LocalizationChannel` logs only the failure *kind* (`PlatformException(<code>)`).
- **Best-effort push.** `_publishToKmp` swallows channel failures (incl. `MissingPluginException`
  before attach) so a bridge hiccup can't disturb the awaited language-apply / cold-start flow.
- **Do NOT run `dart format`** — the repo predates Dart 3.10 tall-style; it churns whole files.
- **Payload is a JSON string** (`jsonEncode(_messages)`), decoded once in KMP — same rationale as
  the runner-state envelope.

---

## Next steps

1. **Wire the first consumer** — add `JobStrings.localized(...)` and point `ActiveJobOverlay`
   (+ `NewJobOverlayService`) at the store; delete the dead `JobScreenExtras` Intent-extra path.
2. **Roll out feature-by-feature** — one `*Strings.localized()` + placeholder audit per PR.
3. **iOS host glue** — add the iOS plugin equivalent when the iOS target lands; also wire
   `iosStorageModule()` into the iOS bootstrap + add an iOS `seedFromCache()` call so persistence
   activates there (Android-only today). Screens don't change.
4. **Trajectory** — when KMP eventually owns the i18n fetch itself (via `SnabbitHttpClient`, like
   the `language/` selection feature already does), swap what *writes* into `LocalizationStore`
   and delete the Dart channel. Consumers stay unchanged — the store is the stable seam.
```
