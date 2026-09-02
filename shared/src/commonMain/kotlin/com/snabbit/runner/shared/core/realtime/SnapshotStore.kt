package com.snabbit.runner.shared.core.realtime

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Where an applied snapshot came from — telemetry dimension (LLD §9). */
enum class SnapshotSource { MQTT, FETCH, SEED }

/** The persisted row shape (LLD §5.2 `runner_home_state`, minus platform columns). */
data class AppliedSnapshot(
    val epoch: Long,
    val stateSeq: Long,
    val widgetJson: String,
    val source: SnapshotSource,
)

/**
 * Versioned snapshot persistence. ALL ordering is enforced here, in exactly
 * one place: [applyIfNewer] is atomic and applies the candidate iff its
 * [AppliedSnapshot.stateSeq] is strictly greater than what is stored.
 *
 * Ordering is by `state_seq` alone. The backend derives `state_seq` from a
 * Redis-backed monotonic clock that never resets, and it stamps `epoch` with
 * Redis wall-time — so the old epoch-then-seq tie-break (LLD §6.3) would let
 * epoch dominate and defeat the seq check. `epoch` is still parsed and
 * persisted for telemetry, just not used for ordering.
 *
 * WS1 provides the Room-backed implementation behind this same interface;
 * [InMemorySnapshotStore] backs commonTest and the WS0 spike.
 */
interface SnapshotStore {
    suspend fun current(): AppliedSnapshot?

    /**
     * Hot stream of the current snapshot: replays the persisted row on
     * subscription (offline-first first-paint / cold-boot seed, LLD §7) and
     * re-emits on every accepted [applyIfNewer]. This is the read-side seam the
     * DB-as-source-of-truth projection ([RunnerStateProjector]) collects — so
     * the store, not a parallel push, is what feeds the KMP read model.
     */
    fun observe(): Flow<AppliedSnapshot?>

    /** @return true iff the candidate was strictly newer and was stored. */
    suspend fun applyIfNewer(candidate: AppliedSnapshot): Boolean
}

/** Strictly-newer test — by `state_seq` only (backend guarantees a monotonic seq). */
fun isNewer(candidateSeq: Long, currentSeq: Long): Boolean = candidateSeq > currentSeq

class InMemorySnapshotStore : SnapshotStore {
    private val mutex = Mutex()
    // StateFlow is the backing store: .value gives an atomic read for current(),
    // and it replays-to-new-collectors + coalesces equal values for observe().
    private val stored = MutableStateFlow<AppliedSnapshot?>(null)

    override suspend fun current(): AppliedSnapshot? = stored.value

    override fun observe(): Flow<AppliedSnapshot?> = stored.asStateFlow()

    override suspend fun applyIfNewer(candidate: AppliedSnapshot): Boolean = mutex.withLock {
        val cur = stored.value
        if (cur == null || isNewer(candidate.stateSeq, cur.stateSeq)) {
            stored.value = candidate
            true
        } else {
            false
        }
    }
}
