package com.snabbit.runner.shared.features.gamification.data

import com.snabbit.runner.shared.features.gamification.domain.model.NudgeKind
import com.snabbit.runner.shared.features.gamification.domain.model.NudgeLabel
import com.snabbit.runner.shared.features.gamification.domain.model.OutcomeStatus
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class GamificationParserTest {

    private val parser = GamificationParser()

    /** Fixed "now" (≈2025-07) between the past/future expiry fixtures below. */
    private val nowMs = 1_752_000_000_000L
    private val futureExpiry = "2999-01-01T00:00:00Z"
    private val pastExpiry = "2000-01-01T00:00:00Z"

    private fun env(json: String): JsonObject = Json.parseToJsonElement(json).jsonObject

    // ── nudges ────────────────────────────────────────────────────────────────

    @Test
    fun parsesSnakeCaseNudge_withCtaOverrideAndCountdown() {
        val state = parser.parseState(
            env(
                """
                {"pre_action_nudges":[{
                  "lifecycle_action_type":"EARLY_LOGIN",
                  "nudge_kind":"risk",
                  "icon_url":"https://x/icon.png",
                  "label":{"key":"nudge_early_login_avoid_no_show",
                           "params":{"time":"04:00 pm","red_cards":1},
                           "default_text":"Login by 04:00 pm to avoid No Show"},
                  "red_cards":1,
                  "expires_at":"$futureExpiry",
                  "cta_overrides":[{"cta_id":"login","red_cards":1}]
                }]}
                """.trimIndent(),
            ),
            nowMs,
        )
        assertEquals(1, state.nudges.size)
        val nudge = state.nudges.first()
        assertEquals("EARLY_LOGIN", nudge.lifecycleActionType)
        assertEquals(NudgeKind.Risk, nudge.nudgeKind)
        assertEquals(1, nudge.redCards)
        assertTrue(nudge.hasCountdown)
        // param normalization duplicated red_cards -> redCards
        assertEquals("1", nudge.label.params["redCards"])
        // cta override flattened, keyed by lowercase id
        assertEquals(1, state.ctaOverrides["login"]?.redCards)
    }

    @Test
    fun parsesCamelCaseNudge() {
        val state = parser.parseState(
            env(
                """
                {"preActionNudges":[{
                  "lifecycleActionType":"LONG_DISTANCE","nudgeKind":"bonus",
                  "iconUrl":"https://x/i.png","label":{"key":"k","default_text":"d"},
                  "goldCoins":10}]}
                """.trimIndent(),
            ),
            nowMs,
        )
        val nudge = state.nudges.single()
        assertEquals(NudgeKind.Bonus, nudge.nudgeKind)
        assertEquals(10, nudge.goldCoins)
    }

    @Test
    fun nudges_preferWidgetDataOverTopLevel() {
        val state = parser.parseState(
            env(
                """
                {"widget_data":{"pre_action_nudges":[{
                    "lifecycle_action_type":"EARLY_CHECKIN","nudge_kind":"opportunity",
                    "icon_url":"https://x/i.png","label":{"key":"k","default_text":"d"}}]},
                 "pre_action_nudges":[{
                    "lifecycle_action_type":"EARLY_LOGIN","nudge_kind":"risk",
                    "icon_url":"https://x/i.png","label":{"key":"k","default_text":"d"}}]}
                """.trimIndent(),
            ),
            nowMs,
        )
        assertEquals(1, state.nudges.size)
        assertEquals("EARLY_CHECKIN", state.nudges.first().lifecycleActionType)
    }

    @Test
    fun dropsInvalidNudge_missingIconUrl() {
        val state = parser.parseState(
            env(
                """
                {"pre_action_nudges":[{
                  "lifecycle_action_type":"EARLY_LOGIN","nudge_kind":"risk",
                  "label":{"key":"k","default_text":"d"}}]}
                """.trimIndent(),
            ),
            nowMs,
        )
        assertTrue(state.nudges.isEmpty())
    }

    @Test
    fun legacyStringLabel_becomesLiteral() {
        val state = parser.parseState(
            env(
                """
                {"pre_action_nudges":[{
                  "lifecycle_action_type":"EARLY_LOGIN","nudge_kind":"risk",
                  "icon_url":"https://x/i.png","label":"Just do it"}]}
                """.trimIndent(),
            ),
            nowMs,
        )
        val label = state.nudges.single().label
        assertEquals(NudgeLabel.LEGACY_LITERAL, label.key)
        assertEquals("Just do it", label.params["text"])
    }

    // ── sheet warnings ─────────────────────────────────────────────────────────

    @Test
    fun dropsStaleSheetWarning_keepsFresh() {
        val state = parser.parseState(
            env(
                """
                {"sheet_warnings":[
                  {"lifecycle_action_type":"EMERGENCY_LOGOUT","expires_at":"$pastExpiry",
                   "cta_overrides":[{"cta_id":"logout","red_cards":1}]},
                  {"lifecycle_action_type":"FALSE_ATTENDANCE","expires_at":"$futureExpiry",
                   "cta_overrides":[{"cta_id":"mark_absent","red_cards":3}]}
                ]}
                """.trimIndent(),
            ),
            nowMs,
        )
        assertEquals(1, state.sheetWarnings.size)
        assertEquals("FALSE_ATTENDANCE", state.sheetWarnings.first().lifecycleActionType)
    }

    @Test
    fun sheetWarning_withoutExpiry_isKept() {
        val state = parser.parseState(
            env("""{"sheet_warnings":[{"lifecycle_action_type":"EMERGENCY_LOGOUT"}]}"""),
            nowMs,
        )
        assertEquals(1, state.sheetWarnings.size)
    }

    // ── cta override resolution ─────────────────────────────────────────────────

    @Test
    fun ctaOverrides_lastWinsAcrossNudges_lowercaseKey() {
        val state = parser.parseState(
            env(
                """
                {"pre_action_nudges":[
                  {"lifecycle_action_type":"A","nudge_kind":"risk","icon_url":"https://x/i.png",
                   "label":{"key":"k","default_text":"d"},
                   "cta_overrides":[{"cta_id":"Login","red_cards":1}]},
                  {"lifecycle_action_type":"B","nudge_kind":"risk","icon_url":"https://x/i.png",
                   "label":{"key":"k","default_text":"d"},
                   "cta_overrides":[{"cta_id":"login","red_cards":5}]}
                ]}
                """.trimIndent(),
            ),
            nowMs,
        )
        assertEquals(1, state.ctaOverrides.size)
        assertEquals(5, state.ctaOverrides["login"]?.redCards)
    }

    // ── balances ────────────────────────────────────────────────────────────────

    @Test
    fun parsesTotals_dualCasing() {
        assertEquals(
            42,
            parser.parseState(env("""{"gold_coins_total":42,"red_cards_total":3}"""), nowMs).coinsTotal,
        )
        assertEquals(
            7,
            parser.parseState(env("""{"goldCoinsTotal":1,"redCardsTotal":7}"""), nowMs).redCardsTotal,
        )
    }

    @Test
    fun nullEnvelope_isEmptyState() {
        val state = parser.parseState(null, nowMs)
        assertTrue(state.nudges.isEmpty())
        assertTrue(state.sheetWarnings.isEmpty())
        assertEquals(0, state.coinsTotal)
    }

    @Test
    fun totalsAbsent_carryForwardPrevious() {
        val previous = parser.parseState(env("""{"gold_coins_total":61,"red_cards_total":3}"""), nowMs)
        // Envelope drops the gamification siblings (the MQTT/widget case).
        val next = parser.parseState(env("""{"widget_name":"X","widget_data":{}}"""), nowMs, previous)
        assertEquals(61, next.coinsTotal)
        assertEquals(3, next.redCardsTotal)
    }

    @Test
    fun totalsPresent_overridePrevious_includingRealZero() {
        val previous = parser.parseState(env("""{"gold_coins_total":61,"red_cards_total":3}"""), nowMs)
        // A real 0 must win over the carried-forward value (absent ≠ zero).
        val next = parser.parseState(env("""{"gold_coins_total":0,"red_cards_total":9}"""), nowMs, previous)
        assertEquals(0, next.coinsTotal)
        assertEquals(9, next.redCardsTotal)
    }

    // ── post-action outcome ──────────────────────────────────────────────────────

    @Test
    fun parsesPostActionOutcome_rewardWithDeltasAndTotals() {
        val outcome = parser.parsePostActionOutcome(
            env(
                """
                {"post_action_outcome":{
                  "lifecycle_action_type":"EARLY_LOGIN","status":"reward",
                  "title_label":{"key":"k","default_text":"Early login"},
                  "gold_coins":10,"gold_coins_total":52,"icon_url":"https://x/coin.png"}}
                """.trimIndent(),
            ),
        )
        assertTrue(outcome!!.isReward)
        assertEquals(OutcomeStatus.Reward, outcome.status)
        assertEquals(10, outcome.goldCoins)
        assertEquals(52, outcome.goldCoinsTotal)
        assertEquals("https://x/coin.png", outcome.iconUrl)
    }

    @Test
    fun postActionOutcome_waivedStatus_caseInsensitive() {
        val outcome = parser.parsePostActionOutcome(
            env(
                """{"post_action_outcome":{"status":"WAIVED","title_label":{"key":"k","default_text":"d"}}}""",
            ),
        )
        assertTrue(outcome!!.isWaived)
    }

    @Test
    fun postActionOutcome_missingStatus_isNull() {
        assertNull(
            parser.parsePostActionOutcome(
                env("""{"post_action_outcome":{"title_label":{"key":"k","default_text":"d"}}}"""),
            ),
        )
    }

    @Test
    fun postActionOutcome_absent_isNull() {
        assertNull(parser.parsePostActionOutcome(env("""{"foo":1}""")))
        assertNull(parser.parsePostActionOutcome(null))
    }
}
