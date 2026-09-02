package com.snabbit.runner.shared.features.job.presentation.inprogress

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitDivider
import com.snabbit.design.atoms.SnabbitDividerType
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitListContainer
import com.snabbit.design.atoms.SnabbitListItem
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.presentation.contact.CustomerContactHandler
import com.snabbit.runner.shared.features.job.presentation.contact.NoOpCustomerContactHandler
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.ui.icons.AppIcons

/**
 * Job details shown on the in-progress screen (from the `current_state` `RUNNER_JOB_IN_PROGRESS`
 * envelope — customer name, `start_time`/`end_time`, `duration`, and any extension).
 *
 * @param customerName the customer's name (`customer_name`).
 * @param jobTiming pre-formatted "start – end" range (e.g. "10:00 AM  -  11:00 AM").
 * @param duration pre-formatted base duration (e.g. "60 min").
 * @param extraDuration pre-formatted extension when the job was extended (e.g. "+15 min"); null when
 *   not extended. Shown in brand-pink next to [duration] — the `on_the_job.dart` `jobExtendedBy` case.
 */
data class JobDetails(
    val customerName: String,
    val jobTiming: String,
    val duration: String,
    val extraDuration: String? = null,
    /** `customer_ph_no` — the number for the Call action (masked call); null → Call is a no-op. */
    val customerPhone: String? = null,
)

/**
 * **Job details** card — customer name with a call action, the job timing, and the duration
 * (with an optional "+extra" extension), split by hairlines. Figma "Expert App DS 2.0" node
 * 1490:11344 (without Kavach) / 1490:11345 (with Kavach) and "Shift — Job Lifecycle DS" 6:8446
 * (extended). Composes DS atoms: [SnabbitListItem] per row, [SnabbitButton] (icon-only Secondary)
 * for the actions, [SnabbitDivider], [SnabbitText], [SnabbitIcon].
 *
 * **Snabbit Kavach** integrates per Figma 19-14862 / 19-15747: pass its UI via [kavach] and it renders
 * as a full-width gradient card layered BEHIND this card, tucked under the bottom edge so the two read
 * as one unit. When null (feature off / not present for the job) only the details card renders.
 *
 * The card is a plain rounded-16 container (the DS [com.snabbit.design.atoms.SnabbitCard] is r-12
 * only; this design is r-16), drawn from tokens.
 *
 * @param contact handles the customer call (masked, with a dialer fallback); defaults to a no-op —
 *   the host passes a real handler. Uses [JobDetails.customerPhone] to place the call.
 * @param kavach optional Snabbit Kavach card, layered behind the details card (feature-gated by the caller).
 */
@Composable
fun JobDetailsCard(
    details: JobDetails,
    modifier: Modifier = Modifier,
    contact: CustomerContactHandler = NoOpCustomerContactHandler,
    analytics: JobAnalytics? = null,
    jobTimingLabel: String = "Job Timing",
    durationLabel: String = "Duration",
    kavach: (@Composable () -> Unit)? = null,
) {
    if (kavach == null) {
        JobDetailsBody(details = details, modifier = modifier, contact = contact, analytics = analytics, jobTimingLabel = jobTimingLabel, durationLabel = durationLabel)
        return
    }
    val kavachContent = kavach
    // Figma 19-14862/19-15747: the Kavach card is full-width and layered BEHIND the details card,
    // offset down so its top tucks under the details card's bottom edge — the two read as one unit.
    Layout(
        modifier = modifier.fillMaxWidth(),
        content = {
            Box(Modifier.fillMaxWidth().zIndex(0f)) { kavachContent() } // behind
            JobDetailsBody(details = details, modifier = Modifier.zIndex(1f), contact = contact, analytics = analytics, jobTimingLabel = jobTimingLabel, durationLabel = durationLabel) // in front
        },
    ) { measurables, constraints ->
        val kavachPlaceable = measurables[0].measure(constraints)
        val detailsPlaceable = measurables[1].measure(constraints)
        val kavachTop = (detailsPlaceable.height - KavachDetailsOverlap.roundToPx()).coerceAtLeast(0)
        layout(maxOf(detailsPlaceable.width, kavachPlaceable.width), kavachTop + kavachPlaceable.height) {
            kavachPlaceable.place(0, kavachTop)
            detailsPlaceable.place(0, 0)
        }
    }
}

/**
 * White rounded-16 details-card body (customer / timing / duration). Rendered in front of the
 * optional Kavach card by [JobDetailsCard].
 */
