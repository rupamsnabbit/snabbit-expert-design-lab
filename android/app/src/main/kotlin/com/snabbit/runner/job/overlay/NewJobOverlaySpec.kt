package com.snabbit.runner.job.overlay

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import com.snabbit.runner.job.JobScreenExtras
import com.snabbit.runner.overlayhost.OverlayHostSession
import com.snabbit.runner.overlayhost.OverlaySpec
import com.snabbit.runner.overlayhost.OverlayWindowStyle
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.data.JobActionStore
import com.snabbit.runner.shared.features.job.data.LocationProvider
import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import com.snabbit.runner.shared.features.job.domain.JobClock
import com.snabbit.runner.shared.features.job.presentation.JobUiIntent
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.JobViewModel
import com.snabbit.runner.shared.features.job.presentation.rememberJobStrings
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import com.snabbit.runner.shared.features.job.presentation.newjob.NewJobOverlaySurface
import com.snabbit.runner.shared.storage.PreferenceStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.koin.mp.KoinPlatform.getKoin

/**
 * The `RUNNER_NEW_JOB` card as a [ComposeOverlayHost] plug-in — the former
 * `NewJobOverlayService` refactored onto the generic host, behaviour
 * identical: same KMP [JobViewModel] (off the bridged store via
 * [RunnerStateSource], accept/deny KMP-direct), same dimmed-modal window
 * (now [OverlayWindowStyle.DimModal] plumbing in the host), same feed-driven
 * teardown the moment the job leaves `NewJob`/`Loading`, same process-lived
 * [actionScope] so an accept survives the window closing.
 *
 * Launched by [com.snabbit.runner.kmp_bridge.JobScreenLauncherPlugin]
 * (`ComposeOverlayHost.start(context, KEY)`) — [shouldTrigger] stays false:
 * the job plugin owns its own launch gating, so the generic launcher never
 * double-triggers it. AWOL-vs-job precedence is the host's per-spec
 * [priority] (penalty beats opportunity), replacing the deleted
 * `OverlayService.instance` cross-feature check.
 */
class NewJobOverlaySpec : OverlaySpec {

    override val key: String = KEY
    override val window: OverlayWindowStyle = OverlayWindowStyle.DimModal
    override val priority: Int = PRIORITY

    private var viewModel: JobViewModel? = null

    override fun visible(session: OverlayHostSession): Flow<Boolean> {
        val vm = createViewModel(session)
        // `Loading` is the cold-mount tick; anything past NewJob (accepted /
        // denied / expired) tears the window down — mirrors JobActivity's
        // finish() handoff, Flutter resumes the downstream lifecycle.
        return vm.uiState.map { state ->
            state is JobUiState.NewJob || state == JobUiState.Loading
        }
    }

    @Composable
    override fun Content(session: OverlayHostSession) {
        val vm = viewModel ?: return
        val analytics = remember { getKoin().get<JobAnalytics>() }
        val strings = JobScreenExtras.applyOverrides(rememberJobStrings(), session.startIntent)
        val state by vm.uiState.collectAsState()
        (state as? JobUiState.NewJob)?.let { newJob ->
            val jobType = when {
                newJob.model.isLongDistance -> "long_distance"
                newJob.model.isLastHourJob -> "last_hour"
                else -> "standard"
            }
            NewJobOverlaySurface(
                state = newJob,
                strings = strings,
                onAccept = {
                    analytics.acceptanceScreenCtaClick(ctaText = "accept_job", jobType = jobType)
                    // Fire the accept (on the process-lived actionScope so it isn't cancelled when this
                    // window later closes) and bring the app up UNDERNEATH, so the runner lands on the
                    // check-in screen the instant the overlay drops. Deliberately NO synchronous
                    // dismissAndStop() here: tearing the window down in the same frame killed it before
                    // the Accept button's in-flight spinner could render. Keeping it up lets the spinner
                    // show; the overlay then auto-dismisses via the host's feed-driven teardown the moment
                    // the accepted job advances off NewJob (visible → false) — spinner → success → check-in.
                    vm.onIntent(JobUiIntent.Accept)
                    session.bringAppToForeground()
                },
                onDeny = {
                    analytics.acceptanceScreenCtaClick(ctaText = "deny", jobType = jobType)
                    // Unlike Accept, Deny does NOT hit the API from the overlay. Open the app with the
                    // deny/logout warning sheet (a shared request the in-app JobScreen consumes) so the
                    // runner confirms there; the deny_job call fires from that sheet (ECPO-860 #3).
                    vm.onIntent(JobUiIntent.RequestDenyFlow)
                    session.bringAppToForeground()
                    session.dismissAndStop()
                },
                onErrorShown = { vm.onIntent(JobUiIntent.ErrorShown) },
                onSuccessShown = { vm.onIntent(JobUiIntent.SuccessShown) },
            )
        }
    }

    private fun createViewModel(session: OverlayHostSession): JobViewModel {
        val vm = JobViewModel(
            source = getKoin().get<RunnerStateSource>(),
            actions = getKoin().get<JobActionRepository>(),
            location = getKoin().get<LocationProvider>(),
            clock = getKoin().get<JobClock>(),
            blockListDataSource = getKoin().get<BlockListRepository>(),
            preferenceStorage = getKoin().get<PreferenceStorage>(),
            // Process-lived Koin single, SHARED with the in-app JobScreen's VM (ActiveJobOverlay), so this
            // overlay's Deny can hand the "open the deny sheet" request to the app it foregrounds — and the
            // in-flight accept/deny state carries across the two surfaces (ECPO-860 #3). MUST be the single,
            // not the per-VM default, or the signal never crosses.
            actionStore = getKoin().get<JobActionStore>(),
            // Process-lived scope (survival POSTs, ECPO-760); the VM's UI stream runs on viewModelScope.
            appScope = actionScope,
            analytics = getKoin().get<JobAnalytics>(),
            crashReporter = getKoin().get<CrashReporter>(),
            serviceId = JobScreenExtras.serviceIdFrom(session.startIntent),
            sosCoordinator = getKoin().get<SosCoordinator>(),
            sosVisibility = getKoin().get(),
            // This host renders the new-job offer as a draw-over-apps overlay (job_acceptance_screen_load).
            displayMode = JobViewModel.DISPLAY_MODE_DRAWOVER,
        )
        viewModel = vm
        return vm
    }

    companion object {
        const val KEY = "new_job"

        /**
         * RC bool key (default false) gating whether the new-job overlay may draw **over other apps**.
         * Mirrored from Flutter `RemoteConfigKeys.showNewJobOverlayOnOtherApps` into the KMP
         * `RemoteConfigStore`; the two triggers ([JobScreenLauncherPlugin], [SnabbitPushService]) read it
         * off `RemoteConfigGateway` and skip starting this overlay unless it is true (ECPO-860 #8).
         *
         * MUST equal the Flutter key string exactly — the mirror stores under that key, and a mismatch
         * makes `getBool` always fall back to the default (false), silently suppressing the overlay.
         */
        const val RC_SHOW_ON_OTHER_APPS = "expert_show_new_job_overlay_on_other_apps"

        /** Below AWOL — an incoming job never covers an active penalty warning. */
        const val PRIORITY = 10

        /**
         * Process-lived scope for the overlay's accept/deny network call, so an
         * accept survives the window being stopped when the app comes to the
         * foreground. Actions are finite fire-and-forget tasks (they complete and
         * don't accumulate); deliberately never cancelled.
         */
        private val actionScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    }
}
