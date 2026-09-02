package com.snabbit.runner.shared.core.realtime

import com.hivemq.client.mqtt.MqttClient
import com.hivemq.client.mqtt.datatypes.MqttQos
import com.hivemq.client.mqtt.exceptions.ConnectionClosedException
import com.hivemq.client.mqtt.exceptions.ConnectionFailedException
import com.hivemq.client.mqtt.lifecycle.MqttClientDisconnectedContext
import com.hivemq.client.mqtt.lifecycle.MqttDisconnectSource
import com.hivemq.client.mqtt.mqtt5.Mqtt5AsyncClient
import com.hivemq.client.mqtt.mqtt5.exceptions.Mqtt5ConnAckException
import com.hivemq.client.mqtt.mqtt5.exceptions.Mqtt5DisconnectException
import com.hivemq.client.mqtt.mqtt5.lifecycle.Mqtt5ClientReconnector
import com.hivemq.client.mqtt.mqtt5.message.disconnect.Mqtt5DisconnectReasonCode
import com.snabbit.runner.shared.core.Logger
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * HiveMQ-backed [RealtimeTransport] (LLD §5.6 — wrapped, NOT forked).
 *
 * Configuration is verbatim from the LLD:
 *  - MQTT 5, `cleanStart(true)` + `sessionExpiryInterval(0)` — no broker-side
 *    offline queue; freshness comes from the retained snapshot (§6.9).
 *  - JWT as the CONNECT password (§8). Blank credentials = anonymous
 *    (local spike broker only).
 *  - `automaticReconnectWithDefaultConfig()` — exponential backoff with
 *    ±25% jitter is HiveMQ built-in (§6.1).
 *  - Server-disconnect reason codes are mapped to our commonMain
 *    [DisconnectReason]; HiveMQ types never leak past this file.
 *
 * Reconnect policy (§6.1): SESSION_TAKEN_OVER / ADMINISTRATIVE_ACTION stop
 * the auto-reconnect (`reconnector.reconnect(false)`); NOT_AUTHORIZED also
 * stops here in the spike — the engine (WS3) will own the
 * refresh-JWT-then-reconnect branch via `reconnector.connectWith()`.
 *
 * Credentials on reconnect (device-verified 2026-08-04): HiveMQ's automatic
 * reconnect re-sends the stored CONNECT **without** the `simpleAuth` supplied to
 * the initial `connectWith().simpleAuth()...send()` — the reconnect CONNECT is
 * anonymous, so every reconnect that reaches the broker is refused
 * `BAD_USER_NAME_OR_PASSWORD`. [reapplyReconnectAuth] re-supplies username + the
 * freshest JWT ([jwtProvider], falling back to the connect-time password) into each
 * reconnect CONNECT from [onDisconnected].
 */
