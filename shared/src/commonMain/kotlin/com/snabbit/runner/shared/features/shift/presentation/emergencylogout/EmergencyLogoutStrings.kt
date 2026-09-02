package com.snabbit.runner.shared.features.shift.presentation.emergencylogout

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.emergency_logout_confirm_error
import com.snabbit.runner.shared.resources.emergency_logout_go_back
import com.snabbit.runner.shared.resources.emergency_logout_load_error
import com.snabbit.runner.shared.resources.emergency_logout_logout
import com.snabbit.runner.shared.resources.emergency_logout_miss_shift_label
import com.snabbit.runner.shared.resources.emergency_logout_period_leave_available_template
import com.snabbit.runner.shared.resources.emergency_logout_red_card_label_template
import com.snabbit.runner.shared.resources.emergency_logout_retry
import com.snabbit.runner.shared.resources.emergency_logout_sheet_close
import com.snabbit.runner.shared.resources.emergency_logout_take_care_body
import com.snabbit.runner.shared.resources.emergency_logout_take_care_cta
import com.snabbit.runner.shared.resources.emergency_logout_take_care_title
import com.snabbit.runner.shared.resources.emergency_logout_title
import org.jetbrains.compose.resources.stringResource
import org.koin.mp.KoinPlatform.getKoin

/**
 * UI text for the emergency-logout flow.
 *
 * Same two-tier i18n as [com.snabbit.runner.shared.core.camera.ui.CameraStrings]:
 * the **fallbacks** live in `composeResources` and are resolved by
 * [rememberEmergencyLogoutStrings]; the host may **override** any label at runtime
 * with the app's server-driven i18n value by passing a named argument.
 *
 * Gamification-related copy ("Lose ₹X", red-card chips, sheet warnings) is
 * deliberately absent — those visuals ship in a separate gamification PR.
 */
data class EmergencyLogoutStrings(
    val title: String,
    val goBack: String,
    val logout: String,
    /** Has a `{count}` placeholder. */
    val periodLeaveWithAvailableTemplate: String,
    /** Red-card consequence tile label — has a `{count}` placeholder. */
    val redCardLabelTemplate: String,
    val missShiftLabel: String,
    val takeCareTitle: String,
    val takeCareBody: String,
    val takeCareCta: String,
    /** Initial-fetch failure. */
    val loadError: String,
    /** Confirm-POST failure. */
    val confirmError: String,
    val retry: String,
    /** Sheet close-button accessibility label. */
    val sheetCloseContentDescription: String,
    /** Earning-loss consequence tile — has a `₹{amount}` placeholder (Hindi reorders it). */
    val loseEarningsTemplate: String = "Lose ₹{amount}",
) {
    /** Resolve the state's error type to its user-facing message. */
    fun messageFor(error: EmergencyLogoutError): String = when (error) {
        EmergencyLogoutError.Load -> loadError
        EmergencyLogoutError.Confirm -> confirmError
    }
}

/**
 * [EmergencyLogoutStrings] with every label defaulted to its `composeResources`
 * fallback. Pass a named argument to override just that label with a server-driven
 * value.
 */
@Composable
fun rememberEmergencyLogoutStrings(
    title: String = stringResource(Res.string.emergency_logout_title),
    goBack: String = stringResource(Res.string.emergency_logout_go_back),
    logout: String = stringResource(Res.string.emergency_logout_logout),
    periodLeaveWithAvailableTemplate: String =
        stringResource(Res.string.emergency_logout_period_leave_available_template),
    redCardLabelTemplate: String = stringResource(Res.string.emergency_logout_red_card_label_template),
    missShiftLabel: String = stringResource(Res.string.emergency_logout_miss_shift_label),
    takeCareTitle: String = stringResource(Res.string.emergency_logout_take_care_title),
    takeCareBody: String = stringResource(Res.string.emergency_logout_take_care_body),
    takeCareCta: String = stringResource(Res.string.emergency_logout_take_care_cta),
    loadError: String = stringResource(Res.string.emergency_logout_load_error),
    confirmError: String = stringResource(Res.string.emergency_logout_confirm_error),
    retry: String = stringResource(Res.string.emergency_logout_retry),
    sheetCloseContentDescription: String = stringResource(Res.string.emergency_logout_sheet_close),
): EmergencyLogoutStrings = remember(
    title, goBack, logout, periodLeaveWithAvailableTemplate, redCardLabelTemplate,
    missShiftLabel, takeCareTitle, takeCareBody, takeCareCta, loadError, confirmError,
    retry, sheetCloseContentDescription,
) {
    EmergencyLogoutStrings(
        title = title,
        goBack = goBack,
        logout = logout,
        periodLeaveWithAvailableTemplate = periodLeaveWithAvailableTemplate,
        redCardLabelTemplate = redCardLabelTemplate,
        missShiftLabel = missShiftLabel,
        takeCareTitle = takeCareTitle,
        takeCareBody = takeCareBody,
        takeCareCta = takeCareCta,
        loadError = loadError,
        confirmError = confirmError,
        retry = retry,
        sheetCloseContentDescription = sheetCloseContentDescription,
    )
}.localized(getKoin().get())

/**
 * Overlays the server-driven i18n map onto these [EmergencyLogoutStrings] (baked into
 * [rememberEmergencyLogoutStrings]); absent keys fall back to the composeResources English.
 * The two count-templates use single-brace `{count}` — server value, composeResources
 * fallback (strings.xml), and the `.replace("{count}")` consumers (PeriodLeaveRow /
 * EmergencyConsequenceCards) are all aligned. Keys follow the PM localization catalog.
 */
fun EmergencyLogoutStrings.localized(store: LocalizationStore): EmergencyLogoutStrings = copy(
    title = store.getMessage("emergency_logout.will_lead_to", title),
    goBack = store.getMessage("emergency_logout.cta_go_back", goBack),
    logout = store.getMessage("emergency_logout.cta_logout", logout),
    periodLeaveWithAvailableTemplate =
        store.getMessage("emergency_logout.period_leave", periodLeaveWithAvailableTemplate),
    redCardLabelTemplate =
        store.getMessage("emergency_logout.penalty_red_card", redCardLabelTemplate),
    missShiftLabel = store.getMessage("emergency_logout.penalty_miss_shift", missShiftLabel),
    loseEarningsTemplate = store.getMessage("emergency_logout.penalty_lose", loseEarningsTemplate),
    takeCareTitle = store.getMessage("post_logout.take_care", takeCareTitle),
    takeCareBody = store.getMessage("emergency_logout_waived.title", takeCareBody),
    takeCareCta = store.getMessage("post_logout.cta_okay", takeCareCta),
    loadError = store.getMessage("emergency_logout.load_error", loadError),
    confirmError = store.getMessage("emergency_logout.confirm_error", confirmError),
    retry = store.getMessage("emergency_logout.retry", retry),
    sheetCloseContentDescription =
        store.getMessage("emergency_logout.sheet_close", sheetCloseContentDescription),
)
