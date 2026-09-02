package com.snabbit.runner.shared.features.tiering

import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Pins the legacy/new tier classification the tiering gates hang off — the release's
 * temporal→state pivot. Two things must never regress:
 *  - `BASIC` is a DISTINCT legacy tier, NOT an alias of the new `BASE`.
 *  - [Tier.isLegacyTier] == {BASIC, PRO, ELITE}; everything else is the new scheme.
 */
class TierTest {

    @Test
    fun `isLegacyTier is exactly BASIC, PRO and ELITE`() {
        val legacy = setOf(Tier.BASIC, Tier.PRO, Tier.ELITE)
        for (tier in Tier.entries) {
            assertEquals(tier in legacy, tier.isLegacyTier, "isLegacyTier wrong for $tier")
        }
    }

    @Test
    fun `new-scheme tiers are not legacy`() {
        assertFalse(Tier.BASE.isLegacyTier)
        assertFalse(Tier.SILVER.isLegacyTier)
        assertFalse(Tier.GOLD.isLegacyTier)
        assertFalse(Tier.DIAMOND.isLegacyTier)
        assertFalse(Tier.PINK_DIAMOND.isLegacyTier)
    }

    @Test
    fun `fromWire keeps BASIC and BASE distinct`() {
        // The load-bearing fix: BASIC (legacy) must NOT collapse into BASE (new base).
        assertEquals(Tier.BASIC, Tier.fromWire("BASIC"))
        assertEquals(Tier.BASE, Tier.fromWire("BASE"))
        assertTrue(Tier.fromWire("BASIC")!!.isLegacyTier)
        assertFalse(Tier.fromWire("BASE")!!.isLegacyTier)
    }

    @Test
    fun `fromWire is case-insensitive and trims`() {
        assertEquals(Tier.PINK_DIAMOND, Tier.fromWire("  pink_diamond  "))
        assertEquals(Tier.GOLD, Tier.fromWire("Gold"))
    }

    @Test
    fun `fromWire returns null for unknown or blank (fail-open handled at call sites)`() {
        assertNull(Tier.fromWire(null))
        assertNull(Tier.fromWire(""))
        assertNull(Tier.fromWire("PLATINUM"))
    }
}
