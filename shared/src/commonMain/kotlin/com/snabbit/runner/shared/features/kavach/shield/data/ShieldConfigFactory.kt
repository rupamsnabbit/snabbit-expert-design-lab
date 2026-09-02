package com.snabbit.runner.shared.features.kavach.shield.data
import com.snabbit.runner.shared.features.kavach.shield.data.store.ModelAssetResolver
import com.snabbit.runner.shared.features.kavach.shield.data.store.SILERO_VAD_MODEL
import com.snabbit.runner.shared.features.kavach.shield.data.store.YAMNET_MODEL
import com.snabbit.runner.shared.features.kavach.shield.data.store.YAMNET_LABELS

import com.safetykavach.shield.core.model.ShieldConfig
import com.safetykavach.shield.core.model.ShieldMlConfig
import com.snabbit.runner.shared.core.config.RemoteConfigGateway

/**
 * Builds the base plugin [ShieldConfig] from Remote Config (D-6) — accelerometer floor, SOS, and
 * recording cadences only. Applied at `initialize`. ML lives in [shieldMlConfig], supplied at the
 * gated ML tier so models materialize + load only on consumption. Fallbacks are the shipped **Flutter
 * app** defaults (accel 2.7 G), NOT the plugin's looser canonical defaults (anti-SOS-flood parity).
 */
suspend fun shieldConfig(rc: RemoteConfigGateway): ShieldConfig {
    val d = ShieldConfig()
    return d.copy(
        recordingDurationSec = rc.getInt("expert_shield_duration_secs", d.recordingDurationSec),
        recordingIntervalSec = rc.getInt("expert_shield_pause_secs", d.recordingIntervalSec),
        // Flutter app fallback (2.7 G), NOT the plugin's looser 1.5 G — a lower fallback re-floods
        // shake false-positives when RC is absent.
        accelerometerMagnitudeG = rc.getDouble("expert_shield_accelerometer_magnitude_g", 2.7),
        accelerometerWindowSec = rc.getDouble("expert_shield_accelerometer_window_sec", d.accelerometerWindowSec),
        accelerometerCooldownSec = rc.getInt("expert_shield_accelerometer_cooldown_sec", d.accelerometerCooldownSec),
        accelerometerLpfAlpha = rc.getDouble("expert_shield_accelerometer_lpf_alpha", d.accelerometerLpfAlpha),
        accelerometerFreefallThresholdG = rc.getDouble("expert_shield_accelerometer_freefall_threshold_g", d.accelerometerFreefallThresholdG),
        accelerometerFreefallMinMs = rc.getInt("expert_shield_accelerometer_freefall_min_ms", d.accelerometerFreefallMinMs),
        accelerometerDropSuppressMs = rc.getInt("expert_shield_accelerometer_drop_suppress_ms", d.accelerometerDropSuppressMs),
        monitoringDurationSec = rc.getInt("expert_shield_manual_duration_secs", d.monitoringDurationSec),
        monitoringIntervalSec = rc.getInt("expert_shield_manual_pause_secs", d.monitoringIntervalSec),
        sosPendingDurationSec = rc.getInt("expert_shield_sos_pending_duration_secs", d.sosPendingDurationSec),
        sosPendingIntervalSec = rc.getInt("expert_shield_sos_pending_interval_secs", d.sosPendingIntervalSec),
        sosRecordingDurationSec = rc.getInt("expert_shield_sos_duration_secs", d.sosRecordingDurationSec),
        sosRecordingIntervalSec = rc.getInt("expert_shield_sos_pause_secs", d.sosRecordingIntervalSec),
    )
}

/**
 * Whether ML should run this session — the RC flag gated by the crash-guard veto ([mlAllowed] false
 * after a prior native load-crash for this build). The caller resolves assets + [configureMl] only when true.
 */
suspend fun mlEnabled(rc: RemoteConfigGateway, mlAllowed: Boolean): Boolean =
    mlAllowed && rc.getBoolean("expert_shield_ml_detection_enabled", false)

/**
 * ML config with the bundled models materialized to on-device paths — built + supplied via
 * `configureMl` only when [mlEnabled], so the disk extraction + native load are never paid off-tier.
 * Detection-threshold fallbacks are the Flutter app defaults (YAMNet 0.5 / topK 3 / VAD 0.8), clamped
 * to guard a bad RC push on a safety-critical gate.
 */
suspend fun shieldMlConfig(rc: RemoteConfigGateway, modelAssets: ModelAssetResolver): ShieldMlConfig {
    val d = ShieldMlConfig(yamnetModelPath = "", vadModelPath = "")
    return d.copy(
        yamnetModelPath = modelAssets.resolve(YAMNET_MODEL),
        vadModelPath = modelAssets.resolve(SILERO_VAD_MODEL),
        yamnetLabelsPath = modelAssets.resolve(YAMNET_LABELS),
        dbSpikeThreshold = rc.getDouble("expert_shield_db_spike_threshold", d.dbSpikeThreshold),
        yamnetConfidenceThreshold = rc.getDouble("expert_shield_yamnet_confidence_threshold", 0.5).coerceIn(0.0, 1.0),
        yamnetTopK = rc.getInt("expert_shield_yamnet_top_k", 3).coerceIn(1, 521),
        // Validated against the known-label allow-list, falling back to the SAFE list — not the plugin
        // default, which includes "Glass" (dropped cutlery scores on it). Flutter parity.
        yamnetTargetClasses = resolveYamnetTargetClasses(
            rc.getStringList("expert_shield_yamnet_target_classes", emptyList()),
        ),
        vadConfidenceThreshold = rc.getDouble("expert_shield_vad_confidence_threshold", 0.8).coerceIn(0.0, 1.0),
    )
}
