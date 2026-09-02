package com.snabbit.runner.shared.features.kavach.shield.data.store

/**
 * Materializes a bundled ML model to a real on-device file path — ORT/TFLite load from a path, not
 * bytes (mirrors the deterrence-audio cache-to-file pattern). The model bytes come from the platform
 * [ShieldAssetReader] (Flutter `flutter_assets/`, single-sourced — ECPO-916). Resolution is idempotent
 * + cached per file. Returns "" on failure, so the detector's `loadModel` no-ops and ML stays disabled
 * non-fatally. Bound per platform in `platformModule`.
 */
interface ModelAssetResolver {
    suspend fun resolve(fileName: String): String
}

// Model file names (bundled as Flutter assets under assets/ml-models/). Single-sourced here.
internal const val SILERO_VAD_MODEL = "silero_vad.onnx"
internal const val YAMNET_MODEL = "yamnet.tflite"
internal const val YAMNET_LABELS = "yamnet_labels.txt"
