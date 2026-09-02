package com.snabbit.runner.shared.features.job.presentation.contact

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.contact_call_initiated
import com.snabbit.runner.shared.resources.contact_call_number_unavailable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException
import org.jetbrains.compose.resources.stringResource
import org.koin.mp.KoinPlatform.getKoin
import com.snabbit.runner.shared.features.job.data.contact.CallingDataSource
import com.snabbit.runner.shared.features.job.data.contact.CustomerContactLauncher

/**
 * Orchestrates the navigation-card contact actions (Call / Map / Chat), migrated from the Flutter
 * `CallUtils.handleCallInitiation` + `MapsNavigationService`. UI-agnostic: the composables call it
 * directly; the host constructs a real [DefaultCustomerContactHandler] and passes it down, while
 * previews / un-hosted screens / tests use [NoOpCustomerContactHandler].
 *
 * [feedback] emits semantic [ContactFeedback] events; the screen resolves the copy from
 * [rememberContactStrings] and shows a snackbar (strings kept out of this layer — PR #452).
 */
interface CustomerContactHandler {
    /** Place a masked call to [phoneNumber]; on failure fall back to the dialer. Blank/null → error feedback. */
    fun call(phoneNumber: String?)

    /** Open Google Maps walking navigation to [latitude],[longitude]. No-op when either is null. */
    fun openMaps(latitude: Double?, longitude: Double?)

    /** Open the customer chat (placeholder). */
    fun openChat()

    /** One-shot semantic feedback for the host to resolve (via [rememberContactStrings]) + surface. */
    val feedback: Flow<ContactFeedback>
}

/** Semantic one-shot contact feedback; the UI resolves the copy from [rememberContactStrings]. */
enum class ContactFeedback { CallInitiated, CallNumberUnavailable }

/** No-op handler — the default when no host handler is wired (previews, tests, un-hosted screens). */
object NoOpCustomerContactHandler : CustomerContactHandler {
    override fun call(phoneNumber: String?) = Unit
    override fun openMaps(latitude: Double?, longitude: Double?) = Unit
    override fun openChat() = Unit
    override val feedback: Flow<ContactFeedback> = emptyFlow()
}

/**
 * Copy for the contact feedback snackbars. Two-tier i18n (per PR #452): the English fallbacks live in
 * `composeResources` and are resolved by [rememberContactStrings]; the host can still override any
 * label at runtime by passing the app's server-driven i18n value into the corresponding field.
 */
data class ContactStrings(
    val callInitiated: String,
    val callNumberUnavailable: String,
)

/** [ContactStrings] with each label defaulted to its `composeResources` fallback. */
@Composable
fun rememberContactStrings(
    callInitiated: String = stringResource(Res.string.contact_call_initiated),
    callNumberUnavailable: String = stringResource(Res.string.contact_call_number_unavailable),
): ContactStrings = remember(callInitiated, callNumberUnavailable) {
    ContactStrings(callInitiated = callInitiated, callNumberUnavailable = callNumberUnavailable)
}.localized(getKoin().get())

/**
 * Overlays the server-driven i18n map onto these [ContactStrings] (baked into
 * [rememberContactStrings]); absent keys fall back to composeResources English.
 */
fun ContactStrings.localized(store: LocalizationStore): ContactStrings = copy(
    callInitiated = store.getMessage("job.contact.call_initiated", callInitiated),
    callNumberUnavailable =
        store.getMessage("job.contact.call_number_unavailable", callNumberUnavailable),
)

/**
 * Production [CustomerContactHandler]. **Call** mirrors the Flutter `CallUtils.handleCallInitiation`:
 * guard a blank number, request the masked call, emit success feedback on 2xx, else fall back to the
 * dialer. **Map** delegates to [CustomerContactLauncher.openMapsNavigation]; **chat** to
 * [CustomerContactLauncher.openChat] (placeholder). Async work runs on the injected [scope].
 */
class DefaultCustomerContactHandler(
    private val calling: CallingDataSource,
    private val launcher: CustomerContactLauncher,
    private val scope: CoroutineScope,
) : CustomerContactHandler {

    private val _feedback = Channel<ContactFeedback>(Channel.BUFFERED)
    override val feedback: Flow<ContactFeedback> = _feedback.receiveAsFlow()

    override fun call(phoneNumber: String?) {
        val phone = phoneNumber?.trim().orEmpty()
        if (phone.isEmpty()) {
            // Never POST `.../phone_call/` with a blank number — surface a graceful error (Flutter guard).
            scope.launch { _feedback.send(ContactFeedback.CallNumberUnavailable) }
            return
        }
        scope.launch {
            val placed = try {
                calling.initiateCall(phone)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                false
            }
            if (placed) {
                _feedback.send(ContactFeedback.CallInitiated)
            } else {
                // Masked call didn't go through — fall back to the device dialer.
                launcher.dial(phone)
            }
        }
    }

    override fun openMaps(latitude: Double?, longitude: Double?) {
        if (latitude == null || longitude == null) return
        launcher.openMapsNavigation(latitude, longitude)
    }

    override fun openChat() = launcher.openChat()
}
