package com.snabbit.runner.shared.core.realtime

/**
 * Connection state of the realtime transport, modelled in commonMain so the
 * engine (WS3) and tests never see client-library types (LLD §5.6: HiveMQ
 * types must not leak above androidMain).
 */
sealed interface TransportState {
    data object Idle : TransportState
    data object Connecting : TransportState
    data object Connected : TransportState

    /** Dropped; the transport's built-in backoff+jitter is retrying. */
    data object Reconnecting : TransportState

    /** Dropped and NOT auto-retrying (policy said stop — see [DisconnectReason]). */
    data class Disconnected(val reason: DisconnectReason) : TransportState
}

/**
 * MQTT 5 server-disconnect reasons that drive the reconnect policy
 * (LLD §6.1). Our own sealed type: the transport maps client-library
 * reason codes into these; everything above androidMain branches on this.
 */
sealed interface DisconnectReason {
    /** 0x8E — another connection with the same client id took the session. Stop reconnecting. */
    data object SessionTakenOver : DisconnectReason

    /** 0x87 — token rejected. Refresh the JWT, then reconnect (engine policy). */
    data object NotAuthorized : DisconnectReason

    /** Broker/administrative kick (force-disconnect on logout/suspend). Honour it. */
    data object AdministrativeAction : DisconnectReason

    /** Socket-level drop with no DISCONNECT packet — network blip, broker restart, dead zone. */
    data class Network(val message: String?) : DisconnectReason

    /** Any other reason-coded disconnect. */
    data class Other(val code: String, val message: String?) : DisconnectReason
}

/**
 * Stable, R8-proof telemetry name — NEVER `::class.simpleName` for an analytics value.
 *
 * The release build runs `minifyEnabled true` with no keep rules for these classes, so reflection
 * on the class name yields the OBFUSCATED name. Production `mqtt_stopped` has been reporting
 * `reason` values of "m" (58) and "i" (5) for exactly this reason — the property has never been
 * readable. (`HomeViewModel` carries the same warning about `intent::class.simpleName`; this is the
 * same trap, one file over.)
 */
fun DisconnectReason.telemetryName(): String = when (this) {
    DisconnectReason.SessionTakenOver -> "session_taken_over"
    DisconnectReason.NotAuthorized -> "not_authorized"
    DisconnectReason.AdministrativeAction -> "administrative_action"
    is DisconnectReason.Network -> "network"
    is DisconnectReason.Other -> "other"
}

/** An inbound MQTT publish, decoded to the fields the engine cares about. */
data class TransportMessage(
    val topic: String,
    val payload: String,
    val retained: Boolean,
)
