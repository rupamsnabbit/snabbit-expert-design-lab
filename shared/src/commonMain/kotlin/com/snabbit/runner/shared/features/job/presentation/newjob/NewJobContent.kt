package com.snabbit.runner.shared.features.job.presentation.newjob

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.gamification.domain.model.PreActionNudge
import com.snabbit.runner.shared.features.gamification.presentation.ui.NudgeBannerList
import com.snabbit.runner.shared.features.job.domain.model.JobCategory
import com.snabbit.runner.shared.features.job.domain.model.JobPayout
import com.snabbit.runner.shared.features.job.domain.model.NewJobModel
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.formatIsoClockTime
import com.snabbit.runner.shared.features.job.presentation.formatRupees
import com.snabbit.runner.shared.ui.components.SnabbitEarningsAccordion
import com.snabbit.runner.shared.ui.components.SnabbitEarningsItem
import com.snabbit.runner.shared.ui.components.SnabbitEarningsItems
import com.snabbit.runner.shared.ui.components.SnabbitJobState
import com.snabbit.runner.shared.ui.components.SnabbitJobStateStatus
import com.snabbit.runner.shared.ui.icons.AppIcons

/**
 * `RUNNER_NEW_JOB` body — the assignment to accept. Composes existing app/DS
 * components only: the [SnabbitJobState] header over the [SnabbitEarningsAccordion]
 * payout card. The accept countdown + CTA live in the screen's bottom bar
 * ([JobScreen]'s footer), matching the Figma "New Job" layout.
 */
@Composable
fun NewJobContent(
    state: JobUiState.NewJob,
    strings: JobStrings,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier,
    // Envelope pre-action nudges (acceptance penalty etc.), threaded from the host's
    // GamificationProjector — Dart parity: new_job_assigned.dart renders
    // `NudgeBannerList(runnerRtDataProvider.preActionNudges)` below the payout card
    // (ECPO-831). Empty (previews/tests) renders nothing.
    preActionNudges: List<PreActionNudge> = emptyList(),
    // Nudge expiry → state re-fetch (the Dart `fetchDataNow()` analogue).
    onNudgeExpired: () -> Unit = {},
) {
    val model = state.model
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(contentPadding)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // Cook shows the vendored chef-hat glyph (DS SnabbitIconName has no ChefHat); Expert keeps the
        // default spray-bottle. Driven by model.category (see JobStateMapper.parseCategory).
        SnabbitJobState(
            label = strings.newJobTitle,
            status = SnabbitJobStateStatus.NewJob,
            icon = if (model.category == JobCategory.Cook) {
                {
                    SnabbitIcon(
                        imageVector = AppIcons.ServiceCook,
                        size = 20.dp,
                        color = SnabbitTheme.colors.iconPrimary,
                        contentDescription = null,
                    )
                }
            } else {
                null
            },
        )

        val payout = model.payout
        if (payout != null) {
            SnabbitEarningsAccordion(
                title = strings.youWillEarn,
                amount = formatRupees(payout.totalEarning),
                items = earningsItems(payout, strings),
            )
        }

        // Envelope pre-action nudges — THE one nudge list on the accept screen
        // (ECPO-831), directly below the earnings card (Figma 2:6891 → 3:8979).
        // Red-card risk nudges render as SnabbitRedCardNudge (NudgeBanner
        // delegates); there is no separate `is_red_card` strip — BE doesn't send
        // that field on RUNNER_NEW_JOB, `pre_action_nudges` powers everything.
        NudgeBannerList(nudges = preActionNudges, onExpired = onNudgeExpired)

        // TODO(ECPO-528): the OT / long-distance / time-PE bonus banners and the
        // deallocation / avoid-penalty warning that sit here in `new_job_assigned.dart`
        // have no DS equivalent yet (Flutter uses the bespoke `AmountBanner`/
        // `WarningBelowTimer`). Flagged per the DS-only rule — needs a DS banner
        // component (or an explicit exception) before they can render here.
    }
}

/**
 * Maps [JobPayout] to the accordion rows. The check-in line is derived from the
 * root-level `check_in_*` fields (not `breakdown`) — the highlighted "Check In by
 * <time>" band — mirroring the Flutter `JobPayoutCard`.
 *
 * Inserted 2nd — right after the first breakdown line — matching the Figma earnings
 * card (node 2:6899). Keeping the highlighted band out of the last slot means a plain
 * row ends the list, so the card's bottom padding reads as breathing room rather than
 * a gap under a colored band.
 */
internal fun earningsItems(
    payout: JobPayout,
    strings: JobStrings,
    /**
     * The check-in bonus was lost (deadline passed): render its row greyed
     * ([SnabbitEarningsItem.valueLost]) instead of the highlighted blue band — the
     * "Earnings change" state on the check-in screen. Default false (new-job / eligible).
     */
    checkInLost: Boolean = false,
): SnabbitEarningsItems {
    val rows = payout.lines.map { line ->
        SnabbitEarningsItem(
            label = line.labelDefault ?: line.labelKey,
            value = formatRupees(line.amount),
            // Figma earnings card: the inline duration ("(1 hr)"), the server icon and the
            // subtitle line all come straight off the breakdown line (render only when present).
            durationText = line.pillText,
            iconUrl = line.iconUrl,
            subtitle = line.subtitle,
        )
    }.toMutableList()

    if (payout.checkInAmount != null) {
        val checkIn = SnabbitEarningsItem(
            label = strings.checkInBy,
            value = formatRupees(payout.checkInAmount),
            accent = formatIsoClockTime(payout.checkInTimeIso),
            highlighted = !checkInLost,
            valueLost = checkInLost,
        )
        rows.add(if (rows.isEmpty()) 0 else 1, checkIn)
    }
    // Wrapped in the [SnabbitEarningsItems] stable holder so the four callers' inline rebuild keeps
    // [SnabbitEarningsAccordion] skippable (a bare List param is unstable — the card never skips).
    return SnabbitEarningsItems(rows)
}
