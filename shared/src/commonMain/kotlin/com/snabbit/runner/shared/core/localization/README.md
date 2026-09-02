# `core/localization` — Flutter → KMP Localization Bridge

Mirrors the Flutter `LanguageProvider`'s server-driven i18n map (key → translated string) plus the
current language into the KMP `:shared` module as a **read model**, so Compose Multiplatform screens
can render localized copy instead of hardcoded English defaults.

**Dart stays the single source of truth** — it owns the HTTP fetch (`internationalization_file/{lang}`);
KMP only *receives* the resolved map over a one-way `MethodChannel`. This is the localization analogue
of `core/runnerstate` (`RunnerStateStore`).

> Ships **inert** — no KMP screen consumes it yet, and the push is **ungated** (best-effort; the
> first consumer will carry its own feature flag). Each push is **persisted** and restored on cold
> start (see below). Full handoff doc: `.claude/docs/LOCALIZATION_BRIDGE.md` (from repo root).

## Data flow

```
LanguageProvider.fetchMessages(lang)              // Flutter, on every language settle
  └─ LocalizationChannel.pushMessages(lang, json) // Dart writer  (best-effort, ungated)
       └─ LocalizationPlugin "pushMessages"        // Android host, MethodChannel
            └─ LocalizationStore.pushMessages(...)  // :shared/commonMain  (this module)
                 ├─ StateFlow<LocalizationSnapshot> ──► getMessage(key, fallback)  ◄─ future consumers
                 └─ persist → PreferenceStorage ; restored on cold start via seedFromCache()
```

## Classes

| Class | Layer | What | Why | ELI5 |
|---|---|---|---|---|
| **`LocalizationStore`** | `commonMain` · this module | Koin `single` holding the current `LocalizationSnapshot` in a `MutableStateFlow`. `pushMessages(lang, json)` writes (never throws — a bad payload is logged, reported to telemetry, and the last good snapshot kept) and **persists** the snapshot as one JSON blob via `PreferenceStorage`; `seedFromCache()` restores it on cold start; `getMessage(key, fallback)` / `getFormattedMessage(key, fallback, values)` read (pure passthrough + `{{param}}` interpolation, mirroring `LanguageProvider`). | Gives every KMP/Compose surface one always-current source of translated copy without re-implementing the fetch — surviving process death so a cold FCM surface isn't stuck on English. It's the stable seam the whole feature hangs off. | A magic box that always holds the newest "word → translation" list and remembers it after a restart. Screens peek inside to get the right words; Flutter keeps refilling it. |
| **`LocalizationSnapshot`** | `commonMain` · this module | Immutable `data class` = `language: String` + `messages: Map<String,String>`, with an `EMPTY` default. The single value the store's `StateFlow` emits. | Keeps language and its words together as one atomic, consistent unit — a reader never sees "new words, old language" mid-update. | One sealed bag labelled with a language, holding all its translated words. You swap the whole bag, never half of it. |
| **`LocalizationPlugin`** | Android host · `:app/kmp_bridge` | `FlutterPlugin` owning the `com.snabbit.runner/localization` `MethodChannel`; on `"pushMessages"` it forwards `{language, messagesJson}` into the injected `LocalizationStore`. | The native landing point that lets Dart hand its i18n map to the KMP store across the platform boundary (Koin resolves the store on attach). | The Android mailbox: Flutter drops the word-list in, and it goes straight into the box. |
| **`LocalizationChannel`** | Flutter · `lib/services` (Dart) | Thin static writer over the same channel: `pushMessages(language, messagesJson)`. Best-effort — swallows channel failures and logs only the *kind* (PII-safe). | The Flutter side of the bridge. Called once from `LanguageProvider.fetchMessages` (the single choke point), so every language change + cold-start restore reaches KMP automatically. | The Flutter mail carrier: packs the words, sends them to the Android mailbox, and shrugs off delivery hiccups. |

*Also in the module:* **`LocalizationStoreTest`** (`commonTest`) — 14 tests covering lookup, fallback,
passthrough (`{{x}}` left intact), interpolation, malformed-JSON-keeps-last-good-**and-reports-to-telemetry**,
non-string-value skipping, and **persistence** (persist-on-push round-trip, cold-start seed, seed-doesn't-
clobber-a-fresh-push, no-storage no-op).

## Read API (what a consumer calls)

```kotlin
val l10n: LocalizationStore = KoinPlatform.getKoin().get()   // Koin single

l10n.getMessage("accept_job", "Accept Job")                  // → translated, else the English fallback
l10n.getFormattedMessage(                                    // → double-brace {{token}} substitution
    "denial_loss_earnings", "You will miss ₹{{loss_amount}}", mapOf("loss_amount" to "1234"),
)
l10n.snapshot()                                              // one-shot peek (EMPTY before first push)
```

`getMessage` is a **pure passthrough** — it never rewrites placeholders. Aligning single- vs
double-brace tokens (and currency symbols) is each consumer's job when it adopts the bridge.

## Consuming it (follow-on, not built yet)

Per feature, add `fun XxxStrings.localized(store: LocalizationStore): XxxStrings` that maps each field
via `store.getMessage("<i18n_key>", <english default>)`, then point the host at it (e.g. replace
`ActiveJobOverlay`'s `remember { JobStrings() }`). Ship a per-key placeholder audit with each migration.
