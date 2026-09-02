package com.snabbit.runner.shared.features.awol.presentation.ui

import android.graphics.BitmapFactory
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import coil3.Image
import coil3.ImageLoader
import coil3.asImage
import coil3.compose.setSingletonImageLoaderFactory
import coil3.test.FakeImage
import coil3.test.FakeImageLoaderEngine
import com.github.takahirom.roborazzi.captureRoboImage
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import com.snabbit.runner.shared.core.permissions.fakes.FakePermissionManager
import com.snabbit.runner.shared.features.awol.awolEnvelope
import com.snabbit.runner.shared.features.awol.domain.AwolFlags
import com.snabbit.runner.shared.features.awol.domain.AwolHotspot
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.awol.presentation.AwolAnalytics
import com.snabbit.runner.shared.features.awol.presentation.AwolViewModel
import com.snabbit.runner.shared.features.job.FakeJobClock
import com.snabbit.runner.shared.features.job.FakeRunnerStateSource
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Golden tests for the AWOL surfaces — one per §2A mockup (home breach, home
 * with a red card issued, movement-required overlay). Rendered on the JVM via
 * Robolectric Native Graphics; goldens live in `src/androidUnitTest/snapshots/`.
 *
 * Record / verify (plain `testDebugUnitTest` leaves these as no-ops):
 *   gradle :shared:recordRoborazziDebug
 *   gradle :shared:verifyRoborazziDebug
 *
 * Determinism: the clock is frozen, payloads use the `remaining_seconds`
 * receipt anchor (no ISO parsing), and the countdown ticker recomputes
 * `anchor − now` against the frozen clock — so the meter reading is stable
 * however long the capture takes. Image loads go through a
 * [FakeImageLoaderEngine] (no network): the breach fixture's `image_url`
 * resolves to a solid block, pinning the loaded-image state; the other
 * fixtures carry no URL, pinning the placeholder state.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-420dpi")
class AwolComponentsScreenshotTest {

    @get:Rule
    val compose = createComposeRule()

    private val strings = AwolStrings()

