package com.snabbit.runner.shared.features.tiering.presentation

import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.tiering.domain.model.NudgeTheme
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.domain.model.TierNudge
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull

/** Resolved title copy + leading icon for a nudge (the KMP port of Flutter `_copyFor`). */
data class TierNudgeCopy(
    val titleKey: String,
    val title: String,
    val iconUrl: String,
)

/**
 * Per-`nudge_name` title copy + icon, resolved through the [LocalizationStore]
 * (mirrors Flutter `_copyFor` + `getFormattedMessage`). The localization key is
 * `tiering_nudge_<name>` (identical to Flutter); the English fallback carries the
 * `{{tier}}` / `{{amount}}` placeholders and [store] substitutes them from the
 * per-nudge values — so a bundled translation interpolates exactly as on Flutter,
 * and today (keys absent) the same English text renders. The icon is the tier badge
 * for a `TIER_SPECIFIC` theme, else the nudge's dedicated asset, falling back to the
 * wire `image_url`. An unknown name → the raw name as both key and title (Flutter
 * default branch).
 */
fun tierNudgeCopy(nudge: TierNudge, tier: Tier?, store: LocalizationStore): TierNudgeCopy {
    val name = nudge.nudgeName.orEmpty()
    val icon = iconUrl(nudge, tier, name)
    val spec = copySpec(name, tier, nudge.nudgeDetails)
        // Unknown nudge_name → raw name as both key and fallback (Flutter default branch).
        ?: return TierNudgeCopy(titleKey = name, title = store.getMessage(name, name), iconUrl = icon)
    return TierNudgeCopy(
        titleKey = spec.key,
        title = store.getFormattedMessage(spec.key, spec.fallback, spec.values),
        iconUrl = icon,
    )
}

/**
 * True when [name] matches none of the client's known nudge cases — the dynamic /
 * default path (its icon is the wire `image_url` and its title is the localized raw
 * [name], vs the client-owned asset/copy the known names get). Used to gate the icon
 * tint: a known nudge's monochrome glyph always tints, a dynamic nudge tints only when
 * the wire carried a theme. Reuses [copySpec] as the single source of the known-name
 * set, so the two can't drift. `THE_COIN_NUDGE` also has no [copySpec] entry, but it is
 * handled as its own render variant upstream and never reaches the dynamic branch.
 */
internal fun isDynamicNudge(name: String?): Boolean =
    !name.isNullOrBlank() && copySpec(name, tier = null, details = null) == null

/** (`tiering_nudge_*` key, English fallback with `{{token}}`s, token values) per
 *  `nudge_name` — the KMP port of Flutter `_copyFor`. Null → unknown name. */
private fun copySpec(name: String, tier: Tier?, details: JsonObject?): CopySpec? {
    val fallback: String
    var values: Map<String, String> = emptyMap()
    when (name) {
        "LAUNCH" -> fallback = "See how Levels work"
        "SHOWING_TIER" -> {
            fallback = "Congratulations! You are a {{tier}} expert"
            values = mapOf("tier" to (tier?.displayName ?: ""))
        }
        "WEEKLY_TIER_SUMMARY" -> fallback = "See this week's rewards"
        "EARLY_CHECK_IN" -> fallback = "Check in early to earn Snabbit Coins"
        "PERFECT_JOB" -> fallback = "Do a perfect job to earn Snabbit Coins"
        "PERFECT_JOBS" -> fallback = "Do perfect jobs to earn more Snabbit Coins"
        "ATTENDANCE_STREAK" -> fallback = "Maintain streak of attendance to get Snabbit Coins"
        "REFER_AND_EARN" -> fallback = "Refer and earn more"
        "RATE_CARD" -> fallback = "Check your rate card"
        "EARLY_LOGIN" -> fallback = "Login early to get Snabbit coins"
        "INSURANCE_SETUP" -> fallback = "Check your Insurance details"
        "NETWORK_HOSPITALS" -> fallback = "Check our network hospitals"
        "SEVA_ACCESS" -> fallback = "Explore Seva spaces near you"
        "LOAN_ELIGIBLE" -> {
            fallback = "Did you know? You're eligible for a {{amount}} loan"
            values = mapOf("amount" to amount(details, "loan_amount"))
        }
        "HEALTH_INSURANCE_CASHLESS" -> fallback = "Use cashless treatment at partner hospitals"
        "ACCIDENTAL_INSURANCE" -> {
            fallback = "Check your Accidental Cover of {{amount}}"
            values = mapOf("amount" to amount(details, "insurance_amount"))
        }
        "EARLY_PAYOUT" -> fallback = "You can take early payout without interest"
        // Benefits with no backend enum yet — best-guess names (reconcile with backend).
        "LUNCH_FLEXIBILITY" -> fallback = "Set your lunch slot for this week"
        "PATH_TO_PROMOTION" -> fallback = "You're eligible — apply to become a Trainer or Lead"
        "RED_CARD_WAIVER" -> fallback = "Do you know? You can waive some red cards"
        "PRIORITY_SUPPORT" -> fallback = "Your issues now get priority, call saathi"
        "MERCH_DISCOUNT" -> fallback = "Your merch discount is live, shop now"
        "BIRTHDAY_GIFT" -> fallback = "You get birthday gift if you're pink diamond"
        "WELCOME_VOUCHERS" -> fallback = "You get gift voucher on becoming pink diamond expert"
        else -> return null
    }
    return CopySpec("tiering_nudge_${name.lowercase()}", fallback, values)
}

