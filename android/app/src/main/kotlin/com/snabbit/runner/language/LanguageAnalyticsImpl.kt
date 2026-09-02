package com.snabbit.runner.language

import com.snabbit.runner.kmp_bridge.LanguagePlugin
import com.snabbit.runner.shared.features.language.LanguageAnalytics
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/**
 * Channel-backed [LanguageAnalytics]. Forwards events to Flutter, which routes
 * them to the app analytics (CleverTap / Mixpanel).
 *
 * A singleton that owns an app-lifetime [scope] (never cancelled), so a
 * fire-and-forget event outlives the VM that emitted it — a `viewModelScope`
 * would cancel a `languageConfirmed` send the instant the screen closes after a
 * successful save. Failures are swallowed so analytics never disrupts the screen.
 */
class LanguageAnalyticsImpl(
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default),
) : LanguageAnalytics {

    override fun screenViewed() {
        send("language_screen_viewed", code = null)
    }

    override fun languageSelected(code: String) {
        send("language_selected", code)
    }

    override fun languageConfirmed(code: String) {
        send("language_confirmed", code)
    }

    private fun send(event: String, code: String?) {
        scope.launch {
            try {
                LanguagePlugin.invokeFlutter(
                    "trackLanguageEvent",
                    mapOf("event" to event, "code" to code),
                )
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                // Analytics is best-effort — never disrupt the screen.
            }
        }
    }
}
