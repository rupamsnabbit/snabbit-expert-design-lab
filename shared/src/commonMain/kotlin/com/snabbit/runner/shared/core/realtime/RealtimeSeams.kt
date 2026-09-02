package com.snabbit.runner.shared.core.realtime

/**
 * Constructor seams for [RealtimeStateEngine] (their production wirings land
 * with WS4; commonTest substitutes fakes — LLD App A test doubles).
 */

/** Receives every snapshot the store accepted (already version-gated). */
fun interface SnapshotSink {
    fun onApplied(envelope: SnapshotEnvelope, source: SnapshotSource)
}

/**
 * Feature #4 fail-loud telemetry: no snapshot for a runner action arrived within the deadline.
 * [action] is the action label (telemetry dimension) so we can see *which* transitions fail to
 * reach us. Production wiring routes this to the analytics tracker; commonTest substitutes a
 * recorder. No-op by default (unwired).
 *
 * [timeoutMs] and [status] are sampled at DIFFERENT moments and can legitimately disagree.
 * [timeoutMs] is the rung that actually lapsed, chosen when the ladder ARMED from the status then
 * (a live connection earns the full deadline; anything else gets the short settle — see
 * `EngineTuning.postActionSettleMs`). [status] is re-read when it LAPSED. So a ladder armed while
 * reconnecting and connected 400ms later emits `(timeout_ms=500, status=connected)`, and the
 * reverse gives a 2s row in a disconnected bucket. Counting by [status] is unaffected — one event
 * per missed action either way — but slicing [timeoutMs] *within* a status will contain a small
 * impurity. Measured transition rate is ~20/runner/day, so the odds of one landing inside a
 * 0.5-2s window are well under 1%; left as-is rather than carrying an extra arm-time dimension.
 *
 * [status] is the engine status at the moment the deadline lapsed (`connected`, `degraded`,
 * `offline`, `poll_only`, …). It exists because this used to fire ONLY on `Connected`: every
 * degraded/offline/poll-only miss was silently uncounted, so the measured miss-rate was a floor of
 * unknown depth — and worse, any change that merely shifted runners between transport states would
 * move the metric without improving anything. Reporting every branch (control flow unchanged — the
 * fetch decision still belongs to the engine) makes the baseline honest enough to measure a fix
 * against.
 */
fun interface PostActionReporter {
    fun onFallbackFired(action: String, timeoutMs: Long, status: String)
}

/**
 * The post-action retry ladder ran to a conclusion. Fires at most once per action that missed its
 * first deadline and says how that miss ENDED, which the fallback event alone never could.
 *
 * **Joining the two events: expect a few unmatched fallbacks, never an unmatched ladder.** A ladder
 * that already reported its miss can still be cancelled outright before reaching this emit, by
 * `stop()` (engine teardown, up to ~33s of remaining rungs) or by a same-action supersede (two
 * `job_accept` post-actions inside one ladder's window ⇒ 2 fallbacks, 1 ladder). Both kill the
 * coroutine, so nothing can run — unlike a kill-switch flip mid-ladder, which stands down
 * gracefully and does emit. The reverse direction cannot happen: this never fires without its
 * fallback, so `ladder ≤ fallback` is the invariant to lean on.
 *
 * [rungsRun] rungs attempted recovery over [waitedMs] of scheduled waiting (fetch time excluded),
 * and [resolved] is whether the state moved before the ladder ran out.
 *
 * Deliberately a RUNG count, not a fetch count. `reconcileNow` coalesces, so one rung can cause
 * zero fetches (another reconcile held the gate and this one queued behind it) or two (its own plus
 * a coalesced follow-up) — "how many fetches did MY trigger cause" has no honest answer under that
 * design. The question this number exists to answer is how far down the ladder recovery had to go
 * before the state moved, and the rung count *is* that; a fetch count would be strictly worse for
 * it, since a coalesced double-fetch on a single rung would inflate it.
 *
 * `resolved=false` at the end of the ladder is the strongest signal available that a transition was
 * genuinely never published: the state was asked for repeatedly, over tens of seconds, and never
 * moved. That is a different owner from "it took 9 seconds", and the single-shot fallback reported
 * both identically.
 *
 * **Known false-positive, and how to spot it.** `resolved` is computed synchronously after the last
 * rung, but `reconcileNow` coalesces: if that rung's fetch queued behind an in-flight reconcile, it
 * returns before the follow-up applies, so a state that lands a beat later is recorded as
 * unresolved. Needs the ladder to reach its final rung AND the gate to be held in that ~300ms AND
 * the transition to arrive in that window, having missed the four fetches before it — so it is rare,
 * and it errs toward making the backend look WORSE, never toward hiding a fault. Left unfixed
 * deliberately: closing it means adding synchronisation to `reconcileNow`, a path shared by every
 * trigger, to correct a label on an action the runner already waited the full ladder for.
 * The signature: a `resolved=false` whose accept ALSO reported
 * `job_accept_resolved{resolved_by=state_transition}` is this edge, not a never-published.
 *
 * **Read `resolved` per [action], never pooled.** "Moved" means the widget changed, so an action
 * whose completion does not alter the rendered state will report `resolved=false` every time —
 * truthfully (nothing moved), but it does NOT mean the backend failed to publish. `house_tasks` is
 * the open question: its sheet and rating reveal are driven entirely by client-local state, and no
 * task/rating field appears in the POST_CHECKOUT widget, so its submission may legitimately change
 * nothing server-side. `attendance` is likely the same shape. Pooling those into an accept-focused
 * "never published" rate would poison it; a uniformly-false action is a signature of this, not of a
 * backend fault. (Intended to be settled from the backend publish log, which is currently absent
 * from Scout for `maestro-core-expert-app` — the first day of this event's data answers it instead.)
 */
