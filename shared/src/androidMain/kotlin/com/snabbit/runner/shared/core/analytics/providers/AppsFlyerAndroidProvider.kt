package com.snabbit.runner.shared.core.analytics.providers

import android.content.Context
import com.appsflyer.AppsFlyerLib
import com.appsflyer.attribution.AppsFlyerRequestListener
import com.appsflyer.deeplink.DeepLink
import com.appsflyer.deeplink.DeepLinkResult
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.analytics.AnalyticsProvider
import com.snabbit.runner.shared.core.analytics.ProviderKeys
import com.snabbit.runner.shared.core.deeplink.DeeplinkDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * AppsFlyer adapter — install attribution + Unified Deep Linking (UDL).
 *
 * `init`'s second argument stays `null`: the legacy `AppsFlyerConversionListener`
 * is not the deep-link surface. Deep links are handled via **UDL**
 * ([AppsFlyerLib.subscribeForDeepLink]), registered **before** `start()` — a
 * listener registered after `start` misses links. `onDeepLinking` delivers both
 * deferred (first install) and direct (already installed) links; on a `FOUND`
 * result we forward the raw `deep_link_value` (+ deferred flag) to
 * [deeplinkDispatcher], which bridges to Flutter. `AppsFlyerRequestListener`
 * remains the orthogonal "did start succeed" callback (§5.5).
 *
 * Constructor takes the application [Context] — the only context AppsFlyer's
 * `init`/`start`/`logEvent` need. The Koin module supplies the *application*
 * context specifically (process-lived), so the long-lived AF singleton never
 * holds anything shorter-lived than the process.
 *
 * Threading: AF posts internal work to the main looper; [start] runs on
 * [Dispatchers.Main] to avoid races with `ActivityLifecycleCallbacks`
 * registration. `track`/`identify`/`reset` are fire-and-forget — AF
 * buffers them internally if called before `start()` completes (§10).
 */
internal class AppsFlyerAndroidProvider(
    private val appContext: Context,
    private val devKey: String,
    private val debugLogging: Boolean,
    private val logger: Logger,
    private val crashReporter: CrashReporter,
    private val deeplinkDispatcher: DeeplinkDispatcher,
) : AnalyticsProvider {

    override val tag: String = ProviderKeys.APPSFLYER

    override suspend fun start() = withContext(Dispatchers.Main) {
        val af = AppsFlyerLib.getInstance()
        // setDebugLog MUST precede init; AF caches the flag at init time.
        if (debugLogging) af.setDebugLog(true)
        // UDL listener MUST be registered before start() — a listener attached
        // after start misses links.
        af.subscribeForDeepLink { result ->
            when (result.status) {
                DeepLinkResult.Status.FOUND -> {
                    val dl = result.deepLink
                    val value = try {
                        dl.deepLinkValue
                    } catch (e: Exception) {
                        logger.e(TAG, "UDL deepLinkValue read failed", e)
                        null
                    }
                    // `DeepLink.isDeferred()` returns a nullable `java.lang.Boolean`
                    // (it reads `clickEvent.opt("is_deferred")` internally and
                    // returns null when the key is absent). Calling `.toString()` on
                    // the platform type would NPE and abort dispatch, silently
                    // dropping the link. Default to `false` when unknown.
                    val isDeferred = dl.isDeferred ?: false
                    val sub1 = readSubValue(dl, "deep_link_sub1")
                    val sub2 = readSubValue(dl, "deep_link_sub2")
                    if (debugLogging) {
                        logger.d(
                            TAG,
                            "UDL FOUND deep_link_value=$value deferred=$isDeferred " +
                                "sub1=$sub1 sub2=$sub2",
                        )
                    }
                    deeplinkDispatcher.dispatch(
                        mapOf(
                            "deep_link_value" to value,
                            "deep_link_sub1" to sub1,
                            "deep_link_sub2" to sub2,
                            "is_deferred" to isDeferred.toString(),
                        ),
                    )
                }
                DeepLinkResult.Status.NOT_FOUND ->
                    if (debugLogging) logger.d(TAG, "UDL: no deep link")
                DeepLinkResult.Status.ERROR ->
                    logger.e(TAG, "UDL error: ${result.error}")
                else -> {}
            }
        }
        // null conversion listener — see kdoc + LLD §5.5.
        af.init(devKey, null, appContext)
        af.start(appContext, devKey, object : AppsFlyerRequestListener {
            override fun onSuccess() {
                if (debugLogging) logger.d(TAG, "AppsFlyer start succeeded")
            }
            override fun onError(code: Int, errorMessage: String) {
                when (code) {
                    // Non-actionable SDK status signals (~11k/week in prod):
                    //   10 = session deduplicated by minTimeBetweenSessions
                    //   11 = isStopTracking enabled, event dropped intentionally
                    //   40 = device-side network failure (DNS / TLS / offline)
                    // Keep visible at warn but do not page Crashlytics.
                    AF_CODE_EVENT_TIMEOUT,
                    AF_CODE_STOP_TRACKING,
                    AF_CODE_NETWORK_FAILURE ->
                        logger.w(TAG, "AppsFlyer onError (code=$code): $errorMessage")
                    // 41 (no dev key) and 50 (server rejected payload, e.g.
                    // bundle-ID / dev-key mismatch) are real misconfig or
                    // breakage. Unknown codes outside the documented set are
                    // also reported defensively — AF publishes no enum beyond
                    // {10, 11, 40, 41, 50}.
                    else -> {
                        logger.e(TAG, "AppsFlyer start failed: code=$code msg=$errorMessage")
                        crashReporter.report(
                            IllegalStateException("AppsFlyer start failed: $code $errorMessage"),
                            mapOf("provider" to tag, "code" to code.toString()),
                        )
                    }
                }
            }
        })
    }

    private fun readSubValue(dl: DeepLink, key: String): String? = try {
        dl.getStringValue(key)
    } catch (e: Exception) {
        logger.e(TAG, "UDL $key read failed", e)
        null
    }

    override fun track(name: String, props: Map<String, Any>) {
        // Non-null value type is guaranteed by AnalyticsProvider's SPI
        // contract (see kdoc) and produced by PropertyValue.sanitize at
        // the tracker boundary — AppsFlyerLib's logEvent overload that
        // takes Map<String, Any> can be called without a cast.
        AppsFlyerLib.getInstance().logEvent(appContext, name, props)
    }

    override fun identify(userId: String?) {
        val af = AppsFlyerLib.getInstance()
        if (userId == null) {
            af.setCustomerUserId(null)
            af.anonymizeUser(true)
        } else {
            af.anonymizeUser(false)
            af.setCustomerUserId(userId)
        }
    }

    override fun reset() {
        val af = AppsFlyerLib.getInstance()
        af.setCustomerUserId(null)
        af.anonymizeUser(true)
    }

    private companion object {
        const val TAG = "AppsFlyerProvider"
        // AppsFlyerRequestListener documented error codes (Unity plugin
        // docs/API.md is the canonical enumeration — same codes across SDKs).
        const val AF_CODE_EVENT_TIMEOUT = 10
        const val AF_CODE_STOP_TRACKING = 11
        const val AF_CODE_NETWORK_FAILURE = 40
    }
}
