package com.snabbit.runner.shared.features.awol.data

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.features.awol.AWOL_BREACH_JSON
import com.snabbit.runner.shared.features.awol.awolEnvelope
import com.snabbit.runner.shared.features.awol.awolTestJson
import com.snabbit.runner.shared.features.awol.domain.AwolPhase
import com.snabbit.runner.shared.features.awol.domain.AwolSnapshot
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.job.FakeJobClock
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlinx.serialization.json.jsonObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Coverage for [toAwolSnapshot] — one test (minimum) per row of the TRD §9
 * mapper fallback table, plus the full-payload happy path.
 */
class AwolStateMapperTest {

    private val logger = FakeLogger()
    private val clock = FakeJobClock(
        now = 0L,
        parsed = mapOf(
            "2026-07-09T10:15:00+05:30" to 1_783_000_500_000L,
            "2026-07-09T10:00:00+05:30" to 1_782_999_600_000L,
        ),
    )
    private val strings = AwolStrings()

    // ── Row: whole awol key ────────────────────────────────────────────────

    @Test
    fun nullEnvelope_isInactive() {
        assertNull((null as RunnerState?).toAwolSnapshot(clock, logger))
    }

    @Test
    fun missingAwolKey_isInactive() {
        val state = RunnerState(
            widgetName = "RUNNER_NEW_JOB",
            widgetData = awolTestJson.parseToJsonElement("""{"job_id": 1}""").jsonObject,
        )
        assertNull(state.toAwolSnapshot(clock, logger))
    }

    @Test
    fun awolKeyNotAnObject_isInactive() {
        val state = RunnerState(
            widgetName = "X",
            widgetData = awolTestJson.parseToJsonElement("""{"awol": "yes"}""").jsonObject,
        )
        assertNull(state.toAwolSnapshot(clock, logger))
    }

    // ── Row: event_id ──────────────────────────────────────────────────────

    @Test
    fun eventId_parsed() {
        assertEquals("evt-42", snapshot(AWOL_BREACH_JSON).eventId)
    }

    @Test
    fun eventId_missingOrEmpty_isNull() {
        assertNull(snapshot("{}").eventId)
        assertNull(snapshot("""{"event_id": ""}""").eventId)
    }

    // ── Row: state (variant + fallback selection only) ─────────────────────

    @Test
    fun state_missingOrUnknown_defaultsToBreach() {
        assertEquals(AwolPhase.BREACH, snapshot("{}").phase)
        assertEquals(AwolPhase.BREACH, snapshot("""{"state": "SOMETHING_NEW"}""").phase)
    }

    @Test
    fun state_reEnteredAndJob_parsed() {
        assertEquals(AwolPhase.RE_ENTERED, snapshot("""{"state": "RE_ENTERED"}""").phase)
        assertEquals(AwolPhase.JOB, snapshot("""{"state": "JOB"}""").phase)
    }

    // ── Row: trigger_at ────────────────────────────────────────────────────

    @Test
    fun triggerAt_parsed_toDeadlineMillis() {
        assertEquals(1_783_000_500_000L, snapshot(AWOL_BREACH_JSON).deadlineMillis)
    }

    @Test
    fun triggerAt_missing_deadlineNull_remainingKept() {
        val s = snapshot("""{"countdown": {"remaining_seconds": 120}}""")
        assertNull(s.deadlineMillis)
        assertEquals(120, s.remainingSeconds)
    }

    @Test
    fun triggerAt_unparseable_deadlineNull_andLogged() {
        val local = FakeLogger()
        val s = awolEnvelope("""{"countdown": {"trigger_at": "not-a-date"}}""")
            .toAwolSnapshot(clock, local)
        assertNull(s?.deadlineMillis)
        assertTrue(local.entries.any { it.level == FakeLogger.Level.WARN })
    }

    // ── Row: total_seconds ─────────────────────────────────────────────────

    @Test
    fun totalSeconds_missing_defaultsTo300() {
        assertEquals(AwolSnapshot.DEFAULT_TOTAL_SECONDS, snapshot("{}").totalSeconds)
    }

