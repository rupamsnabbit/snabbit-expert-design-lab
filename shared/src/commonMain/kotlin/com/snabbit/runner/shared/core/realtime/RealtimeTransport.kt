package com.snabbit.runner.shared.core.realtime

import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * The transport seam (LLD §5.2/§5.6): a deliberately thin interface so that
 *  - the engine (WS3) is testable in commonTest against a fake, and
 *  - the concrete client (HiveMQ today) stays swappable behind it.
 *
 * A plain interface — not expect/actual — so the iOS targets keep compiling
 * with no actual required. Construction happens platform-side.
 *
 * Contract owned by this interface (LLD §5.6): retained delivery surfaces via
 * [TransportMessage.retained]; resubscribe-after-reconnect is the transport's
 * job; reconnect backoff+jitter is the transport's job; credential refresh
 * before (re)connect is the caller's job via [connect]'s config.
 */
interface RealtimeTransport {
    val state: StateFlow<TransportState>
    val messages: SharedFlow<TransportMessage>

    /** Opens the connection and subscribes to [RealtimeConfig.stateTopic] (QoS 1). Idempotent. */
    fun connect(config: RealtimeConfig)

    /** Graceful teardown. Safe to call when not connected. */
    fun disconnect()
}
