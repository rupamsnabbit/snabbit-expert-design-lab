package com.snabbit.runner.shared.features.job.presentation.checkin

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.molecules.SnabbitPhoneInput
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.resolve
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet
import com.snabbit.runner.shared.features.job.presentation.common.OtpEntryField

/** OTP digits the customer shares for check-in (backend `start_job`). */
private const val OTP_LENGTH = 3

/** Digits in an Indian customer phone number (no country code). */
private const val PHONE_LENGTH = 10

/**
 * The **check-in** bottom sheet — a **single** [SnabbitBottomSheet] that morphs through
 * [CheckInStep]s in place, per "one sheet that changes state, not a sheet per step" (the same
 * shape as [JobDenyFlowSheet]):
 *
 * ```
 * Otp ──(No OTP)──▶ Phone          (either submits start_job)
 *  ▲                 │
 *  └──(Use OTP)──────┘
 * Otp | Phone ──(2xx)──▶ Success ──(progress done / tap)──▶ [dismiss + advance stage]
 * ```
 *
 * - **Otp** (Figma 4:9621 / 4:9907): 3-cell OTP + Start Job, with an in-sheet "No OTP" fallback
 *   when the job allows it (`allow_check_in_without_otp`).
 * - **Phone** (Figma 4:10077): the customer's booking phone number + Start Job, with "Use OTP
 *   instead" back to the OTP step.
 * - **Success** (Figma 132:38277): the "Job Started" celebration ([SuccessfulCheckIn]) with an
 *   auto-advancing progress button. **Forced** — no scrim/back/close escape — so it can only
 *   complete via [onSuccessComplete] (fired when the progress fills or the runner taps it), which
 *   closes the sheet and advances the stage.
 *
 * Stateless over [CheckInUiState] (step + `isSubmitting` / `errorMessage`, from `CheckInViewModel`)
 * plus [allowNoOtp] / [jobId] off the envelope. The OTP/phone text is transient local input, re-seeded
 * per job.
 *
 * @param allowNoOtp `allow_check_in_without_otp` — gates the in-sheet "No OTP" fallback button.
 * @param jobId the current job id — re-seeds the OTP/phone inputs when it changes.
 * @param onStartJob submit the entered OTP (fires `CheckInUiIntent.StartJob`).
 * @param onCheckInWithPhone submit the entered phone (fires `CheckInUiIntent.CheckInWithPhone`).
 * @param onSwitchToPhone OTP step → phone fallback ("No OTP").
 * @param onSwitchToOtp phone step → OTP ("Use OTP instead").
 * @param onSuccessComplete the success progress animation finished (or was tapped) — advance + close.
 * @param onDismiss close the sheet (OTP / phone steps only).
 */