    @Test
    fun totalSeconds_parsed_andStringTolerated() {
        assertEquals(900, snapshot(AWOL_BREACH_JSON).totalSeconds)
        assertEquals(600, snapshot("""{"countdown": {"total_seconds": "600"}}""").totalSeconds)
    }

    // ── Row: red_cards_total ───────────────────────────────────────────────

    @Test
    fun redCardsTotal_missing_defaultsToZero() {
        assertEquals(0, snapshot("{}").redCardsTotal)
    }

    @Test
    fun redCardsTotal_parsed() {
        assertEquals(1, snapshot(AWOL_BREACH_JSON).redCardsTotal)
    }

    // ── Row: penalty rate ──────────────────────────────────────────────────

    @Test
    fun penaltyRate_shownOnBreach() {
        // BREACH shows the penalty-rate strip (Figma §2A).
        assertTrue(snapshot("{}").showPenaltyRate)
    }

    @Test
    fun penaltyRate_hiddenOnNonBreach() {
        assertFalse(snapshot("""{"state": "RE_ENTERED"}""").showPenaltyRate)
        assertFalse(snapshot("""{"state": "JOB"}""").showPenaltyRate)
    }

    @Test
    fun penaltyRateCount_fromWarningParams() {
        // Count = the "N red cards will be added" number already in the warning's params,
        // so the strip's count is dynamic without a backend change and matches the warning.
        val s = snapshot("""{"warning_text": {"params": {"red_cards": 2}}}""")
        assertEquals(2, s.penaltyRateCount)
    }

    @Test
    fun penaltyRateCount_missing_isNull_forStripFallback() {
        // No count in the payload (legacy hoods) → null, so the UI uses the AwolStrings copy.
        assertNull(snapshot("{}").penaltyRateCount)
    }

    @Test
    fun penaltyRateCount_zero_isNull_forStripFallback() {
        // A 0 count would render a literal "0" capsule — normalized to null in the
        // mapper so the UI falls back to the AwolStrings copy, same as a missing count.
        val s = snapshot("""{"warning_text": {"params": {"red_cards": 0}}}""")
        assertNull(s.penaltyRateCount)
    }

    // ── Row: hotspot lat/lng ───────────────────────────────────────────────

    @Test
    fun hotspot_missing_isNull() {
        assertNull(snapshot("{}").hotspot)
    }

    @Test
    fun hotspot_withoutCoordinates_hidesDirections() {
        val s = snapshot("""{"hotspot": {"name": "HSR Layout"}}""")
        assertEquals("HSR Layout", s.hotspot?.name)
        assertFalse(s.hotspot!!.hasCoordinates)
    }

    @Test
    fun hotspot_withCoordinates_showsDirections() {
        val s = snapshot(AWOL_BREACH_JSON)
        assertTrue(s.hotspot!!.hasCoordinates)
        assertEquals(12.91, s.hotspot?.latitude)
        assertEquals(77.64, s.hotspot?.longitude)
    }

    // ── Row: texts ─────────────────────────────────────────────────────────

    @Test
    fun texts_missing_fallBackToBundledStrings_perPhase() {
        val breach = snapshot("{}")
        assertEquals(strings.breachTitle, breach.titleText)
        assertEquals(strings.breachWarning, breach.warningText)
        assertEquals(strings.breachBadge, breach.badgeText)

        val reEntered = snapshot("""{"state": "RE_ENTERED"}""")
        assertEquals(strings.reEnteredTitle, reEntered.titleText)
        assertEquals(strings.reEnteredWarning, reEntered.warningText)
        assertEquals(strings.reEnteredBadge, reEntered.badgeText)

        val job = snapshot("""{"state": "JOB"}""")
        assertEquals(strings.jobTitle, job.titleText)
        assertEquals(strings.jobWarning, job.warningText)
        assertEquals(strings.jobBadge, job.badgeText)
    }

