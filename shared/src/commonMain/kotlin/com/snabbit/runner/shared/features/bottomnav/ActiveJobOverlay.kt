package com.snabbit.runner.shared.features.bottomnav

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.lifecycle.viewmodel.compose.viewModel
import com.snabbit.runner.shared.core.alarm.AlarmController
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.features.kavach.shared.domain.JobKavachCoordinator
import com.snabbit.runner.shared.features.kavach.shared.ui.components.KavachMicBlockSheet
import com.snabbit.runner.shared.features.kavach.shared.ui.components.KavachOverlaySheets
import com.snabbit.runner.shared.features.kavach.shared.ui.components.SafetyHomeCard
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetyHomeIntent
import com.snabbit.runner.shared.features.kavach.shared.ui.viewmodel.SafetyHomeViewModel
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.backhandler.BackHandler
import com.snabbit.runner.shared.core.connectivity.LocalConnectivityStatus
import com.snabbit.runner.shared.core.connectivity.NetworkMonitor
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.features.support.data.HelplineRepository
import com.snabbit.runner.shared.features.support.ui.NeedHelpSheet
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository
import com.snabbit.runner.shared.features.gamification.data.GamificationProjector
import com.snabbit.runner.shared.features.tiering.presentation.JobTieringNudge
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TieringNudgeContent
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TieringUiIntent
import com.snabbit.runner.shared.features.tiering.presentation.viewmodel.TieringViewModel
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.domain.audio.JobCueAudioPlayer
import com.snabbit.runner.shared.features.job.data.JobActionStore
import com.snabbit.runner.shared.features.job.data.JobActionScope
import com.snabbit.runner.shared.features.job.data.JobServiceIdHolder
import com.snabbit.runner.shared.features.job.data.LocationProvider
import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.features.job.data.contact.CallingDataSource
import com.snabbit.runner.shared.features.job.data.contact.CustomerContactLauncher
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DefaultDelayedCheckinEffectHandler
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinStrings
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinViewModel
import com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer.BlockCustomerStrings
import com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer.localized
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.localized
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import com.snabbit.runner.shared.features.job.domain.JobClock
import com.snabbit.runner.shared.features.job.presentation.JobScreen
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.JobUiIntent
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.JobViewModel
import com.snabbit.runner.shared.features.job.presentation.rememberJobStrings
import com.snabbit.runner.shared.features.job.presentation.contact.ContactStrings
import com.snabbit.runner.shared.features.job.presentation.contact.DefaultCustomerContactHandler
import com.snabbit.runner.shared.features.job.presentation.contact.rememberJobTtsController
import com.snabbit.runner.shared.storage.PreferenceStorage
import org.koin.compose.viewmodel.koinViewModel
import org.koin.mp.KoinPlatform.getKoin

/**
 * Active-job layer for the bottom-nav shell ([TabNavigator]'s `overlay`): renders
 * [JobScreen] full-screen above the tabs whenever the runner is in a KMP-hosted job stage,
 * driven purely by [RunnerStateSource]. Replaces the old standalone `JobActivity` host — the
 * state stream is identical, so the screen still morphs New Job → Check-In → In-Progress →
 * Completed as `current_state` advances; it just lives over the tabs instead of in its own
 * Activity, and hides itself the moment state leaves the job flow (`NotInJobFlow`).
 *
 * While a job is active, back is **disabled** — the runner can't dismiss an in-flight job.
 * The [JobViewModel] is built once and stays subscribed for the shell's lifetime (even while
 * hidden) so it knows when to appear; `Loading` (cold mount, nothing pushed yet) shows
 * nothing.
 *
 * ponytail: uses default [JobStrings] (English) — parity with the old JobActivity host, which
 * the launcher started with a bare Intent (no extras), so its `JobScreenExtras.stringsFrom`
 * also resolved to defaults. Localizing job strings (via a Koin-held source) is a separate,
 * pre-existing gap, not a regression from this move.
 */
