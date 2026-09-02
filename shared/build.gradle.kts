import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    kotlin("multiplatform")
    id("com.android.library")
    id("org.jetbrains.compose")
    id("org.jetbrains.kotlin.plugin.compose")
    kotlin("plugin.serialization")
    id("io.gitlab.arturbosch.detekt") version "1.23.7"
    // Room KMP (core/database — LLD §5.1/§5.2). KSP2 (Kotlin ≥2.3) uses plain,
    // independent versioning — NOT the old "<kotlin>-<ksp>" scheme — so the pin for
    // Kotlin 2.3.20 is just "2.3.x" (latest patch). See https://github.com/google/ksp/releases.
    id("com.google.devtools.ksp") version "2.3.10"
    id("androidx.room") version "2.7.2"
    // Screenshot (golden) tests for commonMain composables, run on the JVM via
    // Robolectric — no emulator. Plain `testDebugUnitTest` leaves captures as
    // no-ops; use `recordRoborazziDebug` / `verifyRoborazziDebug`.
    id("io.github.takahirom.roborazzi") version "1.49.0"
    // SQLDelight — typesafe SQLite for the Step 7 upload outbox (OD-5). Version pinned in
    // android/settings.gradle pluginManagement. Config block is below the android block.
    id("app.cash.sqldelight")
    // Prevents Flutter tooling from auto-applying kotlin-android to this KMP module.
    // Flutter's FlutterPluginUtils regex matches the id() on this line and sees KGP
    // as already handled, so it skips the auto-apply. The .apply(false) on the next
    // line ensures the plugin is not actually applied (KMP handles the Android target).
    // NOTE: the id() MUST stay on its own line — the regex only matches when it is; do
    // not collapse this onto one line or Flutter re-applies kotlin-android (dup `kotlin`).
    id("org.jetbrains.kotlin.android")
        .apply(false)
}

