package com.snabbit.runner.kmp_bridge

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore

/**
 * Feeds [RunnerStateStore] from the Dart-side FCM cache on killed-state
 * revivals — the missing half of the TRD §8 path. The high-priority FCM data
 * message revives the process and `Application.onCreate` arms the
 * [com.snabbit.runner.overlayhost.OverlayLauncher], but the store itself is
 * normally fed by [RunnerStatePlugin], which only attaches when a
 * `FlutterEngine` is created through MainActivity — exactly what a killed-state
 * revival never has. The background push isolate can't reach the channel
 * either; what it *does* do (`firebaseMessagingBackgroundHandler`,
 * `lib/main.dart`) is re-fetch `current_state` and write it to
 * SharedPreferences as `cached_current_state`(+`_ts`).
 *
 * So this seeder bridges that write natively:
 *  - on [arm] it applies the cache if fresh (the process may have been revived
 *    after the handler already wrote it), and
 *  - registers an [SharedPreferences.OnSharedPreferenceChangeListener] so a
 *    write landing *after* `onCreate` (the usual order — the isolate's fetch
 *    takes longer than process start) is pushed the moment it lands. The
 *    listener is held in a field: SharedPreferences keeps listeners weakly.
 *
 * Freshness mirrors Dart's `applyCachedStateIfFresh` default
 * (`expert_bg_cache_max_age_ms` = 30 s; Remote Config isn't on the native
 * classpath, so the default is a constant here). Removals are ignored — Dart
 * consumes the cache after applying it, and by then the envelope has already
 * reached the store over the channel. The file/key names are the
 * `shared_preferences` plugin's stable legacy-API convention
 * (`FlutterSharedPreferences` / `flutter.` prefix).
 *
 * Failures are logged by *type only* — the envelope carries PII (customer
 * name, phone), same defense-in-depth rule as `RunnerStateChannel`.
 */
object RunnerStateCacheSeeder {

    private const val TAG = "RunnerStateCacheSeeder"
    private const val FLUTTER_PREFS_FILE = "FlutterSharedPreferences"
    private const val KEY_STATE = "flutter.cached_current_state"
    private const val KEY_TS = "flutter.cached_current_state_ts"

    /** Mirror of Dart's `expert_bg_cache_max_age_ms` default in `applyCachedStateIfFresh`. */
    private const val MAX_AGE_MS = 30_000L

    private var listener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    /** Idempotent — only the first call seeds and subscribes. */
    fun arm(context: Context, store: RunnerStateStore) {
        if (listener != null) return
        val prefs = context.getSharedPreferences(FLUTTER_PREFS_FILE, Context.MODE_PRIVATE)
        seedIfFresh(prefs, store)
        listener = SharedPreferences.OnSharedPreferenceChangeListener { changed, key ->
            // Dart writes cached_current_state THEN cached_current_state_ts
            // (lib/main.dart). Key on the ts — the LAST write — so both keys are
            // current when [seedIfFresh] reads them. Keying on the state key
            // would fire while the ts still holds its previous (stale/zero)
            // value, and the freshness gate would reject the fresh envelope.
            if (key == KEY_TS) seedIfFresh(changed, store)
        }.also(prefs::registerOnSharedPreferenceChangeListener)
    }

    private fun seedIfFresh(prefs: SharedPreferences, store: RunnerStateStore) {
        try {
            val json = prefs.getString(KEY_STATE, null) ?: return
            val ageMs = System.currentTimeMillis() - prefs.getLong(KEY_TS, 0L)
            if (ageMs >= MAX_AGE_MS) return
            // The cached JSON is the raw `current_state` response body with
            // `widget_name`/`widget_data` at top level — the store's decoder
            // ignores the extra keys, so it is push-compatible as-is.
            store.pushState(json)
        } catch (e: Exception) {
            Log.e(TAG, "cached current_state seed failed: ${e.javaClass.simpleName}")
        }
    }
}
