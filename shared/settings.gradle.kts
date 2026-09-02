// Standalone Gradle root for :shared so the KMP module builds/tests independently
// of the Flutter android host (whose root is android/settings.gradle, which also
// includes ../shared as a subproject — that build ignores this settings file).
//
// Plugin version pins + repositories are DUPLICATED from android/settings.gradle +
// android/build.gradle (no shared version catalog yet) — keep both in sync on any bump.

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    // Versions for the plugins that build.gradle.kts applies without one.
    plugins {
        val kotlin = "2.3.20"
        id("org.jetbrains.kotlin.multiplatform") version kotlin
        id("org.jetbrains.kotlin.android") version kotlin
        id("org.jetbrains.kotlin.plugin.compose") version kotlin
        id("org.jetbrains.kotlin.plugin.serialization") version kotlin
        id("com.android.library") version "8.10.1"
        id("org.jetbrains.compose") version "1.11.1"
        id("app.cash.sqldelight") version "2.2.1"
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
        // Snabbit Design System — GitHub Packages (mirrors android/build.gradle).
        maven {
            url = uri("https://maven.pkg.github.com/snabbit-tech/snabbit-design-system")
            credentials {
                username = providers.gradleProperty("gpr.user").orNull ?: System.getenv("GITHUB_ACTOR")
                password = providers.gradleProperty("gpr.token").orNull ?: System.getenv("GITHUB_TOKEN")
            }
        }
        // Safety Kavach shield engine — GitHub Packages.
        maven {
            url = uri("https://maven.pkg.github.com/snabbit-tech/safety-kavach-kmp")
            credentials {
                username = providers.gradleProperty("gpr.user").orNull ?: System.getenv("GITHUB_ACTOR")
                password = providers.gradleProperty("gpr.token").orNull ?: System.getenv("GITHUB_TOKEN")
            }
        }
    }
}

rootProject.name = "shared"

// The published artifact is the consumption path. Opt in with `kavach.useLocal=true` (in
// ~/.gradle/gradle.properties) to build the sibling safety-kavach checkout in place instead, so
// plugin edits land without a publish. Off by default so a checkout can't silently shadow the release.
val kavachLocal = file("../../safety-kavach")
if (providers.gradleProperty("kavach.useLocal").orNull == "true" &&
    kavachLocal.resolve("settings.gradle.kts").exists()
) {
    includeBuild(kavachLocal)
    logger.lifecycle("Kavach: building com.safetykavach:shield from ${kavachLocal.canonicalPath}")
}
