package com.snabbit.runner.shared.features.language.domain.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * A selectable language on the Language screen.
 *
 * [code] is the identifier persisted as the runner's `languagePreference`
 * (wire field `obj`). [SerialName]s match the `api/v1/runners/language_list`
 * response so this can double as the deserialization target — the endpoint
 * returns objects that map 1:1 onto this model, so there is no separate DTO
 * layer (see [LanguageDataSourceImpl][com.snabbit.runner.shared.features.language.data.LanguageDataSourceImpl]).
 */
@Serializable
data class LanguageOption(
    @SerialName("obj") val code: String,
    @SerialName("name") val name: String,
    @SerialName("name_native") val nameNative: String,
    @SerialName("icon_text1") val iconText1: String,
    @SerialName("icon_text2") val iconText2: String,
)