@Composable
private fun JobDetailsBody(
    details: JobDetails,
    modifier: Modifier = Modifier,
    contact: CustomerContactHandler = NoOpCustomerContactHandler,
    analytics: JobAnalytics? = null,
    jobTimingLabel: String = "Job Timing",
    durationLabel: String = "Duration",
) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(SnabbitTheme.colors.bgPrimary)
            .border(1.5.dp, SnabbitTheme.colors.borderSubtle, shape)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // ── Customer name + call action ──
        SnabbitListItem(
            container = SnabbitListContainer.Plain,
            titleContent = {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SnabbitIcon(
                        imageVector = AppIcons.Customer,
                        size = 16.dp,
                        color = SnabbitColorsLight.gray600,
                    )
                    SnabbitText(
                        text = details.customerName,
                        // Body-M/16-Medium, gray-900.
                        fontSize = 16.sp,
                        lineHeight = 24.sp,
                        fontWeight = FontWeight.Medium,
                        color = SnabbitTheme.colors.textPrimary,
                    )
                }
            },
            trailingContent = {
                // Chat is disabled (feature off) — only the Call action is shown.
                JobActionButton(
                    icon = AppIcons.Call,
                    onClick = {
                        analytics?.inProgressScreenCtaClick("call")
                        contact.call(details.customerPhone)
                    },
                )
            },
        )

        SnabbitDivider(type = SnabbitDividerType.Line)

        // ── Job timing ──
        JobDetailRow(icon = AppIcons.Clock, label = jobTimingLabel) {
            JobDetailValue(details.jobTiming)
        }

        SnabbitDivider(type = SnabbitDividerType.Line)

        // ── Duration (+ optional extension) ──
        JobDetailRow(icon = AppIcons.Hourglass, label = durationLabel) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                JobDetailValue(details.duration)
                details.extraDuration?.let { extra ->
                    SnabbitText(
                        text = extra,
                        // "+15 min" — brand-pink, Semibold 16/24 (per the extended design/screenshot).
                        fontSize = 16.sp,
                        lineHeight = 24.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SnabbitTheme.colors.textBrand,
                    )
                }
            }
        }
    }
}

/** Figma 19-14862: the Kavach card tucks ~24dp under the details card's bottom edge (one unit). */
private val KavachDetailsOverlap = 24.dp

/** A `[icon] label ⟶ [trailing]` row (label gray-500 Regular; value provided by the caller). */
@Composable
private fun JobDetailRow(
    icon: ImageVector,
    label: String,
    trailing: @Composable () -> Unit,
) {
    SnabbitListItem(
        container = SnabbitListContainer.Plain,
        titleContent = {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SnabbitIcon(imageVector = icon, size = 16.dp, color = SnabbitColorsLight.gray600)
                SnabbitText(
                    text = label,
                    // Body-M/16-Regular, gray-500.
                    fontSize = 16.sp,
                    lineHeight = 24.sp,
                    fontWeight = FontWeight.Normal,
                    color = SnabbitTheme.colors.textSecondary,
                )
            }
        },
        trailingContent = trailing,
    )
}

/** The right-aligned value cell — Body-M/16-Semibold, gray-700. */
@Composable
private fun JobDetailValue(value: String) {
    SnabbitText(
        text = value,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        fontWeight = FontWeight.SemiBold,
        color = SnabbitTheme.colors.textBody,
    )
}

/** A 40×40 pink-tinted icon action (chat / call) — DS [SnabbitButton] icon-only, Secondary, size S. */
@Composable
private fun JobActionButton(icon: ImageVector, onClick: () -> Unit) {
    SnabbitButton(
        text = "",
        onClick = onClick,
        style = SnabbitButtonStyle.Secondary,
        size = SnabbitButtonSize.S,
        iconOnly = true,
        leadingIcon = {
            SnabbitIcon(imageVector = icon, size = 16.dp, color = SnabbitTheme.colors.iconBrand)
        },
    )
}

/* ── Previews ─────────────────────────────────────────────────────────── */

private val sampleJob = JobDetails(
    customerName = "Radhika S",
    jobTiming = "10:00 AM  -  11:00 AM",
    duration = "60 min",
)

@Preview
@Composable
private fun PreviewJobDetailsCard() {
    SnabbitTheme {
        Column(Modifier.background(SnabbitTheme.colors.bgSecondary).padding(20.dp)) {
            JobDetailsCard(details = sampleJob)
        }
    }
}

@Preview
@Composable
private fun PreviewJobDetailsCardExtended() {
    SnabbitTheme {
        Column(Modifier.background(SnabbitTheme.colors.bgSecondary).padding(20.dp)) {
            JobDetailsCard(details = sampleJob.copy(extraDuration = "+15 min"))
        }
    }
}
