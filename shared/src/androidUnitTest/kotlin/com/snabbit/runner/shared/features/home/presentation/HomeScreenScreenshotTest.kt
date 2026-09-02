package com.snabbit.runner.shared.features.home.presentation

import android.graphics.BitmapFactory
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
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
import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import com.snabbit.runner.shared.core.permissions.fakes.FakePermissionManager
import com.snabbit.runner.shared.features.awol.awolEnvelope
import com.snabbit.runner.shared.features.awol.domain.AwolFlags
import com.snabbit.runner.shared.features.awol.presentation.AwolAnalytics
import com.snabbit.runner.shared.features.awol.presentation.AwolViewModel
import com.snabbit.runner.shared.features.awol.presentation.ui.AwolHomeSection
import com.snabbit.runner.shared.features.home.domain.model.HomeBg
import com.snabbit.runner.shared.features.home.presentation.ui.HeroSection
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
 * WHOLE-SCREEN golden for the Home tab's AWOL TAKEOVER arrangement: while an in-app
 * AWOL card is routed (`awolActive` in `HomeScreen.kt`), the Pink hero archetype is
 * forced and the card renders as the SOLE hero-panel content
 * (`HeroSection(HomeBg.Pink) { awolCard() }` in `HeroLayout`) — the attendance/hero
 * cards and the map/searching sheet are hidden until the server clears the AWOL state.
 *
 * Approach — the sanctioned FALLBACK, not the full [HomeViewModel]. Driving a real
 * `HomeViewModel` (≈15 ctor deps, never-completing `viewModelScope` init collectors,
 * a live location fix that fans out to a seva fetch, and pull-to-refresh chrome) to a
 * pixel-stable frame inside a Roborazzi (non-`runTest`) harness is genuinely
 * impractical. Instead this reproduces `HeroLayout`'s takeover body verbatim — a
 * `LazyColumn` (same `layoutGapLg` rhythm) whose single hero item is
 * `HeroSection(HomeBg.Pink) { awolCard() }` — using the SAME internal composables the
 * screen uses (visible here: androidUnitTest shares the module). So the golden
 * exercises the true widgets in the true takeover arrangement; only the VM plumbing
 * and the pinned top-nav/scrim chrome (irrelevant to the takeover) are omitted.
 *
 * The AWOL card is [AwolHomeSection] fed a breach [AwolViewModel] built exactly like
 * `AwolComponentsScreenshotTest` (frozen clock, `remaining_seconds` anchor,
 * `FakeImageLoaderEngine` for the breach illustration).
 *
 * Record / verify:  gradle :shared:recordRoborazziDebug / verifyRoborazziDebug
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-420dpi")
class HomeScreenScreenshotTest {

    @get:Rule
    val compose = createComposeRule()

    // The breach AwolViewModel launches a process-lived collector + a 1-Hz ticker;
    // ride them on a test-owned scope and cancel it in tearDown (see the reference
    // AwolComponentsScreenshotTest for the rationale).
    private val vmScope = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined)

    @After
    fun tearDown() {
        vmScope.cancel()
    }

    private val fakeImageEngine by lazy {
        FakeImageLoaderEngine.Builder()
            .intercept(FIXTURE_IMAGE_URL, fixtureImage("/awol_enter_hotspot.jpg"))
            .default(FakeImage(color = 0xFF64748B.toInt()))
            .build()
    }

    private fun fixtureImage(resourcePath: String): Image {
        val bytes = requireNotNull(javaClass.getResourceAsStream(resourcePath)) {
            "missing test fixture: $resourcePath"
        }.use { it.readBytes() }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size).asImage()
    }

    @Composable
    private fun installFakeImageLoader() {
        setSingletonImageLoaderFactory { context ->
            ImageLoader.Builder(context)
                .components { add(fakeImageEngine) }
                .build()
        }
    }

    private fun breachAwolViewModel(): AwolViewModel {
        val permissions = FakePermissionManager()
        permissions.statuses[SnabbitPermission.Overlay] = PermissionStatus.GRANTED
        return AwolViewModel(
            source = FakeRunnerStateSource(awolEnvelope(BREACH_JSON)),
            clock = FakeJobClock(now = 0L),
            permissions = permissions,
            analytics = AwolAnalytics(FakeAnalyticsTracker()),
            logger = FakeLogger(),
            store = LocalizationStore(FakeLogger(), CrashReporter { _, _ -> }),
            scope = vmScope,
        ).apply {
            // HOME_CARD surface (in-app, no overlay) → AwolHomeSection renders the card.
            setFlags(AwolFlags(overlayEnabled = false, fallbackBreachImageUrl = null))
            setHostVisibility(isForeground = true)
        }
    }

    /**
     * AWOL TAKEOVER golden (`HomeScreen(awolActive = true)`): the in-app AWOL card is the
     * SOLE hero content inside the pink hero panel, mirroring `HeroLayout`'s `awolActive`
     * branch (`HeroSection(HomeBg.Pink) { awolCard() }` with no attendance `HomeCardRenderer`
     * and no `item(key="awol")` below it). AWOL fires only while the runner is working
     * (the SearchingForJobs/Map state), so it never co-occurs with the attendance card — the
     * takeover converts that working state into this pink AWOL panel.
     *
     * FALLBACK approach: reproduce `HeroLayout`'s takeover body verbatim rather than drive the
     * real [HomeViewModel] (~15 ctor deps + never-completing collectors, impractical in a
     * Roborazzi harness). The `awolCard` slot renders [AwolHomeSection] fed a breach
     * [AwolViewModel] fixture ([breachAwolViewModel]); only the VM plumbing and the pinned
     * top-nav/scrim chrome (irrelevant to the takeover) are omitted.
     */
    @Test
    fun homeScreen_awolTakeover() {
        val awolViewModel = breachAwolViewModel()
        compose.setContent {
            installFakeImageLoader()
            SnabbitScreen(title = null) { _ ->
                // HeroLayout's LazyColumn body with awolActive == true: the pink hero holds
                // ONLY awolCard() — attendance/hero cards are all replaced, nothing follows.
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.layoutGapLg),
                ) {
                    item(key = "hero") {
                        HeroSection(bg = HomeBg.Pink) {
                            AwolHomeSection(
                                viewModel = awolViewModel,
                                distanceText = MutableStateFlow("3.2 km away"),
                            )
                        }
                    }
                }
            }
        }
        compose.onRoot().captureRoboImage(
            filePath = "$SNAPSHOTS/home_screen_awol_takeover.png",
        )
    }

    private companion object {
        const val SNAPSHOTS = "src/androidUnitTest/snapshots"

        /** Intercepted by [fakeImageEngine] — never fetched. */
        const val FIXTURE_IMAGE_URL = "https://cdn.test/awol/enter_hotspot.jpg"

        /** §2A breach home card — 15:23 left, penalty strip, hotspot illustration. */
        val BREACH_JSON = """
            {
              "event_id": "evt-home-1",
              "state": "BREACH",
              "countdown": {"remaining_seconds": 923, "total_seconds": 1800},
              "hotspot": {"name": "Jyoti Nivas College Gate", "latitude": 12.91, "longitude": 77.64},
              "image_url": "$FIXTURE_IMAGE_URL"
            }
        """.trimIndent()
    }
}
