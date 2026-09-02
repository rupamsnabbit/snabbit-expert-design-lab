package com.snabbit.runner.shared.core.realtime

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The post-action recovery ladder's RC parse (feature #4).
 *
 * Every branch here is a fail-safe: this value is authored by hand in the Firebase
 * console during an incident, which is exactly when a typo is most likely and least
 * affordable. Nothing an operator can type may produce an empty or unbounded ladder.
 */
class PostActionLadderTest {

    @Test
    fun bracketedList_isParsed() {
        assertEquals(listOf(2_000L, 4_000L, 8_000L), PostActionLadder.parseMs("[2,4,8]"))
    }

    @Test
    fun bareCsv_isParsed() {
        assertEquals(listOf(2_000L, 4_000L, 8_000L), PostActionLadder.parseMs("2,4,8"))
    }

    @Test
    fun whitespace_isTolerated() {
        assertEquals(listOf(3_000L, 6_000L), PostActionLadder.parseMs("  [ 3 , 6 ]  "))
    }

    @Test
    fun blank_fallsBackToTheShippedLadder() {
        assertEquals(PostActionLadder.DEFAULT_MS, PostActionLadder.parseMs(""))
        assertEquals(PostActionLadder.DEFAULT_MS, PostActionLadder.parseMs("   "))
    }

    @Test
    fun garbage_fallsBackToTheShippedLadder() {
        assertEquals(PostActionLadder.DEFAULT_MS, PostActionLadder.parseMs("fast"))
        assertEquals(PostActionLadder.DEFAULT_MS, PostActionLadder.parseMs("[]"))
    }

    // An all-zero ladder would otherwise mean "one fetch then give up" — a behaviour
    // change wearing a tuning value's clothes.
    @Test
    fun allNonPositiveRungs_fallBackRatherThanDisablingRecovery() {
        assertEquals(PostActionLadder.DEFAULT_MS, PostActionLadder.parseMs("0,0,0"))
        assertEquals(PostActionLadder.DEFAULT_MS, PostActionLadder.parseMs("[-5,-1]"))
    }

    @Test
    fun individuallyMalformedRungs_areDroppedNotFatal() {
        assertEquals(listOf(3_000L, 9_000L), PostActionLadder.parseMs("3,abc,9"))
    }

    @Test
    fun rungs_areClampedToTheBand() {
        assertEquals(
            listOf(PostActionLadder.MIN_RUNG_SECS * 1_000L, PostActionLadder.MAX_RUNG_SECS * 1_000L),
            PostActionLadder.parseMs("1,99999"),
        )
    }

    // Each rung is a fetch on an uncached endpoint, so a long ladder is a load
    // multiplier, not just a slow recovery.
    @Test
    fun rungCount_isCapped() {
        val parsed = PostActionLadder.parseMs("2,2,2,2,2,2,2,2,2,2")

        assertEquals(PostActionLadder.MAX_RUNGS, parsed.size)
    }

    @Test
    fun truncationIsReported() {
        val notes = mutableListOf<String>()

        PostActionLadder.parseMs("2,2,2,2,2,2,2,2", notes::add)

        assertEquals(1, notes.size, notes.toString())
        assertTrue("truncated" in notes[0], notes[0])
    }

    @Test
    fun clampAndDropAreReported() {
        val notes = mutableListOf<String>()

        PostActionLadder.parseMs("99999,abc,5", notes::add)

        assertEquals(2, notes.size, notes.toString())
        assertTrue(notes.any { "unparseable" in it }, notes.toString())
        assertTrue(notes.any { "clamped" in it }, notes.toString())
    }

    @Test
    fun fallbackIsReported_butOnlyForANonBlankValue() {
        val garbage = mutableListOf<String>()
        PostActionLadder.parseMs("nonsense", garbage::add)
        assertTrue(garbage.isNotEmpty(), "an operator typo must not be silent")

        // A blank value is the normal "key not set" state, not a mistake to report.
        val blank = mutableListOf<String>()
        PostActionLadder.parseMs("", blank::add)
        assertEquals(emptyList(), blank)
    }

    @Test
    fun aValidLadder_reportsNothing() {
        val notes = mutableListOf<String>()

        PostActionLadder.parseMs("[2,4,8]", notes::add)

        assertEquals(emptyList(), notes)
    }
}
