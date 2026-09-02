package com.snabbit.runner.shared.features.job.presentation.common

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme

/**
 * S3-hosted default campaign illustrations — the fallback shown when `current_state` omits the
 * campaign image URL (host + path per product: assets-expert.snabbit.com / job_flow/campaigns).
 */
object JobCampaignImages {
    private const val HOST = "https://assets-expert.snabbit.com/"

    /** Post-check-in celebration default. */
    const val CHECK_IN: String = HOST + "job_flow/campaigns/expert_v2_job_checkin_campaign.png"

    /** Post-job-end (checkout) campaign default. */
    const val CHECKOUT: String = HOST + "job_flow/campaigns/expert_v2_job_checkout_campaign.png"
}

/**
 * The shared **campaign illustration card** for the job-lifecycle celebrations (Figma 361×263, r-12):
 * loads [imageUrl] via [SnabbitRemoteImage] over a gray-200 backdrop (which shows through while it
 * loads / on error). Shared by the post-check-in celebration
 * ([com.snabbit.runner.shared.features.job.presentation.checkin.SuccessfulCheckIn]) and the
 * post-job-end nudge
 * ([com.snabbit.runner.shared.features.job.presentation.inprogress.PostJobEndCampaign]), which
 * differ only in the details this parameterises:
 *
 * - [showBorder] — the check-in card carries a 2dp [SnabbitTheme.colors.borderSubtle] stroke; the
 *   job-end card has none.
 * - [bannerText] / [bannerEmoji] — the check-in card pins a success status banner (emoji + copy) to
 *   the card's bottom edge; the job-end card has no banner (a null/blank [bannerText] renders none).
 *
 * @param imageUrl the campaign illustration to load — a `current_state` URL or an S3 default the
 *   callers pass as a fallback; null renders only the gray card.
 * @param showBorder draw the 2dp subtle-border stroke around the card.
 * @param bannerEmoji leading emoji on the status banner; omitted when null/blank.
 * @param bannerText status-banner copy; the whole banner is omitted when null/blank.
 */
@Composable
internal fun CampaignCard(
    modifier: Modifier = Modifier,
    imageUrl: String? = null,
    showBorder: Boolean = false,
    bannerEmoji: String? = null,
    bannerText: String? = null,
) {
    val shape = RoundedCornerShape(12.dp)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(361f / 263f)
            .clip(shape)
            .background(SnabbitColorsLight.gray200)
            .then(
                if (showBorder) {
                    Modifier.border(2.dp, SnabbitTheme.colors.borderSubtle, shape)
                } else {
                    Modifier
                },
            ),
    ) {
        // Campaign illustration from current_state (or the S3 default the caller passes as a fallback).
        // The gray-200 backdrop above shows through while it loads / if it fails.
        if (imageUrl != null) {
            SnabbitRemoteImage(
                model = imageUrl,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }

        if (!bannerText.isNullOrBlank()) {
            Row(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp))
                    .background(SnabbitTheme.colors.bgSuccessSubtle)
                    .height(40.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (!bannerEmoji.isNullOrBlank()) {
                    SnabbitText(text = bannerEmoji, variant = SnabbitTextVariant.Caption)
                    Box(Modifier.size(8.dp))
                }
                SnabbitText(
                    text = bannerText,
                    variant = SnabbitTextVariant.Caption,
                    fontWeight = FontWeight.Medium,
                    color = SnabbitTheme.colors.textSuccess,
                )
            }
        }
    }
}
