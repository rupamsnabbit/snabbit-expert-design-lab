package com.snabbit.runner.shared.features.kavach.shield.data

import com.snabbit.runner.shared.core.config.DefaultRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeModelAssetResolver
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ShieldConfigFactoryTest {

    @Test
    fun baseConfig_fallsBackToDefaults_whenRcEmpty() = runTest {
        val cfg = shieldConfig(DefaultRemoteConfigGateway())
        assertEquals(60, cfg.recordingDurationSec)
        assertEquals(2.7, cfg.accelerometerMagnitudeG) // Flutter anti-flood fallback (C1), not plugin's 1.5
    }

    @Test
    fun baseConfig_rcOverridesDefaults() = runTest {
        val rc = FakeRemoteConfigGateway().apply { ints["expert_shield_duration_secs"] = 5 }
        assertEquals(5, shieldConfig(rc).recordingDurationSec)
    }

    @Test
    fun mlEnabled_offByDefault_onByRc_vetoedByCrashGuard() = runTest {
        assertFalse(mlEnabled(DefaultRemoteConfigGateway(), mlAllowed = true))
        val rcOn = FakeRemoteConfigGateway().apply { booleans["expert_shield_ml_detection_enabled"] = true }
        assertTrue(mlEnabled(rcOn, mlAllowed = true))
        assertFalse(mlEnabled(rcOn, mlAllowed = false)) // crash-guard veto overrides the RC flag
    }

    @Test
    fun mlConfig_fallsBackToFlutterDefaults() = runTest {
        val ml = shieldMlConfig(DefaultRemoteConfigGateway(), FakeModelAssetResolver())
        assertEquals(3, ml.yamnetTopK)
        assertEquals(0.5, ml.yamnetConfidenceThreshold)
        assertEquals(0.8, ml.vadConfidenceThreshold)
    }

    @Test
    fun mlConfig_resolvesModelPaths() = runTest {
        val ml = shieldMlConfig(FakeRemoteConfigGateway(), FakeModelAssetResolver(base = "/models"))
        assertEquals("/models/silero_vad.onnx", ml.vadModelPath)
        assertEquals("/models/yamnet.tflite", ml.yamnetModelPath)
        assertEquals("/models/yamnet_labels.txt", ml.yamnetLabelsPath)
    }

    @Test
    fun mlConfig_rcOverridesTargetClasses() = runTest {
        val rc = FakeRemoteConfigGateway().apply { stringLists["expert_shield_yamnet_target_classes"] = listOf("Scream") }
        assertEquals(listOf("Scream"), shieldMlConfig(rc, FakeModelAssetResolver()).yamnetTargetClasses)
    }
}