kotlin {
    applyDefaultHierarchyTemplate()

    // kotlin.time.Instant/Clock are @ExperimentalTime at Kotlin 2.2.x.
    // Module-wide opt-in (not per-file @OptIn) is deliberate: Instant is a
    // shared domain type (delayedcheckin's AwaitingCheckin deadline,
    // ReachByTicker's clock) and per-file annotations would leak the
    // experimental status into every consumer. Revisit when Kotlin
    // stabilises it (expected 2.3+) — the optIn line then simply deletes.
    sourceSets.all {
        languageSettings.optIn("kotlin.time.ExperimentalTime")
    }

    androidTarget {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    val xcf = XCFramework("Shared")
    listOf(
        iosArm64(),
        iosSimulatorArm64(),
    ).forEach { target ->
        target.binaries.framework {
            baseName = "Shared"
            isStatic = true // static XCFramework; flip to false if a dynamic framework is needed on-device.
            // Re-export the shield engine so Swift sees its symbols (VoiceDetector,
            // AudioClassifier, ShieldController) through the single `Shared` module.
            // Requires the shield dependency to be `api` (below).
            export("com.safetykavach:shield:0.1.17")
            xcf.add(this)
        }
    }

    sourceSets {

        commonMain.dependencies {
            // Compose Multiplatform
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material3)
            implementation(compose.ui)
            implementation(compose.components.resources)
            // Material Icons — used for stock icons on the CMP UI
            // (e.g. the Person "current location" marker). R8 strips
            // unused icons in release.
            implementation(compose.materialIconsExtended)

            // @Preview annotation for commonMain (used by ui/components).
            implementation(compose.components.uiToolingPreview)

            // Lifecycle ViewModel (Compose MP) + Koin ViewModel integration. The camera
            // module's ViewModel is an androidx.lifecycle.ViewModel resolved via
            // koinViewModel() and collected with collectAsStateWithLifecycle(). Versions
            // track Compose MP 1.10.3 (JetBrains lifecycle 2.9.6) and koin-core 4.2.1.
            implementation("org.jetbrains.androidx.lifecycle:lifecycle-viewmodel:2.9.6")
            implementation("org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose:2.9.6")
            implementation("org.jetbrains.androidx.lifecycle:lifecycle-runtime-compose:2.9.6")

            // CameraK — KMP camera library (pinned to v0.4)
            // Only imported by CameraKProvider in androidMain/iosMain.
            // If swapping to Camposer, remove these and add Camposer deps.
            implementation("io.github.kashif-mehmood-km:camerak:0.4")
            implementation("io.github.kashif-mehmood-km:image_saver_plugin:0.4")

            // Coroutines (core is multiplatform; the Android main/IO dispatcher
            // support lives in kotlinx-coroutines-android, see androidMain).
            // 1.11.0 (built for Kotlin 2.2.20) — its klib ABI is consumed fine by
            // our Kotlin 2.3.20 compiler; coroutines has no compiler-plugin coupling.
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.11.0")

            // Serialization — 1.11.0 (built for Kotlin 2.3.20, matching our Kotlin
            // plugin version). Bumped from 1.9.0 with the Kotlin 2.2.21 → 2.3.20
            // upgrade (the serialization compiler plugin is versioned with Kotlin).
            implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")

            // Date/time — multiplatform ISO-8601 parsing for the break countdown
            // (LunchReadModel resolves server `start_time`/`cooldown_start_time`
            // to epoch-millis). 0.6.x targets Kotlin 2.x; `Instant` stays in
            // kotlinx.datetime (moved to kotlin.time only in 0.7+).
            implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.6.2")

            // Snabbit Design System (Compose MP) — SnabbitTheme + atoms/molecules/organisms.
            // Released artifact from GitHub Packages (see repositories in android/build.gradle).
            // 0.19.0 ships SVG decoding in `SnabbitRemoteImage` (remote `*.svg` tier badges +
            // themed-nudge icons render out of the box) plus its `colorFilter` hook (the themed
            // icon tint) — both required by the tiering surfaces (TierNudgeListItem / TierAssets).
            implementation("com.snabbit:design-system:0.19.0")
            // Compottie — same version the DS pulls; needed here to name LottieCompositionSpec for SnabbitLottie.
            implementation("io.github.alexzhirkevich:compottie:2.2.4")

            // Ktor client (HTTP)
            implementation("io.ktor:ktor-client-core:3.5.0")
            implementation("io.ktor:ktor-client-content-negotiation:3.5.0")
            implementation("io.ktor:ktor-serialization-kotlinx-json:3.5.0")
            implementation("io.ktor:ktor-client-logging:3.5.0")

            // Coil 3 (KMP image loading) — core/image + the disposition sheet's
            // server-driven option icons (Dart parity: cached_network_image). The
            // network fetcher rides the existing Ktor 3 client (ktor3 artifact);
            // the loader itself is installed by the host via SingletonImageLoader
            // (KmpBootstrap on Android). Pinned to 3.3.0 (built for Kotlin 2.2.0)
            // — 3.4.x/3.5.x ship kotlin-stdlib 2.3.10/2.4.0 metadata our Kotlin
            // 2.2.21 cannot read; bump with the Kotlin upgrade (same story as
            // serialization).
            implementation("io.coil-kt.coil3:coil-compose:3.3.0")
            implementation("io.coil-kt.coil3:coil-network-ktor3:3.3.0")

            // Koin (dependency injection). `api` so consumers — KmpBridgePlugin
            // in particular — can call startKoin / getKoin / module DSL.
            api("io.insert-koin:koin-core:4.2.1")
            // Koin ViewModel integration: `viewModelOf(::Vm)` module DSL + `koinViewModel()`
            // Compose retrieval (multiplatform). Lets route composables self-resolve their
            // ViewModel instead of hand-wiring constructor deps at the call site.
            api("io.insert-koin:koin-compose-viewmodel:4.2.1")

            // Immutable collections — ImmutableList<T> for UiState list fields prevents
            // unnecessary recompositions. Required by ui-reviewer rule.
            // 0.5.0 is the latest stable; compatible with Kotlin 2.2.x.
            implementation("org.jetbrains.kotlinx:kotlinx-collections-immutable:0.5.0")

            // atomicfu (multiplatform atomics for 401-burst debounce in §3.6)
            implementation("org.jetbrains.kotlinx:atomicfu:0.32.1")

            // Grant — KMP runtime-permission engine (core/permissions). `api` because the
            // permissions Koin wiring exposes a GrantManager binding. Requires coroutines >= 1.10.2
            // (satisfied by 1.11.0 above).
            api("dev.brewkits:grant-core:2.2.3")

            // Kavach safety-shield engine (KMP plugin). Local composite build during
            // migration — the coordinate is substituted by the included `safety-kavach`
            // build (see android/settings.gradle `includeBuild`); version is a placeholder.
            // Upgrade to a GitHub Maven artifact later.
            // `api` (not `implementation`) so the framework can `export` it to Swift (above).
            api("com.safetykavach:shield:0.1.17")

            // SQLDelight — durable upload outbox (Step 7). coroutines-extensions is the
            // common (KMP) artifact for Flow-backed queries. Platform drivers below.
            implementation("app.cash.sqldelight:coroutines-extensions:2.2.1")

            // cryptography-kotlin — RSA-OAEP-256 key-wrap for the upload envelope (Step 7.2).
            // Core API is common; providers are per-platform below (jdk on Android, Apple
            // Security.framework on iOS — CryptoKit has no RSA).
            implementation("dev.whyoleg.cryptography:cryptography-core:0.6.0")

            // AndroidX Lifecycle (multiplatform) — lets a native screen's ViewModel extend
            // androidx.lifecycle.ViewModel + use viewModelScope, so the host can scope it to a
            // Nav3 NavEntry (ViewModelStore decorator) and it survives A→B→back.
            implementation("androidx.lifecycle:lifecycle-viewmodel:2.10.0")

            // Room KMP + bundled SQLite driver (core/database, LLD §5.1):
            // one shared RoomDatabase; realtime is the first DAO tenant,
            // IoT/Shield join later. 2.7.x is the documented KMP-stable pairing
            // with androidx.sqlite 2.5.x.
            implementation("androidx.room:room-runtime:2.7.2")
            implementation("androidx.sqlite:sqlite-bundled:2.5.2")
            // DataStore Preferences (KMP) — cross-platform unencrypted storage
            // for PreferenceStorage. Same version as the Android-specific
            // datastore-preferences in androidMain to avoid version conflict.
            implementation("androidx.datastore:datastore-preferences-core:1.2.1")

            // Navigation 3 (Compose Multiplatform). Drives the native Compose back stack
            // (SnabbitNavHost) on Android AND iOS, so the whole host lives in commonMain.
            //  - navigation3-runtime stays on the Google coordinate: it is already fully
            //    KMP (ships iOS binaries) and provides androidx.navigation3.runtime.*.
            //  - The UI layer + the per-entry ViewModelStore decorator come from JetBrains'
            //    multiplatform fork (org.jetbrains.androidx.*), which publishes iOS variants
            //    as of CMP 1.10. On Android the fork's UI delegates to the same Google impl,
            //    so Android runtime behaviour is unchanged.
            // Compatible with CMP 1.10.3 / Kotlin 2.2.21.
            implementation("androidx.navigation3:navigation3-runtime:1.1.2")
            implementation("org.jetbrains.androidx.navigation3:navigation3-ui:1.1.1")
            // Per-entry ViewModelStore so each back-stack entry retains its state across
            // navigation (used by SnabbitNavHost's entryDecorators).
            implementation("org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-navigation3:2.10.0")

            // Multiplatform BackHandler (tabs/TabbedContainer). Fires on Android; on iOS it
            // is currently a no-op — iOS tab-root back is a tracked follow-up.
            implementation("org.jetbrains.compose.ui:ui-backhandler:1.10.3")
        }

        androidMain.dependencies {
            // Provides Dispatchers.Main backed by the Android main looper.
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")

            // WorkManager 2.11.2 (latest stable) — drives the Kavach clip-upload outbox out of band, so
            // a clip left over at job end still syncs across process death and reboot. Needs minSdk 23
            // (we're 26) and compileSdk 33+ (we're 36).
            implementation("androidx.work:work-runtime-ktx:2.11.2")

            // Compose tooling — `@Preview` annotation for Android Studio's
            // Compose Preview pane (androidMain only — Preview is Android-specific).
            implementation(compose.preview)
            implementation(compose.uiTooling)

            // Navigation 3 now lives in commonMain (host + UI are multiplatform via the
            // JetBrains fork) — see the commonMain block. Nothing Nav3-specific here.
            // lifecycle-viewmodel-compose: the Android actual backing commonMain's `viewModel { }`.
            // activity-compose: `androidx.activity.compose.BackHandler` (CameraBackHandler.android.kt).
            // (The bottom-nav shell no longer needs these — it moved to commonMain, reading the
            // exit action from LocalRootShellExit and TTS/back via multiplatform seams.)
            implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
            implementation("androidx.activity:activity-compose:1.12.4")

            // Ktor OkHttp engine (Android HTTP transport)
            implementation("io.ktor:ktor-client-okhttp:3.4.0")
            // OkHttp — compile-visible so PlatformModule's engine binding can accept host-provided
            // okhttp3.Interceptor instances (e.g. debug-only Chucker). Already pulled transitively by
            // ktor-client-okhttp; declared here only to reference the type. #chucker
            implementation("com.squareup.okhttp3:okhttp:4.12.0")

            // Encrypted token storage: DataStore (coroutine-native I/O) +
            // Tink (AES-256-GCM with Android Keystore master key) — see §11.5
            implementation("androidx.datastore:datastore-preferences:1.2.1")
            implementation("com.google.crypto.tink:tink-android:1.21.0")

            // Koin Android extensions (Activity/Application scopes, ViewModel DSL)
            implementation("io.insert-koin:koin-android:4.2.1")

            // core/permissions Android glue: AndroidX core (ContextCompat/ActivityCompat),
            // activity Result APIs (Grant launcher + strict-settings launcher), lifecycle-process
            // (PermissionObserver re-check on app resume).
            implementation("androidx.core:core-ktx:1.13.1")
            implementation("androidx.activity:activity-ktx:1.10.1")
            implementation("androidx.lifecycle:lifecycle-process:2.9.0")
            // Compose lifecycle (LocalLifecycleOwner) for the camera's resume
            // re-check (OnAppResumed actual) — Settings-return permission recovery.
            implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.0")

            // core/location: FusedLocationProviderClient + SettingsClient; coroutines-play-services
            // provides Task.await(). LocationManagerCompat (core-ktx) + StartIntentSenderForResult
            // (activity-ktx) are already on the classpath above.
            implementation("com.google.android.gms:play-services-location:21.3.0")
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.11.0")

            // HiveMQ MQTT Client — MQTT 5 transport for realtime state sync
            // (docs/mqtt-state-sync-lld.html §5.5–5.6: wrapped, NOT forked;
            // reason-coded disconnects; built-in reconnect backoff + ±25% jitter).
            // Netty-based: release builds need R8 keep rules for io.netty.** and
            // org.jctools.** — the WS0 spike runs debug only, rules land with WS2.
            implementation("com.hivemq:hivemq-mqtt-client:1.3.6")

            // WebKit (WebViewAssetLoader for serving captures to WebView)
            implementation("androidx.webkit:webkit:1.13.0")

            // ExifInterface — robust EXIF orientation reads on older budget devices
            // (framework android.media.ExifInterface is buggy pre-Q). Used by
            // PlatformFileOps.android's manual-orientation decode path.
            implementation("androidx.exifinterface:exifinterface:1.3.7")

            // AppsFlyer SDK — install attribution. See docs/KMP_ANALYTICS_MODULE_LLD.md §5.1, §16.
            // Latest stable as of 2026-06 per Maven Central. Pin to a specific patch
            // version; bump deliberately per §16.3.
            implementation("com.appsflyer:af-android-sdk:6.18.0")
            // Mixpanel SDK — analytics events + people profiles. Latest stable
            // on Maven Central as of 2026-06 (8.8.0; everything newer is RC/BETA).
            // Pin to a specific patch version; bump deliberately.
            implementation("com.mixpanel.android:mixpanel-android:8.8.0")
            // CleverTap — pinned to match clevertap_plugin 4.0.0's bundled SDK
            // during the events/push split (one binary, two callers). Bump
            // when the plugin is removed (PR B).
            implementation("com.clevertap.android:clevertap-android-sdk:8.1.0")
            // Play Store install referrer — AppsFlyer auto-detects at runtime.
            // Also declared in android/app/build.gradle, kept here so :shared
            // can stand alone without the host classpath.
            implementation("com.android.installreferrer:installreferrer:2.2")

            // Google Maps Compose — Android map surface. Used by the Android
            // actual of MapBackground. Runs in Lite Mode (static bitmap,
            // no gestures) to keep RAM/battery cheap on low-end devices.
            // API key: `android/app/src/main/AndroidManifest.xml`
            // (`com.google.android.geo.API_KEY`). Transitively pulls in
            // play-services-maps.
            implementation("com.google.maps.android:maps-compose:6.12.2")

            // SQLDelight Android SQLite driver (Step 7 outbox).
            implementation("app.cash.sqldelight:android-driver:2.2.1")

            // cryptography-kotlin JDK provider (RSA-OAEP via JCA) — Step 7.2.
            implementation("dev.whyoleg.cryptography:cryptography-provider-jdk:0.6.0")

            // Official Firebase Remote Config (B-native RC read — no Flutter/Pigeon bridge).
            // compileOnly: the Flutter host (FlutterFire firebase_remote_config + google-services)
            // already bundles + initializes firebase-config at the app level, so :shared compiles
            // against the API and reads the shared FirebaseRemoteConfig singleton at runtime — we
            // neither duplicate nor bump the host's Firebase version. Switch to implementation()
            // when the Flutter host is removed.
            compileOnly(project.dependencies.platform("com.google.firebase:firebase-bom:34.15.0"))
            compileOnly("com.google.firebase:firebase-config")
        }

        iosMain.dependencies {
            // SQLDelight native SQLite driver (Step 7 outbox) — links libsqlite3 on iOS.
            implementation("app.cash.sqldelight:native-driver:2.2.1")

            // cryptography-kotlin Apple provider (RSA-OAEP via Security.framework) — Step 7.2.
            // CryptoKit has no RSA, so this is the Apple RSA path (no bundled OpenSSL binary).
            implementation("dev.whyoleg.cryptography:cryptography-provider-apple:0.6.0")

            // Ktor Darwin (NSURLSession) engine — iOS networking. Same version as ktor-client-core.
            implementation("io.ktor:ktor-client-darwin:3.4.0")
        }

        commonTest.dependencies {
            implementation(kotlin("test"))
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")

            // Ktor MockEngine — in-process HTTP engine for §15.3 interceptor tests
            implementation("io.ktor:ktor-client-mock:3.4.0")

            // Koin test utilities (checkModules, KoinTest)
            implementation("io.insert-koin:koin-test:4.2.1")
        }

        androidUnitTest.dependencies {
            // Robolectric drives Build.VERSION.SDK_INT via @Config(sdk=...) and provides a
            // ShadowPackageManager/Activity for the core/permissions Android tests.
            implementation("junit:junit:4.13.2")
            implementation("org.robolectric:robolectric:4.14.1")

            // SQLDelight JDBC driver — in-memory SQLite for the Step 7 outbox tests (JVM).
            implementation("app.cash.sqldelight:sqlite-driver:2.2.1")

            // Compose UI tests on the JVM (Robolectric-hosted createComposeRule) for the
            // commonMain widgets. Version matches the androidx.compose.ui that CMP 1.10.3
            // resolves to; bump together with the org.jetbrains.compose plugin.
            implementation("androidx.compose.ui:ui-test-junit4:1.10.5")
            // Registers the ComponentActivity that createComposeRule() launches.
            implementation("androidx.compose.ui:ui-test-manifest:1.10.5")

            // Golden tests (screenshot regression) for commonMain composables —
            // Roborazzi renders through Robolectric Native Graphics on the JVM.
            implementation("io.github.takahirom.roborazzi:roborazzi:1.49.0")
            implementation("io.github.takahirom.roborazzi:roborazzi-compose:1.49.0")

            // FakeImageLoaderEngine — deterministic Coil results in golden tests
            // (no network; intercepted URLs return solid-color images).
            implementation("io.coil-kt.coil3:coil-test:3.3.0")
        }

        androidInstrumentedTest.dependencies {
            // OkHttp MockWebServer (localhost HTTP server) for §15.5
            // full-stack integration tests. Note: package renamed from
            // okhttp3.mockwebserver -> mockwebserver3 in 5.x.
            implementation("com.squareup.okhttp3:mockwebserver3:5.3.2")

            // AndroidX Test — JUnit4 runner + ApplicationProvider for tests
            // that need a real Context (Tink + Android Keystore, etc.)
            implementation("androidx.test.ext:junit:1.3.0")
            implementation("androidx.test:core:1.7.0")
            implementation("androidx.test:runner:1.7.0")
        }
    }
}

