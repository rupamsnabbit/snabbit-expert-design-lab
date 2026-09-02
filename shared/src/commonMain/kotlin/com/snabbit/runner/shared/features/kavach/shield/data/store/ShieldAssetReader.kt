package com.snabbit.runner.shared.features.kavach.shield.data.store

/**
 * Reads a Kavach bundled asset by its Flutter asset path (relative to the assets root, e.g.
 * "assets/ml-models/yamnet.tflite").
 *
 * Single source of the ML models / labels / activation Lottie / deterrence clip / upload public key
 * that the Flutter shield ALSO bundles — so the APK ships ONE copy (Flutter's `flutter_assets/`)
 * instead of a duplicate under `composeResources/` (ECPO-916, ~6.6 MB). Android reads the flutter_assets
 * entry via `AssetManager` (bytes come back decompressed); iOS reads it via a host-injected provider.
 *
 * Fail-safe: a miss/failure returns empty bytes — the model resolver then yields "" (ML off,
 * non-fatal) and the Lottie/pubkey callers fall back on their own guards.
 */
interface ShieldAssetReader {
    suspend fun read(assetPath: String): ByteArray

    companion object {
        // Flutter asset paths — mirror pubspec.yaml + the Dart safety_shield adapter. Single-sourced here.
        const val ML_MODELS_DIR = "assets/ml-models"
        const val DETERRENCE_AUDIO = "assets/audio/shield_deterrence.mp3"
        const val ACTIVATION_LOTTIE = "assets/kavach_opt.json"
        const val UPLOAD_PUBLIC_KEY = "assets/keys/shield_public_key.pem"
    }
}
