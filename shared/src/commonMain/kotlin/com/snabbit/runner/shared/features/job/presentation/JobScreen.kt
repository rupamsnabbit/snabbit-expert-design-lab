package com.snabbit.runner.shared.features.job.presentation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.PullToRefreshDefaults
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer.BlockCustomerSheet
import com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer.BlockCustomerStrings
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.CallDispositionSheet
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinEffect
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinEffectHandler
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinFooter
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinIntent
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinStrings
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinToast
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinViewModel
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.NoOpDelayedCheckinEffectHandler
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.PenaltyNudgeBanner
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.RedCardCounterChip
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.SupportSheetState
import com.snabbit.runner.shared.features.job.presentation.contact.ContactFeedback
import com.snabbit.runner.shared.features.job.presentation.contact.CustomerContactHandler
import com.snabbit.runner.shared.features.job.presentation.contact.rememberContactStrings
import com.snabbit.runner.shared.features.job.presentation.contact.NoOpCustomerContactHandler
import com.snabbit.runner.shared.features.job.presentation.contact.NoOpTtsController
import com.snabbit.runner.shared.features.job.presentation.contact.TtsController
import com.snabbit.runner.shared.features.job.presentation.common.AcceptFooter
import com.snabbit.runner.shared.features.job.presentation.common.rememberAcceptCountdown
import com.snabbit.runner.shared.features.job.presentation.checkin.CheckInContent
import com.snabbit.runner.shared.features.job.presentation.common.CheckInFooter
import com.snabbit.runner.shared.features.job.presentation.checkin.CheckInSheet
import com.snabbit.runner.shared.features.job.presentation.checkin.CheckInUiIntent
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.features.job.presentation.inprogress.CheckoutSheet
import com.snabbit.runner.shared.features.job.presentation.inprogress.CheckoutUiIntent
import com.snabbit.runner.shared.features.job.presentation.completed.CompletedContent
import com.snabbit.runner.shared.features.job.presentation.completed.housetasks.HouseTasksSheetContent
import com.snabbit.runner.shared.features.job.presentation.completed.housetasks.HouseTasksUiIntent
import com.snabbit.runner.shared.features.job.presentation.inprogress.InProgressContent
import com.snabbit.runner.shared.features.job.presentation.common.JobActionToast
import com.snabbit.runner.shared.features.job.presentation.common.CustomerBlockedToast
import com.snabbit.runner.shared.features.gamification.domain.model.PreActionNudge
import com.snabbit.runner.shared.features.job.presentation.newjob.JobDenyFlowSheet
import com.snabbit.runner.shared.features.job.presentation.newjob.NewJobContent
import com.snabbit.runner.shared.features.job.presentation.inprogress.rememberInProgressTimer
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen
import com.snabbit.runner.shared.core.designsystem.components.SnabbitHeaderNav
import com.snabbit.runner.shared.core.designsystem.components.helpPill
import com.snabbit.runner.shared.core.designsystem.components.sosPill
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet
import com.snabbit.runner.shared.features.job.presentation.completed.rating.rememberCustomerRatingStrings
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingUiIntent
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingUiState
import com.snabbit.runner.shared.features.job.presentation.inprogress.CompleteJobFooter
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.koin.compose.koinInject

/**
 * The top-level Job lifecycle screen — a single [SnabbitScreen] host whose body
 * and bottom bar swap with [JobUiState] (the KMP analogue of `partner_home.dart`,
 * scoped to the job flow). Phase 1 renders [JobUiState.NewJob]; the other stages
 * are typed placeholders for later phases.
 *
 * Host-agnostic and stateless over [JobViewModel.uiState] — child composables
 * receive intent-sending lambdas, never the ViewModel. [JobUiState.NotInJobFlow]
 * renders nothing so the host can fall back to the legacy Dart UI.
 */

/**
 * RC key (mirrored from Flutter `RemoteConfigKeys.jobEndCampaignMinRemainingMins`) holding the
 * minutes-remaining threshold above which completing a job opens the job-end campaign step; default "5"
 * (MUST match the Flutter-side default in `KmpRemoteConfigMirror`). ECPO-860 #6.
 */
private const val CAMPAIGN_MIN_REMAINING_RC_KEY = "expert_job_end_campaign_min_remaining_mins"
private const val CAMPAIGN_MIN_REMAINING_DEFAULT_MINS = "5"

/** Fixed pull-to-refresh spinner duration — `source.requestRefresh()` is fire-and-forget (no completion
 *  signal), so the indicator holds this long before resetting, mirroring the home screen's refresh. */