android {
    namespace = "com.snabbit.runner.shared"
    compileSdk = 36

    defaultConfig {
        minSdk = 26
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    packaging {
        resources {
            // Some test deps (mockwebserver3, jspecify) ship duplicate
            // OSGi metadata that has no runtime meaning on Android.
            excludes += "/META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }

    testOptions {
        unitTests {
            // Robolectric (core/permissions androidUnitTest) needs merged Android resources.
            isIncludeAndroidResources = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// SQLDelight schema → generated ShieldDatabase (Step 7 upload outbox). Schema .sq files
// live under src/commonMain/sqldelight/<packageName path>/.
sqldelight {
    databases {
        create("ShieldDatabase") {
            packageName.set("com.snabbit.runner.shared.features.kavach.shield.data.db")
        }
    }
}

// ── Compose Multiplatform resources ───────────────────────────────────────────
// Generates the `Res` accessor for files under
// `src/commonMain/composeResources/{drawable,font,…}` so commonMain composables
// can load them via `painterResource(Res.drawable.X)` — e.g. the red-card nudge
// illustrations (ui/nudges). Without this block the plugin's tasks succeed
// silently but no `Res` class is emitted.
compose.resources {
    publicResClass = true
    packageOfResClass = "com.snabbit.runner.shared.resources"
    generateResClass = always
}

// ── Static-analysis guardrails for the build-screen standard ──────────────────
// Enforces the three hard rules (.claude/skills/build-screen) via ForbiddenImport.
// Syntactic only (no type resolution), so it runs fast across all KMP source sets.
detekt {
    buildUponDefaultConfig = false
    config.setFrom(files("detekt.yml"))
    source.setFrom(
        "src/commonMain/kotlin",
        "src/commonTest/kotlin",
        "src/androidMain/kotlin",
        "src/androidInstrumentedTest/kotlin",
        "src/iosMain/kotlin",
    )
    parallel = true
}

// Room KMP: schema history for migrations (LLD core/database policy).
room {
    schemaDirectory("$projectDir/schemas")
}

// Room's compiler runs per KSP target. Android is the shipping target; the
// iOS configs keep the declared iOS targets compiling if/when iOS tasks run.
// (kspIosX64 dropped in lockstep with the iosX64 target — see the kotlin{} block.)
// createComposeRule() launches androidx.activity.ComponentActivity; the test-only
// ui-test-manifest entry registers it (debug-variant only, never in release).
dependencies {
    add("kspAndroid", "androidx.room:room-compiler:2.7.2")
    add("kspIosArm64", "androidx.room:room-compiler:2.7.2")
    add("kspIosSimulatorArm64", "androidx.room:room-compiler:2.7.2")
    "debugImplementation"("androidx.compose.ui:ui-test-manifest:1.10.5")
}
