package com.snabbit.runner.shared.features.tiering.data

import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.camera.fakes.TestAppDispatchers
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import com.snabbit.runner.shared.features.tiering.domain.model.NudgeTheme
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Guards the tolerant, field-isolated tiering-profile decode. The regression it pins:
 * a single unexpected field in the `runners/me` body (a present-but-null
 * `has_viewed_intro`, a `service_id` sent as a string) must NOT null the whole slice.
 * The old strict-DTO decode threw and fell back to an EMPTY profile, silently hiding
 * every tiering surface even for a fully-eligible runner (the "nudges + tiers invisible"
 * bug). Flutter parses each field tolerantly (`as T? ?? default`); this mirrors that.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class DefaultTieringDataSourceTest {

    private fun dataSource(profileStore: RunnerProfileStore, nowMs: Long = 0L) =
        DefaultTieringDataSource(
            runnerState = RunnerStateStore(FakeLogger()),
            profileStore = profileStore,
            dispatchers = TestAppDispatchers(UnconfinedTestDispatcher()),
            currentTimeMs = CurrentTimeMs { nowMs },
            logger = FakeLogger(),
        )

    private fun storeWith(rawJson: String): RunnerProfileStore =
        RunnerProfileStore(FakeLogger()).apply { pushProfile(rawJson) }

    /** A data source whose [RunnerStateStore] already carries [envelopeJson] as the current_state. */
    private fun nudgeSource(envelopeJson: String) =
        DefaultTieringDataSource(
            runnerState = RunnerStateStore(FakeLogger()).apply { pushState(envelopeJson) },
            profileStore = RunnerProfileStore(FakeLogger()),
            dispatchers = TestAppDispatchers(UnconfinedTestDispatcher()),
            currentTimeMs = CurrentTimeMs { 0L },
            logger = FakeLogger(),
        )

    @Test
    fun `present-but-null has_viewed_intro does not null the tier`() = runTest {
        val store = storeWith(
            """{"user":{"name":"A","id":1},"tier":"GOLD","service_id":1,"status":"ACTIVE","has_viewed_intro":null}""",
        )
        val profile = dataSource(store).profile.first()
        assertEquals(Tier.GOLD, profile.tier) // was null before the fix (whole decode threw → empty default)
        assertFalse(profile.hasViewedIntro) // null coerced to false (Flutter `as bool? ?? false` parity)
        assertEquals(1, profile.serviceId)
        assertFalse(profile.isSuspended)
    }

    @Test
    fun `type-drifted service_id (sent as a string) does not null the tier`() = runTest {
        val store = storeWith("""{"tier":"SILVER","service_id":"1","status":"ACTIVE","has_viewed_intro":true}""")
        val profile = dataSource(store).profile.first()
        assertEquals(Tier.SILVER, profile.tier)
        assertTrue(profile.hasViewedIntro)
        assertEquals(1, profile.serviceId) // "1" coerced to 1
    }

    @Test
    fun `a well-formed body decodes every tiering field`() = runTest {
        val store = storeWith(
            """{"tier":"GOLD","service_id":1,"status":"SUSPENDED","has_viewed_intro":true,"tier_effective_date":"2020-01-01"}""",
        )
        val profile = dataSource(store, nowMs = 1_700_000_000_000L).profile.first()
        assertEquals(Tier.GOLD, profile.tier)
        assertTrue(profile.hasViewedIntro)
        assertTrue(profile.isSuspended)
        assertTrue(profile.isTieringEnabled) // effective date 2020-01-01 <= now
    }

    @Test
    fun `an absent tiering slice yields the empty default`() = runTest {
        val store = storeWith("""{"user":{"name":"A","id":1},"public_pic":"x"}""")
        val profile = dataSource(store).profile.first()
        assertEquals(null, profile.tier)
        assertFalse(profile.hasViewedIntro)
        assertFalse(profile.isTieringEnabled)
    }

    @Test
    fun `re-emits when only a tiering-only field changes (has_viewed_intro flips)`() = runTest {
        // Reactivity regression: the runner watches the intro → ONLY `has_viewed_intro` flips;
        // the rest of `runners/me` is identical, so the decoded RunnerProfile (which does NOT
        // model the tiering-only fields) is EQUAL. If the tiering flow triggers on
        // `profileStore.state` (that RunnerProfile), the StateFlow dedupes and the update is
        // DROPPED — the banner never becomes the play-video row. It must trigger on the raw body.
        val dispatcher = UnconfinedTestDispatcher(testScheduler)
        val store = RunnerProfileStore(FakeLogger())
        store.pushProfile("""{"user":{"name":"A","id":1},"tier":"GOLD","service_id":1,"status":"ACTIVE","has_viewed_intro":false}""")
        val ds = DefaultTieringDataSource(
            runnerState = RunnerStateStore(FakeLogger()),
            profileStore = store,
            dispatchers = TestAppDispatchers(dispatcher),
            currentTimeMs = CurrentTimeMs { 0L },
            logger = FakeLogger(),
        )
        val seen = mutableListOf<Boolean>()
        val job = launch(dispatcher) { ds.profile.collect { seen += it.hasViewedIntro } }
        // Only has_viewed_intro changes; everything else (incl. tier) is identical.
        store.pushProfile("""{"user":{"name":"A","id":1},"tier":"GOLD","service_id":1,"status":"ACTIVE","has_viewed_intro":true}""")
        job.cancel()
        assertTrue(seen.contains(true), "tiering flow did not re-emit on a has_viewed_intro-only change")
    }

    // ── tier_nudge decode: themeProvided (recognised-theme rule) ──

    @Test
    fun `tier_nudge with a recognised theme sets themeProvided`() = runTest {
        val nudge = nudgeSource("""{"tier_nudge":{"nudge_name":"LUNCH_SELECTION","theme":"GENERIC"}}""").nudge.first()
        assertNotNull(nudge)
        assertTrue(nudge.themeProvided)
        assertEquals(NudgeTheme.GENERIC, nudge.theme)
    }

    @Test
    fun `tier_nudge with no theme leaves themeProvided false`() = runTest {
        val nudge = nudgeSource("""{"tier_nudge":{"nudge_name":"LUNCH_SELECTION"}}""").nudge.first()
        assertNotNull(nudge)
        assertFalse(nudge.themeProvided)
        assertEquals(NudgeTheme.GENERIC, nudge.theme) // still defaults GENERIC for styling
    }

    @Test
    fun `tier_nudge with an unknown theme leaves themeProvided false`() = runTest {
        // A NEW backend theme this version doesn't model must count as "no theme", so the
        // dynamic image renders un-tinted (not flattened by the fallback GENERIC tint).
        val nudge = nudgeSource("""{"tier_nudge":{"nudge_name":"LUNCH_SELECTION","theme":"NEON_FUTURE"}}""").nudge.first()
        assertNotNull(nudge)
        assertFalse(nudge.themeProvided)
        assertEquals(NudgeTheme.GENERIC, nudge.theme)
    }
}
