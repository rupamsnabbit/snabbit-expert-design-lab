package com.snabbit.runner.shared.features.job.presentation.inprogress

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.runner.shared.features.job.presentation.inprogress.CheckoutUiState
import com.snabbit.runner.shared.features.job.presentation.inprogress.CheckoutStep
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.resolve
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet
import com.snabbit.runner.shared.features.job.presentation.common.OtpEntryField

/** OTP digits the customer shares to end the job (backend `check_out`). */
private const val CHECKOUT_OTP_LENGTH = 3

/**
 * The **checkout** bottom sheet opened from the in-progress "Complete Job" CTA — a **single**
 * [SnabbitBottomSheet] that morphs through [CheckoutStep]s in place (the same shape as [CheckInSheet]):
 *
 * ```
 * Campaign ─(progress done / tap)─▶ Otp ─(2xx check_out)─▶ [refresh + close]
 * ```
 *
 * - **Campaign** (Figma 10:14765): the post-job-end [PostJobEndCampaign] nudge with an auto-advancing
 *   Okay CTA. Dismissible. (Skipped when the job has no campaign — the flow then opens at [CheckoutStep.Otp].)
 * - **Otp** (Figma 10:13893 / 10:13962): a 3-cell [OtpEntryField] + a full-width **End Job** CTA that
 *   stays disabled until all digits are entered, then submits `check_out`. Dismissible.
 *
 * The post-checkout house-tasks selection ("What tasks did you do?") is now a separate forced sheet on the
 * Completed stage (ECPO-528), not a step here.
 *
 * Stateless over [CheckoutUiState] (the step + `isSubmitting` / `errorMessage`, from
 * `CheckoutViewModel.uiState`). The OTP text is transient local input, re-seeded per job.
 *
 * @param jobId the current job id — re-seeds the OTP input when it changes, so a reused sheet can't
 *   carry a stale OTP across jobs (matches [CheckInSheet]).
 * @param campaignImageUrl the campaign illustration for the [CheckoutStep.Campaign] step (from the envelope).
 * @param onCampaignComplete the campaign CTA completed → advance to the OTP step.
 * @param onEndJob submit the entered OTP (fires `CheckoutUiIntent.EndJob` → `check_out`).
 * @param onDismiss close the sheet.
 */
@Composable
internal fun CheckoutSheet(
    flow: CheckoutUiState,
    jobId: Int?,
    strings: JobStrings,
    campaignImageUrl: String?,
    onCampaignComplete: () -> Unit,
    onEndJob: (otp: String) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var otp by remember(jobId) { mutableStateOf("") }

    // Only the OTP step uses the sheet's title + footer; the campaign step carries its own heading + CTA
    // inside its content.
    val footer: (@Composable () -> Unit)? = if (flow.step == CheckoutStep.Otp) {
        {
            SnabbitButton(
                text = strings.endJob,
                onClick = { onEndJob(otp) },
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
                enabled = otp.length == CHECKOUT_OTP_LENGTH && !flow.isSubmitting,
                loading = flow.isSubmitting,
            )
        }
    } else {
        null
    }

    SnabbitBottomSheet(
        onDismissRequest = onDismiss,
        // Keep the End Job footer clear of both the keyboard and the system navigation bar by padding
        // with whichever is taller (mirrors the check-in sheet): keyboard DOWN → clears the nav bar,
        // keyboard UP → clears the IME with no extra nav-bar gap. windowInsetsPadding consumes these
        // insets so the modal's own handling can't double-count them.
        modifier = modifier
            .windowInsetsPadding(WindowInsets.ime.union(WindowInsets.navigationBars)),
        title = if (flow.step == CheckoutStep.Otp) strings.enterOtpToEndJobTitle else null,
        draggable = false,
        footer = footer,
    ) {
        when (flow.step) {
            CheckoutStep.Campaign -> PostJobEndCampaign(
                imageUrl = campaignImageUrl,
                strings = strings,
                onOkayComplete = onCampaignComplete,
            )
            CheckoutStep.Otp -> OtpEntryField(
                otp = otp,
                onOtpChange = { otp = it },
                helperText = strings.otpHelper,
                error = flow.errorMessage?.let { strings.resolve(it) },
                enabled = !flow.isSubmitting,
                length = CHECKOUT_OTP_LENGTH,
            )
        }
    }
}