private const val REFRESH_SPINNER_MILLIS = 700L

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JobScreen(
    viewModel: JobViewModel,
    /** Job-lifecycle instrumentation for the composable-owned surfaces (accept footer + deny sheet). */
    analytics: JobAnalytics,
    strings: JobStrings = rememberJobStrings(),
    modifier: Modifier = Modifier,
    contact: CustomerContactHandler = NoOpCustomerContactHandler,
    delayedCheckin: DelayedCheckinEffectHandler = NoOpDelayedCheckinEffectHandler,
    // The penalty section's MVI unit (null = feature unhosted; the stage renders plain).
    delayedCheckinVm: DelayedCheckinViewModel? = null,
    delayedCheckinStrings: DelayedCheckinStrings = DelayedCheckinStrings(),
    // Read-aloud (TTS) for the check-in nav card's "Listen" pill; host-provided, no-op otherwise.
    tts: TtsController = NoOpTtsController,
    // Strings for the reused block sub-component on the Completed stage.
    blockStrings: BlockCustomerStrings = BlockCustomerStrings(),
    // Snabbit Kavach UI (host-provided; null when un-hosted / not present). Card → the details-card
    // slot; overlays → the card's condition/consent/permission sheets + mic-block (NOT the SOS alert —
    // that's the app-scoped AppSosHost). The SOS pill is the in-content SnabbitHeaderNav (TapSos).
    kavachCard: (@Composable () -> Unit)? = null,
    kavachOverlays: (@Composable () -> Unit)? = null,
    // Envelope pre-action nudges for the new-job accept stage (ECPO-831), threaded from the
    // host's GamificationProjector like the kavach slots — the screen stays DI-free.
    preActionNudges: List<PreActionNudge> = emptyList(),
    onNudgeExpired: () -> Unit = {},
    // Tiering job nudge (host-built from TieringViewModel) placed inline in the check-in,
    // check-in-success sheet, and in-progress stages. Null → not shown (ineligible / no nudge).
    jobTieringNudge: (@Composable () -> Unit)? = null,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    // Completed-stage rating labels resolved from composeResources (server-overridable). PR #452.
    val ratingStrings = rememberCustomerRatingStrings()

    // Contact-action feedback (e.g. "Call initiated") → a transient snackbar. The no-op handler
    // emits nothing, so an un-hosted screen simply shows none. Copy resolved from composeResources.
    val contactStrings = rememberContactStrings()
    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(contact, contactStrings) {
        contact.feedback.collect { feedback ->
            val message = when (feedback) {
                ContactFeedback.CallInitiated -> contactStrings.callInitiated
                ContactFeedback.CallNumberUnavailable -> contactStrings.callNumberUnavailable
            }
            snackbarHostState.showSnackbar(message)
        }
    }

    // Delayed check-in penalty feedback → the top green/red banner (DC-82's success toast;
    // DelayedCheckinToast). One-shot local state, cleared by the toast's auto-dismiss.
    var dcToast by remember { mutableStateOf<DelayedCheckinEffect.Toast?>(null) }
    LaunchedEffect(delayedCheckin) {
        delayedCheckin.toasts.collect { dcToast = it }
    }

    // Post-block "The customer is blocked" confirmation — the VM's `blockedToast` one-shot flipped into
    // screen-local state, cleared by the toast's auto-dismiss (see CustomerBlockedToast). Rendered as a
    // Compose toast (Figma red), consistent with dcToast / JobActionToast.
    var showBlockedToast by remember { mutableStateOf(false) }
    LaunchedEffect(viewModel) {
        viewModel.blockedToast.collect { showBlockedToast = true }
    }

    // The penalty section's render state + its effects → the handler (Dial / TTS run
    // there; Toast / OpenCheckIn come back on the handler's flows collected here).
    //
    // `DelayedCheckinUiState` TICKS once a second while a penalty countdown is live, so
    // reading it whole in this (screen-root) scope re-executed the entire JobScreen each
    // second. It is split instead — same hoisting as `acceptRemaining` / `inProgressTimer`
    // below: the non-ticking slices are `derivedStateOf` (this scope only re-runs when one
    // of them actually changes), and the countdown stays a `State` whose `.value` is read
    // in the footer leaf alone. Overrun was already collapsed onto one value in the
    // ViewModel (OVERRUN_SENTINEL); this covers the pre-deadline window.
    val dcStateHolder = delayedCheckinVm?.let { vm -> vm.uiState.collectAsStateWithLifecycle() }
    val dcPenalty by remember(dcStateHolder) { derivedStateOf { dcStateHolder?.value?.penalty } }
    val dcSupportSheet by remember(dcStateHolder) {
        derivedStateOf { dcStateHolder?.value?.supportSheet }
    }
    val dcSubmitting by remember(dcStateHolder) {
        derivedStateOf { dcStateHolder?.value?.submitting == true }
    }
    // Overrun is derived from the state's OWN `isOverrun` (not re-implemented here as a
    // sign test), so the footer's Help → "Call Partner Support" swap can never drift from
    // the contract. It flips at most once per penalty, so it costs no per-second work.
    val dcOverrun by remember(dcStateHolder) {
        derivedStateOf { dcStateHolder?.value?.isOverrun == true }
    }
    // Signed seconds to the penalty deadline. Held as a State (never read here) so the
    // per-second tick lands only in the footer that renders it.
    val dcRemaining = remember(dcStateHolder) {
        derivedStateOf { dcStateHolder?.value?.remainingSeconds ?: 0 }
    }
    LaunchedEffect(delayedCheckinVm) {
        delayedCheckinVm?.effects?.collect { delayedCheckin.handle(it) }
    }

    // The check-in sub-flow (its own MVI unit) — created per job while the await-check-in stage
    // renders, morphing OTP → phone → success in one sheet. Leaving the stage unmounts it, so the
    // sheet closes with the stage (no explicit safety-net dismiss needed).
    val checkInVm = (state as? JobUiState.AwaitingCheckIn)?.let { ci ->
        remember(ci.jobId) { viewModel.createCheckInViewModel() }
    }
    val checkInState = checkInVm?.let { vm ->
        val cs by vm.uiState.collectAsStateWithLifecycle()
        cs
    }

    // The deny/logout warning sheet is a stateless sheet — its open/closed state is screen-local
    // (it reads isLastHour/lossAmount off the live NewJob model). Reset when we leave the new-job
    // stage so a stale open-state from a prior job doesn't re-open the sheet on the next offer.
    var showDenySheet by remember { mutableStateOf(false) }
    val inNewJob = state is JobUiState.NewJob
    LaunchedEffect(inNewJob) { if (!inNewJob) showDenySheet = false }

    // The draw-over-apps overlay's Deny opens the app and asks (via the shared JobActionStore) for this
    // deny sheet to be shown here, rather than denying directly (ECPO-860 #3). Open it once the matching
    // New-Job offer is on screen; if the offer is instead gone or a DIFFERENT job is now showing (the
    // overlay-Deny→foreground race deallocated it), drop the request so it can't re-open the sheet for an
    // unrelated later offer — including a re-offer of the same job id. Only a still-settling Loading state
    // keeps it pending.
    val denyFlowRequestedForJob by viewModel.denyFlowRequestedForJob.collectAsStateWithLifecycle()
    LaunchedEffect(denyFlowRequestedForJob, state) {
        val requestedJobId = denyFlowRequestedForJob ?: return@LaunchedEffect
        val currentNewJobId = (state as? JobUiState.NewJob)?.model?.jobId
        when {
            currentNewJobId == requestedJobId -> {
                showDenySheet = true
                viewModel.onIntent(JobUiIntent.DenyFlowShown)
            }
            // Foreground state still settling (Loading) — keep the request pending until the offer lands.
            state is JobUiState.Loading -> Unit
            // Offer gone / a different job now on screen — drop the stale request.
            else -> viewModel.onIntent(JobUiIntent.DenyFlowShown)
        }
    }

    // Accept countdown: ticked once here (non-null only in the new-job stage) and shared by the
    // bottom-bar AcceptFooter and the deny/logout sheet, so their progress fills stay in lockstep
    // (ECPO issue #2 — the sheet no longer restarts its own timer). Held as a State and read (`.value`)
    // only in those leaves, so the per-second tick doesn't recompose the whole screen (like the
    // inProgressTimer below). Tick stops when we leave the stage.
    val acceptRemaining = (state as? JobUiState.NewJob)?.let { rememberAcceptCountdown(it) }

    // In-progress countdown: seeded from the envelope, ticked locally into the pill colour / time /
    // progress / callout and the Complete-Job enabled state. Non-null only while in the stage, so the
    // footer + content share one source of truth (and the tick stops when we leave the stage).
    val inProgressTimer = (state as? JobUiState.InProgress)?.let { rememberInProgressTimer(it, strings) }

    // ECPO-860 #6: the job-end campaign step shows only when the runner finishes EARLY — more than the
    // RC-controlled threshold (default 5 min) of job time remaining. Read the (mirror-backed) gateway
    // here so a live RC change is honoured; the threshold is compared against the live countdown at press.
    val remoteConfig = koinInject<RemoteConfigGateway>()

    // The checkout sub-flow (its own MVI unit) — created per job while the in-progress stage renders,
    // morphing campaign → OTP in one sheet. Leaving the stage unmounts it, so the sheet closes with the
    // stage (no explicit safety-net dismiss needed); a 2xx check_out closes it and refreshes to advance
    // to the Completed stage (whose forced house-tasks sheet follows — ECPO-528).
    val checkoutVm = (state as? JobUiState.InProgress)?.let { ip ->
        remember(ip.jobId) { viewModel.createCheckoutViewModel() }
    }
    val checkoutState = checkoutVm?.let { vm ->
        val cs by vm.uiState.collectAsStateWithLifecycle()
        cs
    }

    // Completed stage: the rate-customer VM (reused, host-provided deps) is created per job when the
    // stage renders; its selectedRating drives the block card + the "Ready for next job" enabled state.
    val completedRating = (state as? JobUiState.Completed)?.let { c ->
        remember(c.jobId) { viewModel.createRatingViewModel(c.jobId ?: -1) }
    }
    val completedRatingState = completedRating?.let { vm ->
        val rs by vm.uiState.collectAsStateWithLifecycle()
        rs
    }
    // The block-customer sheet (owned by the ViewModel) and the just-blocked flag (card → Unblock),
    // closed as a safety net when we leave the Completed stage. The "customer blocked" confirmation is
    // the Compose CustomerBlockedToast below (driven by the VM's blockedToast one-shot) — consistent with the
    // DelayedCheckin / JobAction toasts; the Completed stage stays mounted until "Ready for next job".
    val blockCustomer by viewModel.blockCustomer.collectAsStateWithLifecycle()
    val blockedForJobId by viewModel.blockedForJobId.collectAsStateWithLifecycle()
    val unblockInProgress by viewModel.unblockInProgress.collectAsStateWithLifecycle()
    // The post-checkout house-tasks show-once gate (ECPO-528): non-null (a jobId) drives the forced
    // tasks sheet on the Completed stage; null once submitted (or already-submitted from a prior run).
    val tasksSheetForJob by viewModel.tasksSheetForJob.collectAsStateWithLifecycle()
    val inCompleted = state is JobUiState.Completed
    LaunchedEffect(inCompleted) { if (!inCompleted) viewModel.onIntent(JobUiIntent.DismissBlockFlow) }

    // Sticky bottom CTA — accept/deny for a new job, "Check In" (opens the OTP sheet) at the
    // check-in stage, "Complete Job" while in progress; no footer for the other stages.
    val bottomBar: (@Composable () -> Unit)? = when (val s = state) {
        is JobUiState.NewJob -> {
            {
                val jobType = when {
                    s.model.isLongDistance -> "long_distance"
                    s.model.isLastHourJob -> "last_hour"
                    else -> "standard"
                }
                AcceptFooter(
                    state = s,
                    // The hoisted countdown State (read as `.value` inside the footer's own scope, so the
                    // per-second tick recomposes only the footer). Falls back to the envelope seed inside
                    // AcceptFooter when null.
                    remaining = acceptRemaining,
                    strings = strings,
                    onAccept = {
                        analytics.acceptanceScreenCtaClick(ctaText = "accept_job", jobType = jobType)
                        viewModel.onIntent(JobUiIntent.Accept)
                    },
                    // Deny opens the deny/logout warning sheet, which fires the deny from there.
                    onDeny = {
                        analytics.acceptanceScreenCtaClick(ctaText = "deny", jobType = jobType)
                        showDenySheet = true
                    },
                )
            }
        }
        is JobUiState.AwaitingCheckIn -> {
            {
                val penalty = dcPenalty
                if (penalty != null && delayedCheckinVm != null) {
                    // Penalty active: the always-urgent "RUNNING LATE" banner-footer with the
                    // signed timer; secondary escalates Help → "Call Partner Support" on overrun.
                    // Check In opens the screen-local sheet directly — same guarantee as the
                    // plain footer below, independent of how the effect handler is wired.
                    //
                    // The ticking countdown is read HERE, in the footer slot's own scope (like
                    // `inProgressTimer?.value` below), so the 1 Hz tick recomposes this footer
                    // and nothing else.
                    DelayedCheckinFooter(
                        remainingSeconds = dcRemaining.value,
                        totalSeconds = penalty.totalSeconds,
                        secondaryLabel = if (dcOverrun) {
                            delayedCheckinStrings.callPartnerSupport
                        } else {
                            delayedCheckinStrings.help
                        },
                        strings = delayedCheckinStrings,
                        onCheckIn = { checkInVm?.onIntent(CheckInUiIntent.Open) },
                        onSecondaryClick = { delayedCheckinVm.onIntent(DelayedCheckinIntent.SupportClicked) },
                    )
                } else {
                    CheckInFooter(
                        state = s,
                        strings = strings,
                        onCheckIn = { checkInVm?.onIntent(CheckInUiIntent.Open) },
                    )
                }
            }
        }
        is JobUiState.InProgress -> {
            {
                CompleteJobFooter(
                    label = strings.completeJob,
                    // Enabled once the job nears its end (yellow/red); disabled (pink-200) in green.
                    // Read `.value` here (not in the screen body) so the per-second tick recomposes only
                    // this footer, not the whole screen.
                    enabled = inProgressTimer?.value?.completeEnabled == true,
                    // Open the campaign step ONLY on an early finish — more than the RC threshold
                    // (`expert_job_end_campaign_min_remaining_mins`, default 5 min) of job time left at
                    // press; otherwise skip straight to the OTP step (ECPO-860 #6). Compared against the
                    // live ticked countdown, so a runner who lingers past the threshold gets OTP directly.
                    onComplete = {
                        val remainingSec = inProgressTimer?.value?.remainingSeconds ?: 0
                        val thresholdMins = remoteConfig
                            .getString(CAMPAIGN_MIN_REMAINING_RC_KEY, CAMPAIGN_MIN_REMAINING_DEFAULT_MINS)
                            .toIntOrNull() ?: CAMPAIGN_MIN_REMAINING_DEFAULT_MINS.toInt()
                        val showCampaign = remainingSec > thresholdMins.coerceAtLeast(0) * 60
                        checkoutVm?.onIntent(CheckoutUiIntent.Open(hasCampaign = showCampaign))
                    },
                )
            }
        }
        is JobUiState.Completed -> {
            {
                CompleteJobFooter(
                    label = strings.readyForNextJob,
                    // Enabled once the runner rates the customer (any smiley); disabled (pink-200) until then.
                    enabled = completedRatingState?.selectedRating != null,
                    // Submit the (deferred) rating, then refresh to advance — the rating VM owns the
                    // requestRefresh, so this replaces the old direct JobUiIntent.Refresh.
                    onComplete = { completedRating?.onIntent(CustomerRatingUiIntent.Submit) },
                    // Leading spinner while the rating POST + refresh are in flight.
                    loading = completedRatingState?.isSubmitting == true,
                )
            }
        }
        else -> null
    }

    SnabbitScreen(
        modifier = modifier,
        // SOS/help live in the in-content SnabbitHeaderNav below (sosPill → JobUiIntent.TapSos →
        // raiseManual; AppSosHost renders the alert). No SnabbitScreen top-nav actions (would duplicate).
        bottomBar = bottomBar,
        containerColor = SnabbitTheme.colors.bgSecondary,
        snackbarHostState = snackbarHostState,
    ) { contentPadding ->
        // The Help + SOS header (Figma 1:28063) floats OVER the stage body as a transparent overlay —
        // it paints no background, so each stage's own background (the in-progress gradient glow,
        // bgSecondary elsewhere) fills to the very top of the screen behind it, instead of the header
        // sitting in its own opaque band. The body is offset down by the header's measured height so
        // its chrome clears the pills.
        val density = LocalDensity.current
        val layoutDirection = LocalLayoutDirection.current
        var headerHeightPx by remember { mutableStateOf(0) }
        val bodyPadding = PaddingValues(
            start = contentPadding.calculateStartPadding(layoutDirection),
            // The header already consumes the status-bar inset, so REPLACE (not add to) the scaffold's
            // top inset with the header height — otherwise the status bar would be counted twice.
            top = with(density) { headerHeightPx.toDp() },
            end = contentPadding.calculateEndPadding(layoutDirection),
            bottom = contentPadding.calculateBottomPadding(),
        )
        Box(Modifier.fillMaxSize()) {
            // ── Stage body (fills the screen; its background reaches the top behind the header) ──
            // Pull-to-refresh re-fetches current_state (JobUiIntent.Refresh → source.requestRefresh()),
            // mirroring the home screen. requestRefresh is fire-and-forget (no completion signal), so the
            // spinner holds a fixed REFRESH_SPINNER_MILLIS; the envelope stream advances the stage when the
            // refreshed state lands. The indicator is offset below the floating Help/SOS header. Only the
            // scrollable stages (all four job stages) actually trigger the pull; Loading/NotInJobFlow don't.
            val refreshScope = rememberCoroutineScope()
            var isRefreshing by remember { mutableStateOf(false) }
            val pullState = rememberPullToRefreshState()
            PullToRefreshBox(
                isRefreshing = isRefreshing,
                onRefresh = {
                    isRefreshing = true
                    viewModel.onIntent(JobUiIntent.Refresh)
                    refreshScope.launch {
                        delay(REFRESH_SPINNER_MILLIS)
                        isRefreshing = false
                    }
                },
                modifier = Modifier.fillMaxSize(),
                state = pullState,
                // Default indicator anchors at the top of the box, which sits behind the transparent
                // floating header — push it down by the measured header height so the spinner is visible.
                indicator = {
                    PullToRefreshDefaults.Indicator(
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .padding(top = bodyPadding.calculateTopPadding()),
                        isRefreshing = isRefreshing,
                        state = pullState,
                    )
                },
            ) {
                when (val s = state) {
                    JobUiState.Loading -> CenteredLoader(bodyPadding)
                    // Host falls back to the legacy Dart job UI for non-job states.
                    JobUiState.NotInJobFlow -> Box(Modifier.fillMaxSize())
                    is JobUiState.NewJob -> {
                        NewJobContent(
                            s,
                            strings,
                            bodyPadding,
                            preActionNudges = preActionNudges,
                            onNudgeExpired = onNudgeExpired,
                        )
                        if (showDenySheet) {
                            // The deny / last-hour-logout confirmation sheet opened (fires once per open).
                            LaunchedEffect(Unit) {
                                if (s.model.isLastHourJob) {
                                    analytics.lastHourDenyConfirmationLoad(
                                        earningsMissed = s.model.lossAmount,
                                        jobEarnings = s.model.payout?.totalEarning,
                                    )
                                } else {
                                    analytics.denyConfirmationLoad(jobEarnings = s.model.payout?.totalEarning)
                                }
                            }
                            // Close on success so the accept/deny toast shows during the VM's success-hold;
                            // a failure keeps successMessage null, so the sheet stays up with its inline error.
                            LaunchedEffect(s.successMessage) { if (s.successMessage != null) showDenySheet = false }
                            // Guarded like inProgressTimer below: pass the hoisted countdown State straight to
                            // the sheet (non-null throughout the new-job stage), which reads `.value` in its body.
                            acceptRemaining?.let { remaining ->
                                JobDenyFlowSheet(
                                    // isLastHour/lossAmount come straight off the live NewJob model.
                                    isLastHour = s.model.isLastHourJob,
                                    lossAmount = s.model.lossAmount,
                                    strings = strings,
                                    // Shares the hoisted accept-countdown ticker with the footer so the Accept
                                    // fill stays in lockstep (no jump when the sheet opens — ECPO issue #2).
                                    remaining = remaining,
                                    acceptTotalSeconds = s.acceptTotalSeconds,
                                    // Gate + surface the in-flight accept/deny inside the sheet: it closes on
                                // success (above), so a failure keeps it up with the inline error. Passing
                                // the action (not a bare bool) spins the button that was pressed.
                                submittingAction = s.submittingAction,
                                errorMessage = s.errorMessage?.let { strings.resolve(it) },
                                    onAccept = {
                                        if (s.model.isLastHourJob) {
                                            analytics.lastHourDenyConfirmationCtaClick("accept_job")
                                        } else {
                                            analytics.denyConfirmationCtaClick("accept_job")
                                        }
                                        viewModel.onIntent(JobUiIntent.Accept)
                                    },
                                    // Deny and last-hour "Logout" both fire deny_job; a last-hour deny then
                                    // routes to the attendance widget, rendered by the legacy Flutter surface
                                    // once this Activity finishes.
                                    onDeny = {
                                        if (s.model.isLastHourJob) {
                                            analytics.lastHourDenyConfirmationCtaClick("logout")
                                        } else {
                                            analytics.denyConfirmationCtaClick("deny")
                                        }
                                        viewModel.onIntent(JobUiIntent.Deny)
                                    },
                                    onDismiss = { showDenySheet = false },
                                )
                            }
                        }
                    }
                    is JobUiState.AwaitingCheckIn -> {
                    CheckInContent(
                        s,
                        strings,
                        bodyPadding,
                        contact = contact,
                        tts = tts,
                        analytics = analytics,
                        // B10: penalty active (delayed check-in) flips ADDRESS above PRICING.
                        penaltyActive = dcPenalty != null,
                        // Penalty section under the header whenever a penalty countdown is
                        // active: the "N Red Card(s) Received" pill (rendered even at 0 —
                        // Dart parity, the most common first-penalty state) plus the
                        // "X red card will be added" deduction banner when the widget's
                        // pre_action_nudges carries one.
                        topContent = dcPenalty?.let { penalty ->
                            {
                                RedCardCounterChip(
                                    receivedRedCards = penalty.receivedRedCards,
                                    strings = delayedCheckinStrings,
                                )
                                penalty.nudge?.let { nudge ->
                                    PenaltyNudgeBanner(nudge = nudge)
                                }
                            }
                        },
                        jobTieringNudge = jobTieringNudge,
                    )
                    // The "Call Support Partner" disposition sheet (FR-11/12/13).
                    (dcSupportSheet as? SupportSheetState.Shown)?.let { sheet ->
                        CallDispositionSheet(
                            options = sheet.options,
                            isSubmitting = dcSubmitting,
                            strings = delayedCheckinStrings,
                            onSubmit = { option ->
                                delayedCheckinVm?.onIntent(DelayedCheckinIntent.SubmitDisposition(option))
                            },
                            onDismiss = { delayedCheckinVm?.onIntent(DelayedCheckinIntent.DismissSheet) },
                        )
                    }
                        checkInState?.let { flow ->
                            CheckInSheet(
                                flow = flow,
                                allowNoOtp = s.allowNoOtp,
                                jobId = s.jobId,
                                strings = strings,
                                onStartJob = { otp -> checkInVm?.onIntent(CheckInUiIntent.StartJob(otp)) },
                                onCheckInWithPhone = { phone -> checkInVm?.onIntent(CheckInUiIntent.CheckInWithPhone(phone)) },
                                onSwitchToPhone = { checkInVm?.onIntent(CheckInUiIntent.SwitchToPhone) },
                                onSwitchToOtp = { checkInVm?.onIntent(CheckInUiIntent.SwitchToOtp) },
                                onSuccessComplete = { checkInVm?.onIntent(CheckInUiIntent.SuccessAcknowledged) },
                                onDismiss = { checkInVm?.onIntent(CheckInUiIntent.Dismiss) },
                                jobTieringNudge = jobTieringNudge,
                            )
                        }
                    }
                    is JobUiState.InProgress -> inProgressTimer?.let { timer ->
                    InProgressContent(s, timer, strings, bodyPadding, contact = contact, analytics = analytics, kavachCard = kavachCard, jobTieringNudge = jobTieringNudge)
                        checkoutState?.let { flow ->
                            CheckoutSheet(
                                flow = flow,
                                jobId = s.jobId,
                                strings = strings,
                                campaignImageUrl = s.campaignImageUrl,
                                onCampaignComplete = { checkoutVm?.onIntent(CheckoutUiIntent.CampaignComplete) },
                                onEndJob = { otp -> checkoutVm?.onIntent(CheckoutUiIntent.EndJob(otp)) },
                                onDismiss = { checkoutVm?.onIntent(CheckoutUiIntent.Dismiss) },
                            )
                        }
                    }
                    is JobUiState.Completed -> completedRating?.let { ratingVm ->
                        CompletedContent(
                            state = s,
                            ratingState = completedRatingState ?: CustomerRatingUiState(),
                            ratingStrings = ratingStrings,
                            strings = strings,
                            isBlocked = blockedForJobId == s.jobId,
                            isUnblocking = unblockInProgress,
                            contentPadding = bodyPadding,
                            onSelectRating = { rating ->
                                ratingVm.onIntent(CustomerRatingUiIntent.SelectRating(rating))
                            },
                            onBlock = { viewModel.onIntent(JobUiIntent.OpenBlockFlow) },
                            onUnblock = { viewModel.onIntent(JobUiIntent.UnblockCustomer) },
                        )
                        blockCustomer?.let { blockVm ->
                            BlockCustomerSheet(
                                viewModel = blockVm,
                                customerName = s.customerName?.takeIf { it.isNotBlank() } ?: strings.customerFallback,
                                customerAddress = s.customerAddress.orEmpty(),
                                strings = blockStrings,
                                onDismiss = { viewModel.onIntent(JobUiIntent.DismissBlockFlow) },
                            )
                        }
                        // Post-checkout house-tasks: a forced (non-dismissible) sheet over the rating, shown
                        // once per job until submitted (ECPO-528). Reuses the checkout forced chrome — no
                        // scrim / back / close. Keyed on the jobId so a new job gets a fresh VM; on submit
                        // success the VM closes the gate (tasksSheetForJob → null) and refreshes to reveal
                        // the rating underneath.
                        tasksSheetForJob?.let { tasksJobId ->
                            val houseTasksVm = remember(tasksJobId) { viewModel.createHouseTasksViewModel(tasksJobId) }
                            val houseTasksState by houseTasksVm.uiState.collectAsStateWithLifecycle()
                            // Forced + non-dismissible normally; but if the task_collection fetch errors the
                            // sheet becomes dismissible (swipe / back / close) so the runner isn't trapped —
                            // dismissing closes the show-once gate in memory (JobUiIntent.DismissHouseTasks).
                            val tasksDismissibleOnError = houseTasksState.isFetchError
                            SnabbitBottomSheet(
                                onDismissRequest = {
                                    if (tasksDismissibleOnError) {
                                        viewModel.onIntent(JobUiIntent.DismissHouseTasks(tasksJobId))
                                    }
                                },
                                draggable = tasksDismissibleOnError,
                                dismissible = tasksDismissibleOnError,
                                showCloseButton = tasksDismissibleOnError,
                            ) {
                                HouseTasksSheetContent(
                                    state = houseTasksState,
                                    strings = strings,
                                    onToggle = { houseTasksVm.onIntent(HouseTasksUiIntent.Toggle(it)) },
                                    onRetry = { houseTasksVm.onIntent(HouseTasksUiIntent.Retry) },
                                    onSubmit = { houseTasksVm.onIntent(HouseTasksUiIntent.Submit) },
                                )
                            }
                        }
                    }
                }
            // Delayed check-in feedback banner (green "call back soon" / red errors), the
            // DC-82 success-toast surface — top-aligned like JobActionToast, auto-dismissing.
            dcToast?.let { toast ->
                Box(Modifier.fillMaxSize().padding(contentPadding)) {
                    DelayedCheckinToast(toast = toast, onShown = { dcToast = null })
                }
            }
                // Accept/deny feedback toast (red error / green success), inset into the
                // safe area; tapping through the one-shot clears it so it won't re-show.
                (state as? JobUiState.NewJob)?.let { newJob ->
                    Box(Modifier.fillMaxSize().padding(bodyPadding)) {
                        JobActionToast(
                            state = newJob,
                        strings = strings,
                            onErrorShown = { viewModel.onIntent(JobUiIntent.ErrorShown) },
                            onSuccessShown = { viewModel.onIntent(JobUiIntent.SuccessShown) },
                        )
                    }
                }
            // Kavach overlays (consent/condition sheets, SOS alert, permission dialog, mic-block) —
            // host-provided; rendered over the in-progress stage only (spec 2).
            if (state is JobUiState.InProgress) kavachOverlays?.invoke()
            }

            // ── Transparent floating top nav (Help + SOS) ──
            // No background, aligned to the top of the screen, over the same status-bar inset + gutters
            // as Home's PinnedTopNav. Its measured height feeds [headerHeightPx] to offset the body above.
            Box(
                Modifier
                    .align(Alignment.TopStart)
                    .fillMaxWidth()
                    .onSizeChanged { headerHeightPx = it.height }
                    .windowInsetsPadding(WindowInsets.statusBars)
                    .padding(
                        top = SnabbitTheme.spacing.`6`,
                        start = SnabbitTheme.spacing.`6`,
                        end = SnabbitTheme.spacing.`6`,
                        bottom = SnabbitTheme.spacing.`4`,
                    ),
            ) {
                // SOS pill hidden when the backend says so (sos_visibility.visible) — Flutter parity.
                val sosVisible by viewModel.sosVisible.collectAsState()
                SnabbitHeaderNav(
                    trailing = buildList {
                        add(helpPill(strings.topNavHelpLabel) { viewModel.onIntent(JobUiIntent.TapHelp) })
                        if (sosVisible) add(sosPill(strings.topNavSosLabel) { viewModel.onIntent(JobUiIntent.TapSos) })
                    },
                )
            }

            // ── Post-block "The customer is blocked" confirmation (red #DC2626 — Figma) ──
            // Declared AFTER the floating Help/SOS nav (last sibling → wins z-order, never occluded), but
            // offset DOWN by [bodyPadding] (the measured nav height) so it lands JUST BELOW the Help/SOS
            // pills — fully visible, and not over them (which would hide the SOS button). Same inset as
            // the sibling JobActionToast; driven by the VM's blockedToast one-shot, cleared on auto-dismiss.
            if (showBlockedToast) {
                Box(Modifier.fillMaxSize().padding(bodyPadding)) {
                    CustomerBlockedToast(
                        message = strings.customerBlockedToast,
                        onShown = { showBlockedToast = false },
                    )
                }
            }
        }
        }
    }


@Composable
private fun CenteredLoader(contentPadding: PaddingValues) {
    Box(
        modifier = Modifier.fillMaxSize().padding(contentPadding),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(color = SnabbitTheme.colors.iconBrand)
    }
}