private data class CopySpec(val key: String, val fallback: String, val values: Map<String, String>)

/** TIER_SPECIFIC → the tier badge; else the nudge's dedicated icon; else the wire `image_url`. */
private fun iconUrl(nudge: TierNudge, tier: Tier?, name: String): String {
    if (nudge.theme == NudgeTheme.TIER_SPECIFIC) {
        val badge = tier?.let { TierAssets.badgeUrl(it) }.orEmpty()
        return badge.ifEmpty { nudge.imageUrl.orEmpty() }
    }
    return TierAssets.iconUrl(iconFile(name)).ifEmpty { nudge.imageUrl.orEmpty() }
}

private fun iconFile(name: String): String = when (name) {
    "LAUNCH" -> "generic_see_benefits.svg"
    "SHOWING_TIER", "WEEKLY_TIER_SUMMARY" -> "generic_tier_summary.svg"
    "PERFECT_JOBS", "ATTENDANCE_STREAK", "REFER_AND_EARN", "RATE_CARD", "EARLY_LOGIN" -> "motivation_rank.svg"
    "INSURANCE_SETUP", "NETWORK_HOSPITALS", "HEALTH_INSURANCE_CASHLESS" -> "benefit_health_insurance.svg"
    "SEVA_ACCESS" -> "benefit_seva.svg"
    "LOAN_ELIGIBLE" -> "benefit_loan.svg"
    "ACCIDENTAL_INSURANCE" -> "benefit_accidental.svg"
    "EARLY_PAYOUT" -> "benefit_early_payout.svg"
    "LUNCH_FLEXIBILITY" -> "benefit_lunch.svg"
    "PATH_TO_PROMOTION" -> "benefit_promotion.svg"
    "RED_CARD_WAIVER" -> "benefit_red_card_waiver.svg"
    "PRIORITY_SUPPORT" -> "benefit_customer_priority.svg"
    "MERCH_DISCOUNT" -> "benefit_merch.svg"
    "BIRTHDAY_GIFT" -> "benefit_birthday.svg"
    "WELCOME_VOUCHERS" -> "benefit_vouchers.svg"
    else -> ""
}

/**
 * Read an amount from `nudge_details`: a numeric value → Indian-grouped `₹`
 * currency (mirrors the Flutter `formatIndianCurrency`, e.g. 300000 → "₹3,00,000");
 * a value the backend already formatted (a string) is passed through unchanged.
 */
private fun amount(details: JsonObject?, key: String): String {
    // Tolerant read: a present-but-non-scalar value (object/array) coerces to null via `as?`
    // rather than throwing `.jsonPrimitive` inside the un-runCatching'd VM collector.
    val primitive = details?.get(key) as? JsonPrimitive ?: return ""
    primitive.intOrNull?.let { return "₹${indianGrouped(it)}" }
    return primitive.contentOrNull.orEmpty()
}

/** Indian digit grouping — last three digits, then groups of two: 300000 → "3,00,000". */
private fun indianGrouped(value: Int): String {
    val sign = if (value < 0) "-" else ""
    val digits = if (value == Int.MIN_VALUE) "2147483648" else kotlin.math.abs(value).toString()
    if (digits.length <= 3) return "$sign$digits"
    val last3 = digits.substring(digits.length - 3)
    var rest = digits.substring(0, digits.length - 3)
    val sb = StringBuilder()
    while (rest.length > 2) {
        sb.insert(0, "," + rest.substring(rest.length - 2))
        rest = rest.substring(0, rest.length - 2)
    }
    sb.insert(0, rest)
    return "$sign$sb,$last3"
}