@Composable
internal fun CheckInSheet(
    flow: CheckInUiState,
    allowNoOtp: Boolean,
    jobId: Int?,
    strings: JobStrings,
    onStartJob: (otp: String) -> Unit,
    onCheckInWithPhone: (phone: String) -> Unit,
    onSwitchToPhone: () -> Unit,
    onSwitchToOtp: () -> Unit,
    onSuccessComplete: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    // Tiering job nudge shown inside the "Job Started" success step (below the campaign image).
    jobTieringNudge: (@Composable () -> Unit)? = null,
) {
    var otp by remember(jobId) { mutableStateOf("") }
    var phone by remember(jobId) { mutableStateOf("") }

    val isSuccess = flow.step == CheckInStep.Success

    val footer: (@Composable () -> Unit)? = when (flow.step) {
        CheckInStep.Otp -> {
            {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    SnabbitButton(
                        text = strings.startJob,
                        onClick = { onStartJob(otp) },
                        style = SnabbitButtonStyle.Primary,
                        size = SnabbitButtonSize.L,
                        fullWidth = true,
                        enabled = otp.length == OTP_LENGTH && !flow.isSubmitting,
                        loading = flow.isSubmitting,
                    )
                    // "No OTP" only when the backend allows OTP-less check-in for this job.
                    // Rendered as a borderless underlined link (not a Tertiary button): the
                    // underline carries the same brand-pink that used to be the button's border.
                    if (allowNoOtp) {
                        val noOtpEnabled = !flow.isSubmitting
                        Box(
                            modifier = Modifier.fillMaxWidth(),
                            contentAlignment = Alignment.Center,
                        ) {
                            SnabbitText(
                                text = strings.noOtp,
                                color = if (noOtpEnabled) {
                                    SnabbitTheme.colors.borderBrand
                                } else {
                                    SnabbitTheme.colors.textDisabled
                                },
                                fontWeight = FontWeight.Medium,
                                textDecoration = TextDecoration.Underline,
                                modifier = Modifier.clickable(
                                    enabled = noOtpEnabled,
                                    onClick = onSwitchToPhone,
                                ),
                            )
                        }
                    }
                }
            }
        }
        CheckInStep.Phone -> {
            {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    SnabbitButton(
                        text = strings.startJob,
                        onClick = { onCheckInWithPhone(phone) },
                        style = SnabbitButtonStyle.Primary,
                        size = SnabbitButtonSize.L,
                        fullWidth = true,
                        enabled = phone.length == PHONE_LENGTH && !flow.isSubmitting,
                        loading = flow.isSubmitting,
                    )
                    SnabbitButton(
                        text = strings.useOtpInstead,
                        onClick = onSwitchToOtp,
                        style = SnabbitButtonStyle.Tertiary,
                        size = SnabbitButtonSize.L,
                        fullWidth = true,
                        enabled = !flow.isSubmitting,
                    )
                }
            }
        }
        // Success has no footer — its CTA lives in the content.
        CheckInStep.Success -> null
    }

    SnabbitBottomSheet(
        onDismissRequest = onDismiss,
        // Keep the Start Job footer clear of both the keyboard and the system navigation bar. Pad by
        // whichever of the two is taller: keyboard DOWN (the OTP field doesn't auto-focus, so the
        // sheet opens this way) → clears the nav bar; keyboard UP → clears the IME with no extra
        // nav-bar gap. windowInsetsPadding also *consumes* these insets, so the modal's own inset
        // handling can't double-count them.
        modifier = modifier
            .windowInsetsPadding(WindowInsets.ime.union(WindowInsets.navigationBars)),
        // Success renders its own "Job Started" heading; OTP/phone use the sheet title.
        title = when (flow.step) {
            CheckInStep.Otp -> strings.enterOtpTitle
            CheckInStep.Phone -> strings.enterPhoneTitle
            // Success renders its own heading in the content.
            CheckInStep.Success -> null
        },
        // No drag handle (matches Figma); close button + scrim dismiss the OTP/phone steps only.
        draggable = false,
        // Success is a forced terminal step — only the progress button completes it.
        dismissible = !isSuccess,
        showCloseButton = !isSuccess,
        footer = footer,
    ) {
        when (flow.step) {
            CheckInStep.Otp -> OtpEntryField(
                otp = otp,
                onOtpChange = { otp = it },
                helperText = strings.otpHelper,
                error = flow.errorMessage?.let { strings.resolve(it) },
                enabled = !flow.isSubmitting,
            )
            CheckInStep.Phone -> SnabbitPhoneInput(
                // SnabbitPhoneInput owns its text field, +91 prefix, digit filtering and focus
                // border, and swaps helper→error itself — just cap the length.
                value = phone,
                onValueChange = { phone = it.take(PHONE_LENGTH) },
                showLabel = false,
                placeholder = "",
                helperText = strings.phoneHelper,
                error = flow.errorMessage?.let { strings.resolve(it) },
                enabled = !flow.isSubmitting,
            )
            CheckInStep.Success -> SuccessfulCheckIn(
                strings = strings,
                onProgressComplete = onSuccessComplete,
                // TODO(ECPO-528): pass the real post_check_in_success_campaign once it's mapped
                // onto AwaitingCheckIn; null omits the illustration card.
                jobTieringNudge = jobTieringNudge,
            )
        }
    }
}
