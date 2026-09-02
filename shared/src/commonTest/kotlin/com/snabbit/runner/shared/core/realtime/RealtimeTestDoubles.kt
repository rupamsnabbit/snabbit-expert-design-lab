package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.connectivity.ConnectivityStatus
import com.snabbit.runner.shared.core.connectivity.NetworkMonitor
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject

class FakeRealtimeTransport : RealtimeTransport {
    private val _state = MutableStateFlow<TransportState>(TransportState.Idle)
    override val state: StateFlow<TransportState> = _state
    private val _messages = MutableSharedFlow<TransportMessage>(extraBufferCapacity = 16)
    override val messages: SharedFlow<TransportMessage> = _messages

    val connectCalls = mutableListOf<RealtimeConfig>()
    var disconnectCount = 0

    override fun connect(config: RealtimeConfig) { connectCalls += config }
    override fun disconnect() { disconnectCount++; _state.value = TransportState.Idle }

    fun setState(state: TransportState) { _state.value = state }
    suspend fun emit(message: TransportMessage) { _messages.emit(message) }
}

class RecordingSink : SnapshotSink {
    val applied = mutableListOf<Pair<SnapshotEnvelope, SnapshotSource>>()
    override fun onApplied(envelope: SnapshotEnvelope, source: SnapshotSource) {
        applied += envelope to source
    }
}

class RecordingPostActionReporter : PostActionReporter {
    val fired = mutableListOf<Triple<String, Long, String>>()

    /** Action + timeout only — for assertions that predate the `status` dimension. */
    val firedActions: List<Pair<String, Long>> get() = fired.map { it.first to it.second }

    override fun onFallbackFired(action: String, timeoutMs: Long, status: String) {
        fired += Triple(action, timeoutMs, status)
    }
}

class RecordingOutcomeReporter : PostActionOutcomeReporter {
    data class Finished(
        val action: String,
        val rungsRun: Int,
        val waitedMs: Long,
        val resolved: Boolean,
        val status: String,
    )

    val finished = mutableListOf<Finished>()

    override fun onLadderFinished(
        action: String,
        rungsRun: Int,
        waitedMs: Long,
        resolved: Boolean,
        status: String,
    ) {
        finished += Finished(action, rungsRun, waitedMs, resolved, status)
    }
}

class RecordingDiscardReporter : SnapshotDiscardReporter {
    val discarded = mutableListOf<Triple<Long, Long, SnapshotSource>>()
    override fun onDiscarded(candidateSeq: Long, currentSeq: Long, source: SnapshotSource) {
        discarded += Triple(candidateSeq, currentSeq, source)
    }
}

class FakeFetcher(var result: SnapshotEnvelope? = null) : CurrentStateFetcher {
    var calls = 0
    /** When set, fetch suspends until completed — for dedupe tests. */
    var gate: CompletableDeferred<Unit>? = null
    override suspend fun fetch(): SnapshotEnvelope? {
        calls++
        gate?.await()
        return result
    }
}

class FakeCredentials(var next: String? = "fresh-jwt") : CredentialsProvider {
    var calls = 0
    override suspend fun freshJwt(): String? { calls++; return next }
}

class FakeNetworkMonitor(initial: ConnectivityStatus = ConnectivityStatus.Online) : NetworkMonitor {
    private val _status = MutableStateFlow(initial)
    override val status: StateFlow<ConnectivityStatus> = _status
    fun set(status: ConnectivityStatus) { _status.value = status }
}

fun testConfig() = RealtimeConfig(
    host = "test", clientId = "c1", stateTopic = "maestro/user/1/state",
    username = "1", password = "jwt-0",
)

fun testTuning() = EngineTuning(
    retainedWaitMs = 5_000, degradedAfterMs = 30_000, degradedIntervalMs = 60_000,
    jitterMs = { 0L },
)

fun widgetJson(name: String = "SPIKE", seq: Long = 0): JsonObject = buildJsonObject {
    put("widget_name", name)
    putJsonObject("widget_data") { put("seq", seq) }
}

/**
 * [widgetTag] defaults to [seq] so the widget moves with the seq (the common case). Pass it
 * explicitly to decouple them and model what production actually does: `state_seq` is minted when
 * the backend computes a response, so a fetch during an untransitioned action returns a NEWER seq
 * carrying the SAME widget — `envelope(seq = 6, widgetTag = 5)`.
 */
fun envelope(seq: Long, epoch: Long = 0, schema: Int = 1, name: String = "SPIKE", widgetTag: Long = seq) =
    SnapshotEnvelope(schemaVersion = schema, epoch = epoch, stateSeq = seq, widget = widgetJson(name, widgetTag))

/** [widgetTag] decouples the widget from the seq — see [envelope]. */
fun message(
    seq: Long,
    epoch: Long = 0,
    schema: Int = 1,
    retained: Boolean = true,
    widgetTag: Long = seq,
) = TransportMessage(
    topic = "maestro/user/1/state",
    payload = """{"event_type":"STATE_SNAPSHOT","schema_version":$schema,"epoch":$epoch,"state_seq":$seq,"widget":{"widget_name":"SPIKE","widget_data":{"seq":$widgetTag}},"ts":1}""",
    retained = retained,
)
