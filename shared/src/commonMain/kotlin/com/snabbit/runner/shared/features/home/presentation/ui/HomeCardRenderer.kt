package com.snabbit.runner.shared.features.home.presentation.ui

import androidx.compose.runtime.Composable
import com.snabbit.runner.shared.features.gamification.domain.model.PreActionNudge
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent
import com.snabbit.runner.shared.features.home.presentation.ui.cards.HotspotNavigationCard
import com.snabbit.runner.shared.features.home.presentation.ui.cards.LunchActiveCard
import com.snabbit.runner.shared.features.home.presentation.ui.cards.SeeYouTomorrowCard
import com.snabbit.runner.shared.features.home.presentation.ui.cards.SuspendedCard
import com.snabbit.runner.shared.features.home.presentation.ui.cards.TodayStatusCard
import com.snabbit.runner.shared.features.home.presentation.ui.cards.TomorrowProvisionalCard

@Composable
fun HomeCardRenderer(
    card: HomeCard,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    inFlight: HomeUiIntent? = null,
    /** EARLY_LOGIN nudge for the TodayStatus Present card (host-threaded). */
    loginNudge: PreActionNudge? = null,
    /** True once the suspended "Come Back to Work" request has resolved —
     *  locks that CTA to "Request submitted". Only consumed by the Suspended
     *  card; harmless elsewhere. */
    suspendRequestSubmitted: Boolean = false,
) {
    when (card) {
        is HomeCard.Attendance.TomorrowProvisional -> TomorrowProvisionalCard(
            card = card,
            strings = strings,
            onIntent = onIntent,
            presentLoading = inFlight == HomeUiIntent.ConfirmMarkProvisional(present = true),
        )
        is HomeCard.Attendance.TodayStatus -> TodayStatusCard(card, strings, onIntent, loginNudge = loginNudge)
        is HomeCard.ShiftLogin -> HotspotNavigationCard(card, strings, onIntent)
        is HomeCard.Lunch -> LunchActiveCard(
            card = card,
            strings = strings,
            onIntent = onIntent,
            endLoading = inFlight == HomeUiIntent.RequestEndBreak,
        )
        is HomeCard.Suspended -> SuspendedCard(
            card = card,
            strings = strings,
            onIntent = onIntent,
            submitted = suspendRequestSubmitted,
            comeBackLoading = inFlight == HomeUiIntent.RequestComeBack,
        )
        HomeCard.SeeYouTomorrow -> SeeYouTomorrowCard(strings = strings, onIntent = onIntent)
    }
}
