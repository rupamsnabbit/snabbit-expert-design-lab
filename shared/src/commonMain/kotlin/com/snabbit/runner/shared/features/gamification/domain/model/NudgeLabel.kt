package com.snabbit.runner.shared.features.gamification.domain.model

/**
 * A localisation token — the KMP port of Dart `lib/models/gamification/nudge_label.dart`.
 *
 * A label is either a server-driven `{ key, params, default_text }` triple or a
 * legacy plain string (wrapped as `key == `[LEGACY_LITERAL]`, params = {"text": …}`).
 * [params] values are stringified at parse time so `{{placeholder}}` templating
 * is a pure string substitution. The parser duplicates `red_cards` / `gold_coins`
 * / `deadline_time` into their camelCase forms so Python-style snake_case payloads
 * still satisfy `{{redCards}}`-style templates.
 *
 * Resolution to display text (server `default_text` → client English fallback)
 * lives in the presentation layer (`ResolveNudgeLabel`), matching Dart.
 */
data class NudgeLabel(
    val key: String,
    val params: Map<String, String> = emptyMap(),
    val defaultText: String? = null,
) {
    /** Mirrors Dart `NudgeLabel.isValid`. */
    val isValid: Boolean get() = key.isNotEmpty()

    companion object {
        const val LEGACY_LITERAL = "legacy_literal"

        /** Empty / invalid label — the parse fallback for a null or malformed value. */
        val EMPTY = NudgeLabel(key = "")

        /** Wrap a legacy plain-string title as a literal label. */
        fun literal(text: String): NudgeLabel =
            NudgeLabel(key = LEGACY_LITERAL, params = mapOf("text" to text))
    }
}
