package com.snabbit.runner.shared.features.shift.presentation.login
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics
import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.core.camera.CapturedMedia
import com.snabbit.runner.shared.core.location.LocationProvider
import com.snabbit.runner.shared.core.location.LocationResult
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftLoginError
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.shift.core.domain.repository.ShiftRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Drives the shift-login flow (intro sheet → camera → upload → success).
 *
 * Architecture notes:
 *  - GPS is fetched in parallel during [ShiftLoginPhase.IntroSheet] so the
 *    user's tap on OK doesn't pay for a fresh fix. If the fetch fails (incl.
 *    permission denied) the upload proceeds without lat/lng — Dart parity.
 *  - The camera owns its own permission lifecycle via `CameraFlow` +
 *    `CameraViewModel`; this VM only receives the terminal [CameraResult]
 *    via [ShiftLoginUiIntent.CameraCompleted].
 *  - Success is a 1-second overlay tick before the host pops back to Home.
 */
class ShiftLoginViewModel(
    private val location: LocationProvider,
    private val shiftRepository: ShiftRepository,
    private val analytics: ShiftLoginAnalytics,
    private val errorAnalytics: ErrorAnalytics,
    private val scope: CoroutineScope,
    private val loginType: String = LOGIN_TYPE_DAILY,
    private val successDwellMs: Long = SUCCESS_DWELL_MS,
    /**
     * Invoked once, the moment the upload returns OK. The host wires this to
     * `RunnerStateStore.requestRefresh()` so Dart re-fetches `current_state`
     * concurrent with the success-overlay dwell — by the time the overlay
     * dismisses, the post-login envelope has usually already landed and the
     * home is recomposed under the cover of the overlay.
     */
    private val onShiftLoggedIn: () -> Unit = {},
    /**
     * Invoked with the decoded gamification outcome when the login response
     * carries a `post_action_outcome` (e.g. EARLY_LOGIN reward). The host wires
     * this to `PostActionCoordinator.present(...)` — fire-and-forget, because the
     * login screen navigates away, so the popup renders on the home surface that
     * hosts the overlay. No-op when the response carries no outcome.
     */
    private val onPostAction: (PostActionOutcome) -> Unit = {},
) {
    private val _uiState = MutableStateFlow(ShiftLoginUiState())
    val uiState: StateFlow<ShiftLoginUiState> = _uiState.asStateFlow()

    private val _effects = MutableSharedFlow<ShiftLoginUiEffect>(extraBufferCapacity = 4)
    val effects: SharedFlow<ShiftLoginUiEffect> = _effects.asSharedFlow()

    /** Latest GPS result, or null while pending. Read at upload time. */
    private var cachedLocation: LocationResult? = null

    init {
        // Start the GPS fetch in parallel with the intro sheet — by the time
        // the user reads the do-not grid and taps OK, lat/lng is usually ready.
        // Permission denial / disabled service / timeout all collapse into
        // "send without coords" rather than blocking the flow.
        scope.launch { cachedLocation = location.getCurrentOrLastKnown() }
        analytics.introShown(loginType)
    }

    fun onIntent(intent: ShiftLoginUiIntent) {
        when (intent) {
            ShiftLoginUiIntent.AcknowledgeIntro -> {
                analytics.introAcknowledged(loginType)
                enterCamera()
            }
            is ShiftLoginUiIntent.CameraCompleted -> handleCameraResult(intent.result)
            ShiftLoginUiIntent.Retake -> {
                analytics.retakeTapped(loginType)
                enterCamera()
            }
            ShiftLoginUiIntent.Dismiss -> {
                // Dismiss is shared with top-bar back, so only count it as an error-surface CTA when the
                // dismiss-only Error sheet is actually showing.
                if (_uiState.value.phase is ShiftLoginPhase.Error) {
                    errorAnalytics.errorScreenCtaClick(ctaText = "dismiss", errorType = "shift_login_failed")
                }
                _effects.tryEmit(ShiftLoginUiEffect.Finish)
            }
            ShiftLoginUiIntent.SuccessTickElapsed ->
                _effects.tryEmit(ShiftLoginUiEffect.Finish)
        }
    }

    private fun handleCameraResult(result: CameraResult) {
        when (result) {
            is CapturedMedia -> {
                analytics.captured(loginType)
                startUpload(result.filePath)
            }
            is CameraResult.Cancelled ->
                _effects.tryEmit(ShiftLoginUiEffect.Finish)
            is CameraResult.Error -> {
                _uiState.value = _uiState.value.copy(phase = ShiftLoginPhase.Error(ShiftLoginError.Unknown()))
                fireErrorSheetLoad(isNetworkError = false)
            }
        }
    }

    private fun startUpload(path: String) {
        _uiState.value = _uiState.value.copy(phase = ShiftLoginPhase.Uploading(path))
        scope.launch {
            val (lat, lng) = currentCoords()
            when (val r = shiftRepository.shiftLogin(selfiePath = path, lat = lat, lng = lng)) {
                is Result.Ok -> {
                    analytics.checkResult(loginType, passed = true, failureCodes = emptyList())
                    analytics.loginSucceeded(loginType, coinsEarned = r.value?.goldCoins ?: 0)
                    // Fire the runner-state refresh BEFORE the success dwell so
                    // the network RTT overlaps with the 1s celebration. The
                    // home recomposes into its post-login archetype while still
                    // covered by the Success overlay — when the overlay
                    // dismisses, the cross-fade lands on a fresh Map sheet
                    // instead of the stale pre-login pink hero.
                    onShiftLoggedIn()
                    // Hand any EARLY_LOGIN reward to the host; it presents on
                    // home after this screen finishes.
                    r.value?.let(onPostAction)
                    enterSuccess(path)
                }
                is Result.Err -> {
                    val phase = mapErrorToPhase(r.error, capturedPath = path)
                    val codes = (r.error as? ShiftLoginError.Validation)?.codes.orEmpty()
                        .map { it.name }
                    analytics.checkResult(loginType, passed = false, failureCodes = codes)
                    if (phase is ShiftLoginPhase.Validation) analytics.retakeShown(loginType, codes)
                    _uiState.value = _uiState.value.copy(phase = phase)
                    // The Validation phase is a bespoke selfie surface (its own selfie_retake_bs_* events);
                    // only the generic dismiss-only Error sheet emits the cross-cutting error event.
                    if (phase is ShiftLoginPhase.Error) {
                        fireErrorSheetLoad(isNetworkError = r.error is ShiftLoginError.NoConnection)
                    }
                }
            }
        }
    }

    private fun enterSuccess(path: String) {
        _uiState.value = _uiState.value.copy(phase = ShiftLoginPhase.Success(path))
        scope.launch {
            delay(successDwellMs)
            onIntent(ShiftLoginUiIntent.SuccessTickElapsed)
        }
    }

    // Validation gets its own full-screen phase (current-vs-expected comparison over
    // the captured selfie); everything else is the generic Error phase carrying the
    // domain error. Copy resolution — including Unknown's serverMessage passthrough —
    // lives in the UI (ShiftLoginStrings.messageFor).
    private fun mapErrorToPhase(error: ShiftLoginError, capturedPath: String): ShiftLoginPhase =
        when (error) {
            is ShiftLoginError.Validation ->
                ShiftLoginPhase.Validation(codes = error.codes, capturedPath = capturedPath)
            else -> ShiftLoginPhase.Error(error)
        }

    /** The dismiss-only Error sheet just appeared → cross-cutting `error_screen_load` (no retry CTA,
     *  so the only follow-up event is `dismiss`). Fired once per entry; the phase is terminal. */
    private fun fireErrorSheetLoad(isNetworkError: Boolean) =
        errorAnalytics.errorScreenLoad(
            errorType = "shift_login_failed",
            errorFormat = "bottomsheet",
            errorContext = "shift_login",
            isNetworkError = isNetworkError,
            retryAvailable = false,
            contactSupportAvailable = false,
        )

    private fun currentCoords(): Pair<Double?, Double?> {
        val loc = (cachedLocation as? LocationResult.Success)?.location ?: return null to null
        return loc.latitude to loc.longitude
    }

    private fun enterCamera() {
        analytics.captureShown(loginType)
        _uiState.value = _uiState.value.copy(phase = ShiftLoginPhase.Camera)
    }

    private companion object {
        const val SUCCESS_DWELL_MS = 1_000L
        const val LOGIN_TYPE_DAILY = "daily"
    }
}
