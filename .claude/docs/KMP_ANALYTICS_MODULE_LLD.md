# KMP Analytics Module -- Low-Level Design

> **Version:** 1.0 | **Status:** Shipped. v1 ships AppsFlyer as the sole provider on Android, install-attribution-only + AF-relevant funnel events. Routing is decided KMP-side via `analyticsRoutes`; Dart fires every event unconditionally and the tracker drops what is not in the allowlist. No consent gate, no conversion listener, no deep-link handling. Mixpanel / CleverTap / Firebase Analytics / Meta migrate from the Dart facade in later phases. | **Last updated:** 2026-06-06
>
> **Changes from 0.9 — second-pass review cleanup.** Targeted fixes from a fresh multi-agent PR review:
> - **`PropertyValue.sanitize` return type tightened to `Map<String, Any>`.** The non-null guarantee was previously comment-only; now it's encoded in the type. `AnalyticsProvider.track` SPI signature follows suit (`Map<String, Any>`).
> - **Deleted `@Suppress("UNCHECKED_CAST")` + cast in `AppsFlyerAndroidProvider.track`.** The strengthened SPI types make AF's `Map<String, Any>` overload reachable without a cast.
> - **`KmpAnalyticsChannel` debug error logs no longer print full `$e`.** `PlatformException.toString()` echoes `details`, which a future plugin change could populate with method args (incl. PII-bearing props). Now logs `PlatformException(code)` or `runtimeType` only.
> - **Removed duplicate `installreferrer:2.2` declaration** from `android/app/build.gradle` — reached transitively via `:shared` (where AF SDK lives).
> - **Documented `AnalyticsProvider.start()` pre-bootstrap-call tolerance contract** — implementations MUST accept `track`/`identify`/`reset` before `start()` completes (AF buffers; future providers must do the same or no-op).
> - **Documented Koin double-binding singleton semantics** in `AnalyticsModule.kt` — both `single { AnalyticsTrackerImpl(...) }` and `single<AnalyticsTracker> { get<AnalyticsTrackerImpl>() }` resolve to the SAME instance (Koin returns the constructed singleton on subsequent `get()`s). Clarifies a pattern that could read as double-construction.
>
> Rejected reviewer claims documented in `~/.claude/plans/jazzy-inventing-goblet.md` (logEvent's discarded MP/CT Futures are already internally-caught and resolve successfully; double-Main-dispatch is a no-op when already on Main; identifyOnLogin's sync body can't throw; double-wrapped error handling is belt-and-suspenders by design).
>
> **Changes from 0.8 — review cleanup.** Surgical follow-up after PR review:
> - **Deleted unused `Destination.ALL` and `Destination.ATTRIBUTION`** — vestigial from v0.7 when `reset()` defaulted on `ALL`.
> - **Dropped `registeredDestinations` precomputed field**. `bootstrap`/`track`/`identify`/`reset` now iterate `Destination.entries` directly with `?: continue` doing real skip work — removes the unreachable defensive `?: continue` against a map lookup whose keys were derived from the same map.
> - **Moved `logUnregisteredRoutes` from per-`track` check to `init { }` block.** A route mentioning a Destination whose provider isn't bound is a startup-time misconfig — both sides are immutable post-construction, so checking once at init beats checking on every event.
> - **Killed the `AnalyticsTracker as AnalyticsTrackerImpl` cast** in `KmpBootstrap` via a sibling Koin binding for the impl. `getKoin().get<AnalyticsTrackerImpl>().bootstrap()` resolves directly now.
> - **`OnboardingAnalytics.identifyOnLogin` restructured.** Each platform-call wrapped in its own `try/catch` so a Mixpanel SDK throw can't block the AppsFlyer `setCustomerUserId`. KMP `identify` now co-located with `MixpanelSetup.identify` at the top of the method instead of trailing.
> - **`KmpAnalyticsSink` added to webview track composite.** Webview events fired via Bifrost `trackEvent` now also flow through the KMP channel and consult `analyticsRoutes` — same routing story as native Dart events.
> - **Documented `suspend` failure-isolation choice.** `bootstrap` uses raw `try/catch` (not `runCatching`) because `runCatching` would swallow `CancellationException` and break coroutine cancellation semantics.
>
> **Changes from 0.7 — routing pivot.** The per-call `destinations: Set<Destination>` parameter is gone. The tracker now owns a `Map<String, Set<Destination>>` (`AnalyticsRoutes.kt`) and consults it on every `track` call; unmapped events drop silently (debug builds log). Affected surface:
> - `AnalyticsTracker.track/identify/reset` lose the `destinations` argument. `identify` and `reset` fan to all registered providers (identity is never routed).
> - `AnalyticsPlugin.kt` (MethodChannel handler) stops parsing `destinations` from the Dart payload.
> - `KmpAnalyticsChannel` (Dart) drops the `destinations` arg from all three methods.
> - `analytics_destinations.dart` (Dart enum mirror) **deleted** — Dart no longer names KMP destinations.
> - `OnboardingAnalytics._afRelevantEvents` allowlist **deleted** — superseded by `analyticsRoutes` on KMP. `OnboardingAnalytics.logEvent` now fires `MixpanelSetup` + `ClevertapSetup` + `KmpAnalyticsChannel.track` unconditionally; the tracker decides AF.
> - `OnboardingAnalytics.identifyOnLogin` now calls `KmpAnalyticsChannel.identify` (restoring the AppsFlyer `setCustomerUserId` plumbing that was lost when release renamed `identifyExpert → identifyOnLogin`).
> - `Destination.kt` retains the enum — still load-bearing as the routing-map value type and the provider's `destination` tag.
>
> **Why KMP-side.** Single audit point for the AF surface: every event AF can ever see is in one Kotlin file under `:shared`. PR-review discipline scales better than tracking a per-call `destinations` arg scattered across many call sites. Sections §2.3, §3.2, §11.3, §12.1, §12.2 read with that pivot in mind — superseded specifics are footnoted inline.
>
> **Shorebird scope.** Shorebird Code Push only patches the Dart AOT snapshot. `analyticsRoutes` lives in `:shared`'s Kotlin code, so additions/changes require a Play Store release — treat the map as release-blocking config. If hot route changes become necessary, the path is Firebase Remote Config (already wired in the app) reading a JSON map into the tracker at bootstrap, not Shorebird.
>
> **Changes from 0.6**
> - **Dev key lives as a hardcoded `private const val APPSFLYER_DEV_KEY` in `SnabbitRunnerApplication.kt`**, not in `local.properties` via `BuildConfig`. Matches existing precedent in the codebase (`MixpanelSetup._projectToken` is hardcoded in Dart; CleverTap account-id + token are committed in AndroidManifest meta-data; Google Maps API key same). The AppsFlyer dev key is a client identifier that ships in every APK anyway — gitignoring it via `local.properties` was security theater. Saves 4 lines of Gradle and the "add to local.properties" onboarding step. `BuildConfig.DEBUG` retained for `debugLogging` (1 line of `buildFeatures { buildConfig true }` opt-in). Appendix A updated.
>
> **Changes from 0.5**
> - **Removed `AnalyticsEvents.kt` and `AnalyticsKeys.kt`.** Zero call sites in v1 — only consumer is `OnboardingAnalytics.dart`, which uses raw strings on the Dart side (Kotlin constants don't help there). §2.5 rewritten to explain *why no catalogue*; §2.6 example uses raw strings; §17.1 codegen subsection deleted; glossary "canonical event" entry updated.
>
> **Changes from 0.4**
> - **§13 reframed + new §13.5 "Dual-fire to AppsFlyer from existing per-feature wrappers."** Existing Dart wrappers like `OnboardingAnalytics` keep their Mixpanel/CleverTap paths intact but gain a small dual-fire to `KmpAnalyticsChannel` for AF-relevant events (`otp_verification_success`, `language_selected`). Per-wrapper `_afRelevantEvents` allowlist; PR review enforces. Identity calls (`identifyExpert`) also forward `setCustomerUserId` to AF.
> - §13 intro updated to reflect that the dual-fire is the one exception to "leave Dart facades untouched."
>
> **Changes from 0.3 — simplification pass.** v0.3 had accumulated speculative engineering. Removed:
> - **`RateLimitedLogger` and all associated machinery** (old §10.3). AF won't fail often enough to need rate limiting; plain `Logger` is fine.
> - **`isStarted` flag on `AnalyticsProvider` + pre-bootstrap event-drop ceremony** (old §10.4). AppsFlyer buffers calls before `start()` returns; the few-millisecond gap doesn't need its own protocol.
> - **`setUserProperty` and `flush()` from the public API and SPI**. AppsFlyer supports neither. Re-add when Mixpanel/CleverTap migrate to KMP and actually need them.
> - **`traits` parameter on `identify`**. AppsFlyer ignores it. Re-add with `setUserProperty` later.
> - **`AppsFlyerEventMapper.kt` as a separate file**. With zero canonical mappings in v1 (no `PAYOUT_INITIATED → PURCHASE` until Growth asks), the mapper is empty boilerplate. Fold into the provider; extract when there's content to extract.
> - **`ProviderContractTest` abstract base** (old §15.5). Only meaningful with 2+ providers; speculative until then.
> - **Vendor-import lint `commonTest`**. We control the imports; PR review catches drift.
> - **`AnalyticsConfig.startTimeoutMs` parameter + 5 s timeout machinery** (old §5.9). AF init runs in ~20–80 ms; the timeout was guarding against a failure mode we've never seen. Bootstrap launches the coroutine fire-and-forget — Application.onCreate doesn't wait either way.
> - **Separate `AnalyticsCoroutineExceptionHandler`** (old §14.3). Plain launch is enough; the existing `hydrateAll` CEH pattern wasn't worth duplicating for a code path that has nowhere to throw.
> - **ProGuard verification ceremony + APK size budget sections** (old §16.4 / §16.5). Collapsed to one line each in §16.
> - **§17.1 codegen, §18.5 WorkManager analytics, parts of §17** — speculative.
>
> **Changes from 0.2 (preserved):**
> - **Removed: `AttributionSource`, `ConversionData`, `DeepLinkData`, `AppsFlyerConversionRelay`, `/analytics_attribution` and `/analytics_deeplinks` EventChannels.** Verified the runner app has zero page-specific deep links (only `otpless://` auth callback + FCM push intent filter; no `app_links` / `uni_links` / `firebase_dynamic_links` / `go_router` in `pubspec.yaml`). AppsFlyer's docs confirm `init(devKey, null, ctx)` is the recommended minimal integration.
> - **Added: `AppsFlyerRequestListener` on `start()`** (§5.5) — cheap, surfaces invalid-dev-key at runtime.
>
> **Changes from 0.1 (preserved):**
> - **§7 removed.** No consent gate; India-only product.
> - §1.5: vendor SDK lives in `shared/androidMain`, not host.
> - §2.4: sanitiser widens `Int` → `Long` to kill Dart-vs-Kotlin call-origin drift.
> - §8.1 / §14.3: bootstrap signature matches the real `KmpBootstrap.initialize(app: Application, crashReporter: ((Throwable, Map<String, String>) -> Unit)?)`.
> - §13: phase-2 dedup uses Remote Config flag, not call-site discipline.
> - §15.4 + Appendix A: separate test-only AppsFlyer dev key.

## 1. Overview

This document specifies the internal design of the KMP analytics module
(`shared/.../analytics/`). It defines a vendor-neutral tracker interface, a
provider SPI for individual analytics SDKs, a per-event destination routing
model, the AppsFlyer Android implementation, the Flutter bridge that exposes
the tracker to Dart, and the lifecycle / failure-isolation rules.

The module is built so future providers — Mixpanel, CleverTap, Firebase
Analytics, Meta — slot in by implementing the provider SPI and adding
themselves to a destination enum, with no change to call sites or the public
API.

### 1.1 Scope

- Everything under `shared/src/commonMain/kotlin/com/snabbit/runner/shared/core/analytics/`
- AppsFlyer provider implementations under `shared/src/androidMain/.../core/analytics/providers/`
  and `shared/src/iosMain/.../core/analytics/providers/`
- Koin DI additions to `CoreModule.kt` / `PlatformModule.kt`
- AppsFlyer init wiring in `KmpBootstrap.initialize(...)`
- New `AnalyticsPlugin` under `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/`
- New Dart facade under `lib/services/analytics/kmp_analytics_channel.dart`
- **Excludes (v1):** Mixpanel / CleverTap / Firebase Analytics / Meta provider
  implementations — those stay in their existing Dart facades and migrate
  later (§13). iOS AppsFlyer wiring is specified but not built (runner is
  Android-only today, §1.4).

### 1.2 Why KMP

Analytics is a textbook KMP fit:

- Event names, properties, and routing decisions are vendor-neutral and
  belong in shared business logic, not in two parallel iOS/Android codebases.
- Vendor SDKs (AppsFlyer, Mixpanel, CleverTap, Firebase, Meta) all publish
  Android (Java/Kotlin) and iOS (ObjC/Swift) SDKs with mirror-image APIs —
  `expect/actual` maps cleanly onto that.
- Centralising in KMP removes the three-way drift between Dart, Android, and
  iOS analytics call sites observed today (`MixpanelSetup`, `ClevertapSetup`,
  `FirebaseAnalytics` each have their own swallow-and-log idioms).

### 1.3 Why "loose" event API

We deliberately chose a loose `track(name, props, destinations)` interface
over a sealed `AnalyticsEvent` hierarchy. Rationale:

- Analytics events on this product churn weekly — adding a sealed subtype per
  new event would create more friction than schema enforcement is worth at
  this stage.
- The Flutter MethodChannel boundary already forces serialisation to a
  primitive map, so a typed hierarchy on the KMP side would have to flatten
  back to `name + Map<String, Any?>` at the bridge anyway.
- Per-feature wrapper objects (§2.6) give us most of the typed-event benefits
  (autocomplete, refactor safety, hardcoded destinations) without locking the
  core interface.

Tradeoff accepted: typos in event names or property keys land in production
unless guarded by the §2.5 key/name constants and §2.6 wrapper convention.

### 1.4 Directory structure

Paths relative to repo root.

```
snabbit-runner-app/
+-- shared/
|   +-- src/
|       +-- commonMain/kotlin/com/snabbit/runner/shared/
|       |   +-- core/
|       |       +-- analytics/
|       |       |   +-- AnalyticsTracker.kt              -- public interface (§2)
|       |       |   +-- AnalyticsTrackerImpl.kt          -- router-backed impl (§3)
|       |       |   +-- AnalyticsConfig.kt               -- host-supplied dev key + debug flag (§14.3)
|       |       |   +-- Destination.kt                   -- enum of provider IDs (§3.1)
|       |       |   +-- AnalyticsProvider.kt             -- internal SPI each vendor implements (§4)
|       |       |   +-- PropertyValue.kt                 -- allowed primitive types + sanitiser (§2.4)
|       |       |   +-- di/
|       |       |       +-- AnalyticsModule.kt           -- Koin: tracker (§14.1)
|       +-- androidMain/kotlin/com/snabbit/runner/shared/
|       |   +-- core/
|       |       +-- analytics/
|       |       |   +-- providers/
|       |       |       +-- AppsFlyerAndroidProvider.kt  -- AppsFlyer Android SDK adapter; init listener is null (§5)
|       |       |   +-- di/
|       |       |       +-- AnalyticsPlatformModule.kt   -- Koin: provider, Context-bound bits (§14.2)
|       |       +-- AndroidManifest.xml                  -- adds INTERNET / ACCESS_NETWORK_STATE / AD_ID (§5.7, §16.2)
|       +-- iosMain/kotlin/com/snabbit/runner/shared/
|           +-- core/
|               +-- analytics/
|                   +-- providers/
|                       +-- AppsFlyerIosProvider.kt      -- AppsFlyer iOS SDK adapter (§6, spec only)
+-- android/
|   +-- app/src/main/kotlin/com/snabbit/runner/
|       +-- SnabbitRunnerApplication.kt                  -- passes AppsFlyer dev key to KmpBootstrap (§8.1)
|       +-- kmp_bridge/
|           +-- AnalyticsPlugin.kt                       -- FlutterPlugin + KoinComponent (§11)
+-- lib/
    +-- services/
        +-- analytics/
            +-- kmp_analytics_channel.dart               -- Dart facade over MethodChannel (§12)
            +-- analytics_destinations.dart              -- mirror of Destination enum for Dart callers
            +-- analytics_service.dart                   -- existing — kept for Firebase RC user properties (§13.1)
            +-- job_lifecycle_analytics.dart             -- existing — migrates to kmp_analytics_channel in phase 2
```

**Layout:** All vendor-neutral logic in `commonMain`. Each vendor's SDK
adapter lives in the platform source set where its SDK is available.
Dart-side callers go through one channel and one facade.

### 1.5 Design goals

| Goal                              | Rationale                                                                                            |
| --------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Single funnel for all events      | Eliminate the three-way drift across `MixpanelSetup`, `ClevertapSetup`, `FirebaseAnalytics` in Dart  |
| Per-event destination routing     | Some events (install, revenue) only matter to AppsFlyer; others (product funnels) only to Mixpanel   |
| Analytics never crashes the app   | All provider calls wrapped — exceptions logged, never rethrown (§10)                                 |
| Bootstrap never blocks app launch | Provider `start()` runs on a fire-and-forget coroutine. Application.onCreate proceeds while AF inits in background |
| Pluggable providers               | Adding Mixpanel = one `AnalyticsProvider` impl + one enum entry; zero changes to existing call sites |
| Vendor SDKs stay out of `commonMain` | `commonMain` has zero references to `com.appsflyer.*` or vendor types — only the SPI                |
| Vendor SDK lives in `shared/`, not the host | `shared/androidMain` carries the AppsFlyer dependency. Mirrors how `OkHttp` lives in `shared/androidMain` for `defaultHttpClientEngine` |
| Flutter-callable today            | MethodChannel surface mirrors the KMP API one-for-one                                                |

### 1.6 What this module is not

- **Not a consent manager.** India-only product, no opt-in legally required
  today (§18.1 tracks the DPDP Act exposure that would change this). The
  tracker fires every event to every registered + currently-configured
  destination. `reset()` (§8.3) clears identity on logout; that's the only
  user-controlled lever.
- **Not a user-property store for Firebase Remote Config targeting.** That is
  the existing `lib/services/analytics/analytics_service.dart` job (sets
  `cluster_id`, `region_id`, etc. as Firebase Analytics user properties so
  RC conditions can target them). Phase 1 leaves that path untouched (§13.1).
- **Not a session manager.** Session boundaries come from the OS lifecycle
  via each vendor SDK; this module does not synthesise its own sessions.
- **Not a debugger / event-viewer UI.** `AnalyticsConfig.debugLogging`
  prints routed events to the `Logger` in debug builds (§4.4); richer
  tooling is out of scope.

---

## 2. Public API

The public surface is a single interface, exposed via Koin and the Flutter
bridge.

### 2.1 `AnalyticsTracker` interface

```kotlin
// shared/src/commonMain/.../core/analytics/AnalyticsTracker.kt

interface AnalyticsTracker {

    /**
     * Fire an event to whichever destinations [analyticsRoutes] maps it
     * to. Events not in the route map drop silently (debug builds log).
     *
     * @param name  Event name — discipline lives in [analyticsRoutes].
     * @param props Property bag — sanitised by [PropertyValue]; null
     *              values dropped, Int widened to Long, strings >1024
     *              chars truncated.
     */
    fun track(name: String, props: Map<String, Any?> = emptyMap())

    /**
     * Associate the current device with a backend user. Null clears
     * identity. Fans to all registered providers — identity is not
     * routed.
     */
    fun identify(userId: String?)

    /**
     * Clear identity and reset device-scope state. Call on logout. Fans
     * to all registered providers (AppsFlyer: `setCustomerUserId(null)`
     * + `anonymizeUser(true)`).
     */
    fun reset()
}
```

The routing table is a sibling top-level val:

```kotlin
// shared/src/commonMain/.../core/analytics/AnalyticsRoutes.kt
internal val analyticsRoutes: Map<String, Set<Destination>> = mapOf(
    "otp_verification_success" to setOf(Destination.AppsFlyer),
    "language_selected"        to setOf(Destination.AppsFlyer),
)
```

Wired into Koin in §14.1.

### 2.2 What's deliberately missing

- **`setUserProperty`** — AppsFlyer has no concept. Re-add as a no-op-by-default
  SPI method when Mixpanel/CleverTap arrive in phase 2.
- **`flush(): suspend`** — AppsFlyer flushes on its own schedule. Re-add when a
  vendor that exposes a flush primitive lands and a call site actually
  needs it (e.g. logout teardown for Mixpanel).
- **`traits: Map` on `identify`** — only Mixpanel/CleverTap can use them; AF
  ignores. Re-add with `setUserProperty`.
- **Suspend on `track`/`identify`** — every target SDK queues internally;
  forcing call sites into coroutines for no benefit.

### 2.3 Why KMP-side routing (v0.8) — and why we used to do call-site

**Today (v0.8):** `analyticsRoutes` in `:shared` is the single source of
truth. Every event AF can ever see is auditable in one file. PR review of
that file is the gate. Call sites carry zero routing concerns.

**Earlier (v0.1–0.7):** call sites passed `destinations: Set<Destination>`
explicitly. Rationale at the time: the interface is loose (string + map)
so destinations had to live somewhere, and the call site was readable.
Per-feature wrappers (§2.6) hardcoded the set so day-to-day callers saw
one named function, not a long destination list.

**Why we moved:** with multiple wrappers (`OnboardingAnalytics`,
`JobLifecycleAnalytics`, …) each maintaining their own
`_afRelevantEvents` allowlist, the AF surface fragmented. A single Kotlin
map replaces N Dart sets and removes "which destinations does this fire
to?" as a question for any call site that goes through the tracker.

**Tradeoff:** changes to `analyticsRoutes` ship in the APK, not via
Shorebird (Kotlin code is not patched by Code Push). Acceptable —
AF surface changes are not high-frequency.

### 2.4 Property values — `PropertyValue` and the JSON-safe contract

Properties must round-trip across the MethodChannel back to KMP and onward
to each vendor SDK. The contract on `Map<String, Any?>` values is:

| Allowed                                  | Why                                                  |
| ---------------------------------------- | ---------------------------------------------------- |
| `String`                                 | Universal                                            |
| `Int`, `Long`                            | Long survives MethodChannel as long; Int widens to Long on bridge crossing — document this |
| `Double`, `Float`                        | Double survives; Float widens                        |
| `Boolean`                                | Universal                                            |
| `List<Any?>` of the above (homogeneous)  | Some vendors flatten heterogeneous lists oddly       |
| `Map<String, Any?>` of the above (nested)| Vendors vary — AppsFlyer flattens, Mixpanel preserves|
| `null`                                   | Dropped from the outgoing payload                    |

`PropertyValue.sanitize(props: Map<String, Any?>): Map<String, Any?>` runs
on every call. It:

1. Strips nulls.
2. Widens `Int`/`Short`/`Byte` → `Long` (Dart `int` always lands as `Long`,
   so this makes call-origin irrelevant — see §9.1).
3. Replaces values outside the allowed set with `toString()` and logs a
   warning.
4. Truncates strings >1024 chars (AppsFlyer silently drops at ~1k).

Sanitisation runs once at the tracker boundary.

### 2.5 No event-name / key catalogue in v1

v0.3 specced `AnalyticsEvents.kt` + `AnalyticsKeys.kt` constant objects;
v0.6 drops them. Rationale:

- The only KMP-side consumer in v1 is the `AnalyticsTracker` interface
  itself, which takes raw `String` names. Per-feature wrappers (§13.5) own
  event names today — and those wrappers live in Dart, where Kotlin
  constants don't help.
- A Kotlin catalogue with no Kotlin call sites is dead code.
- When per-feature KMP wrappers (Kotlin-side `BookingAnalytics`, etc.)
  arrive in phase 2, each wrapper owns its own canonical names inline.
  Centralised catalogues only pay back when callers actually share them.

If event-name canonicalisation becomes a real problem, re-add then.
Don't pre-build for it.

### 2.6 Per-feature wrappers — the soft-typing convention

The loose API is *meant* to be wrapped per feature. Example:

```kotlin
// shared/src/commonMain/.../features/booking/BookingAnalytics.kt
class BookingAnalytics(private val tracker: AnalyticsTracker) {

    fun accepted(bookingId: String, serviceType: String, etaMin: Int) {
        tracker.track(
            name = "booking_accepted",
            props = mapOf(
                "booking_id" to bookingId,
                "service_type" to serviceType,
                "eta_min" to etaMin,
            ),
            destinations = setOf(Destination.AppsFlyer, Destination.Mixpanel),
        )
    }
}
```

Callers see one named function. Event name, properties, and destinations
are all baked in. PR review of `BookingAnalytics` is where schema discipline
happens — no central catalogue needed.

The same convention applies on the Dart side (§12).

### 2.7 Property cardinality and PII

Three rules enforced by review, not code:

- **No PII in property values.** Phone, email, name, exact location must not
  be tracked. Use hashed identifiers if necessary.
- **No unbounded-cardinality keys.** No timestamps as keys, no per-request
  UUIDs as keys — they become unusable funnels.
- **`identify(userId)` is the only place a raw backend user id flows.**
  Property maps should never carry it except as a destination-scoped trait.

---

## 3. Destinations and routing

### 3.1 `Destination` enum

```kotlin
// shared/src/commonMain/.../core/analytics/Destination.kt
enum class Destination {
    AppsFlyer,
    Mixpanel,         // v1: not implemented; reserved
    CleverTap,        // v1: not implemented; reserved
    FirebaseAnalytics,// v1: not implemented; reserved
    Meta;             // v1: not implemented; reserved

    companion object {
        val ALL: Set<Destination> = values().toSet()

        /** Convenience: providers attribution / install / revenue cares about. */
        val ATTRIBUTION: Set<Destination> = setOf(AppsFlyer)

        /** Convenience: in-product funnel tools (post-migration). */
        val PRODUCT: Set<Destination> = setOf(Mixpanel, CleverTap)
    }
}
```

### 3.2 Routing flow

```
call site
   |
   v
AnalyticsTracker.track(name, props)
   |
   v
AnalyticsTrackerImpl
   |   1. destinations = analyticsRoutes[name] ?: return  // unmapped → drop, debug log
   |   2. sanitize(props)                                  — §2.4
   |   3. for each destination d in Destination.entries (deterministic order):
   |        if d not in destinations: continue
   |        provider = providers[d] ?: continue            // unregistered → drop, §3.3
   |        runCatching { provider.track(name, props) }
   |          .onFailure { logger.e("$d.track failed for '$name'", t); crashReporter.report(t, mapOf("provider" to d.name, "op" to "track", "name" to name)) }
   v
AppsFlyerAndroidProvider.track(name, props)
   v
AppsFlyerLib.getInstance().logEvent(ctx, name, props as Map<String, Any>, null)
```

Iteration follows `Destination.entries` order — deterministic across runs.

### 3.3 Unknown destinations are silently dropped

Routing to `Destination.Mixpanel` in v1 (before the Mixpanel provider exists)
is a no-op — `providers[Mixpanel]` returns null. This is intentional:

- Call sites can declare their full destination set today without waiting
  for every provider to land.
- The migration from Dart `MixpanelSetup` → KMP `MixpanelProvider` becomes a
  drop-in: when the provider is registered, those routes start firing
  without any call-site edit.

A periodic log line (`Logger.d("analytics: $name dropped for $missing")`)
surfaces routes that consistently fall on the floor.

### 3.4 No remote-config override in v1

We deliberately rejected runtime override of destinations via Firebase RC in
the design discussion. Destinations live in code. If a vendor needs to be
kill-switched, that's a code change + release. Reconsider if a real outage
demonstrates the need.

---

## 4. Provider SPI

### 4.1 `AnalyticsProvider` interface

```kotlin
// shared/src/commonMain/.../core/analytics/AnalyticsProvider.kt

interface AnalyticsProvider {

    /** Stable id — matches a [Destination] entry. */
    val destination: Destination

    /**
     * Called once at bootstrap from [KmpBootstrap.initialize] via
     * [AnalyticsTrackerImpl.bootstrap]. Vendor-specific:
     *
     *  - AppsFlyer: `init(devKey, null, ctx)` then `start(app, requestListener)`.
     *  - Mixpanel (future): `Mixpanel.getInstance(ctx, token)`.
     *
     * Throws — caller catches, disables that destination, logs.
     */
    suspend fun start()

    /** Vendor-specific event log. Sanitised props; caller traps exceptions. */
    fun track(name: String, props: Map<String, Any?>)

    /** Null = clear identity (vendor-specific). */
    fun identify(userId: String?)

    /** Reset device-scope state. Vendor-specific. */
    fun reset()
}
```

### 4.2 Provider registration

Providers are registered in the platform Koin module and collected into a
`Map<Destination, AnalyticsProvider>` by `AnalyticsTrackerImpl`. The
platform module reads `AnalyticsConfig` (§14.3) and **only registers a
provider if its config slot is populated** — a blank AppsFlyer dev key
means no `AppsFlyerProvider` binding, which means `providers[AppsFlyer]`
returns null, which is handled by §3.3 ("unknown destination → drop").
This is how we run dev / unit-test builds without AF credentials without
needing extra flags.

```kotlin
// shared/androidMain/.../core/analytics/di/AnalyticsPlatformModule.kt
val analyticsAndroidModule = module {
    // AppsFlyer — only registered when the dev key is present.
    val devKey = getProperty<String?>("appsflyer.devKey") // injected by KmpBootstrap, §14.3
    if (!devKey.isNullOrBlank()) {
        single<AnalyticsProvider>(named("appsflyer")) {
            AppsFlyerAndroidProvider(
                context = androidContext(),
                devKey = devKey,
                debugLogging = get<AnalyticsConfig>().debugLogging,
                logger = get(),
                appDispatchers = get(),
                crashReporter = get(),
            )
        }
    }
    // Future:
    // single<AnalyticsProvider>(named("mixpanel")) { MixpanelAndroidProvider(...) }
}
```

The tracker resolves all providers via `getAll<AnalyticsProvider>()` and
groups by `destination`.

### 4.3 No vendor-type leakage in `commonMain`

Hard rule, mirrored from snabbit-comm: nothing in `commonMain/.../analytics/`
imports `com.appsflyer.*`, `com.mixpanel.*`, etc. The SPI is the boundary.
PR review enforces; no test scanner needed for v1 (we control the imports).

### 4.4 Debug logging

`AnalyticsTrackerImpl` writes every routed event to `Logger.d` when
`AnalyticsConfig.debugLogging` is true. No separate `LoggingProvider` class
— it would just wrap the same `Logger`. Disabled in release.

---

## 5. AppsFlyer provider — Android

### 5.1 SDK choice and version

- Package: `com.appsflyer:af-android-sdk:6.18.0` (latest stable on Maven
  Central as of 2026-06-03). Pin to a specific patch version in
  `shared/build.gradle.kts`.
- Optional: `com.android.installreferrer:installreferrer:2.2` — required for
  Play Store install referrer parsing; AppsFlyer auto-detects it at runtime.

### 5.2 Init lifecycle

AppsFlyer Android requires these calls in order:

```kotlin
val af = AppsFlyerLib.getInstance()
if (debugLogging) af.setDebugLog(true)        // must precede init()
af.init(devKey, null, applicationContext)     // null listener — §5.5
af.start(application, devKey, requestListener) // optional listener — §5.5
```

Constraints:

1. Must run with the `Application` instance, not an `Activity` — guaranteed
   by §14.3 typing `app: Application`.
2. `setDebugLog` must precede `init`; AF caches the flag at init time.
3. `init` second argument is `null` — see §5.5 for why.
4. Both calls together complete in ~20–80 ms on a typical mid-range device.
   Even on bad networks AF returns quickly; the actual attribution traffic
   is async and doesn't block `start()`.

Wiring (see §8.1 for full diagram):

```
// Top of SnabbitRunnerApplication.kt — see §14.3 / Appendix A for rationale.
private const val APPSFLYER_DEV_KEY = "..."   // blank → AF provider not registered

SnabbitRunnerApplication.onCreate
  +-- KmpBootstrap.initialize(
  |     app = this,
  |     crashReporter = { t, m -> Firebase.crashlytics.recordException(t) },
  |     analyticsConfig = AnalyticsConfig(
  |       appsFlyerDevKey = APPSFLYER_DEV_KEY,
  |       debugLogging = BuildConfig.DEBUG,
  |     ),
  |   )
        +-- startKoin (loads coreModule + platformModule + analyticsModule + analyticsAndroidModule)
        +-- CoroutineScope(SupervisorJob() + Dispatchers.Main).launch {
              (tracker as AnalyticsTrackerImpl).bootstrap()  // calls provider.start() for each
        }
```

### 5.3 Event-name and property mapping

AppsFlyer has canonical event names (`AFInAppEventType.*`) and parameter
keys (`AFInAppEventParameterName.*`) that unlock attribution features
(retargeting, revenue counting). In v1 we have **no canonical mappings to
apply** — events flow through verbatim. When Growth asks for retargeting
on `LOGIN` or revenue on `PAYOUT_INITIATED`, add the mapping as a private
`when` inside `AppsFlyerAndroidProvider.track()`. Don't preemptively
extract a `Mapper` class for an empty mapping table.

Property values: `Map<String, Any>` (AF rejects nulls; §2.4 already
dropped them).

### 5.4 `setCustomerUserId` for `identify`

AF ties user id to attribution. Install event is always attributed to the
anonymous device; the user id attaches on the first post-login event and
AF's dashboard joins them. Implementation:

```kotlin
override fun identify(userId: String?) {
    val af = AppsFlyerLib.getInstance()
    if (userId == null) {
        af.setCustomerUserId(null)
        af.anonymizeUser(true)
    } else {
        af.anonymizeUser(false)
        af.setCustomerUserId(userId)
    }
}
```

Called from §8.2 (login) and §8.3 (logout). Safe before `start()` returns
— AF buffers these.

### 5.5 No conversion listener; `AppsFlyerRequestListener` only

**`init`'s second argument is `null`.** Per AppsFlyer's docs, the
`AppsFlyerConversionListener` is optional and recommended `null` for
install-attribution-only integrations. The runner app has no page-specific
deep links (no `app_links`, `uni_links`, `firebase_dynamic_links`, or
`go_router` — only `otpless://` auth callback + FCM intent filter) so
`onAppOpenAttribution` and `onConversionDataSuccess.deep_link_value` have
no consumer. Wiring the listener now would produce dead `SharedFlow`s.

We do wire **`AppsFlyerRequestListener`** on `start()` — this is the
orthogonal "did the request succeed" callback, not the conversion API:

```kotlin
af.start(application, devKey, object : AppsFlyerRequestListener {
    override fun onSuccess() {
        logger.d(TAG, "AppsFlyer start succeeded")
    }
    override fun onError(code: Int, errorMessage: String) {
        logger.e(TAG, "AppsFlyer start failed: code=$code msg=$errorMessage")
        crashReporter.report(
            IllegalStateException("AppsFlyer start failed: $code $errorMessage"),
            mapOf("provider" to "AppsFlyer", "code" to code.toString()),
        )
    }
})
```

Catches "wrong dev key" at runtime. Five lines, no flow, no class.

**Forward pointer (phase 2):** when Mixpanel/CleverTap migrate to KMP and
marketing wants install-source super properties (`media_source`,
`campaign`) attached to product events, the `AppsFlyerConversionListener`
comes back — re-add as `AppsFlyerConversionRelay` exposing a
`SharedFlow<ConversionData>` for the Mixpanel/CleverTap providers to
consume. Don't pre-build; the shape isn't load-bearing for v1.

### 5.6 Failure modes

| Mode                          | Behaviour                                                                  |
| ----------------------------- | -------------------------------------------------------------------------- |
| Dev key blank / missing       | Provider **not registered** in Koin (§4.2). `providers[AppsFlyer]` is null. AF-routed events drop with the §3.3 "unknown destination" log. |
| Dev key invalid               | `init` + `start` succeed locally; AF reports failure async via `AppsFlyerRequestListener.onError(code, msg)` — logged + crashReporter (§5.5). Events fire; AF drops them server-side. |
| `start()` throws              | Caught in `AnalyticsTrackerImpl.bootstrap`; logged + crashReporter; that destination is disabled for the process. |
| `track()` throws              | Caught in tracker `runCatching` (§3.2); logged + crashReporter; single-event failure doesn't taint subsequent calls. |
| Play Store referrer missing   | Non-fatal — AF falls back to other attribution sources. |
| Process without GMS           | Provider starts; AF degrades to fallback attribution. |

### 5.7 AndroidManifest additions

Required permissions (added under `shared/src/androidMain/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<!-- Optional but recommended for attribution quality -->
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />
```

The `INSTALL_REFERRER_SERVICE` receiver from `installreferrer:2.2` is
declared by that library's manifest — nothing to add for it.

### 5.8 ProGuard / R8

AppsFlyer ships consumer ProGuard rules (`consumer-rules.pro`). Nothing to
add manually.

---

## 6. AppsFlyer provider — iOS (spec only)

Documented now so the API boundary is correct; not built in v1 (runner app
is Android-only — see `CLAUDE.md`).

### 6.1 SDK

- `AppsFlyerFramework` ~6.14+
- Distributed via CocoaPods (`pod 'AppsFlyerFramework'`) or SPM. Decide at
  iOS-enable time.

### 6.2 Lifecycle

```swift
AppsFlyerLib.shared().appsFlyerDevKey = "..."
AppsFlyerLib.shared().appleAppID = "..."        // App Store ID
AppsFlyerLib.shared().delegate = conversionDelegate
AppsFlyerLib.shared().start()                   // call after ATT prompt resolves
```

iOS-specific extra: must run `ATTrackingManager.requestTrackingAuthorization`
*before* `start()` if we want IDFA. Without it AF falls back to SKAdNetwork.

### 6.3 `expect` boundaries

The vendor-neutral surface is concrete — `AnalyticsTracker`,
`AnalyticsProvider`, `AnalyticsConfig` all live in `commonMain` and don't
need `expect/actual`. Platform divergence is in the providers themselves,
which live entirely under platform source sets. No `expect/actual`
declarations needed for the v1 surface; the iOS adapter slots in by
adding a `single<AnalyticsProvider>` binding to an
`AnalyticsPlatformModule.ios.kt` Koin module.

---

## 7. Consent — out of scope

**No consent gate. India-only product; the product decision is to not
collect explicit analytics consent.**

`reset()` (§8.3) clears identity on logout, which is the only user-facing
lever. There is no `ConsentState`, no `ConsentGate`, no opt-out plumbing,
no `analytics_consent` channel.

The trigger to revisit is the **DPDP Act (Digital Personal Data Protection
Act, 2023)** — see §18.1. If/when that flips, the right entry points are:

- A `ConsentGate` inserted at §3.2 step 1.5 (between sanitise and dispatch).
- A `MutableStateFlow<ConsentState>` Koin binding the gate reads.
- A new `AnalyticsConsentPlugin` (Flutter MethodChannel) that mutates that
  state flow from a Dart-side consent UI.
- `provider.reset()` invoked when a destination flips from granted →
  denied.

All four are deferrable; the rest of this LLD is built so they can be
added without changing call sites or the public API.

---

## 8. Lifecycle and integration points

### 8.1 Application boot

```
1. Process start
   |
   +-- SnabbitRunnerApplication.onCreate                             (existing, +1 param)
   |     +-- super.onCreate()                                        (CleverTap base — runs first)
   |     +-- KmpBootstrap.initialize(
   |     |     app = this,
   |     |     crashReporter = { t, m -> /* Firebase.crashlytics... */ },
   |     |     analyticsConfig = AnalyticsConfig(
   |     |       appsFlyerDevKey = APPSFLYER_DEV_KEY,                (top-level const — blank → provider not registered)
   |     |       debugLogging = BuildConfig.DEBUG,
   |     |     ),
   |     |   )
   |     |     +-- AeadConfig.register()                             (existing)
   |     |     +-- startKoin { modules(platformModule, coreModule, analyticsModule, analyticsAndroidModule) }
   |     |     +-- CoroutineScope(SupervisorJob() + Dispatchers.IO).launch { StoreManager.hydrateAll() }  (existing)
   |     |     +-- CoroutineScope(SupervisorJob() + Dispatchers.Main).launch {
   |     |           tracker.bootstrap()  // for each provider: runCatching { p.start() }
   |     |         }
   |
   +-- FlutterEngine boots                                            (existing — MainActivity)
         +-- AnalyticsPlugin attaches (§11)
         +-- Dart-side analytics calls flow through MethodChannel
```

Things deliberately not wired here:

- **No `AF_INSTALL` synthetic emit.** AF fires install itself on `start()`.
- **No StoreManager dedupe flag.** AF handles install dedupe internally.
- **No start timeout.** AF init is fast; if it hangs, that's a Crashlytics
  signal, not something the analytics module should paper over.

### 8.2 Login flow

```
Dart: login API succeeds → user id known
   |
   +-- kmp_analytics_channel.identify(userId, destinations: {AppsFlyer})
         +-- AnalyticsPlugin → tracker.identify(...)
               +-- AppsFlyerProvider.identify(userId)
                     +-- AppsFlyerLib.setCustomerUserId(userId)
                     +-- AppsFlyerLib.anonymizeUser(false)
```

### 8.3 Logout flow

```
Dart: logout intent
   |
   +-- analyticsBookingExit / shutdown events fire             (still attached to user — reset has not run)
   +-- kmp_analytics_channel.reset(destinations: Destination.ALL)
   |     +-- tracker.reset(ALL)
   |           +-- AppsFlyerAndroidProvider.reset()
   |                 +-- setCustomerUserId(null) + anonymizeUser(true)
   +-- AuthPlugin.clearToken()                                  (existing — MUST run after analytics reset)
```

Ordering rule: any teardown analytics fire **before** `reset(ALL)`; `reset`
fires **before** `AuthPlugin.clearToken`. Reversing #1 and #2 attributes
the logout-trail events to the anonymous device. Reversing #2 and #3 risks
the AF SDK racing against the cleared auth state on its background flush
(not destructive, but generates a confusing AF dashboard row).

Dart-side enforcement: `LogoutFlow` coroutine in `lib/services/auth/`
(existing) calls these in the documented order. Add a comment pointing at
this section.

---

## 9. Property values across the bridge

### 9.1 Channel codec

We use Flutter's `StandardMethodCodec` (default). It supports `String`,
`int`, `double`, `bool`, `List`, `Map<String, Object>`, and `null`.

Two notable behaviours:

- Dart `int` → Kotlin `Long` (not `Int`). The §2.4 sanitiser also widens
  Kotlin-side `Int`/`Short`/`Byte` → `Long`, so every property value of an
  integral type ends up as `Long` regardless of call origin. This is the
  single source of truth — providers must accept `Long` for integral
  values.
- Dart-side `Map<String, dynamic>` → Kotlin `Map<Any?, Any?>` — we coerce
  to `Map<String, Any?>` at the plugin boundary, dropping non-string keys
  with a warning (the sanitiser also does this for any nested map, §2.4
  step 5).

### 9.2 Round-trip test

`AnalyticsPluginPropertiesTest` (`androidInstrumentedTest`) sends every
allowed value type through the channel and asserts the Kotlin side receives
the documented Kotlin type. Catches codec drift early.

---

## 10. Failure semantics

Analytics must never crash the app. Three rules:

1. **Sanitisation throws nothing.** `PropertyValue.sanitize` coerces or
   stringifies bad inputs and logs.
2. **Each provider call is wrapped.** `AnalyticsTrackerImpl` wraps every
   `provider.track / identify / reset` in
   `runCatching { ... }.onFailure { logger.e(...); crashReporter.report(t, mapOf("provider" to d.name, "event" to name)) }`.
3. **Provider `start()` failures don't stop bootstrap.** A failed AppsFlyer
   init disables that destination only.

What we don't do:

- **Don't swallow silently.** Every failure logs at WARN/ERROR with the
  destination and event name (no property values — those may contain
  PII-shaped strings; log `props.keys` instead).
- **Don't retry on track failure.** Vendor SDKs retry internally.
- **Don't rethrow from any analytics call site.** The wrapper is the wall.
- **Don't gate the tracker on provider readiness.** Events arriving
  during the millisecond window between `KmpBootstrap.initialize` returning
  and `provider.start()` completing call straight through; AF buffers them
  internally. The race is too tight to justify a protocol.

---

## 11. Flutter bridge — `AnalyticsPlugin`

### 11.1 Channels

| Channel                                      | Type          | Direction      | Purpose                                                 |
| -------------------------------------------- | ------------- | -------------- | ------------------------------------------------------- |
| `com.snabbit.runner/analytics`               | MethodChannel | Dart → KMP     | `track` / `identify` / `reset`                          |

One channel. No EventChannels — without conversion data / deep links to
push, there's nothing for KMP to stream to Dart.

### 11.2 `AnalyticsPlugin.kt`

```kotlin
// android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/AnalyticsPlugin.kt

class AnalyticsPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    KoinComponent {

    private val tracker: AnalyticsTracker by inject()
    private lateinit var method: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        method = MethodChannel(binding.binaryMessenger, "com.snabbit.runner/analytics")
        method.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "track" -> {
                tracker.track(
                    name = call.argument<String>("name")!!,
                    props = call.argument<Map<String, Any?>>("props") ?: emptyMap(),
                    destinations = call.argument<List<String>>("destinations")!!.toDestinationSet(),
                )
                result.success(null)
            }
            "identify" -> {
                tracker.identify(
                    userId = call.argument<String?>("userId"),
                    destinations = call.argument<List<String>>("destinations")!!.toDestinationSet(),
                )
                result.success(null)
            }
            "reset" -> {
                tracker.reset(
                    destinations = call.argument<List<String>>("destinations")
                        ?.toDestinationSet() ?: Destination.ALL
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        method.setMethodCallHandler(null)
    }
}
```

Registered in `MainActivity.configureFlutterEngine` alongside the existing
`NetworkConfigPlugin` / `AuthPlugin` / `KmpHelloPlugin` (`MainActivity.kt:129-131`).

### 11.3 Destination encoding across the channel

Destinations cross as `List<String>` (e.g. `["AppsFlyer", "Mixpanel"]`).
`List<String>.toDestinationSet()` extension parses to enum, ignoring (with a
warning log) any unknown values. Forward-compatible: a Dart caller using
`"Meta"` before the KMP Meta provider exists is a no-op, not an error.

---

## 12. Dart facade

### 12.1 `KmpAnalyticsChannel`

```dart
// lib/services/analytics/kmp_analytics_channel.dart

class KmpAnalyticsChannel {
  KmpAnalyticsChannel._();
  static final instance = KmpAnalyticsChannel._();

  static const _method = MethodChannel('com.snabbit.runner/analytics');

  Future<void> track({
    required String name,
    Map<String, Object?> props = const {},
    required Set<AnalyticsDestination> destinations,
  }) async {
    try {
      await _method.invokeMethod('track', {
        'name': name,
        'props': props,
        'destinations': destinations.map((d) => d.name).toList(),
      });
    } catch (e) {
      // Silent — analytics must never crash the caller. Mirror of KMP rule.
      if (kDebugMode) debugPrint('analytics.track failed: $e');
    }
  }

  Future<void> identify({
    required String? userId,
    required Set<AnalyticsDestination> destinations,
  }) async { /* mirror */ }

  Future<void> reset({
    Set<AnalyticsDestination> destinations = const {},
  }) async { /* mirror — empty set means ALL on KMP side */ }
}
```

### 12.2 Dart `AnalyticsDestination` enum

Mirror of the KMP `Destination` enum. Hand-maintained in v1; auto-gen target
in §17.

### 12.3 Per-feature Dart wrappers

Mirror of §2.6:

```dart
// lib/services/analytics/booking_analytics.dart
class BookingAnalytics {
  static Future<void> accepted({
    required String bookingId,
    required String serviceType,
    required int etaMin,
  }) =>
      KmpAnalyticsChannel.instance.track(
        name: 'booking_accepted',
        props: {
          'booking_id': bookingId,
          'service_type': serviceType,
          'eta_min': etaMin,
        },
        destinations: {AnalyticsDestination.appsFlyer},
      );
}
```

Day-to-day Dart code touches `BookingAnalytics.accepted(...)`, never the raw
channel.

---

## 13. Coexistence with existing Dart analytics

v1 leaves the existing Mixpanel / CleverTap / Firebase Analytics Dart
facades **untouched** for their own destinations — they keep firing in
parallel. The one exception is per-feature wrappers that own
attribution-relevant events: those gain a small dual-fire to the KMP
AppsFlyer destination (§13.5). No changes to `mixpanel_setup.dart` /
`clevertap.dart` / `analytics_service.dart` themselves.

### 13.1 `lib/services/analytics/analytics_service.dart` (Firebase RC user props)

**Stays as-is permanently** *or* moves into KMP later — open question
(§18.1). Critical constraint: the `cluster_id` / `region_id` /
`training_center_id` / `service_id` / `build_type` / `account_id` user
properties feed Firebase Remote Config conditions. Any change must preserve
those properties as Firebase Analytics user properties, not as KMP-side
state.

### 13.2 `lib/services/mixpanel_setup.dart`

Continues firing through the existing `mixpanel_flutter` plugin. Phase 2
migration plan:

1. Implement `MixpanelAndroidProvider` (`com.mixpanel.android:mixpanel-android`)
   in KMP.
2. Register under `Destination.Mixpanel`.
3. Switch call sites one feature at a time from `MixpanelSetup.logEvent` →
   per-feature KMP wrapper. Verify event parity in Mixpanel dashboard before
   removing the old call.
4. Once all call sites moved, delete `mixpanel_setup.dart` and the
   `mixpanel_flutter` Pub dependency.

**Dedup during overlap.** Same event would fire twice (once via Dart
plugin, once via KMP). We use a Firebase Remote Config flag,
`analytics.dart_destinations_disabled`, that the Dart facade reads at
startup:

```dart
// lib/services/mixpanel_setup.dart
final disabledSet = (remoteConfig.getString('analytics.dart_destinations_disabled') ?? '')
    .split(',').map((s) => s.trim()).toSet();

void logEvent(String name, Map<String, Object?> props) {
  if (disabledSet.contains('mixpanel')) return;  // KMP owns this now
  _mixpanelFlutter.track(name, properties: props);
}
```

The flag flips per provider, per release. Avoids the "discipline at every
call site" failure mode where one stray `MixpanelSetup.logEvent` call
double-fires for the rest of eternity. Roll-forward and roll-back are RC
console toggles — no app release needed.

### 13.3 `lib/services/clevertap.dart`

Same plan as Mixpanel. CleverTap migration is lower priority (engagement /
push, not attribution / analytics).

### 13.4 `lib/services/analytics/job_lifecycle_analytics.dart`

Already a per-feature wrapper — already follows the §2.6 convention. Phase
1: leave alone. Phase 2: change its internals from calling MixpanelSetup
directly to calling `KmpAnalyticsChannel.instance.track(...)`. Call sites
don't change.

### 13.5 Unconditional forward to the KMP tracker (v0.8 — replaces dual-fire)

Existing per-feature Dart wrappers like `OnboardingAnalytics`
(`lib/services/analytics/onboarding_analytics.dart`) own funnel events
that AppsFlyer cares about — `otp_verification_success`,
`language_selected`, etc. These events are valuable for AF retargeting +
attribution joins even before the Mixpanel/CleverTap KMP-side migration
lands.

**Pattern: wrappers fire every event at the KMP tracker
unconditionally.** No per-wrapper allowlist. The KMP tracker reads
`analyticsRoutes` and drops anything not mapped, so AF only sees what
the routing table says it should.

```dart
// lib/services/analytics/onboarding_analytics.dart — current

static void logEvent(String name, Map<String, dynamic> props) {
  final merged = <String, dynamic>{ ..._superProps, ...props };
  MixpanelSetup.logEvent(name, merged);
  ClevertapSetup.logEvent(name, merged);
  // KMP-side analyticsRoutes decides whether AF receives this.
  KmpAnalyticsChannel.instance.track(name: name, props: merged);
}

static Future<void> identifyOnLogin(UserProfile profile) async {
  final id = profile.id.toString();

  // Each platform call is a MethodChannel hop. Sequencing them with
  // `await` would sum ~1-5ms round-trips into avoidable latency, and
  // none depend on the previous one (MP buffers internally, KMP
  // identify is independent). We detach each Future via .catchError
  // so async SDK throws don't surface as unhandled futures.
  MixpanelSetup.identify(id).catchError((_) {});
  KmpAnalyticsChannel.instance.identify(userId: id).catchError((_) {});

  MixpanelSetup.setUserProfile({ /* phone, runner_id, cluster_id, ... */ })
      .catchError((_) {});
  registerSuperProperties({ /* runner_id, cluster_id, region_id */ });
}

// Caller signals intent:
// unawaited(OnboardingAnalytics.identifyOnLogin(profile));
```

Rules:

- **No filter on the Dart side.** Don't pre-check `_afRelevantEvents` or
  similar. KMP filters. Anything else is shadow state.
- **Merged props are sent unmodified.** Sanitisation runs on the KMP
  side (`PropertyValue.sanitize`).
- **Identity calls in `identifyOnLogin`** always reach AF (and any
  future KMP provider) — identity is not routed, only event traffic is.
- **No `traits` to AF.** AF ignores them; the Mixpanel `setUserProfile`
  call stays Dart-side.

**Phase 2 unwind.** When Mixpanel/CleverTap KMP providers land and
`OnboardingAnalytics` migrates off direct `MixpanelSetup` /
`ClevertapSetup` calls, the entire `logEvent` body collapses to a single
`KmpAnalyticsChannel.instance.track(name, props)` call —
`analyticsRoutes` already knows where each event goes. The §13.2 Remote
Config dedup flag handles the cutover so Mixpanel/CleverTap don't
double-fire during the transition.

**Other wrappers to apply this pattern to in v1:**

- `lib/services/analytics/job_lifecycle_analytics.dart` — same pattern
  if/when it adopts the KMP channel. Adding AF coverage for its events
  is just an `analyticsRoutes` entry on the KMP side.
- New per-feature wrappers: forward every event to
  `KmpAnalyticsChannel`; add `analyticsRoutes` entries on the KMP side
  for the ones AF should receive. PR review of
  `AnalyticsRoutes.kt` is the AF surface gate.

---

## 14. Dependency injection (Koin)

### 14.1 `AnalyticsModule.kt` (commonMain)

```kotlin
// shared/src/commonMain/.../core/analytics/di/AnalyticsModule.kt
val analyticsModule = module {
    single<AnalyticsTracker> {
        AnalyticsTrackerImpl(
            providers = getAll<AnalyticsProvider>(),
            routes = analyticsRoutes,
            debugLogging = get<AnalyticsConfig>().debugLogging,
            logger = get<Logger>(),
            crashReporter = get<CrashReporter>(),
        )
    }
}
```

### 14.2 `AnalyticsPlatformModule.kt` (androidMain)

See §4.2 for the module sketch. One rule: **provider registration is
conditional on dev key presence.** Blank/missing key means no Koin
binding, no provider, no event flow — the tracker drops AF-destination
events with the §3.3 log. This is the dev / unit-test path.

`AnalyticsConfig` itself is bound by `KmpBootstrap.initialize` (§14.3) so
the module sees it at startup time.

### 14.3 Bootstrap addition

`KmpBootstrap.initialize` gains one optional `analyticsConfig` parameter.
The existing `app: Application` and `crashReporter` signatures are
preserved.

```kotlin
// shared/src/androidMain/.../core/KmpBootstrap.kt — updated
object KmpBootstrap {
    fun initialize(
        app: Application,
        crashReporter: ((Throwable, Map<String, String>) -> Unit)? = null,
        analyticsConfig: AnalyticsConfig = AnalyticsConfig.Disabled,
    ) {
        AeadConfig.register()
        startKoin {
            androidContext(app)
            modules(
                platformModule(app, crashReporter),
                coreModule,
                analyticsModule,
                analyticsAndroidModule(analyticsConfig),  // factory, see below
            )
        }

        // Existing hydrateAll path (unchanged) — see KmpBootstrap.kt:46-53.
        val log = getKoin().get<Logger>()
        val hydrateHandler = CoroutineExceptionHandler { _, t ->
            log.e(TAG, "hydrateAll failed", t)
            crashReporter?.invoke(t, mapOf("op" to "hydrateAll"))
        }
        CoroutineScope(SupervisorJob() + Dispatchers.IO + hydrateHandler).launch {
            getKoin().get<StoreManager>().hydrateAll()
        }

        // Analytics bootstrap — fire-and-forget on Main. No CEH, no timeout.
        // If providers list is empty (no dev key), bootstrap() loops zero
        // times and returns immediately. Failures inside provider.start()
        // are caught by the runCatching inside bootstrap().
        CoroutineScope(SupervisorJob() + Dispatchers.Main).launch {
            (getKoin().get<AnalyticsTracker>() as AnalyticsTrackerImpl).bootstrap()
        }
    }
    // terminate() unchanged
    private const val TAG = "KmpBootstrap"
}
```

`AnalyticsConfig` (commonMain):

```kotlin
// shared/src/commonMain/.../core/analytics/AnalyticsConfig.kt
data class AnalyticsConfig(
    val appsFlyerDevKey: String? = null,
    val debugLogging: Boolean = false,
) {
    val isEnabled: Boolean get() = !appsFlyerDevKey.isNullOrBlank()
    companion object { val Disabled = AnalyticsConfig() }
}
```

`analyticsAndroidModule` is a **factory** that accepts `AnalyticsConfig`
and conditionally registers providers (§4.2). It binds `AnalyticsConfig`
itself as a `single { config }` so downstream code can resolve it.

---

## 15. Testing strategy

### 15.1 Test pyramid

| Layer                            | Source set                | What it covers                                            |
| -------------------------------- | ------------------------- | --------------------------------------------------------- |
| Unit (sanitiser)                 | `commonTest`              | `PropertyValue.sanitize` — null strip, Int→Long widening, string truncation |
| Unit (tracker routing)           | `commonTest`              | `AnalyticsTrackerImpl` — destination filtering, unknown-destination drop, exception isolation |
| Provider (AppsFlyer Android)     | `androidInstrumentedTest` | Real `AppsFlyerLib` against a **separate test dev key** (§15.4) |
| Plugin channel round-trip        | `androidInstrumentedTest` | `AnalyticsPluginPropertiesTest` — every supported property type through Flutter's StandardMethodCodec |
| Koin graph                       | `androidInstrumentedTest` | Adds `analyticsModule` + `analyticsAndroidModule` to the existing `KoinModulesTest` — verifies graph resolves with/without dev key |

### 15.2 `FakeAnalyticsProvider`

`commonTest`-only fake recording every call:

```kotlin
class FakeAnalyticsProvider(
    override val destination: Destination,
    private val throwOn: Set<String> = emptySet(),
    private val throwOnStart: Boolean = false,
) : AnalyticsProvider {
    val calls = mutableListOf<RecordedCall>()

    override suspend fun start() {
        if (throwOnStart) throw RuntimeException("simulated start failure")
        calls += RecordedCall.Start
    }
    override fun track(name: String, props: Map<String, Any?>) {
        if (name in throwOn) throw RuntimeException("simulated")
        calls += RecordedCall.Track(name, props)
    }
    override fun identify(userId: String?) { calls += RecordedCall.Identify(userId) }
    override fun reset() { calls += RecordedCall.Reset }
}
```

### 15.3 Failure isolation

`AnalyticsTrackerImplFailureTest`:

- Provider that throws on every `track` → tracker logs, doesn't crash,
  fires sibling providers correctly.
- Provider that throws on `start` → that destination is disabled, others
  remain usable.

### 15.4 AppsFlyer provider tests

`androidInstrumentedTest`: hits the real `AppsFlyerLib` with
`setDebugLog(true)` against a **dedicated test dev key** (see Appendix A).
Asserts `getAppsFlyerUID()` returns non-null after `start()`.

**The test dev key MUST be a separate AppsFlyer app, not the production
app.** CI runs would otherwise pollute production attribution dashboards
with bot installs, breaking marketing's funnel analysis. The test app is
created once in the AF console (Growth owns); the key lives in CI secrets
and is injected via Gradle `androidInstrumentedTest` resource manifest —
never committed.

### 15.5 Coverage requirement

100 % branch coverage on `commonMain` analytics files, per the runner-app
`make coverage-check` policy. Provider impls in `androidMain` are excluded
from the branch-coverage gate — instrumented tests provide functional
coverage instead.

---

## 16. Dependencies

### 16.1 `shared/build.gradle.kts` additions

```kotlin
androidMain.dependencies {
    // AppsFlyer SDK
    implementation("com.appsflyer:af-android-sdk:6.18.0")
    // Play Store install referrer — auto-detected by AppsFlyer at runtime
    implementation("com.android.installreferrer:installreferrer:2.2")
}
```

`commonMain` adds **no** new dependencies — analytics-module-side state is
covered by existing Koin, coroutines, atomicfu pins.

### 16.2 Manifest merge

`shared/` does not currently ship an `AndroidManifest.xml`. Creating one
under `shared/src/androidMain/AndroidManifest.xml` is part of this work:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="com.google.android.gms.permission.AD_ID" />
</manifest>
```

`INTERNET` and `ACCESS_NETWORK_STATE` are already in the host manifest
(lines 4 and 22); manifest merger deduplicates. `AD_ID` is new but Play
Store-safe.

### 16.3 Versioning + ProGuard + size

- **Versioning.** AF ships breaking changes on majors only. Pin to a patch
  version; bump deliberately. Each bump runs §15.4 against the test dev key.
- **ProGuard.** AF's `consumer-rules.pro` is sufficient. No local rules.
- **APK size.** ~1.8 MB added (`af-android-sdk` 1.7 MB + `installreferrer`
  80 KB). Acceptable against the runner app's ~80 MB footprint.

---

## 17. Future-providers recipe

When Mixpanel / CleverTap / Firebase Analytics / Meta migrations land:

1. Add to `Destination` enum (if not reserved).
2. Add SDK dep to `androidMain.dependencies`.
3. Add config slot to `AnalyticsConfig` (e.g. `mixpanelToken: String? = null`).
4. Create `MixpanelAndroidProvider : AnalyticsProvider` in
   `androidMain/.../analytics/providers/`.
5. Register in `analyticsAndroidModule` — conditional `if
   (!config.mixpanelToken.isNullOrBlank()) { single<AnalyticsProvider> { ... } }`.
   Identical pattern to AppsFlyer (§4.2).
6. Add `androidInstrumentedTest` against a test token.
7. Update `Destination` Dart mirror.
8. Flip `analytics.dart_destinations_disabled` Remote Config flag once
   KMP-side parity is validated in dashboards. Verify for one release.
   Then delete `mixpanel_setup.dart` + Pub dep.

Re-add at the same time (when needed by the new provider):

- `setUserProperty` on tracker + SPI (Mixpanel super properties).
- `flush(): suspend` (if Mixpanel-on-logout matters).
- `traits: Map` on `identify`.
- `AppsFlyerConversionRelay` + `AttributionSource` if Mixpanel/CleverTap
  want install-source super properties.

---

## 18. Open questions

### 18.1 DPDP Act exposure

India's Digital Personal Data Protection Act, 2023 introduces consent
requirements for processing personal data — including device identifiers,
which is what AppsFlyer collects. As of the date of this doc, enforcement
rules are still being finalised. **No consent gate today (§7)**, but the
following watchpoints flip the decision:

- DPDP enforcement notification (date TBD by MeitY).
- AF's IDFA-equivalent (`gaid`) collection becomes legally restricted on
  Android — this would force a `consent_required` check at AF init time.
- Product expansion outside India (EU = GDPR, US states = state-specific
  laws like CCPA).

The §7 re-introduction path is documented in this LLD. Treat as a known
~2-week project, not a rewrite.

### 18.2 Should the Firebase RC user-property setter live in KMP?

`lib/services/analytics/analytics_service.dart` writes Firebase Analytics
user properties (`cluster_id`, etc.) that drive Remote Config conditions.
Moving this into a `FirebaseAnalyticsProvider` is feasible but couples
Remote Config evaluation to analytics startup order. Decide before phase 2.

### 18.3 Do we need per-destination flush ordering?

Some flows (e.g. logout) want to flush analytics before tearing down the
auth token. The current `flush(destinations: Set<Destination>)` is
unordered. If we discover a real dependency (Mixpanel uses the token in its
identify call?), introduce a typed `FlushPolicy` parameter. Don't pre-empt.

### 18.4 Mixpanel/CleverTap event-name canonicalisation

When those providers migrate, do we keep their current event names (and let
the provider mapper translate from a single canonical KMP name), or do we
align all vendors on one canonical name? Probably the former, to preserve
dashboard continuity. Confirm with the data team at migration time.

---

## Appendix A: AppsFlyer onboarding checklist

| Step                                                              | Owner    | Status |
| ----------------------------------------------------------------- | -------- | ------ |
| Create AppsFlyer **production** app in dashboard                  | growth   | TBD    |
| Create AppsFlyer **test** app (separate, for CI — §15.4)          | growth   | TBD    |
| Obtain dev key (debug + release distinguished by app id, not key) | growth   | TBD    |
| Replace placeholder `APPSFLYER_DEV_KEY` const in `SnabbitRunnerApplication.kt` | runner   | TBD    |
| Add test dev key to instrumented test harness (separate from prod) | platform | TBD    |
| Configure Play Store install referrer in Play Console             | platform | TBD    |
| Define canonical events list in AF dashboard                      | growth   | TBD    |
| Smoke test debug build with `setDebugLog(true)`                   | QA       | §15.4  |
| Release-build sanity check — first install attributed correctly   | growth   | post-merge |

## Appendix B: Glossary

| Term              | Definition                                                                 |
| ----------------- | -------------------------------------------------------------------------- |
| Provider          | An `AnalyticsProvider` implementation = one vendor SDK adapter             |
| Destination       | The `Destination` enum entry identifying a provider                        |
| Canonical event   | A vendor-agnostic event name owned by a per-feature wrapper                |
| `setCustomerUserId` | AppsFlyer's identity setter; ties events to a backend user                |
| `AppsFlyerRequestListener` | Callback for `start()` success/failure — **not** the conversion listener (§5.5) |
