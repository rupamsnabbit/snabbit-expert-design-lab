package com.snabbit.runner.shared.features.job.presentation.newjob

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import org.jetbrains.compose.resources.painterResource
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitButtonLoadingPosition
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.data.JobSubmitAction
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.formatRupees
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.snabbit_deny_loss_earning
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet

/**
 * The **deny / logout** bottom sheet for a deniable New Job — a single loss-earnings warning with
 * **Accept Job** and a secondary CTA:
 *
 * - **Deny** (normal) — denies the job (`deny_job`) and closes.
 * - **Logout** (last-hour) — fires the *same* `deny_job`; the backend treats denying the last-hour
 *   job as the shift logout. The label changes; the action doesn't.
 *
 * Both close the sheet and refresh `current_state`. For a last-hour deny the refreshed state
 * returns the attendance widget (`PA_BEFORE_LOGOUT`), which the **legacy Flutter** surface renders
 * once the KMP `JobActivity` finishes — so marking the next-day attendance is deliberately **not**
 * part of this sheet.
 *
 * Stateless: open/closed is the screen's own local state, and [isLastHour]/[lossAmount] are read off
 * the live New Job model. Callbacks fire intents; the ViewModel runs the deny + refresh, and the
 * screen drops its open-state on success (so the toast shows).
 *
 * @param isLastHour last-hour job ⇒ the secondary CTA reads "Logout" (vs "Deny"); the action is
 *   identical (`deny_job`). Long-distance never overrides this (last-hour takes precedence).
 * @param lossAmount money forfeited by denying, for the warning title (null/0 ⇒ generic copy).
 * @param remaining live accept-countdown [State], ticked by `rememberAcceptCountdown` and hoisted by
 *   [JobScreen] so the Accept progress fill stays in lockstep with the footer's; its `.value` is read
 *   in the sheet body, so only that leaf recomposes each second.
 * @param acceptTotalSeconds full accept window in seconds, for the progress fraction.
 * @param onAccept accept the job (fires Accept + closes the flow).
 * @param onDeny deny / logout the job (fires Deny + closes the flow) — same action for both labels.
 * @param onDismiss close the sheet without acting (close button / scrim / back).
 */
@Composable
internal fun JobDenyFlowSheet(
    isLastHour: Boolean,
    lossAmount: Int?,
    strings: JobStrings,
    remaining: State<Int>,
    acceptTotalSeconds: Int,
    submittingAction: JobSubmitAction?,
    errorMessage: String?,
    onAccept: () -> Unit,
    onDeny: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    SnabbitBottomSheet(
        onDismissRequest = onDismiss,
        modifier = modifier,
        draggable = false,
    ) {
        DenyWarningBody(
            strings = strings,
            lossAmount = lossAmount,
            isLastHour = isLastHour,
            remaining = remaining,
            acceptTotalSeconds = acceptTotalSeconds,
            submittingAction = submittingAction,
            errorMessage = errorMessage,
            onAccept = onAccept,
            onSecondary = onDeny,
        )
    }
}

/**
 * Warning body — illustration + loss title, then Accept Job + (Deny | Logout). Figma stacks the
 * icon+title block (gap 16) over the button group (gap 12), 20 between.
 */
@Composable
private fun DenyWarningBody(
    strings: JobStrings,
    lossAmount: Int?,
    isLastHour: Boolean,
    remaining: State<Int>,
    acceptTotalSeconds: Int,
    submittingAction: JobSubmitAction?,
    errorMessage: String?,
    onAccept: () -> Unit,
    onSecondary: () -> Unit,
) {
    // Accept keeps the live accept countdown while the sheet is open: a green progress button whose
    // trailing band fills as the window drains. The countdown [State] is ticked by rememberAcceptCountdown
    // and hoisted by JobScreen, so the sheet and the footer share ONE ticker and stay in lockstep — no
    // fill jump when the sheet opens over the footer (ECPO issue #2). Reading `.value` here, in the sheet
    // body, confines the per-second tick to this leaf.
    val remainingSeconds = remaining.value
    val total = acceptTotalSeconds.coerceAtLeast(1)
    val progress = (1f - remainingSeconds.toFloat() / total).coerceIn(0f, 1f)

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Loss-of-earnings illustration (100×100 per Figma), replacing the gray placeholder.
            // Swap the `snabbit_deny_loss_earning` drawable to change it — no code change.
            Image(
                painter = painterResource(Res.drawable.snabbit_deny_loss_earning),
                contentDescription = null,
                modifier = Modifier.size(100.dp),
                contentScale = ContentScale.Fit,
            )
            // "You will miss earnings of ₹X" when the envelope carries a loss_amount; otherwise the
            // generic copy. `formatRupees` prepends the ₹, filling the {amount} placeholder.
            val title = if ((lossAmount ?: 0) > 0) {
                strings.denyMissEarningsTitle
                    .replace("₹{amount}", "{amount}") // server copy embeds ₹; formatRupees adds its own
                    .replace("{amount}", formatRupees(lossAmount))
            } else {
                strings.denyLoseEarningsTitle
            }
            SnabbitText(
                text = title,
                variant = SnabbitTextVariant.Heading2,
                color = SnabbitTheme.colors.textPrimary,
                textAlign = TextAlign.Center,
            )
            // A failed accept/deny (e.g. a 400 "not on duty") surfaces here in-context — the sheet
            // now stays open on failure (the VM only closes it on success).
            if (errorMessage != null) {
                SnabbitText(
                    text = errorMessage,
                    variant = SnabbitTextVariant.BodyMd,
                    color = SnabbitTheme.colors.textError,
                    textAlign = TextAlign.Center,
                )
            }
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Accept = green progress button (Figma "Progress Buttons"), its trailing band filling
            // with the accept countdown — the same treatment as the footer's Accept CTA.
            SnabbitButton(
                text = strings.acceptJob,
                onClick = onAccept,
                style = SnabbitButtonStyle.Success,
                progress = progress,
                loadingPosition = SnabbitButtonLoadingPosition.Leading,
                fullWidth = true,
                size = SnabbitButtonSize.L,
                // Spinner only while ACCEPT is in flight; a deny spins the Deny button below, not this one
                // (mirrors AcceptFooter). Both buttons block taps while either action runs.
                loading = submittingAction == JobSubmitAction.Accept,
                enabled = submittingAction == null,
            )
            // Deny (normal) / Logout (last-hour) — same `deny_job` action, different label. Figma tints
            // the label Red-600 (#DC2626): keep the NeutralStroke outline but override the content colour
            // to `SnabbitColorsLight.red600`. There is no "destructive outline" DS style (Destructive is
            // filled red + white), so the palette ref is the way — same pattern as SafetyHomeCard /
            // ChangeAttendanceConfirmSheet; the semantic token set has no red-600 text role.
            SnabbitButton(
                text = if (isLastHour) strings.logout else strings.deny,
                onClick = onSecondary,
                style = SnabbitButtonStyle.NeutralStroke,
                size = SnabbitButtonSize.L,
                fullWidth = true,
                contentColor = SnabbitColorsLight.red600,
                // Spinner on the button that was actually pressed; disabled (not spinning) while Accept runs.
                loading = submittingAction == JobSubmitAction.Deny,
                loadingPosition = SnabbitButtonLoadingPosition.Leading,
                enabled = submittingAction == null,
            )
        }
    }
}