class HiveMqttTransport(
    private val logger: Logger,
    /**
     * Supplies the freshest JWT for reconnect CONNECTs (read from encrypted storage
     * per attempt) so a token refreshed after login is used. Defaults to none — the
     * anonymous/spike path falls back to the connect-time password.
     */
    private val jwtProvider: () -> String? = { null },
) : RealtimeTransport {

    private val _state = MutableStateFlow<TransportState>(TransportState.Idle)
    override val state: StateFlow<TransportState> = _state.asStateFlow()

    private val _messages = MutableSharedFlow<TransportMessage>(
        extraBufferCapacity = 16,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    override val messages: SharedFlow<TransportMessage> = _messages.asSharedFlow()

    private var client: Mqtt5AsyncClient? = null

    /**
     * Last config passed to [connect] — the disconnected listener runs on HiveMQ's
     * thread, so [reapplyReconnectAuth] reads it there; @Volatile for that hand-off.
     */
    @Volatile
    private var currentConfig: RealtimeConfig? = null

    override fun connect(config: RealtimeConfig) {
        logger.d(
            TAG,
            "connect() ${config.host}:${config.port} tls=${config.useTls} clientId=${config.clientId} " +
                "topic=${config.stateTopic} hasAuth=${config.username.isNotBlank()}",
        )
        if (client != null) {
            logger.w(TAG, "connect() ignored — client already exists (idempotent guard)")
            return
        }
        _state.value = TransportState.Connecting
        currentConfig = config

        var builder = MqttClient.builder()
            .useMqttVersion5()
            .identifier(config.clientId)
            .serverHost(config.host)
            .serverPort(config.port)
            .addConnectedListener {
                logger.d(TAG, "connected — ${config.stateTopic}")
                _state.value = TransportState.Connected
            }
            .addDisconnectedListener { ctx -> onDisconnected(ctx) }
            .automaticReconnectWithDefaultConfig()
        if (config.useTls) {
            builder = builder.sslWithDefaultConfig()
        }
        val built = builder.buildAsync()
        client = built

        val connect = built.connectWith()
            .cleanStart(true)
            .sessionExpiryInterval(0L)
            .keepAlive(config.keepAliveSeconds)
        val sendFuture = if (config.username.isNotBlank()) {
            connect.simpleAuth()
                .username(config.username)
                .password(config.password.encodeToByteArray())
                .applySimpleAuth()
                .send()
        } else {
            connect.send()
        }
        sendFuture.whenComplete { _, error ->
            if (error != null) {
                // Auto-reconnect keeps retrying; state stays Connecting/Reconnecting. The
                // exception type distinguishes a CONNACK auth rejection from a socket drop.
                logger.w(TAG, "initial CONNECT failed: ${error::class.simpleName}: ${error.message}", error)
            } else {
                subscribe(built, config)
            }
        }
    }

    /**
     * Subscribed ONCE, from the initial CONNECT's future — intentionally NOT re-called on
     * reconnect. The HiveMQ client re-issues callback-registered subscriptions itself on an
     * automatic reconnect (independent of `cleanStart`/session — it's a client feature, not a
     * broker session restore), so a reconnect resumes receiving publishes with no explicit
     * re-subscribe. Device-verified: after airplane ON→OFF the retained snapshot lands within
     * ~50ms of reconnect and live `source=MQTT` snapshots keep applying. Do NOT also subscribe
     * from `addConnectedListener` — that would double-register the callback.
     */
    private fun subscribe(client: Mqtt5AsyncClient, config: RealtimeConfig) {
        client.subscribeWith()
            .topicFilter(config.stateTopic)
            .qos(MqttQos.AT_LEAST_ONCE)
            .callback { publish ->
                _messages.tryEmit(
                    TransportMessage(
                        topic = publish.topic.toString(),
                        payload = publish.payloadAsBytes.decodeToString(),
                        retained = publish.isRetain,
                    ),
                )
            }
            .send()
            .whenComplete { _, error ->
                if (error != null) {
                    logger.e(TAG, "SUBSCRIBE failed for ${config.stateTopic}", error)
                } else {
                    logger.d(TAG, "subscribed to ${config.stateTopic} (QoS1, retained on subscribe)")
                }
            }
    }

    private fun onDisconnected(ctx: MqttClientDisconnectedContext) {
        // A USER-initiated disconnect is our own deliberate teardown (disconnect()/engine.stop());
        // HiveMQ won't auto-reconnect it, and disconnect() already set Idle. Bail — flipping to
        // Reconnecting or re-applying auth here would spuriously revive a torn-down transport.
        if (ctx.source == MqttDisconnectSource.USER) {
            logger.d(TAG, "disconnected: USER-initiated (deliberate teardown) — not reconnecting")
            _state.value = TransportState.Idle
            return
        }
        val reason = mapDisconnect(ctx)
        val cause = ctx.cause
        // Which lifecycle point this fired at: CONNACK_REJECTED = broker refused OUR CONNECT
        // (auth); SERVER_DISCONNECT = kicked mid-session; SOCKET_DROPPED = live conn lost;
        // CONNECT_FAILED = never reached the broker (DNS/offline).
        val stage = when (cause) {
            is Mqtt5ConnAckException -> "CONNACK_REJECTED"
            is Mqtt5DisconnectException -> "SERVER_DISCONNECT"
            is ConnectionClosedException -> "SOCKET_DROPPED"
            is ConnectionFailedException -> "CONNECT_FAILED"
            else -> "OTHER"
        }
        // One concise, permanent breadcrumb for field/crash triage. `attempts` climbing while
        // Reconnecting = a stuck loop; `stage`/`reason` say why.
        logger.w(
            TAG,
            "disconnected: stage=$stage reason=$reason source=${ctx.source} " +
                "attempts=${ctx.reconnector.attempts} cause=${cause?.let { it::class.simpleName }}: ${cause?.message}",
        )
        when (reason) {
            is DisconnectReason.SessionTakenOver,
            is DisconnectReason.AdministrativeAction,
            is DisconnectReason.NotAuthorized,
            -> {
                // Policy (§6.1): do not fight the server. Engine decides what's next.
                logger.w(TAG, "$reason → stopping auto-reconnect")
                ctx.reconnector.reconnect(false)
                _state.value = TransportState.Disconnected(reason)
            }
            else -> {
                // Network-ish drop: built-in backoff+jitter keeps retrying and re-establishes the
                // subscription. Surface Reconnecting FIRST so the engine arms its degraded fallback
                // even if the credential re-apply below throws, THEN re-supply credentials into the
                // pending CONNECT (HiveMQ drops them on reconnect — else the broker refuses it).
                _state.value = TransportState.Reconnecting
                reapplyReconnectAuth(ctx)
                logger.d(TAG, "reconnecting (attempt ${ctx.reconnector.attempts})")
            }
        }
    }

    /**
     * Re-supply `simpleAuth` (username + freshest JWT) into the CONNECT HiveMQ's
     * automatic reconnect will send. HiveMQ does NOT retain the credentials from the
     * initial `connectWith().simpleAuth()...send()` — the stored reconnect CONNECT is
     * anonymous — so without this every reconnect that reaches the broker is refused
     * `BAD_USER_NAME_OR_PASSWORD` (device-verified). The JWT is read fresh from
     * [jwtProvider] each attempt so a token refreshed after login is picked up; it falls
     * back to the connect-time password. No-op for the anonymous (spike-broker) path.
     *
     * ⚠️ DO NOT REMOVE / short-circuit this without an equivalent — it is the fix for
     * background-reconnect failing after every drop (PR #593). There is no unit test guarding
     * it (HiveMQ reconnector isn't fakeable here); it was verified on-device. If you touch it,
     * re-run the airplane-ON→OFF test and confirm the reconnect CONNECT still carries auth.
     */
    private fun reapplyReconnectAuth(ctx: MqttClientDisconnectedContext) {
        val cfg = currentConfig ?: return
        if (cfg.username.isBlank()) return // anonymous — no credentials to re-apply
        val reconnector = ctx.reconnector as? Mqtt5ClientReconnector ?: run {
            // Must not be silent — this is the one path the docs above say never to short-circuit.
            logger.e(TAG, "reconnector is ${ctx.reconnector::class.simpleName}, not Mqtt5ClientReconnector — cannot re-apply auth; reconnect may be refused")
            return
        }
        val jwt = jwtProvider()?.takeIf { it.isNotBlank() } ?: cfg.password
        if (jwt.isBlank()) {
            // Both the fresh token and the connect-time password are empty (e.g. logged out) —
            // sending an empty-password CONNECT would just be refused. Skip rather than guarantee it.
            logger.e(TAG, "no credentials for reconnect (jwtProvider + config password both blank) — skipping re-apply")
            return
        }
        // Runs inside HiveMQ's disconnect callback; the client swallows a throw here and would then
        // reconnect with the anonymous stored CONNECT (the exact bug this fixes), so isolate + report
        // rather than let it vanish (repo fail-loud convention).
        try {
            reconnector.connectWith()
                .cleanStart(true)
                .sessionExpiryInterval(0L)
                .keepAlive(cfg.keepAliveSeconds)
                .simpleAuth()
                .username(cfg.username)
                .password(jwt.encodeToByteArray())
                .applySimpleAuth()
                .applyConnect()
            logger.d(TAG, "re-applied simpleAuth to reconnect CONNECT")
        } catch (t: Throwable) {
            logger.e(TAG, "failed to re-apply simpleAuth to reconnect CONNECT — reconnect may be refused", t)
        }
    }

    private fun mapDisconnect(ctx: MqttClientDisconnectedContext): DisconnectReason {
        // A server-sent DISCONNECT surfaces as an Mqtt5DisconnectException carrying the DISCONNECT
        // message (verified on 1.3.6 — no getDisconnect() accessor on the context). ANYTHING else —
        // a socket-level drop OR a CONNACK-refused (re)connect — has no such cause -> Network. We
        // deliberately do NOT special-case CONNACK auth codes into NotAuthorized. This is a trade,
        // not auto-recovery: with credentials re-applied on every reconnect ([reapplyReconnectAuth]),
        // a transient broker refusal is ridden out by auto-reconnect. A genuinely stale token does
        // NOT self-heal over MQTT here — jwtProvider reads a cached token snapshot, so MQTT only
        // returns once something else writes a fresh token to storage (a login / token refresh). What
        // keeps the runner working meanwhile is the engine's degraded HTTP fallback. Routing to
        // NotAuthorized would drop that fallback and strand the runner, so Network is the safer bucket.
        val cause = ctx.cause
        val reasonCode = (cause as? Mqtt5DisconnectException)?.mqttMessage?.reasonCode
            ?: return DisconnectReason.Network(cause?.message)
        return when (reasonCode) {
            Mqtt5DisconnectReasonCode.SESSION_TAKEN_OVER -> DisconnectReason.SessionTakenOver
            Mqtt5DisconnectReasonCode.NOT_AUTHORIZED -> DisconnectReason.NotAuthorized
            Mqtt5DisconnectReasonCode.ADMINISTRATIVE_ACTION -> DisconnectReason.AdministrativeAction
            else -> DisconnectReason.Other(
                code = reasonCode.toString(),
                message = cause.message,
            )
        }
    }

    override fun disconnect() {
        val c = client ?: return
        client = null
        c.disconnect().whenComplete { _, _ ->
            logger.d(TAG, "disconnected (graceful)")
        }
        _state.value = TransportState.Idle
    }

    private companion object {
        const val TAG = "HiveMqttTransport"
    }
}