@OptIn(ExperimentalComposeUiApi::class) // BackHandler (compose ui-backhandler) is still experimental
@Composable
internal fun ActiveJobOverlay() {
    val koin = getKoin()
    val scope = rememberCoroutineScope()
    val strings = rememberJobStrings()
    // Job-lifecycle instrumentation (Koin single) — one instance shared by the VM and the screen.
    val jobAnalytics = remember { koin.get<JobAnalytics>() }

    // Built once and kept subscribed for the shell's lifetime (mirrors JobActivity's wiring),
    // so it observes RunnerStateSource continuously and can drive its own visibility.
    val jobViewModel = remember {
        JobViewModel(
            source = koin.get<RunnerStateSource>(),
            actions = koin.get<JobActionRepository>(),
            location = koin.get<LocationProvider>(),
            clock = koin.get<JobClock>(),
            blockListDataSource = koin.get<BlockListRepository>(),
            preferenceStorage = koin.get<PreferenceStorage>(),
            // Process-lived Koin single, SHARED with the draw-over overlay's VM: carries the in-flight
            // accept/deny state and the overlay→app "open the deny sheet" request across the two New-Job
            // surfaces (ECPO-860 #3). Without the shared single each VM had its own store and the signal
            // never crossed.
            actionStore = koin.get<JobActionStore>(),
            // Process-lived Koin single — NOT `rememberCoroutineScope()`, which is what this used to
            // pass. Compose cancels a composition scope when the overlay leaves composition (Activity
            // destroy, KMP↔Flutter handoff, "Don't keep activities"), which cancelled the accept POST
            // mid-flight and left the shared JobActionStore stuck `submitting` forever — a spinning,
            // un-tappable Accept, no completion event, no error, and every later accept dropped.
            // Reproduced in JobViewModelTest.accept_whenHostScopeIsCancelled*.
            appScope = koin.get<JobActionScope>().scope,
            analytics = jobAnalytics,
            // Best-effort reporter so a swallowed blocked-customer profile-push failure isn't invisible.
            crashReporter = koin.get<CrashReporter>(),
            // Read once at construction (service_id is fixed per runner, pushed from Dart at
            // profile load) → picks the New-Job header Cook vs Expert glyph; null falls back to
            // the envelope category. Matches the old JobActivity's read-once-from-Intent behaviour.
            serviceId = koin.get<JobServiceIdHolder>().serviceId.value,
            // SOS pill (top nav) → raiseManual (job-independent); AppSosHost renders the alert + nav.
            sosCoordinator = koin.get(),
            sosVisibility = koin.get(),
            // Mirror-backed RC gateway → the Completed-stage block sub-VM's "n/max" cap.
            remoteConfig = koin.get<RemoteConfigGateway>(),
            blockStrings = BlockCustomerStrings().localized(koin.get()),
            // Tapping Check In acknowledges the delayed-check-in alert → stop the
            // host-owned alarm instead of letting it run out its repeat count.
            silenceAlarm = koin.get<AlarmController>()::silence,
            // In-progress voice cues (half-time / T-10): played natively (KMP-owned), localized off
            // the mirrored LocalizationStore. Auto-checkout stays host-owned (Dart push path).
            jobCuePlayer = koin.get<JobCueAudioPlayer>(),
            localization = koin.get<LocalizationStore>(),
        )
    }
    val contact = remember {
        DefaultCustomerContactHandler(
            calling = koin.get<CallingDataSource>(),
            launcher = koin.get<CustomerContactLauncher>(),
            scope = scope,
        )
    }
    val networkMonitor = remember { koin.get<NetworkMonitor>() }

    // Delayed check-in penalty: a shell-lived VM observing RunnerStateStore's
    // `delayed_checkin_penalty` slice. When a penalty is pushed, the AwaitingCheckIn stage
    // swaps to the "RUNNING LATE" footer + Call-Support disposition sheet; otherwise it stays
    // inert (state is null → plain check-in footer). Built before the early return and kept
    // subscribed for the shell's lifetime — same pattern as [viewModel]/[safetyVm], so its
    // store collector isn't orphaned on the injected [scope]. (Old-pattern injected scope.)
    val delayedCheckinVm = remember {
        DelayedCheckinViewModel(
            store = koin.get(),
            appConfig = koin.get(),
            session = koin.get(),
            repository = koin.get(),
            analytics = koin.get(),
            scope = scope,
            strings = DelayedCheckinStrings().localized(koin.get()),
        )
    }
    // Dial → shared launcher (parity with [contact]); Toast → re-emitted for JobScreen's banner.
    val delayedCheckinHandler = remember {
        DefaultDelayedCheckinEffectHandler(launcher = koin.get<CustomerContactLauncher>())
    }

    // Kavach: a shell-lived SafetyHomeViewModel drives the card (recording/monitoring state + the
    // Activate → consent/permission flow) + its overlays; the JobKavachCoordinator drives the
    // mandatory-mic block. SOS itself is app-scoped (AppSosHost + the SOS pill's TapSos), not here.
    val safetyVm = viewModel {
        SafetyHomeViewModel(
            nav = koin.get(), dataSource = koin.get(), sosCoordinator = koin.get(),
            permissionGate = koin.get(), lifecycle = koin.get(), analytics = koin.get(),
        )
    }
    val kavachCoordinator = remember { koin.get<JobKavachCoordinator>() }
    val safety by safetyVm.uiState.collectAsState()
    val micBlocked by kavachCoordinator.micBlock.collectAsState()

    // Envelope pre-action nudges → the new-job accept screen's NudgeBannerList (ECPO-831),
    // Dart parity: new_job_assigned.dart renders runnerRtDataProvider.preActionNudges.
    // Expiry re-fetches state, the KMP analogue of Dart's fetchDataNow().
    val gamification = remember { koin.get<GamificationProjector>() }
    val gamState by gamification.state.collectAsState()

    val uiState by jobViewModel.uiState.collectAsState()
    val active = uiState !is JobUiState.NotInJobFlow && uiState !is JobUiState.Loading
    if (!active) return

    // Job in flight → owning back would let the runner escape it. Consume and ignore — but record the
    // tap (job_back_pressed) so we can see how often runners try to back out of an active job.
    BackHandler(enabled = true) { jobViewModel.onIntent(JobUiIntent.BackPressed) }

    // Help pill → the "Need help?" sheet (Flutter SupportPopup parity). The VM emits on
    // [JobViewModel.openHelp]; the sheet resolves the helpline number and hands it back to
    // the shared [contact] (masked-call → dialer fallback = CallUtils parity).
    var showHelp by remember { mutableStateOf(false) }
    LaunchedEffect(jobViewModel) { jobViewModel.openHelp.collect { showHelp = true } }

    // Read-aloud engine for the check-in card's "Listen" pill — the host TTS bridge the old
    // JobActivity used to own. [rememberJobTtsController] is a platform seam (expect/actual): the
    // Android actual builds `AndroidTtsController` on the host Context and releases the native
    // engine via onDispose when this leaves composition (state exits the job flow); iOS returns
    // NoOp. Passed into JobScreen → CheckInContent, which stops it when leaving the stage.
    val tts = rememberJobTtsController()

    // Feed real connectivity into the tree so JobScreen's baked-in "No/Bad internet" banner
    // reflects device state (as JobActivity did).
    val connectivity by networkMonitor.status.collectAsState()

    // Tiering job nudge (EARLY_CHECK_IN in check-in / PERFECT_JOB once started) — the same
    // gated nudge the home ApplicableTieringNudge would show; the full-screen job UI hosts it
    // inline instead. `homeNudge` is already routed to the Job variant + gated by shouldShowTiering.
    val tieringVm: TieringViewModel = koinViewModel()
    val tierState by tieringVm.uiState.collectAsState()
    val jobNudge = tierState.homeNudge as? TieringNudgeContent.Job
    // Impression fired ONCE per nudge identity at the host: the success sheet overlays the
    // check-in content, so the nudge can be composed in two placements at once — dedup here.
    LaunchedEffect(jobNudge?.titleKey) {
        if (jobNudge != null) tieringVm.onIntent(TieringUiIntent.NudgeShown)
    }
    // Static (routeless) — no tap navigation, mirroring the Flutter job nudge.
    val jobTieringNudge: (@Composable () -> Unit)? = jobNudge?.let { nudge ->
        { JobTieringNudge(title = nudge.title, coinsCount = nudge.coinsCount, onClick = {}) }
    }

    CompositionLocalProvider(LocalConnectivityStatus provides connectivity) {
        JobScreen(
            viewModel = jobViewModel,
            analytics = jobAnalytics,
            strings = strings,
            contact = contact,
            tts = tts,
            delayedCheckin = delayedCheckinHandler,
            delayedCheckinVm = delayedCheckinVm,
            delayedCheckinStrings = DelayedCheckinStrings().localized(koin.get()),
            blockStrings = BlockCustomerStrings().localized(koin.get()),
            // Card in the details-card slot, shown once Kavach is monitoring for this job (the
            // coordinator arms monitoring-only for a present+granted job, so `monitoring` reactively
            // ⟺ "present & active" — no stale one-shot present read on this shell-lived VM). Spec 2.
            kavachCard = if (safety.monitoring) {
                {
                    SafetyHomeCard(
                        recording = safety.recording,
                        noStorage = safety.noStorage,
                        onActivate = { safetyVm.onIntent(SafetyHomeIntent.Activate) },
                        onStorageClick = { safetyVm.onIntent(SafetyHomeIntent.RetryStorage) },
                        activationLottiePlaying = safety.activationLottiePlaying,
                    )
                }
            } else {
                null
            },
            kavachOverlays = {
                // Card overlays only (consent/condition/permission) + mic-block. The SOS alert is the
                // app-scoped AppSosHost, so showSosAlert=false here (no duplicate alert).
                KavachOverlaySheets(uiState = safety, onIntent = safetyVm::onIntent, showSosAlert = false)
                KavachMicBlockSheet(visible = micBlocked, onOpenSettings = { kavachCoordinator.openAppSettings() })
            },
            preActionNudges = gamState.nudges,
            onNudgeExpired = gamification::requestRefresh,
            jobTieringNudge = jobTieringNudge,
        )
        // Help pill → "Need help?" sheet (Flutter SupportPopup parity); "Call us" routes the
        // resolved helpline number through the shared contact (masked-call → dialer fallback).
        if (showHelp) {
            NeedHelpSheet(
                helplineRepo = koin.get<HelplineRepository>(),
                onCall = { number ->
                    koin.get<AnalyticsTracker>().track("contact_us_button_clicked")
                    contact.call(number)
                },
                onDismiss = { showHelp = false },
            )
        }
    }
}
