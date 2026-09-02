package com.snabbit.runner.shared.features.job.presentation.checkin

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.rememberJobStrings
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.runner.shared.features.job.presentation.common.AutoProgressButton
import com.snabbit.runner.shared.features.job.presentation.common.CampaignCard
import com.snabbit.runner.shared.features.job.presentation.common.DEFAULT_AUTO_ADVANCE_MILLIS
import com.snabbit.runner.shared.features.job.presentation.common.JobCampaignImages

/**
 * The **campaign** payload for the successful-check-in screen — sourced from the `current_state`
 * envelope's `widget_data.post_check_in_success_campaign`. Mapping is wired later; the fields here
 * are the display bits the screen needs. All nullable so an absent/partial campaign degrades
 * gracefully (no image card, no banner).
 *
 * @param imageUrl the celebration illustration (e.g. the "Namaste" art); loaded via [CampaignCard]'s
 *   remote image. Null/blank falls back to the S3 `JobCampaignImages.CHECK_IN` default.
 * @param bannerEmoji leading emoji on the status banner (e.g. "🙏").
 * @param bannerText the status-banner copy (e.g. "Say Namaste", "Gold Bonus unlocked").
 */
data class PostCheckInSuccessCampaign(
    val imageUrl: String? = null,
    val bannerEmoji: String? = null,
    val bannerText: String? = null,
)

/**
 * **Successful check-in** — the "Job Started" celebration content shown once a check-in succeeds:
 * a green check, the title, an optional campaign illustration (with its status banner), and a
 * progress CTA that **auto-advances** (fills over [progressDurationMillis]) and fires
 * [onProgressComplete] on completion — or immediately if the runner taps it. Figma node 132:38277
 * ("Job Started" bottom sheet).
 *
 * This is **content only** — it is NOT wrapped in a [SnabbitBottomSheet]; the caller supplies the
 * sheet chrome (close button, gray-50 surface, insets) when wiring it in, exactly like
 * [CheckInContent]. Design tokens + DS components throughout, so it stays commonMain-pure.
 *
 * @param onProgressComplete run when the progress fill completes (or the CTA is tapped) — e.g.
 *   dismiss the sheet / advance the lifecycle. Fires at most once.
 * @param campaign the `post_check_in_success_campaign` data; when null the S3 default illustration
 *   shows (with no banner).
 * @param progressDurationMillis how long the CTA takes to auto-fill before firing.
 */
@Composable
internal fun SuccessfulCheckIn(
    strings: JobStrings,
    onProgressComplete: () -> Unit,
    modifier: Modifier = Modifier,
    campaign: PostCheckInSuccessCampaign? = null,
    progressDurationMillis: Int = DEFAULT_AUTO_ADVANCE_MILLIS,
    // Tiering job nudge ("Do a perfect job") — sits 8dp below the campaign image, above OK.
    jobTieringNudge: (@Composable () -> Unit)? = null,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(32.dp),
    ) {
        // Green check + title.
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(60.dp)
                    .clip(CircleShape)
                    // Solid success green (#059669). No semantic "strong success bg" token exists —
                    // the palette green600 mirrors SnabbitButton/ProgressButton's Success fill.
                    .background(SnabbitColorsLight.green600),
                contentAlignment = Alignment.Center,
            ) {
                SnabbitIcon(
                    name = SnabbitIconName.Check,
                    size = 32.dp,
                    color = SnabbitTheme.colors.iconInverse,
                )
            }
            SnabbitText(
                text = strings.jobStarted,
                variant = SnabbitTextVariant.Heading2,
                color = SnabbitTheme.colors.textPrimary,
                textAlign = TextAlign.Center,
            )
        }

        // Illustration + CTA.
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            // Image + tiering nudge grouped 8dp apart (the nudge sits right below the campaign
            // image); the group keeps the 28dp gap to the OK button.
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // Always show the illustration — the backend campaign image when present, else the
                // S3 default (the banner only shows when the campaign supplies one).
                CampaignImageCard(campaign)
                jobTieringNudge?.invoke()
            }
            AutoProgressButton(
                label = strings.okAction,
                onProgressComplete = onProgressComplete,
                durationMillis = progressDurationMillis,
            )
        }
    }
}

/**
 * The check-in campaign illustration card: the shared [CampaignCard] with a 2dp border and (when the
 * backend supplies one) the success status banner pinned to its bottom. The image is the campaign's
 * [PostCheckInSuccessCampaign.imageUrl] when present, else the S3 [JobCampaignImages.CHECK_IN] default
 * — so the celebration always shows an illustration, even before the campaign is mapped from the API.
 */
@Composable
private fun CampaignImageCard(campaign: PostCheckInSuccessCampaign?) {
    CampaignCard(
        imageUrl = campaign?.imageUrl?.takeIf { it.isNotBlank() } ?: JobCampaignImages.CHECK_IN,
        showBorder = true,
        bannerEmoji = campaign?.bannerEmoji,
        bannerText = campaign?.bannerText,
    )
}

// ── Preview ────────────────────────────────────────────────────────────────

@Preview
@Composable
private fun PreviewSuccessfulCheckIn() {
    SnabbitTheme {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(SnabbitTheme.colors.bgSecondary),
        ) {
            SuccessfulCheckIn(
                strings = rememberJobStrings(),
                onProgressComplete = {},
                campaign = PostCheckInSuccessCampaign(
                    bannerEmoji = "🙏",
                    bannerText = "Say Namaste",
                ),
            )
        }
    }
}
