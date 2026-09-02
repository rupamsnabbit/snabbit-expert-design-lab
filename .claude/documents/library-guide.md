---
description: Pinned library versions with bump constraints, commonMain import blocklist, and iOS compilation gate. Loaded by build-feature skill.
---

# Library Guide — Snabbit Runner KMP

## Pinned Versions — Do Not Bump Independently

| Artifact | Pinned version | Constraint |
|---|---|---|
| `kotlinx-serialization-json` | `1.9.0` | 1.10.x+ requires Kotlin 2.3.x — bump only with Kotlin upgrade |
| `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel` | `2.9.0` | Latest **stable**. CMP 1.10.x is JetBrains-aligned with the **2.10.0 line** (pre-release: `2.10.0-alpha06` / `2.11.0-beta01`) — we stay on stable and accept the one-line skew. Bump with `lifecycle-runtime-compose` when that line stabilizes. |
| `org.jetbrains.androidx.lifecycle:lifecycle-runtime-compose` | `2.9.0` | Same release train — always bump together. Provides `collectAsStateWithLifecycle()` (commonMain). |
| `com.snabbit:design-system` | `0.11.0` | Internal — bump requires DS team sign-off |
| `io.insert-koin:koin-core` | `4.2.1` | Declared as `api()` — bump affects all consumers, coordinate across modules |
| `io.insert-koin:koin-compose-viewmodel` | `4.2.1` | Bumping independently from koin-core risks API mismatch |
| `org.jetbrains.kotlinx:kotlinx-collections-immutable` | `0.5.0` | Latest stable as of Jun 2024; compatible with Kotlin 2.2.x |

## Navigation library dependency — not declared in `:shared` (add before use)
The `NavigationController` itself is **BUILT** (pure-Kotlin, no dependency — see `cmp-architecture-structure.md`). What is *not* in the build is a navigation-**library** dependency: none is declared in `shared/build.gradle.kts` today. If one is ever needed, the intended library is **CMP Navigation 3 (stable)**; add it with the library checklist + owner approval:

| Artifact | Version | Notes |
|---|---|---|
| `org.jetbrains.androidx.navigation3:navigation3-ui` | **`1.1.1` (stable)** | CMP Navigation 3; requires CMP 1.10+. The intended nav library. |
| `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-navigation3` | version **[TBD]** | optional — ViewModel support for Nav3. Exact version **unconfirmed** — verify on Maven Central before declaring. |
| `org.jetbrains.compose.material3.adaptive:adaptive-navigation3` | `1.3.0-beta02` (beta) | optional — Material 3 adaptive. |
| `org.jetbrains.androidx.navigation:navigation-compose` (classic 2.x) | `2.10.0-alpha02` | legacy alternative; prefer Navigation 3. |

Source: kotlinlang.org/docs/multiplatform/compose-navigation-3.

## commonMain Import Blocklist

These break iOS compilation and must never appear in `commonMain`:
- `android.*`
- `java.io.*`, `java.util.*` — use `kotlinx.*` multiplatform equivalents
- `androidx.*` — only `org.jetbrains.androidx.*` (JetBrains KMP forks) are allowed in `commonMain`

## iOS Compilation Gate

All `commonMain` changes must compile for all three iOS targets before merge.
Run: `./gradlew :shared:compileTestKotlinIosArm64`
Targets configured: `iosX64`, `iosArm64`, `iosSimulatorArm64`
