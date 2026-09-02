package com.snabbit.runner.shared.features.shift.presentation.login
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics
import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.camera.CameraErrorCode
import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.core.location.LocationResult
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.shift.FakeLocationProvider
import com.snabbit.runner.shared.features.shift.FakeShiftRepository
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftLoginError
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class ShiftLoginViewModelTest {

    private data class Wired(
        val vm: ShiftLoginViewModel,
        val location: FakeLocationProvider,
        val repo: FakeShiftRepository,
        val analytics: FakeAnalyticsTracker,
        val loggedInCallCount: () -> Int,
    )

    private fun wire(scope: TestScope, location: FakeLocationProvider = FakeLocationProvider()): Wired {
        val repo = FakeShiftRepository()
        val tracker = FakeAnalyticsTracker()
        var loggedInCalls = 0
        val vm = ShiftLoginViewModel(
            location = location,
            shiftRepository = repo,
            analytics = ShiftLoginAnalytics(tracker),
            errorAnalytics = ErrorAnalytics(tracker),
            scope = scope.backgroundScope,
            onShiftLoggedIn = { loggedInCalls++ },
        )
        return Wired(vm, location, repo, tracker, { loggedInCalls })
    }

    /** Subscribes to [ShiftLoginViewModel.effects] on the test's backgroundScope so
     *  tryEmit lands in the buffer (no replay; late subscribers see nothing). */
    private fun TestScope.collectEffects(vm: ShiftLoginViewModel): MutableList<ShiftLoginUiEffect> {
        val sink = mutableListOf<ShiftLoginUiEffect>()
        backgroundScope.launch { vm.effects.collect { sink += it } }
        return sink
    }

    private val photo = CameraResult.Photo(filePath = "/tmp/x.jpg", token = "tok", sizeBytes = 100L)

    @Test fun initialPhase_isIntroSheet() = runTest {
        val (vm) = wire(this); runCurrent()
        assertEquals(ShiftLoginPhase.IntroSheet, vm.uiState.value.phase)
    }

    @Test fun acknowledgeIntro_advancesToCamera() = runTest {
        val (vm) = wire(this); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        assertEquals(ShiftLoginPhase.Camera, vm.uiState.value.phase)
    }

    @Test fun dismissFromIntro_emitsFinishWithoutRefresh() = runTest {
        val (vm) = wire(this); runCurrent()
        val effects = collectEffects(vm); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.Dismiss); runCurrent()
        assertEquals(ShiftLoginUiEffect.Finish, effects.single())
    }

    @Test fun cameraSuccess_uploadOk_firesLoggedInThenFinishAfterDwell() = runTest {
        val w = wire(this); runCurrent()
        val effects = collectEffects(w.vm); runCurrent()
        w.vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        w.vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()

        // Upload fired immediately + success → Success phase
        assertIs<ShiftLoginPhase.Success>(w.vm.uiState.value.phase)
        assertEquals("/tmp/x.jpg", w.repo.loginCalls.single().selfiePath)

        // Lat/lng from default FakeLocationProvider
        assertEquals(12.9716, w.repo.loginCalls.single().lat)
        assertEquals(77.5946, w.repo.loginCalls.single().lng)

        // onShiftLoggedIn fires synchronously with Success entry — so the
        // host-side runner-state refresh races the 1s dwell, not the dismiss.
        assertEquals(1, w.loggedInCallCount())

        // After dwell, Finish
        advanceTimeBy(1_001); runCurrent()
        assertEquals(ShiftLoginUiEffect.Finish, effects.single())
    }

    @Test fun uploadError_doesNotFireLoggedIn() = runTest {
        val w = wire(this); runCurrent()
        w.repo.enqueueLogin(Result.Err(ShiftLoginError.NoConnection))
        w.vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        w.vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()
        assertEquals(0, w.loggedInCallCount())
    }

    @Test fun gpsFailure_sendsNullCoords() = runTest {
        val fake = FakeLocationProvider(
            current = LocationResult.PermissionDenied,
            lastKnown = LocationResult.PermissionDenied,
        )
        val (vm, _, repo) = wire(this, location = fake); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()
        assertNull(repo.loginCalls.single().lat)
        assertNull(repo.loginCalls.single().lng)
    }

    @Test fun upload_validationError_goesToValidationPhase() = runTest {
        val (vm, _, repo) = wire(this); runCurrent()
        repo.enqueueLogin(
            Result.Err(ShiftLoginError.Validation(listOf(SelfieValidationCode.FaceNotDetected))),
        )
        vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()
        val phase = assertIs<ShiftLoginPhase.Validation>(vm.uiState.value.phase)
        assertEquals(listOf(SelfieValidationCode.FaceNotDetected), phase.codes)
        // The captured selfie is threaded through so the sheet can show it as the
        // "your photo" (❌) side of the current-vs-expected comparison.
        assertEquals("/tmp/x.jpg", phase.capturedPath)
    }

    @Test fun retakeFromValidation_returnsToCamera() = runTest {
        val (vm, _, repo) = wire(this); runCurrent()
        repo.enqueueLogin(Result.Err(ShiftLoginError.Validation(emptyList())))
        vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.Retake); runCurrent()
        assertEquals(ShiftLoginPhase.Camera, vm.uiState.value.phase)
    }

    @Test fun upload_noConnection_mapsToErrorPhase() = runTest {
        val (vm, _, repo) = wire(this); runCurrent()
        repo.enqueueLogin(Result.Err(ShiftLoginError.NoConnection))
        vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()
        val phase = assertIs<ShiftLoginPhase.Error>(vm.uiState.value.phase)
        assertEquals(ShiftLoginError.NoConnection, phase.error)
    }

    @Test fun upload_unknown_withServerMessage_usesServerMessage() = runTest {
        val (vm, _, repo) = wire(this); runCurrent()
        repo.enqueueLogin(
            Result.Err(ShiftLoginError.Unknown(statusCode = 400, serverMessage = "custom oops")),
        )
        vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()
        val phase = assertIs<ShiftLoginPhase.Error>(vm.uiState.value.phase)
        // The VM now carries the domain error verbatim; the serverMessage → display
        // resolution moved to the UI (ShiftLoginStrings.messageFor).
        assertEquals("custom oops", (phase.error as ShiftLoginError.Unknown).serverMessage)
    }

    @Test fun cameraCancelled_emitsFinishWithoutRefresh() = runTest {
        val (vm) = wire(this); runCurrent()
        val effects = collectEffects(vm); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.CameraCompleted(CameraResult.Cancelled)); runCurrent()
        assertEquals(ShiftLoginUiEffect.Finish, effects.single())
    }

    @Test fun cameraError_goesToErrorPhase() = runTest {
        val (vm) = wire(this); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        vm.onIntent(
            ShiftLoginUiIntent.CameraCompleted(
                CameraResult.Error(code = CameraErrorCode.INTERNAL_ERROR, message = "boom"),
            ),
        )
        runCurrent()
        assertIs<ShiftLoginPhase.Error>(vm.uiState.value.phase)
    }

    @Test fun successTickElapsed_emitsFinish() = runTest {
        val (vm) = wire(this); runCurrent()
        val effects = collectEffects(vm); runCurrent()
        vm.onIntent(ShiftLoginUiIntent.SuccessTickElapsed); runCurrent()
        assertEquals(ShiftLoginUiEffect.Finish, effects.single())
    }

    @Test fun analytics_introShown_onInit() = runTest {
        val w = wire(this); runCurrent()
        assertTrue("selfie_intro_bs_load" in w.analytics.trackedNames)
    }

    @Test fun analytics_happyPath_firesFunnelInOrder() = runTest {
        val w = wire(this); runCurrent()
        w.vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        w.vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()
        assertTrue(
            w.analytics.trackedNames.containsAll(
                listOf(
                    "selfie_intro_bs_load",
                    "selfie_intro_bs_cta_click",
                    "selfie_capture_screen_load",
                    "selfie_capture_screen_cta_click",
                    "selfie_check_result",
                    "login_success_screen_load",
                ),
            ),
        )
        assertEquals(
            "pass",
            w.analytics.events.last { it.name == "selfie_check_result" }.props["overall_result"],
        )
    }

    @Test fun analytics_validationFailure_firesFailResultAndRetake() = runTest {
        val w = wire(this); runCurrent()
        w.repo.enqueueLogin(
            Result.Err(ShiftLoginError.Validation(listOf(SelfieValidationCode.FaceMismatch))),
        )
        w.vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        w.vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()
        assertEquals(
            "fail",
            w.analytics.events.last { it.name == "selfie_check_result" }.props["overall_result"],
        )
        assertTrue("selfie_retake_bs_load" in w.analytics.trackedNames)
        w.vm.onIntent(ShiftLoginUiIntent.Retake); runCurrent()
        assertTrue("selfie_retake_bs_cta_click" in w.analytics.trackedNames)
    }

    @Test fun errorSheet_networkFailure_firesErrorScreenLoadThenDismissCta() = runTest {
        val w = wire(this); runCurrent()
        w.repo.enqueueLogin(Result.Err(ShiftLoginError.NoConnection))
        w.vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        w.vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()
        // The dismiss-only Error sheet loaded — with is_network_error true and no retry CTA.
        val load = w.analytics.events.single { it.name == "error_screen_load" }
        assertEquals("shift_login_failed", load.props["error_type"])
        assertEquals("bottomsheet", load.props["error_format"])
        assertEquals("shift_login", load.props["error_context"])
        assertEquals(true, load.props["is_network_error"])
        assertEquals(false, load.props["retry_available"])
        // Tapping Dismiss on the error sheet → error_screen_cta_click(dismiss).
        w.vm.onIntent(ShiftLoginUiIntent.Dismiss); runCurrent()
        val cta = w.analytics.events.single { it.name == "error_screen_cta_click" }
        assertEquals("dismiss", cta.props["cta_text"])
        assertEquals("shift_login_failed", cta.props["error_type"])
    }

    @Test fun cameraError_firesErrorScreenLoad_nonNetwork() = runTest {
        val w = wire(this); runCurrent()
        w.vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        w.vm.onIntent(
            ShiftLoginUiIntent.CameraCompleted(
                CameraResult.Error(code = CameraErrorCode.INTERNAL_ERROR, message = "boom"),
            ),
        )
        runCurrent()
        val load = w.analytics.events.single { it.name == "error_screen_load" }
        assertEquals(false, load.props["is_network_error"])
    }

    @Test fun validationFailure_doesNotFireGenericErrorScreenLoad() = runTest {
        // The Validation/Retake surface has its own bespoke selfie events; it must NOT double-count as a
        // generic error_screen_load.
        val w = wire(this); runCurrent()
        w.repo.enqueueLogin(Result.Err(ShiftLoginError.Validation(listOf(SelfieValidationCode.FaceMismatch))))
        w.vm.onIntent(ShiftLoginUiIntent.AcknowledgeIntro); runCurrent()
        w.vm.onIntent(ShiftLoginUiIntent.CameraCompleted(photo)); runCurrent()
        assertTrue("error_screen_load" !in w.analytics.trackedNames)
    }

    @Test fun dismissFromIntro_doesNotFireErrorCta() = runTest {
        // Dismiss is shared with top-bar back; outside the Error phase it must not emit an error CTA.
        val w = wire(this); runCurrent()
        w.vm.onIntent(ShiftLoginUiIntent.Dismiss); runCurrent()
        assertTrue("error_screen_cta_click" !in w.analytics.trackedNames)
    }
}
