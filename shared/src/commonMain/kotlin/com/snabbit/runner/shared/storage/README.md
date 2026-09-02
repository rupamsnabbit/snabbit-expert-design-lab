# KMP Storage Module

Cross-platform persistent key–value storage for the `:shared` module. Two tiers —
**encrypted** (`SecureStorage`) and **plain** (`PreferenceStorage`) — behind a single
`StorageFactory`. Android and iOS have full implementations; `commonMain` holds the
contracts, the plain-storage implementation, and the factory.

> **Scope note:** this module (`com.snabbit.runner.shared.storage`) is the general-purpose
> app storage SDK. It is **separate** from `core/storage` (`EncryptedStore` /
> `TinkDataStoreEncryptedStore` / `StoreManager`), which is a narrower token-hydration
> store used by the network/auth layer. See [Two encrypted stores](#two-encrypted-stores).

## Contents
1. [Capabilities](#capabilities) — types, operations, guarantees
2. [Package layout](#package-layout) — file organization + the flat-vs-grouped decision
3. [Class reference](#class-reference) — every file, what & why, plus a plain-English column
4. [Architecture](#architecture) — how the tiers map to platform crypto/stores
5. [Two encrypted stores](#two-encrypted-stores) — this module vs `core/storage`
6. [iOS verification status](#ios-verification-status)

---

## Capabilities

**Data types** — every accessor exists for all five primitives:

| Type    | Secure (Android)         | Secure (iOS)      | Preference (both) |
|---------|--------------------------|-------------------|-------------------|
| String  | ✅                       | ✅                | ✅                |
| Int     | ✅                       | ✅                | ✅                |
| Long    | ✅                       | ✅                | ✅                |
| Boolean | ✅                       | ✅                | ✅                |
| Double  | ✅ (native, no bit-hack) | ✅                | ✅ (native)       |

**Operations** (all `suspend`): `getX(key)` → value or `null` if absent · `putX(key, value)`
(upsert) · `remove(key)` · `clear()`. Every mutating op returns a `Boolean` success flag —
`true` when persisted, `false` when it failed (already logged + reported). Callers that need
durability (e.g. persisting an auth token) should check it rather than assume success.

**Guarantees**
- **Never throws.** Read miss/failure → `null`; write failure → logged + reported and returns
  `false` (never silently "succeeds").
- **Atomic writes** on the DataStore-backed paths (no lost-update / TOCTOU races).
- **Encryption at rest** for `SecureStorage`: Android = Tink AES-256-GCM under an Android
  Keystore master key, with the entry key bound as associated data (anti-swap); iOS =
  Keychain Services, hardware-backed (Secure Enclave where available), device-bound and
  excluded from iCloud/backup migration.
- **No destructive reads.** A `SecureStorage` read of an undecryptable/corrupt entry returns
  `null` and **retains** the ciphertext (a transient crypto fault must not permanently destroy
  a recoverable secret); the corruption is reported once per key.
- **Bounded crypto-bootstrap recovery** (Android): keyset build failures are classified —
  transient I/O errors back off and retry (never wipe); only a genuine keyset/key loss, after
  repeated failures, wipes + recreates (once per episode). No permanent "dead" latch.
- **Cross-platform parity**: identical behaviour for typed round-trips, cross-type reads,
  `remove`, and `clear`, enforced by the shared contract tests.

**Threading** — call from any dispatcher; implementations own their I/O (DataStore internally;
Keychain and the Android `KeyManager` bootstrap via the injected `AppDispatchers.io`).

**Observability** — every failure emits a `StorageEvent` name via `Logger` and a
non-fatal via `CrashReporter` (Crashlytics / Coralogix).

**What it is NOT** — not a database, not for large blobs, not reactive (no `Flow`
exposed), and it does not enumerate/list keys.

---

## Package layout

Current layout is **flat** — contracts, implementations, and `KeyManager` all sit directly in
`storage/`, with only `di/` split out:

```
storage/
├─ SecureStorage.kt               # contract — encrypted tier
├─ PreferenceStorage.kt           # contract — plain tier
├─ StorageFactory.kt              # contract — single entry point
├─ StorageEvent.kt                # telemetry event-name constants
├─ DefaultStorageFactory.kt       # impl  (commonMain)
├─ DataStorePreferenceStorage.kt  # impl  (commonMain)
├─ PreferenceDataStore.kt         # DataStore factory (commonMain)
├─ TinkSecureStorage.kt           # impl  (androidMain)
├─ KeyManager.kt                  # crypto/keyset lifecycle (androidMain)
├─ KeychainSecureStorage.kt       # impl  (iosMain)
└─ di/
   ├─ StorageModule.kt            # Koin wiring (androidMain)
   └─ StorageModule.ios.kt        # Koin wiring (iosMain)
```

**Why flat.** The sibling `core/storage` module is also flat (and has no `di/`). Keeping both
storage modules on the same shape avoids a one-off convention a reader has to re-learn per
module. At ~12 files this is still easy to scan.

**Proposed grouped layout (deferred).** If the module grows, a functionality-grouped split
reads better:

```
storage/
├─ contract/   # SecureStorage · PreferenceStorage · StorageFactory · StorageEvent
├─ impl/       # DefaultStorageFactory · DataStorePreferenceStorage · TinkSecureStorage · KeychainSecureStorage
├─ crypto/     # KeyManager
└─ di/         # StorageModule(.ios)
```

This is **only** worth adopting if `core/storage` converges onto the same standard at the same
time — doing it in this module alone would make the two storage modules diverge, which is worse
than the current mild flatness. Tracked as a follow-up; intentionally not done in this PR.

---

## Class reference

| Class / File | Layer · Platform | What it is | Why it's needed | ELI5 |
|---|---|---|---|---|
| **`SecureStorage`** *(interface)* | commonMain · all | The contract for **encrypted** typed K-V storage of sensitive data (tokens, session IDs). | Feature code depends on an abstraction, not on Tink/Keychain; lets us swap platform impls and fakes. | The instruction card on a safe: "put things in, take them out." It never says how the lock works. |
| **`PreferenceStorage`** *(interface)* | commonMain · all | Same shape, for **non-sensitive** data (feature flags, settings, cached config). | Separates "must be encrypted" from "just needs to persist" so a boolean flag doesn't pay crypto cost. | The label on an ordinary drawer — same "put/take," but no lock. |
| **`StorageFactory`** *(interface)* | commonMain · all | Convenience single entry point: `secureStorage()` / `preferenceStorage()`. | One handle for both tiers; not load-bearing — Koin already binds each tier by interface. | The front desk that hands you the right key — safe or drawer. |
| **`DataStorePreferenceStorage`** | commonMain · all | `PreferenceStorage` built on Jetpack DataStore (KMP). | One unencrypted store for both platforms; atomic writes, native types, no SharedPreferences. | The actual drawer — built once, fits both phones. |
| **`PreferenceDataStore.kt`** *(`createPreferenceDataStore`)* | commonMain · all | Factory that builds a `DataStore<Preferences>` from a file-path lambda (self-heals a corrupt file). | DataStore needs a platform file path; this keeps the storage class path-agnostic. | A flat-pack drawer kit you assemble wherever you point it. |
| **`DefaultStorageFactory`** | commonMain · all | `StorageFactory` impl delegating to the injected secure + preference singletons. | Trivial and identical on both platforms (replaced the old `AndroidStorageFactory`). | The desk clerk who just fetches whichever key you ask for. |
| **`StorageEvent`** *(object)* | commonMain · all | String constants for failure log-event names (`STORAGE_READ_FAILED`, …). | Uniform, grep-able telemetry across Crashlytics/Coralogix. | Standard sticker labels for every "something went wrong" note. |
| **`TinkSecureStorage`** | androidMain | `SecureStorage` impl: Tink AES-256-GCM encrypt → Base64 → DataStore. | Android's hardware-backed encryption for tokens. | Android's safe — scrambles your stuff with a chip-guarded key, then files it away. |
| **`KeyManager`** | androidMain | Owns the Tink AEAD keyset (Android Keystore master key): lazy `suspend` build under a `Mutex`, bounded-backoff retry, failure classification, once-per-episode recovery. | Encryption needs a key; failures must degrade safely — retry transient faults, wipe only on genuine keyset loss. | The locksmith for the safe — makes and guards the key; on a jam it waits and retries, and only cuts a brand-new key when the old one is truly lost. |
| **`StorageModule.kt`** *(`storageModule(app)`)* | androidMain | Koin module wiring the Android impls + the two DataStores. | Connects everything for Android DI at boot. | The Android wiring diagram. |
| **`KeychainSecureStorage`** | iosMain | `SecureStorage` impl on iOS **Keychain Services** (hardware-backed, `ThisDeviceOnly`, `AfterFirstUnlock`). | iOS's counterpart to Tink+Keystore — the Keychain does encryption *and* storage in one. | The iPhone's built-in safe — iOS locks it with the Secure Enclave for you. |
| **`StorageModule.ios.kt`** *(`iosStorageModule()`)* | iosMain | Koin module wiring the iOS impls (Keychain + DataStore + factory). | Connects everything for iOS DI. | The iPhone wiring diagram. |
| **`InMemorySecureStorage`** / **`InMemoryPreferenceStorage`** | commonTest | HashMap-backed fakes matching the serialize-through-string contract. | Fast, deterministic unit tests with no device or crypto. | A cardboard "pretend safe" for rehearsals. |
| **`SecureStorageContractTest`** / **`PreferenceStorageContractTest`** / **`StorageFactoryTest`** | commonTest | Behaviour specs run against the fakes. | Lock in round-trip, cross-type, `remove`, `clear`, and write-result guarantees for every type. | The checklist that proves the drawer actually works. |
| **`TinkSecureStorageTest`** / **`KoinModulesTest`** | androidInstrumentedTest | On-device tests: real Tink + DataStore round-trips, corrupt-payload retention, and Koin-graph resolution. | Verify real crypto/persistence + DI wiring on Android hardware. | A real-safe stress test in the workshop before shipping. |

---

## Architecture

```
                       StorageFactory  (DefaultStorageFactory)
                        /                              \
              SecureStorage                        PreferenceStorage
              (encrypted)                           (plain)
             /            \                              |
   Android  |             | iOS                          | Android + iOS
   TinkSecureStorage      KeychainSecureStorage      DataStorePreferenceStorage
     │  Tink AES-256-GCM    │  Keychain Services          │
     │  (KeyManager +       │  (Secure Enclave,           │
     │   Android Keystore)  │   hardware-backed)          │
     ▼                      ▼                             ▼
   DataStore<Preferences>   iOS Keychain              DataStore<Preferences>
   (ciphertext on disk)     (encrypted store)         (plaintext on disk)
```

- **Android secure** = encrypt (Tink) **then** persist (DataStore) — two layers.
- **iOS secure** = Keychain is both the crypto and the store — one layer.
- **Plain** (both platforms) = DataStore, unencrypted, one KMP implementation.

---

## Two encrypted stores

There are intentionally two encrypted stores in `:shared`; don't confuse them:

| | `storage.SecureStorage` (this module) | `core.storage.EncryptedStore` |
|---|---|---|
| Purpose | General app secure storage SDK | Token hydration for the network/auth layer |
| API | Typed (String/Int/Long/Bool/Double) | `getString` / `putString` / `getAll` / `delete` |
| Android impl | `TinkSecureStorage` (Tink → DataStore) | `TinkDataStoreEncryptedStore` (Tink → DataStore) |
| iOS impl | `KeychainSecureStorage` | none yet |
| Consumed by | Feature code (via `StorageFactory`) | `StoreManager` → `AuthInterceptor` |

They share the Tink+DataStore approach on Android but are distinct types with distinct
keysets and lifecycles.

---

## iOS verification status

`KeychainSecureStorage` is written to the standard Kotlin/Native `platform.Security`
Keychain pattern. iOS Kotlin cannot currently be compiled in the local dev environment
(a Kotlin/Native klib-resolver defect around the `koin-core` iOS artifact, unrelated to
this code). **Verify iOS builds in CI / Xcode.** Android is the local gate and is green.