fun interface PostActionOutcomeReporter {
    fun onLadderFinished(action: String, rungsRun: Int, waitedMs: Long, resolved: Boolean, status: String)
}

/**
 * A snapshot reached the client but was NOT stored, because its `state_seq` was not strictly newer
 * than what we already hold ([SnapshotStore.applyIfNewer]).
 *
 * This is the single most diagnostic moment in the realtime path and it was invisible: the discard
 * only wrote `logger.d`, which is release-gated to a no-op, so a dropped state left no trace
 * anywhere. With the backend measured publishing post-action snapshots in ~1s, "never delivered"
 * and "delivered then discarded here" are the two remaining explanations for a stalled screen — and
 * they have different owners. This event separates them.
 *
 * **Expect this to be RARE, and near-silent for `source=fetch`.** Review predicted the opposite —
 * that idle polls would flood it — on the assumption that `state_seq` only advances when state
 * changes. It does not: the backend mints it while computing a response, so a fetch essentially
 * always carries a strictly newer seq and wins the gate. Device-verified over a full session:
 * **12 fetches → 12 applied → 0 discarded**, including consecutive idle polls, with seq deltas
 * tracking wall-clock and the 60s poll cadence to the millisecond.
 *
 * The corollary is the honest caveat on this event: because a fetch rarely loses the gate, a low
 * count here is NOT evidence that pushes are arriving intact — it mostly means fetches keep
 * out-stamping them. Read it as an MQTT-side signal (`source=mqtt`) and nothing more.
 */
fun interface SnapshotDiscardReporter {
    fun onDiscarded(candidateSeq: Long, currentSeq: Long, source: SnapshotSource)
}

/** Re-reads the JWT (encrypted storage / re-auth) for the NOT_AUTHORIZED branch (LLD §6.1). */
fun interface CredentialsProvider {
    suspend fun freshJwt(): String?
}

/**
 * The HTTP reconcile: `GET current_state`, mapped into the envelope shape
 * (the response carries the same widget + state_seq — LLD §6.4). Returns
 * null on failure; the engine's trigger policy decides retries.
 */
fun interface CurrentStateFetcher {
    suspend fun fetch(): SnapshotEnvelope?
}

/** Why the engine was externally woken (LLD §6.4 trigger matrix). */
enum class WakeReason { FCM_DATA, APP_FOREGROUND, BRIDGE_WATCHDOG, USER_REFRESH }

/** Why a reconcile ran — telemetry dimension (LLD §9 `source` refinement). */
enum class ReconcileReason { CONNECT_GAP, WAKE, VERSION_GAP, DEGRADED, POLL, POST_ACTION }

/** Engine-level status: transport state + policy overlays (LLD §6.1). */
sealed interface RealtimeStatus {
    data object Idle : RealtimeStatus
    data object Connecting : RealtimeStatus
    data object Connected : RealtimeStatus
    data object Reconnecting : RealtimeStatus

    /** Not connected for a while — HTTP reconcile loop is the data path (LLD §6.4 DEGRADED). */
    data object Degraded : RealtimeStatus

    /**
     * MQTT is disabled app-side by the Firebase Remote Config kill-switch
     * (`expert_mqtt_enabled` = false — feature #1). The transport is never
     * connected; the periodic HTTP reconcile loop (current_state → DB → read
     * model) is the sole data path. Distinct from [Degraded], which is an
     * *involuntary* fallback after a live connection drops — [PollOnly] is a
     * *deliberate, sustained* poll mode we can flip in and out of live.
     */
    data object PollOnly : RealtimeStatus

    /**
     * MQTT is not connected AND the device has no validated internet (feature #2).
     * The HTTP reconcile is futile, so the engine surfaces this instead of polling —
     * the KMP screen shows the offline banner over the last-known (DB) state. Clears
     * to [Degraded]/[Connected] the moment connectivity + the socket recover.
     */
    data object Offline : RealtimeStatus

    /** Server told us to stop (taken over / kicked / auth-refused after refresh). */
    data class Stopped(val reason: DisconnectReason) : RealtimeStatus
}

/**
 * Stable snake_case name for analytics. Deliberately NOT `toString()`: the default rendering of
 * [RealtimeStatus.Stopped] embeds its [DisconnectReason], which would shatter the dimension into
 * unbounded values and make the property useless to group by.
 */
fun RealtimeStatus.telemetryName(): String = when (this) {
    RealtimeStatus.Idle -> "idle"
    RealtimeStatus.Connecting -> "connecting"
    RealtimeStatus.Connected -> "connected"
    RealtimeStatus.Reconnecting -> "reconnecting"
    RealtimeStatus.Degraded -> "degraded"
    RealtimeStatus.PollOnly -> "poll_only"
    RealtimeStatus.Offline -> "offline"
    is RealtimeStatus.Stopped -> "stopped"
}
