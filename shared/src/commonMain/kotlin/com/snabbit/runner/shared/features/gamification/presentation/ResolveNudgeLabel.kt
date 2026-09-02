package com.snabbit.runner.shared.features.gamification.presentation

import com.snabbit.runner.shared.features.gamification.domain.model.NudgeLabel

/**
 * Resolves a [NudgeLabel] to display text — the KMP port of Dart
 * `lib/widgets/gamification/resolve_nudge_label.dart`. Pure (no Compose): the UI
 * calls [resolve] and renders the result (NudgeBanner additionally parses the
 * `**bold**` markers the copy carries).
 *
 * Resolution order, matching Dart:
 *  1. `legacy_literal` → the raw `text` param.
 *  2. server `default_text` (with `{{placeholder}}` params substituted).
 *  3. a client-side English fallback keyed by [NudgeLabel.key].
 *
 * Localisation note: Dart routes 2 & 3 through `LanguageProvider.getFormattedMessage`
 * (server default first, then the app's i18n bundle). KMP has no equivalent
 * bundle wired here yet, so [resolve] performs the same `{{placeholder}}`
 * substitution directly. When a KMP localisation seam lands, swap [substitute]
 * for it without changing call sites.
 */
object ResolveNudgeLabel {

    fun resolve(label: NudgeLabel): String {
        if (label.key == NudgeLabel.LEGACY_LITERAL) {
            return label.params["text"].orEmpty()
        }
        val serverDefault = label.defaultText?.trim()
        if (!serverDefault.isNullOrEmpty()) {
            return substitute(serverDefault, label.params)
        }
        var fallback = englishFallbackFor(label.key)
        // Avoid leaving `{{redCards}}` visible when the BE omits params
        // (tests / older payloads) — mirrors Dart's special case.
        if (label.key == KEY_FALSE_ATTENDANCE && label.params["redCards"] == null) {
            fallback = "**False attendance** — red card penalty may apply"
        }
        return substitute(fallback, label.params)
    }

    /** Replace every `{{name}}` occurrence with `params[name]` (unmatched left as-is, like Dart). */
    private fun substitute(template: String, params: Map<String, String>): String {
        if (params.isEmpty() || !template.contains("{{")) return template
        var out = template
        for ((key, value) in params) {
            out = out.replace("{{$key}}", value)
        }
        return out
    }

    /** Client English fallbacks (port of Dart `_defaultEnglishForNudgeKey`). */
    private fun englishFallbackFor(key: String): String = when (key) {
        "nudge_long_distance_bonus" -> "**Accept long distance job** to earn"
        "nudge_early_checkin" -> "Eligible for Early Checkin"
        "nudge_accept_avoid_penalty" -> "**Accept the job** to avoid penalty"
        "nudge_early_login_earn_before" ->
            "Login before {{deadlineTime}} to earn {{coins}} gold coins"
        KEY_FALSE_ATTENDANCE -> "**False attendance** — **{{redCards}}** red cards penalty"
        "nudge_mark_present_earn" -> "**Mark present** to earn for the jobs you complete"
        "nudge_provisional_absent" -> "**Mark absent** — confirm to continue"
        // Last-resort: BE should always send default_text; empty avoids a raw key leak.
        else -> ""
    }

    private const val KEY_FALSE_ATTENDANCE = "nudge_false_attendance_penalty"
}
