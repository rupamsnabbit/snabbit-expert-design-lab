package com.snabbit.runner.shared.core.network

/**
 * Network/transport error categories. Wire values mirror the Dart enum in
 * `lib/services/globals.dart` (e.g. `noInternet`, `serverDown`) so the
 * Kotlin pipeline produces the same strings the Dart side already handles.
 *
 * See KMP_NETWORK_MODULE_LLD §7.3.
 */
enum class AppErrorType(val wireValue: String) {
    NONE("none"),
    NO_INTERNET("noInternet"),
    SERVER_DOWN("serverDown"),
    /**
     * TLS / certificate failure (handshake error, expired cert, hostname
     * mismatch, pinning violation, potential MITM). Distinct from
     * [INVALID_REQUEST] because it is a transport-security signal, not
     * user-input invalidity — different operational meaning, different
     * user message, and worth surfacing to alerting on its own channel.
     */
    SECURITY_ERROR("securityError"),
    INVALID_REQUEST("invalidRequest"),
    OTHER_ERROR("otherError");

    companion object {
        fun fromWireValue(value: String): AppErrorType =
            entries.firstOrNull { it.wireValue == value } ?: OTHER_ERROR
    }
}
