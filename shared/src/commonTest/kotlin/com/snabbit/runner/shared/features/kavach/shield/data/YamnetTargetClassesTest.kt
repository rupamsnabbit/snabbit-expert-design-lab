package com.snabbit.runner.shared.features.kavach.shield.data

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** RC → trigger-class resolution. Flutter parity: validate, drop unknowns, never run wide open. */
class YamnetTargetClassesTest {

    @Test
    fun emptyRc_fallsBackToSafeList() {
        assertEquals(SAFE_YAMNET_TARGET_CLASSES, resolveYamnetTargetClasses(emptyList()))
    }

    @Test
    fun allInvalidRc_fallsBackToSafeList() {
        // The flood case: a stray short label would match nearly every AudioSet class via contains().
        assertEquals(SAFE_YAMNET_TARGET_CLASSES, resolveYamnetTargetClasses(listOf("a", "", "NotAClass")))
    }

    @Test
    fun dropsUnknowns_keepsValid() {
        assertEquals(
            listOf("Screaming", "Explosion"),
            resolveYamnetTargetClasses(listOf("Screaming", "bogus", "Explosion", "x")),
        )
    }

    @Test
    fun safeListContainsNoEverydayImpactSounds() {
        // "Glass" is the one the plugin default carries and Flutter deliberately excludes.
        assertFalse(SAFE_YAMNET_TARGET_CLASSES.contains("Glass"))
        assertFalse(SAFE_YAMNET_TARGET_CLASSES.contains("Breaking"))
    }

    @Test
    fun knownLabels_coverTheSafeList() {
        // Every fallback entry must itself be a valid label, else a round-trip through RC drops it.
        SAFE_YAMNET_TARGET_CLASSES.forEach { assertTrue(it in YAMNET_KNOWN_LABELS, "missing: $it") }
    }

    @Test
    fun knownLabels_matchesFlutterEnumSize() {
        // Guard against a partial port — Dart's YamnetClass has 68 members.
        assertEquals(68, YAMNET_KNOWN_LABELS.size)
    }
}
