package com.snabbit.runner.shared.features.profile.domain

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * KMP mirror of the Dart `VishwaasBannerRemoteConfig` / `VishwaasLangImageConfig`
 * (RC `expert_vishwaas_banner`, JSON). Parsed from the string flag Flutter pushes
 * across the RC bridge. Only the **drawer** surface is used by the Profile header
 * banner; the sheet is parsed only to match the Dart validity rule.
 *
 * Two shapes (same as Dart):
 *  - **nested**: `{ "drawer": {…}, "provisional_attendance_sheet": {…} }`
 *  - **flat/legacy**: a single `{ "image_by_lang": {…}, … }` applied to both.
 *
 * Pure `commonMain` (kotlinx-serialization) — iOS-safe. Parsing never throws:
 * malformed/empty JSON yields `null` (→ no banner).
 */
data class VishwaasBannerConfig(
    val drawer: VishwaasLangImageConfig?,
    val provisionalAttendanceSheet: VishwaasLangImageConfig?,
) {
    companion object {
        private val json = Json { ignoreUnknownKeys = true; isLenient = true }

        /**
         * Parse the primary config string, falling back to the legacy flat string
         * when primary is empty/invalid (Dart `VishwaasBannerRemoteConfig.load`).
         */
        fun parse(primary: String, legacyFlat: String): VishwaasBannerConfig? =
            tryParse(primary) ?: tryParse(legacyFlat)

        private fun tryParse(raw: String): VishwaasBannerConfig? {
            if (raw.isBlank()) return null
            val obj = runCatching { json.parseToJsonElement(raw) as? JsonObject }.getOrNull() ?: return null
            val hasNested = obj.containsKey("drawer") || obj.containsKey("provisional_attendance_sheet")
            if (hasNested) {
                val d = VishwaasLangImageConfig.tryParse(obj["drawer"] as? JsonObject)
                val p = VishwaasLangImageConfig.tryParse(obj["provisional_attendance_sheet"] as? JsonObject)
                if (d == null && p == null) return null
                return VishwaasBannerConfig(drawer = d, provisionalAttendanceSheet = p)
            }
            val shared = VishwaasLangImageConfig.tryParse(obj) ?: return null
            return VishwaasBannerConfig(drawer = shared, provisionalAttendanceSheet = shared)
        }
    }
}

/** Language-keyed image URLs + optional fallback/action (Dart `VishwaasLangImageConfig`). */
data class VishwaasLangImageConfig(
    val imageByLang: Map<String, String>,
    val fallbackLang: String?,
    val actionUrl: String?,
) {
    /**
     * Picks the image for [languagePreference], else the [fallbackLang], else the
     * first non-empty URL (identical to Dart `resolveImageUrl`). Null when none.
     */
    fun resolveImageUrl(languagePreference: String?): String? {
        if (languagePreference != null) {
            imageByLang[languagePreference]?.takeIf { it.isNotEmpty() }?.let { return it }
        }
        fallbackLang?.let { fb -> imageByLang[fb]?.takeIf { it.isNotEmpty() }?.let { return it } }
        return imageByLang.values.firstOrNull { it.isNotEmpty() }
    }

    companion object {
        fun tryParse(json: JsonObject?): VishwaasLangImageConfig? {
            if (json == null) return null
            val raw = json["image_by_lang"] as? JsonObject ?: return null
            val imageByLang = buildMap {
                raw.forEach { (key, value) ->
                    (value as? JsonPrimitive)?.takeIf { it.isString }?.content?.trim()
                        ?.takeIf { it.isNotEmpty() }?.let { put(key, it) }
                }
            }
            if (imageByLang.isEmpty()) return null
            return VishwaasLangImageConfig(
                imageByLang = imageByLang,
                fallbackLang = json.stringOrNull("fallback_lang"),
                actionUrl = json.stringOrNull("action_url"),
            )
        }

        private fun JsonObject.stringOrNull(key: String): String? =
            (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content?.trim()?.takeIf { it.isNotEmpty() }
    }
}