    // Each ViewModel launches a process-lived collector + a 1-Hz ticker (the
    // frozen clock keeps the anchor in the future forever); ride them on a
    // scope this test owns and cancel it in tearDown so they don't leak onto
    // DefaultExecutor for the rest of the JVM test process.
    private val vmScope = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined)

    @After
    fun tearDown() {
        vmScope.cancel()
    }

    /**
     * Deterministic Coil engine — the fixture URL resolves to the REAL bundled
     * `enter_hotspot` illustration (the legacy Flutter placeholder; [FIXTURE_IMAGE_URL]
     * mirrors its CDN path), so the golden shows the actual image rather than a
     * stand-in. Any other URL falls back to a solid slate block. Built lazily so
     * the decode runs inside the Robolectric native-graphics sandbox.
     */
    private val fakeImageEngine by lazy {
        FakeImageLoaderEngine.Builder()
            .intercept(FIXTURE_IMAGE_URL, fixtureImage("/awol_enter_hotspot.jpg"))
            .default(FakeImage(color = 0xFF64748B.toInt()))
            .build()
    }

    /** Decodes a bundled androidUnitTest resource into a Coil [Image] — no network. */
    private fun fixtureImage(resourcePath: String): Image {
        val bytes = requireNotNull(javaClass.getResourceAsStream(resourcePath)) {
            "missing test fixture: $resourcePath"
        }.use { it.readBytes() }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size).asImage()
    }

    /** Installs the fake engine as the singleton loader [RemoteImage] resolves. */
    @Composable
    private fun installFakeImageLoader() {
        setSingletonImageLoaderFactory { context ->
            ImageLoader.Builder(context)
                .components { add(fakeImageEngine) }
                .build()
        }
    }

    private fun viewModel(
        awolJson: String,
        foreground: Boolean,
        overlayEnabled: Boolean = false,
        fallbackBreachImageUrl: String? = null,
    ): AwolViewModel {
        val permissions = FakePermissionManager()
        permissions.statuses[SnabbitPermission.Overlay] = PermissionStatus.GRANTED
        val viewModel = AwolViewModel(
            source = FakeRunnerStateSource(awolEnvelope(awolJson)),
            clock = FakeJobClock(now = 0L),
            permissions = permissions,
            analytics = AwolAnalytics(FakeAnalyticsTracker()),
            logger = FakeLogger(),
            store = LocalizationStore(FakeLogger(), CrashReporter { _, _ -> }),
            scope = vmScope,
        )
        viewModel.setFlags(
            AwolFlags(
                overlayEnabled = overlayEnabled,
                fallbackBreachImageUrl = fallbackBreachImageUrl,
            ),
        )
        viewModel.setHostVisibility(isForeground = foreground)
        return viewModel
    }

    @Test
    fun homeCard_breach() {
        val viewModel = viewModel(BREACH_JSON, foreground = true)
        compose.setContent {
            installFakeImageLoader()
            SnabbitTheme(darkTheme = false) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    AwolHomeCard(viewModel = viewModel)
                    AwolHotspotTile(
                        hotspot = AwolHotspot(
                            name = "Jyoti Nivas College Gate",
                            latitude = 12.91,
                            longitude = 77.64,
                        ),
                        strings = strings,
                        onMap = {},
                        distanceText = "3.2 km away",
                    )
                }
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/awol_home_card_breach.png")
    }

    @Test
    fun homeCard_redCardIssued() {
        val viewModel = viewModel(RED_CARD_JSON, foreground = true)
        compose.setContent {
            SnabbitTheme(darkTheme = false) {
                Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                    AwolHomeCard(viewModel = viewModel)
                }
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/awol_home_card_red_card.png")
    }

    @Test
    fun homeCard_reEntered() {
        val viewModel = viewModel(RE_ENTERED_JSON, foreground = true)
        compose.setContent {
            SnabbitTheme(darkTheme = false) {
                Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                    AwolHomeCard(viewModel = viewModel)
                }
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/awol_home_card_reentered.png")
    }

    @Test
    fun homeSection_breach() {
        val viewModel = viewModel(BREACH_JSON, foreground = true)
        compose.setContent {
            installFakeImageLoader()
            // The host-embedded pairing: AwolHomeSection themes itself (the
            // platform view can't), so no SnabbitTheme wrapper here.
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                AwolHomeSection(
                    viewModel = viewModel,
                    distanceText = MutableStateFlow("3.2 km away"),
                )
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/awol_home_section_breach.png")
    }

    @Test
    fun overlay_movementRequired() {
        // JOB carries no server image_url; in production Dart always pushes the
        // legacy fallback (awol_enter_hotspot placeholder), so the image slot is
        // filled, not empty. Pin that fallback-image state — matches the legacy
        // Flutter overlay, which never left the slot null.
        val viewModel = viewModel(
            JOB_JSON,
            foreground = false,
            overlayEnabled = true,
            fallbackBreachImageUrl = FIXTURE_IMAGE_URL,
        )
        compose.setContent {
            installFakeImageLoader()
            AwolOverlaySurface(viewModel = viewModel)
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/awol_overlay_movement_required.png")
    }

    /**
     * Breach overlay: the redesigned penalty-rate strip (❗ badge + clock) shows,
     * and the `consequences` the payload carries on breach are NOT surfaced — the
     * suppression that keeps malformed breach consequences (e.g. "Deduction of MinG")
     * off the card. Both CTAs present.
     *
     * Bugfix: the badge is the client-overridden "MOVEMENT REQUIRED" (not the server
     * `badge_text`), and with no `red_cards_total` the warning is the count-driven
     * penalty line "You will face a penalty if you don't return before the timer expires."
     * — so the `warning_text` in [BREACH_OVERLAY_JSON] is not rendered.
     */
    @Test
    fun overlay_breach() {
        val viewModel = viewModel(BREACH_OVERLAY_JSON, foreground = false, overlayEnabled = true)
        compose.setContent {
            installFakeImageLoader()
            AwolOverlaySurface(viewModel = viewModel)
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/awol_overlay_breach.png")
    }

    private companion object {
        const val SNAPSHOTS = "src/androidUnitTest/snapshots"

        /** Intercepted by [fakeImageEngine] — never fetched. */
        const val FIXTURE_IMAGE_URL = "https://cdn.test/awol/enter_hotspot.jpg"

        /**
         * §2A "Home card — breach": 15:23 left, penalty strip, no red cards yet.
         *
         * Bugfix: on BREACH the client OVERRIDES the server warning copy — the warning
         * is driven by `red_cards_total`. With no `red_cards_total` (== 0) the warning is
         * the penalty line "You will face a penalty if you don't return before the timer
         * expires.". The `warning_text` carried below is therefore NOT rendered here — it's
         * left in place only to prove the override wins over a server-supplied string.
         * The badge stays server-preferred; none is supplied, so the bundled
         * "HOTSPOT BREACH" fallback renders.
         */
        val BREACH_JSON = """
            {
              "event_id": "evt-shot-1",
              "state": "BREACH",
              "countdown": {"remaining_seconds": 923, "total_seconds": 1800},
              "hotspot": {"name": "Jyoti Nivas College Gate", "latitude": 12.91, "longitude": 77.64},
              "warning_text": {"key": "w", "default": "Return in time or 1 red card will be added"},              "image_url": "$FIXTURE_IMAGE_URL"
            }
        """.trimIndent()

        /**
         * §2A "Home card — red card issued": same card + "1 Red Card Received" pill.
         *
         * Bugfix: with `red_cards_total` == 1 (> 0) the client-driven breach warning is
         * "Return in time or 1 red card will be added" (singular). The badge is the
         * bundled "HOTSPOT BREACH" fallback (no server badge_text supplied). Here the
         * rendered warning happens to match the `warning_text` string, but it is
         * COMPUTED from the count, not read from the field.
         */
        val RED_CARD_JSON = """
            {
              "event_id": "evt-shot-2",
              "state": "BREACH",
              "countdown": {"remaining_seconds": 923, "total_seconds": 1800},
              "hotspot": {"name": "Jyoti Nivas College Gate", "latitude": 12.91, "longitude": 77.64},
              "warning_text": {"key": "w", "default": "Return in time or 1 red card will be added"},              "red_cards_total": 1
            }
        """.trimIndent()

        /**
         * §2A "Home card — re-entered": green BACK IN HOTSPOT badge + "Re-entered
         * hotspot" title only — the re-entry view is confirmation-only, so the
         * `warning_text` and `consequences` supplied below are deliberately NOT
         * rendered (nor is the Show Directions CTA), per product. They stay in the
         * fixture to prove the phase gate drops them.
         */
        val RE_ENTERED_JSON = """
            {
              "event_id": "evt-shot-5",
              "state": "RE_ENTERED",
              "hotspot": {"name": "Jyoti Nivas College Gate", "latitude": 12.91, "longitude": 77.64},
              "warning_text": {"key": "w", "default": "You exited the hotspot once today. Repeated breaches may result in:"},
              "consequences": [
                {"text": {"key": "c1", "default": "Deduction of MinG"}},
                {"text": {"key": "c2", "default": "50 Penalty"}}
              ]
            }
        """.trimIndent()

        /**
         * Breach overlay: penalty strip + a `consequences` array that must stay hidden
         * (the "Deduction of MinG" garbled-data case), 15:23, both CTAs. No
         * `red_cards_total` → the client-driven breach warning is the penalty line; the
         * `warning_text` below is not rendered (client override for the BREACH phase).
         */
        val BREACH_OVERLAY_JSON = """
            {
              "event_id": "evt-shot-4",
              "state": "BREACH",
              "countdown": {"remaining_seconds": 923, "total_seconds": 1800},
              "hotspot": {"name": "Jyoti Nivas College Gate", "latitude": 12.91, "longitude": 77.64},
              "title": {"key": "t", "default": "Please return to hotspot within"},
              "warning_text": {"key": "w", "default": "Return in time or 1 red card will be added"},              "consequences": [
                {"text": {"key": "c1", "default": "Deduction of MinG"}},
                {"text": {"key": "c2", "default": "50 Penalty"}}
              ],
              "image_url": "$FIXTURE_IMAGE_URL"
            }
        """.trimIndent()

        /** §2A "Overlay — over any app": red MOVEMENT REQUIRED variant, 14:23, both CTAs. */
        val JOB_JSON = """
            {
              "event_id": "evt-shot-3",
              "state": "JOB",
              "countdown": {"remaining_seconds": 863, "total_seconds": 1800},
              "hotspot": {"name": "Jyoti Nivas College Gate", "latitude": 12.91, "longitude": 77.64},
              "title": {"key": "t", "default": "Please return to hotspot within"},
              "warning_text": {"key": "w", "default": "You will face a penalty if you don't return before the timer expires."}
            }
        """.trimIndent()
    }
}
