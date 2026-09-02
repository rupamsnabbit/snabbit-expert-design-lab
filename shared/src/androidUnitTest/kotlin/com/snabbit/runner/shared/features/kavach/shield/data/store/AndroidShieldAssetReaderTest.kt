package com.snabbit.runner.shared.features.kavach.shield.data.store

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Regression guard for the Flutter-asset key resolution (#1 prefix-fallback + #2 RC override). The real
 * APK path was validated against the assembled artifact (`assets/flutter_assets/assets/ml-models/yamnet.tflite`
 * et al present); this pins the reader's key CONSTRUCTION — ordering, de-dup, prefix-join — so a future
 * edit can't silently break the path the runtime read depends on.
 */
class AndroidShieldAssetReaderTest {

    @Test
    fun defaultPrefix_triesFlutterAssetsThenRaw() {
        assertEquals(
            listOf("flutter_assets/assets/ml-models/yamnet.tflite", "assets/ml-models/yamnet.tflite"),
            shieldAssetCandidateKeys("assets/ml-models/yamnet.tflite", SHIELD_FLUTTER_ASSETS_PREFIX),
        )
    }

    @Test
    fun realModelKey_isFirstCandidate() {
        // The exact key confirmed present in the assembled APK must be the first one tried.
        assertEquals(
            "flutter_assets/assets/ml-models/yamnet.tflite",
            shieldAssetCandidateKeys("assets/ml-models/yamnet.tflite", SHIELD_FLUTTER_ASSETS_PREFIX).first(),
        )
    }

    @Test
    fun rcOverride_prefixWinsFirst_thenDefault_thenRaw() {
        assertEquals(
            listOf(
                "custom_assets/assets/kavach_opt.json",
                "flutter_assets/assets/kavach_opt.json",
                "assets/kavach_opt.json",
            ),
            shieldAssetCandidateKeys("assets/kavach_opt.json", "custom_assets"),
        )
    }

    @Test
    fun rcPrefixEqualsDefault_isDeduped() {
        assertEquals(
            listOf("flutter_assets/assets/keys/shield_public_key.pem", "assets/keys/shield_public_key.pem"),
            shieldAssetCandidateKeys("assets/keys/shield_public_key.pem", SHIELD_FLUTTER_ASSETS_PREFIX),
        )
    }
}
