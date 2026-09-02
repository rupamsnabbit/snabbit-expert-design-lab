package com.snabbit.runner.shared.core.realtime

/**
 * Connection parameters for the realtime (MQTT) transport.
 *
 * Mirrors the `mqtt_config` object delivered in `GET /runners/me`
 * (LLD §3.2 / Appendix C). In production this is parsed from that response
 * and persisted in encrypted storage; the WS0 soak spike populates it from
 * intent extras instead.
 *
 * [password] carries the login JWT (the MQTT CONNECT password). Blank
 * [username]/[password] mean "connect anonymously" — used only against the
 * local spike broker, never in production.
 */
data class RealtimeConfig(
    val host: String,
    val port: Int = 1883,
    val useTls: Boolean = false,
    val username: String = "",
    val password: String = "",
    val clientId: String,
    val stateTopic: String,
    val keepAliveSeconds: Int = 60,
)
