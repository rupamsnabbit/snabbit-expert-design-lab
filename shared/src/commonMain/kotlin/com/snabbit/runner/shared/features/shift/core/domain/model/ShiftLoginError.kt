package com.snabbit.runner.shared.features.shift.core.domain.model

/**
 * Domain failure modes for the shift-login flow. The data layer collapses
 * `NetworkError` + the server's `SELFIE_VALIDATION_ERROR` payload into these
 * cases so the VM never sees HTTP / Ktor types — it just picks a sheet + message.
 */
sealed interface ShiftLoginError {
    /** No network / DNS / SSL / timeout. */
    data object NoConnection : ShiftLoginError

    /** 401 / 403 — token expired or revoked. */
    data object Unauthorized : ShiftLoginError

    /** 5xx — server is broken. */
    data object Server : ShiftLoginError

    /**
     * 4xx with `errors[].code == "SELFIE_VALIDATION_ERROR"` — codes drive
     * the validation sheet. May be empty if the server returned the marker
     * but no parseable codes.
     */
    data class Validation(val codes: List<SelfieValidationCode>) : ShiftLoginError

    /**
     * Any other 4xx, or unexpected. [serverMessage] is the first non-blank
     * per-item message the response's `errors[]` carried, falling back to the
     * legacy top-level string, when present.
     */
    data class Unknown(
        val statusCode: Int? = null,
        val serverMessage: String? = null,
    ) : ShiftLoginError
}