    @Test
    fun texts_defaultString_withParamInterpolation() {
        val s = snapshot(AWOL_BREACH_JSON)
        // Title still renders the server `default` with `{{param}}` interpolation.
        assertEquals("Return to HSR Layout within", s.titleText)
        // BREACH warning is client-owned (derived from warning_text.params.red_cards —
        // absent in this legacy-shaped fixture, so the generic fallback applies), but
        // the badge is server-driven: the payload's badge_text ("HOTSPOT BREACH") wins.
        assertEquals(strings.breachWarning, s.warningText)
        assertEquals("HOTSPOT BREACH", s.badgeText)
    }

    // ── Breach badge is server-driven (payload badge_text wins) ────────────

    @Test
    fun breachBadge_usesPayloadBadgeText() {
        val s = snapshot(
            """{"state": "BREACH", "badge_text": {"key": "k", "default": "HOTSPOT BREACH"}}""",
        )
        assertEquals("HOTSPOT BREACH", s.badgeText)
    }

    @Test
    fun nonBreachBadge_stillPrefersPayload() {
        val s = snapshot(
            """{"state": "RE_ENTERED", "badge_text": {"key": "k", "default": "CUSTOM BADGE"}}""",
        )
        assertEquals("CUSTOM BADGE", s.badgeText)
    }

    // ── B2/B3: breach warning derives from the pending red-card count ──────

    @Test
    fun breachWarning_generic_whenParamsAbsent() {
        // No warning_text.params (legacy hoods) → the generic bundled warning,
        // ignoring the server's rendered warning_text default.
        val s = snapshot(
            """{"state": "BREACH", "red_cards_total": 3,
               "warning_text": {"key": "k", "default": "server warning"}}""",
        )
        assertEquals(strings.breachWarning, s.warningText)
    }

    @Test
    fun breachWarning_generic_whenParamsCountIsZero() {
        // params.red_cards == 0 → nothing pending this step → the generic bundled warning.
        val s = snapshot(
            """{"state": "BREACH",
               "warning_text": {"key": "k", "default": "server warning",
               "params": {"red_cards": 0}}}""",
        )
        assertEquals(strings.breachWarning, s.warningText)
    }

    @Test
    fun breachWarning_dynamicSingular_whenOneRedCardPending() {
        val s = snapshot(
            """{"state": "BREACH",
               "warning_text": {"key": "k", "default": "server warning",
               "params": {"red_cards": 1}}}""",
        )
        assertEquals("Return in time or 1 red card will be added", s.warningText)
        assertEquals(strings.redCardsPendingWarningOf(1), s.warningText)
    }

    @Test
    fun breachWarning_dynamicPlural_whenMultipleRedCardsPending() {
        val s = snapshot(
            """{"state": "BREACH",
               "warning_text": {"key": "k", "default": "server warning",
               "params": {"red_cards": 3}}}""",
        )
        assertEquals("Return in time or 3 red cards will be added", s.warningText)
        assertEquals(strings.redCardsPendingWarningOf(3), s.warningText)
    }

    @Test
    fun breachWarning_tracksParamsCount_notRedCardsTotal() {
        // The lifetime received balance (red_cards_total → the pill) and the per-step
        // pending count (params.red_cards → warning + strip) diverge here: the warning
        // must follow params, never the total.
        val s = snapshot(
            """{"state": "BREACH", "red_cards_total": 7,
               "warning_text": {"key": "k", "default": "server warning",
               "params": {"red_cards": 2}}}""",
        )
        assertEquals(strings.redCardsPendingWarningOf(2), s.warningText)
        assertEquals(2, s.penaltyRateCount)
        assertEquals(7, s.redCardsTotal)
    }

    @Test
    fun texts_blankDefault_fallsBack() {
        val s = snapshot("""{"title": {"key": "k", "default": ""}}""")
        assertEquals(strings.breachTitle, s.titleText)
    }

