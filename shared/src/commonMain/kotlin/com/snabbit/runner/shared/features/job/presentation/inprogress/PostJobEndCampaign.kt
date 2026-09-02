package com.snabbit.runner.shared.features.job.presentation.inprogress

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.common.AutoProgressButton
import com.snabbit.runner.shared.features.job.presentation.rememberJobStrings
import com.snabbit.runner.shared.features.job.presentation.common.CampaignCard
import com.snabbit.runner.shared.features.job.presentation.common.DEFAULT_AUTO_ADVANCE_MILLIS
import com.snabbit.runner.shared.features.job.presentation.common.JobCampaignImages

/**
 * **Post-job-end campaign** — the nudge shown once the job ends (checkout), the KMP analogue of
 * [SuccessfulCheckIn]'s post-check-in campaign. Figma "Shift — Job Lifecycle DS" node 10:14765: a
 * centered title over the campaign illustration, with an auto-advancing **Okay** CTA
 * ([AutoProgressButton]) that fires [onOkayComplete] when the progress fills (or on tap).
 *
 * The illustration is the `current_state` [imageUrl] when present, else the S3
 * [JobCampaignImages.CHECKOUT] default — so the campaign step always has art. Content-only (no
 * [SnabbitBottomSheet] chrome), like [SuccessfulCheckIn]; the caller supplies the sheet.
 *
 * @param imageUrl the campaign illustration from `current_state`; null/blank → the S3 default.
 * @param onOkayComplete run when the CTA's progress completes (or it's tapped) — advance / close.
 *   Fires at most once.
 * @param progressDurationMillis how long the CTA takes to auto-fill before firing.
 */
@Composable
internal fun PostJobEndCampaign(
    imageUrl: String?,
    strings: JobStrings,
    onOkayComplete: () -> Unit,
    modifier: Modifier = Modifier,
    progressDurationMillis: Int = DEFAULT_AUTO_ADVANCE_MILLIS,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        // Figma: 32 between the title and the illustration + CTA block.
        verticalArrangement = Arrangement.spacedBy(32.dp),
    ) {
        SnabbitText(
            text = strings.jobEndCampaignTitle,
            modifier = Modifier.fillMaxWidth(),
            variant = SnabbitTextVariant.Heading2,
            // gray-800 (#1F2937) per Figma — no exact semantic text token exists, so the palette
            // shade is used directly (as SuccessfulCheckIn does for its success green).
            color = SnabbitColorsLight.gray800,
            textAlign = TextAlign.Center,
        )

        Column(
            modifier = Modifier.fillMaxWidth(),
            // Figma: 28 between the illustration and the CTA.
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            // Campaign illustration (Figma 361×263, r-12) — the job-end variant has no border/banner.
            // The backend [imageUrl] when present, else the S3 default so the step always has art.
            CampaignCard(imageUrl = imageUrl?.takeIf { it.isNotBlank() } ?: JobCampaignImages.CHECKOUT)
            AutoProgressButton(
                label = strings.okayAction,
                onProgressComplete = onOkayComplete,
                durationMillis = progressDurationMillis,
            )
        }
    }
}

/* ── Preview ─────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewPostJobEndCampaign() {
    SnabbitTheme {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(SnabbitTheme.colors.bgSecondary)
                .padding(16.dp),
        ) {
            PostJobEndCampaign(
                imageUrl = "https://example.com/campaign.png",
                strings = rememberJobStrings(),
                onOkayComplete = {},
            )
        }
    }
}
