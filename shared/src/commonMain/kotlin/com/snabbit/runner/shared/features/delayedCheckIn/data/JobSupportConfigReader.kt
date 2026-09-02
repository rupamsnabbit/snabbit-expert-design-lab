package com.snabbit.runner.shared.features.job.delayedcheckin.data

import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.SupportOption
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/**
 * Decodes the `job_support` slice of the app-config document (mirrored from
 * the Flutter startup fetch via
 * [com.snabbit.runner.shared.core.appconfig.AppConfigStore]) into the FR-11
 * "Call Support Partner" option grid. Never throws — every malformed shape
 * degrades per the Dart defaulting below.
 *
 * Behavioural parity source (Dart, read-only):
 * `JobSupportConfig.fromJson` / `JobSupportOption.fromJson` in
 * `lib/models/job_support/job_support_models.dart`, and the label render in
 * `job_support_bottom_sheet.dart` (`lp.getMessage(label.key, label.default)`):
 *
 *  - [appConfig] null, `job_support` absent / not an object, or `options`
 *    absent / not a list → empty list. (Dart treats a null config as its
 *    "Support details not found" state — the future ViewModel maps an empty
 *    grid to `ConfigMissing` the same way.)
 *  - an entry that isn't an object → dropped (Dart: `whereType<Map>`).
 *  - `id` absent / blank → dropped (Dart: `where((o) => o.id.isNotEmpty)`);
 *    a numeric id is accepted as its string form (Dart: `id?.toString()`).
 *  - `label` as an object → `{key, default}`, resolved through
 *    [resolveLabel] (Dart resolves via `LanguageProvider.getMessage` at
 *    render; the default keeps the English fallback until the ViewModel
 *    passes the language gateway). A blank `key` short-circuits to the
 *    fallback. `label` as a plain string → used verbatim; absent → "".
 *  - `icon_url` absent → null.
 */
fun readJobSupportOptions(
    appConfig: JsonObject?,
    resolveLabel: (key: String, fallback: String) -> String = { _, fallback -> fallback },
): List<SupportOption> {
    val support = appConfig?.get("job_support") as? JsonObject ?: return emptyList()
    val options = support["options"] as? JsonArray ?: return emptyList()
    return options.mapNotNull { entry ->
        val option = entry as? JsonObject ?: return@mapNotNull null
        val id = (option["id"] as? JsonPrimitive)?.contentOrNull.orEmpty()
        if (id.isEmpty()) return@mapNotNull null
        SupportOption(
            id = id,
            label = when (val label = option["label"]) {
                is JsonObject -> {
                    val key = (label["key"] as? JsonPrimitive)?.contentOrNull.orEmpty()
                    // The real backend emits `default_text` (see maestro-core's
                    // TranslatableText payloads); `default` is kept for tolerance
                    // with the Dart model's legacy key.
                    val fallback = (label["default_text"] as? JsonPrimitive)?.contentOrNull
                        ?.takeIf { it.isNotEmpty() }
                        ?: (label["default"] as? JsonPrimitive)?.contentOrNull.orEmpty()
                    if (key.isEmpty()) fallback else resolveLabel(key, fallback)
                }
                is JsonPrimitive -> label.contentOrNull.orEmpty()
                else -> ""
            },
            iconUrl = (option["icon_url"] as? JsonPrimitive)?.contentOrNull,
        )
    }
}