    @Test
    fun texts_unresolvedParam_leftVerbatim() {
        val s = snapshot("""{"title": {"key": "k", "default": "Back in {{mins}} min", "params": {}}}""")
        assertEquals("Back in {{mins}} min", s.titleText)
    }

    @Test
    fun texts_doubleBraceParam_interpolated() {
        // App-wide contract is `{{param}}` (Dart LanguageProvider.getFormattedMessage
        // + server templates). Single-brace replacement previously left the outer
        // braces, rendering e.g. `{once}` for the re-entered warning.
        // RE_ENTERED (not BREACH) so warning_text is server-preferred — BREACH derives
        // its warning from the pending red-card param and ignores the payload text.
        val s = snapshot(
            """{"state": "RE_ENTERED",
               "warning_text": {"key": "awol_re_entered_warning",
               "default": "You exited the hotspot {{breach_count_text}} today.",
               "params": {"breach_count_text": "once"}}}""",
        )
        assertEquals("You exited the hotspot once today.", s.warningText)
    }

    // ── Row: anything else — never throws ──────────────────────────────────

    @Test
    fun garbageTypesEverywhere_neverThrows() {
        val s = snapshot(
            """
            {"event_id": 12, "state": 5, "breach_count": "x", "detected_at": [],
             "countdown": "later", "hotspot": [1], "title": "plain",
             "consequences": {"a": 1}, "image_url": {}, "red_cards_total": "many",
             "penalty_rate": [], "badge_text": 9}
            """.trimIndent(),
        )
        assertNotNull(s)
        assertEquals(AwolPhase.BREACH, s.phase)
        assertNull(s.deadlineMillis)
        assertEquals(0, s.redCardsTotal)
        assertTrue(s.consequences.isEmpty())
        assertNull(s.imageUrl)
    }

    // ── Full payload ───────────────────────────────────────────────────────

    @Test
    fun fullPayload_parsesEveryField() {
        val s = snapshot(AWOL_BREACH_JSON)
        assertEquals("evt-42", s.eventId)
        assertEquals(AwolPhase.BREACH, s.phase)
        assertEquals(240, s.remainingSeconds)
        assertEquals(900, s.totalSeconds)
        assertEquals(2, s.breachCount)
        assertEquals(1_782_999_600_000L, s.detectedAtMillis)
        assertEquals("https://img/map.png", s.imageUrl)
        assertEquals(2, s.consequences.size)
        assertEquals("Red card", s.consequences[0].text)
        assertEquals("Blocked for 4 hours", s.consequences[1].text)
        assertEquals("https://img/c1.png", s.consequences[0].iconUrl)
    }

    @Test
    fun consequences_nonObjectEntries_dropped() {
        val s = snapshot("""{"consequences": [1, "x", {"icon_url": "u"}]}""")
        assertEquals(1, s.consequences.size)
        assertNull(s.consequences[0].text)
    }

    // ── hasAwolPayload (the launcher's deterministic trigger) ──────────────

    @Test
    fun hasAwolPayload_trueOnlyForAnAwolObject() {
        assertTrue(awolEnvelope("{}").hasAwolPayload())
        assertTrue(awolEnvelope(AWOL_BREACH_JSON).hasAwolPayload())

        assertFalse((null as RunnerState?).hasAwolPayload())
        assertFalse(RunnerState(widgetName = "X", widgetData = null).hasAwolPayload())
        assertFalse(
            RunnerState(
                widgetName = "X",
                widgetData = awolTestJson.parseToJsonElement("""{"job_id": 1}""").jsonObject,
            ).hasAwolPayload(),
        )
        // Non-object awol value → not a payload (same rule as the mapper).
        assertFalse(
            RunnerState(
                widgetName = "X",
                widgetData = awolTestJson.parseToJsonElement("""{"awol": "yes"}""").jsonObject,
            ).hasAwolPayload(),
        )
    }

    private fun snapshot(awolJson: String): AwolSnapshot =
        awolEnvelope(awolJson).toAwolSnapshot(clock, logger, strings)
            ?: error("expected snapshot for $awolJson")
}
