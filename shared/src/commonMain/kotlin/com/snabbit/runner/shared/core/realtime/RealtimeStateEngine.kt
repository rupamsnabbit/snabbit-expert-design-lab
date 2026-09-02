package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.connectivity.AlwaysOnlineNetworkMonitor
import com.snabbit.runner.shared.core.connectivity.ConnectivityStatus
import com.snabbit.runner.shared.core.connectivity.NetworkMonitor
import kotlinx.atomicfu.atomic
import kotlinx.atomicfu.getAndUpdate
import kotlinx.atomicfu.update
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject

/**
 * Timing knobs, injectable so commonTest runs on virtual time with
 * deterministic jitter (LLD App A test doubles).
 */
data class EngineTuning(
    /** No retained snapshot within this window after connect ⇒ reconcile (LLD §6.9 step 7). */
    val retainedWaitMs: Long = 5_000,
    /** Not Connected for this long ⇒ DEGRADED: periodic HTTP reconcile (LLD §6.4). */
    val degradedAfterMs: Long = 30_000,
    val degradedIntervalMs: Long = 60_000,
    /** MQTT not Connected within this window of start/re-enable ⇒ fall to the HTTP
     *  poll loop (feature #2 connect-timeout). MQTT keeps auto-reconnecting. */
    val connectTimeoutMs: Long = 25_000,
    /**
     * After a post-action, no newer snapshot applied within this window ⇒ fetch current_state
     * (feature #4 post-action fallback).
     *
     * RC-driven, and the value in play depends on whether RC has landed yet. `pushAppConfig`
     * coerces to `MIN_POST_ACTION_SECONDS` (2s) and persists, so a runner who has ever received an
     * RC push runs 2s. `hydrate` does NOT re-coerce — it does not need to, since only coerced
     * values are ever written — but before the first push there is nothing persisted at all, so a
     * fresh install / cold start runs this 5s default until RC arrives.
     */
    val postActionDeadlineMs: Long = 5_000,
    /**
     * Waits BETWEEN post-action fetches, after the first [postActionDeadlineMs] miss — the retry
     * ladder. Cumulative from the action's 2xx, and note the first rung is [postActionDeadlineMs],
     * NOT a constant: at the RC-pinned 2s that gives fetches at 2s, 5s, 10s, 20s, 35s — but on a
     * pre-RC cold start (5s default) the same list gives 5s, 8s, 13s, 23s, 38s.
     *
     * RC-driven since the network-tuning change: `expert_post_action_retry_ladder_secs`
     * (see [PostActionLadder.KEY_SECS]) reshapes the tail without a store release, clamped per
     * rung and capped at [PostActionLadder.MAX_RUNGS]. This default IS [PostActionLadder.DEFAULT_MS] —
     * one source of truth, so the shipped fallback and the RC-revert value cannot drift apart. Note the first rung is still [postActionDeadlineMs], not
     * a member of this list.
     *
     * Sized against what the first rung can actually see: at 2s the backend has often not
     * transitioned the job yet, so a lone fetch there returns the PRE-action state and the runner
     * is left on a spinner nothing else will clear. The tail rungs exist to outlast that — a
     * post-2xx transition was observed on-device arriving at 29s.
     */
    val postActionRetryDelaysMs: List<Long> = PostActionLadder.DEFAULT_MS,
    /**
     * First-rung wait when MQTT is NOT connected, replacing [postActionDeadlineMs].
     *
     * That deadline buys two different things: grace for MQTT to deliver, and time for the backend
     * to actually transition the job. When the transport isn't Connected the first is worthless —
     * nothing can arrive — but the second still holds: the backend publishes ~0.6-1.1s after the
     * action, so firing at T+0 would just read pre-action state and burn a rung. Hence a short
     * settle rather than either extreme.
     */
    val postActionSettleMs: Long = 500,
    /** Jitter before every reconcile — herd protection on the uncached endpoint (LLD §6.4). */
    val jitterMs: () -> Long = { (0..2_000L).random() },
)

/**
 * The realtime orchestrator (LLD §5.2): owns the transport lifecycle, funnels
 * every snapshot — pushed or fetched — through the ONE version gate
 * ([SnapshotStore.applyIfNewer]), runs the reconcile-trigger matrix (§6.4) and
 * the reason-code policy (§6.1). Pure commonMain: platform pieces arrive via
 * constructor seams; fully testable on fakes + virtual time.
 */
class RealtimeStateEngine(
    private val transport: RealtimeTransport,
    private val store: SnapshotStore,
    private val fetcher: CurrentStateFetcher,
    private val credentials: CredentialsProvider,
    private val sink: SnapshotSink,
    private val scope: CoroutineScope,
    private val logger: Logger,
    private val tuning: EngineTuning = EngineTuning(),
    /** Feature #2: gates the HTTP fallback — Offline ⇒ surface [RealtimeStatus.Offline]
     *  instead of a futile fetch. Defaults to always-online when unwired. */
    private val network: NetworkMonitor = AlwaysOnlineNetworkMonitor,
    /** Feature #4: fail-loud telemetry when the post-action fallback fires. No-op by default. */
    private val postActionReporter: PostActionReporter = PostActionReporter { _, _, _ -> },
    private val discardReporter: SnapshotDiscardReporter = SnapshotDiscardReporter { _, _, _ -> },
    /** Feature #4: how the retry ladder ended (rungs run + resolved). No-op by default. */
    private val postActionOutcomeReporter: PostActionOutcomeReporter =
        PostActionOutcomeReporter { _, _, _, _, _ -> },
) {
    private val _status = MutableStateFlow<RealtimeStatus>(RealtimeStatus.Idle)
    val status: StateFlow<RealtimeStatus> = _status.asStateFlow()

    private var config: RealtimeConfig? = null
    private val started = atomic(false)
    /** Lenient on purpose: only used to slice `widget_name`/`widget_data` out for comparison. */
    private val widgetJson = Json { ignoreUnknownKeys = true; isLenient = true }
    private val reconcileInFlight = atomic(false)
    /** A reconcile trigger arrived while one was fetching — serve it before releasing the gate. */
    private val reconcileFollowUp = atomic(false)
    private val authRefreshAttempted = atomic(false)

    /** True once any snapshot (push or fetch) has been APPLIED since the last connect. */
    private val snapshotSinceConnect = atomic(false)

    private var retainedWaitJob: Job? = null
    private var degradedJob: Job? = null
    /** The poll-only / kill-switch HTTP loop (feature #1); null unless MQTT is disabled app-side. */
    private var pollJob: Job? = null
    /** Feature #2: fires if MQTT hasn't reached Connected within connectTimeoutMs. */
    private var connectDeadlineJob: Job? = null
    /**
     * Feature #4: one retry ladder per action label. Was a single shared Job, which made ANY
     * post-action cancel the previous action's ladder mid-recovery — an automatic AutoOT accept or
     * an attendance action landing inside an accept's retry window silently killed the accept's
     * only recovery (and the old test asserted exactly that: "only the latest action fires").
     * Re-arming the SAME action still supersedes. Atomic copy-on-write map because [stop] cancels
     * from the caller's thread while ladders register/deregister on the confined engine scope.
     */
    private val postActionJobs = atomic<Map<String, Job>>(emptyMap())

    fun start(config: RealtimeConfig) {
        if (!started.compareAndSet(expect = false, update = true)) {
            logger.w(TAG, "start() ignored — already started")
            return
        }
        this.config = config
        startCollectors()
        _status.value = RealtimeStatus.Connecting
        transport.connect(config)
        armConnectDeadline()
    }

    /**
     * Poll-only mode — the app-side MQTT kill-switch (`expert_mqtt_enabled` =
     * false, feature #1). The transport is NEVER connected; the periodic HTTP
     * reconcile loop is the sole data path (current_state → DB → projector → read
     * model), so KMP surfaces still render, just fed by HTTP instead of MQTT.
     * Flip back to MQTT live via [setMqttEnabled].
     */
    fun startPollOnly(config: RealtimeConfig) {
        if (!started.compareAndSet(expect = false, update = true)) {
            logger.w(TAG, "startPollOnly() ignored — already started")
            return
        }
        this.config = config
        // Collectors run so a later live flip to MQTT ([setMqttEnabled]) needs no
        // re-wire; the transport simply stays Idle until then.
        startCollectors()
        logger.d(TAG, "starting POLL_ONLY (MQTT disabled app-side)")
        _status.value = RealtimeStatus.PollOnly
        startPollLoop()
    }

    private fun startCollectors() {
        scope.launch { transport.state.collect { onTransportState(it) } }
        scope.launch { transport.messages.collect { onMessage(it) } }
        scope.launch { network.status.collect { onConnectivityChange(it) } }
    }

    fun stop() {
        if (!started.compareAndSet(expect = true, update = false)) return
        retainedWaitJob?.cancel()
        degradedJob?.cancel()
        pollJob?.cancel()
        connectDeadlineJob?.cancel()
        postActionJobs.getAndSet(emptyMap()).values.forEach(Job::cancel)
        transport.disconnect()
        _status.value = RealtimeStatus.Idle
    }

    /**
     * Live app-side MQTT kill-switch flip (feature #1), driven by a Remote Config
     * change pushed from Dart. ON→OFF: drop the socket and fall to the poll-only
     * HTTP loop. OFF→ON: stop polling and (re)connect MQTT. No-op if the engine
     * isn't started or the requested mode already holds.
     */
    fun setMqttEnabled(enabled: Boolean) {
        // Runs on the engine scope, which the host confines to a single thread
        // (Dispatchers.Default.limitedParallelism(1)) so this serializes with
        // onTransportState + the collectors — the transport's `client` is not
        // thread-safe, and the Flutter plugin calls this off the main thread.
        scope.launch {
            if (!started.value) return@launch
            val cfg = config ?: return@launch
            val pollOnly = _status.value == RealtimeStatus.PollOnly
            when {
                enabled && pollOnly -> {
                    logger.d(TAG, "MQTT re-enabled app-side — leaving poll-only, reconnecting")
                    pollJob?.cancel()
                    _status.value = RealtimeStatus.Connecting
                    transport.connect(cfg)
                    armConnectDeadline()
                }
                !enabled && !pollOnly -> {
                    logger.d(TAG, "MQTT disabled app-side — entering poll-only")
                    retainedWaitJob?.cancel()
                    degradedJob?.cancel()
                    transport.disconnect()
                    _status.value = RealtimeStatus.PollOnly
                    startPollLoop()
                }
            }
        }
    }

    /** The poll-only HTTP loop: reconcile now, then every [EngineTuning.degradedIntervalMs]. */
    private fun startPollLoop() {
        if (pollJob?.isActive == true) return
        pollJob = scope.launch {
            while (isActive) {
                reconcileNow(ReconcileReason.POLL)
                delay(tuning.degradedIntervalMs)
            }
        }
    }

    /** External wake (FCM data-message / foreground / bridge watchdog — LLD §6.4/§6.5). */
    fun onWakeSignal(reason: WakeReason) {
        logger.d(TAG, "wake: $reason")
        // Whole body on the confined scope: this entry point runs on the platform main thread
        // (FCM service, foreground tracker, refresh bridge) while the collectors and
        // setMqttEnabled run confined — and the transport client is not thread-safe (the
        // invariant setMqttEnabled documents). connect() used to run on the caller's thread,
        // racing the confined side; tolerable when FCM was the only caller, not now that every
        // foreground edge and pull-to-refresh lands here.
        scope.launch {
            // Same guard every other scope-hopping entry point carries (setMqttEnabled, onPostAction,
            // refreshCredentialsAndReconnect). It matters more now the whole body is queued: stop()
            // can land between the enqueue and this running, and stop() never clears `config`, so an
            // unguarded wake would build a FRESH auto-reconnecting HiveMQ client on a torn-down
            // engine — one that the already-returned stop() will never disconnect, leaving an
            // orphaned socket retrying with a possibly-revoked JWT for the life of the process.
            if (!started.value) return@launch
            val cfg = config
            if (cfg != null &&
                _status.value != RealtimeStatus.PollOnly && // poll-only: never resurrect the socket
                transport.state.value !is TransportState.Connected &&
                transport.state.value !is TransportState.Connecting
            ) {
                transport.connect(cfg)
            }
            // The reconnect above is always worth attempting — a wake is a fair moment to re-try the
            // socket, and jwtProvider re-reads storage so a token written since may revive it. The
            // HTTP fetch is not: Stopped means the token was REFUSED, and the engine already refuses
            // to poll in that state ("sign-out owns recovery", enterFallbackPoll). Until this, a
            // KMP-cohort pull-to-refresh reached reconcileNow through the bridge and fetched anyway —
            // unthrottled and tap-repeatable — quietly breaking that invariant from the outside.
            // Offline deliberately still fetches: connectivity can return before the monitor notices,
            // and a user-initiated refresh is a fair prompt to try. It costs one request and, unlike
            // Stopped, produces no auth noise.
            if (_status.value is RealtimeStatus.Stopped) {
                logger.d(TAG, "wake: skipping fetch — auth-dead (status=${_status.value.telemetryName()})")
                return@launch
            }
            reconcileNow(ReconcileReason.WAKE)
        }
    }

    /**
     * Feature #4 — post-action fallback. A KMP-cohort runner just performed a
     * state-mutating action ([action] = a short label, telemetry dimension); the
     * resulting state is expected to arrive as an MQTT snapshot. If no NEWER snapshot
     * is applied within [EngineTuning.postActionDeadlineMs], fetch current_state as a
     * safety net — and report the miss so we still see which transitions the backend
     * fails to publish (the fail-loud diagnostic the eager requestRefresh removal was
     * meant to surface).
     *
     * **Retries on a ladder** ([EngineTuning.postActionRetryDelaysMs]) instead of fetching
     * once. The single-shot version fired one fetch at [EngineTuning.postActionDeadlineMs]
     * past the 2xx — RC-pinned to its 2s floor in production — which is early enough that
     * the backend has routinely not transitioned the job yet. That lone fetch returned the
     * pre-action state, recovery was spent for good, and the runner sat on a spinner no
     * later event could clear. Retrying also absorbs the two silent give-ups inside
     * [reconcileNow]: a fetch that fails, and a fetch skipped because a concurrent
     * reconcile held `reconcileInFlight` — both of which used to consume the only attempt.
     *
     * **Call at action SUCCESS, before any toast hold / success animation.** The
     * baseline seq is captured when this arms, so a late call (after the transition
     * has already landed) would read a post-transition baseline and false-report a
     * miss on the healthy path.
     *
     * Ladders are per action label: repeating an action supersedes its own pending ladder, while a
     * DIFFERENT action leaves it running — a shared single deadline meant any later action
     * silently cancelled a pending accept's recovery mid-ladder.
     * Skipped in poll-only (no MQTT — the poll loop owns the refresh). Rungs landing in
     * Stopped (honor "no HTTP while auth-dead", as armConnectDeadline does) or Offline (a
     * futile fetch) skip the fetch but KEEP WAITING, so a ladder that starts auth-dead or
     * offline still recovers if the status clears before it runs out — the single-shot
     * version simply had no recovery at all in those states. Otherwise no status guard:
     * post-actions are inherently foreground/unlocked (the #2 locked-cold-boot 401 concern
     * can't apply).
     */
    fun onPostAction(action: String) {
        // KNOWN MEASUREMENT GAP: poll-only never arms a deadline, so its actions can never report a
        // miss. Reporting here instead would fire on EVERY action (there is no deadline to lapse) and
        // inflate the rate rather than complete it. Counting poll-only properly means arming the
        // deadline in that mode too — a behaviour change, deliberately not bundled into this
        // telemetry-only PR. Poll-only is the `expert_mqtt_enabled=false` kill-switch, so this is
        // expected to be an empty population today.
        if (_status.value == RealtimeStatus.PollOnly) return
        // Hop onto the engine's confined scope before touching the timer field —
        // the bridge invokes this off the platform/VM thread and the job fields
        // aren't thread-safe (the confinement setMqttEnabled relies on). This
        // launched coroutine IS the deadline; from the confined thread it cancels
        // any prior deadline and registers itself so a later action (or stop())
        // can cancel it — no off-thread field write.
        scope.launch {
            if (!started.value) return@launch // stopped between the call and this dispatch
            // Supersede a pending ladder for the SAME action only — other actions' ladders keep
            // running (see the postActionJobs doc).
            postActionJobs.getAndUpdate { it - action }[action]?.cancel()
            val self = this.coroutineContext[Job]!!
            postActionJobs.update { it + (action to self) }
            // Deregister on ANY exit — resolved, exhausted, early return, cancelled. Identity-
            // guarded (not label-guarded) so a newer same-action ladder that has already replaced
            // this entry is never removed by its predecessor's completion.
            self.invokeOnCompletion {
                postActionJobs.update { m -> if (m[action] === self) m - action else m }
            }
            val baselineWidget = currentWidget()
            var waitedMs = 0L
            var rungsRun = 0
            var reported = false
            var resolved = false
            var status = _status.value

            // Only a live MQTT connection earns the full deadline; anything else is waiting for a
            // transport that cannot deliver (device-observed: a runner sat in degraded HTTP poll for
            // 36s before an accept, then still burned the full 2s MQTT grace before its first fetch).
            val firstRungMs =
                if (status == RealtimeStatus.Connected) tuning.postActionDeadlineMs
                else tuning.postActionSettleMs
            for (waitMs in listOf(firstRungMs) + tuning.postActionRetryDelaysMs) {
                delay(waitMs)
                waitedMs += waitMs
                // `break`, not `return@launch`: both of the bails below are reachable AFTER the miss
                // was reported, and returning skipped the outcome event entirely — leaving a
                // fallback with no ladder to reconcile against, on exactly the abandoned-recovery
                // cases the outcome exists to surface. Supersede-cancellation still emits nothing:
                // that kills the coroutine outright and its replacement reports instead.
                if (!started.value) break // stop() during the wait — no fetch post-teardown
                if (widgetMoved(baselineWidget)) { resolved = true; break }
                status = _status.value
                // A live flip of the MQTT kill-switch mid-ladder hands refresh to the poll loop.
                if (status == RealtimeStatus.PollOnly) break
                if (!reported) {
                    // Report the miss ONCE, on the first lapsed deadline, and unconditionally —
                    // every branch below is a deadline that lapsed, so every branch is a miss. Only
                    // the recovery *action* differs by status, and that is what `status` records.
                    // (Previously only the Connected branch reported, which silently excluded every
                    // degraded/offline miss from the rate.) Firing once keeps this event's meaning —
                    // and its rate — identical to the single-shot era; the ladder's own outcome is a
                    // separate event rather than N inflated copies of this one.
                    reported = true
                    // The rung that actually lapsed, not the nominal deadline — otherwise every
                    // disconnected-transport miss would report a 2s wait it never made.
                    postActionReporter.onFallbackFired(action, firstRungMs, status.telemetryName())
                }
                when (status) {
                    // Auth-dead (armConnectDeadline avoids the same 401 storm) or no validated
                    // internet — skip THIS rung's fetch, but stay on the ladder: the #2 fallback
                    // loop recovers the connection, not the action pending behind it.
                    is RealtimeStatus.Stopped, RealtimeStatus.Offline ->
                        logger.d(TAG, "post-action '$action' — rung skipped (status=${status.telemetryName()})")
                    else -> {
                        rungsRun++
                        logger.w(TAG, "post-action '$action' — no snapshot after ${waitedMs}ms; fetching current_state (rung $rungsRun)")
                        reconcileNow(ReconcileReason.POST_ACTION)
                    }
                }
                // End on the fetch that carried the transition, not one rung later — otherwise
                // every healthy recovery would over-report `waitedMs` by a full rung.
                if (widgetMoved(baselineWidget)) { resolved = true; break }
            }
            // The final rung's own fetch may have carried the transition — count it before reporting.
            if (!resolved) resolved = widgetMoved(baselineWidget)
            // Only for actions that actually missed: a healthy action reports nothing at all.
            if (reported) {
                postActionOutcomeReporter.onLadderFinished(action, rungsRun, waitedMs, resolved, status.telemetryName())
            }
        }
    }

    /**
     * The rendered state actually MOVED since the post-action baseline — the ladder's exit condition.
     *
     * Deliberately NOT a `state_seq` comparison. `state_seq` is minted by the backend when it
     * *computes a response*, not when state changes (device-verified: 12 fetches → 12 applied, 0
     * discarded, deltas tracking wall-clock and the 60s poll to the millisecond). So "seq is newer"
     * is satisfied by any successful fetch, which made the ladder exit on its own rung-1 fetch and
     * report `resolved=true` while the job sat in New — reinstating the exact stuck spinner this
     * whole feature exists to clear, and reporting it as healthy. Seq remains correct for
     * [SnapshotStore.applyIfNewer]: ordering writes is what it IS a monotonic clock for.
     *
     * Compares `widget_name` + `widget_data` only. The stored `widgetJson` is the full
     * current_state-shaped envelope, so it also carries `state_seq` itself plus the
     * `sheet_warnings` / `gold_coins_total` / `red_cards_total` / `tier_nudge` siblings — comparing
     * it whole would differ on every snapshot and reproduce the same always-true bug.
     *
     * Known narrow false-positive: a field inside the job's own `widget_data` flipping mid-ladder
     * (`show_deallocation_warning` as the offer runs down) ends the ladder early. That is one field
     * on the card the runner is looking at, versus today's *every* fetch.
     */
    private suspend fun widgetMoved(baseline: String?): Boolean = currentWidget() != baseline

    /** `widget_name` + `widget_data` of the applied snapshot, or null if nothing is stored yet. */
    private suspend fun currentWidget(): String? {
        val json = store.current()?.widgetJson ?: return null
        return runCatching {
            val obj = widgetJson.parseToJsonElement(json).jsonObject
            buildJsonObject {
                put("widget_name", obj["widget_name"] ?: JsonNull)
                put("widget_data", obj["widget_data"] ?: JsonNull)
            }.toString()
        }.getOrElse {
            // Unparseable: treat as "no baseline / unchanged" rather than a spurious move — a decode
            // failure must not be read as a transition and silently end a runner's recovery.
            logger.w(TAG, "widget compare: unparseable snapshot", it)
            null
        }
    }

    // ---- transport state → status + timers -------------------------------

    private fun onTransportState(state: TransportState) {
        logger.d(TAG, "transport → $state (status=${_status.value})")
        // Poll-only (app-side kill-switch): ignore ALL transport emissions. The live
        // ON→OFF flip disconnects the socket, and the graceful disconnect itself
        // re-emits Reconnecting on the real transport — without this guard that would
        // clobber PollOnly, re-arm the degraded loop (double-polling), and a later
        // wake could resurrect the very socket the kill-switch disabled.
        if (_status.value == RealtimeStatus.PollOnly) return
        when (state) {
            is TransportState.Connected -> {
                _status.value = RealtimeStatus.Connected
                authRefreshAttempted.value = false
                connectDeadlineJob?.cancel() // connected in time — no #2 fallback
                degradedJob?.cancel()
                snapshotSinceConnect.value = false
                // §6.9 step 7: retained should arrive on subscribe; if it doesn't,
                // the slot may be empty/stale (cold topic, retainer misconfig) — fetch.
                retainedWaitJob?.cancel()
                retainedWaitJob = scope.launch {
                    delay(tuning.retainedWaitMs)
                    if (!snapshotSinceConnect.value) reconcileNow(ReconcileReason.CONNECT_GAP)
                }
            }
            is TransportState.Reconnecting -> {
                _status.value = RealtimeStatus.Reconnecting
                startDegradedCountdown()
            }
            is TransportState.Disconnected -> onPolicyDisconnect(state.reason)
            is TransportState.Connecting -> _status.value = RealtimeStatus.Connecting
            is TransportState.Idle -> Unit // engine-initiated teardown
        }
    }

    /** Reconnecting/Disconnected: after a grace period, fall to the HTTP poll loop. */
    private fun startDegradedCountdown() {
        if (degradedJob?.isActive == true) return
        degradedJob = scope.launch {
            delay(tuning.degradedAfterMs)
            runFallbackPollLoop()
        }
    }

    /**
     * Feature #2 connect-timeout: if MQTT hasn't reached Connected within
     * [EngineTuning.connectTimeoutMs] of start/re-enable, fall to the HTTP poll loop
     * (no extra grace — the connect window WAS the grace; a stuck Connecting had no
     * bound before this). MQTT keeps auto-reconnecting, so a later Connected cancels
     * the loop and switches back.
     */
    private fun armConnectDeadline() {
        connectDeadlineJob?.cancel()
        connectDeadlineJob = scope.launch {
            delay(tuning.connectTimeoutMs)
            // Skip Connected (recovered), PollOnly (kill-switch) AND Stopped — a terminal
            // Stopped(NotAuthorized) deliberately stays off HTTP ("sign-out owns recovery");
            // resurrecting the poll would re-create the current_state 401 bg-isolate storm.
            // (Review #1.)
            val s = _status.value
            if (s != RealtimeStatus.Connected && s != RealtimeStatus.PollOnly && s !is RealtimeStatus.Stopped) {
                logger.d(TAG, "connect timeout — falling to HTTP poll")
                enterFallbackPoll()
            }
        }
    }

    private fun enterFallbackPoll() {
        // Preempt a still-counting-down degraded grace (they share degradedJob): otherwise a
        // Reconnecting during the connect window swallows the connect-deadline and the RC
        // connect-timeout is inert. Restarting an already-running loop is harmless. (Review #2.)
        degradedJob?.cancel()
        degradedJob = scope.launch { runFallbackPollLoop() }
    }

    /**
     * The HTTP fallback loop (features #2 / §6.4 DEGRADED), connectivity-gated:
     * while NOT connected, Offline ⇒ surface [RealtimeStatus.Offline] and SKIP the
     * fetch (REST is futile — the KMP screen shows the offline banner over the last
     * DB state); Online/BadConnection ⇒ [RealtimeStatus.Degraded] + poll
     * current_state. Cancelled the instant MQTT reconnects (onTransportState).
     */
    private suspend fun CoroutineScope.runFallbackPollLoop() {
        logger.d(TAG, "entering degraded HTTP poll loop (current_state is the data path)")
        while (isActive) {
            if (network.status.value == ConnectivityStatus.Offline) {
                _status.value = RealtimeStatus.Offline
            } else {
                _status.value = RealtimeStatus.Degraded
                reconcileNow(ReconcileReason.DEGRADED)
            }
            delay(tuning.degradedIntervalMs)
        }
    }

    /**
     * Feature #2: regained validated internet while offline-degraded — reconcile
     * now instead of waiting for the next poll tick (MQTT auto-reconnect resumes in
     * parallel; a Connected cancels the loop). No-op unless we're in [Offline].
     */
    private fun onConnectivityChange(status: ConnectivityStatus) {
        // Regained internet mid-offline-fallback — restart the loop so the immediate poll
        // and the periodic tick share ONE schedule (no double-reconcile). Its first
        // iteration sets Degraded + reconciles now. (Review #3.)
        if (status != ConnectivityStatus.Offline && _status.value == RealtimeStatus.Offline) {
            enterFallbackPoll()
        }
    }

    /** LLD §6.1 reason-code policy. */
    private fun onPolicyDisconnect(reason: DisconnectReason) {
        when (reason) {
            is DisconnectReason.NotAuthorized -> {
                // Only a server-sent DISCONNECT with NOT_AUTHORIZED reaches here — a CONNACK-refused
                // reconnect is Network (see HiveMqttTransport.mapDisconnect), so it keeps
                // auto-reconnecting with re-applied credentials + degraded HTTP. Refresh the JWT once
                // and reconnect; a second refusal without an intervening Connected ⇒ stop (§6.1).
                if (authRefreshAttempted.compareAndSet(expect = false, update = true)) {
                    scope.launch { refreshCredentialsAndReconnect() }
                } else {
                    logger.w(TAG, "auth refused twice — stopping (sign-out flow owns recovery)")
                    _status.value = RealtimeStatus.Stopped(reason)
                }
            }
            is DisconnectReason.SessionTakenOver,
            is DisconnectReason.AdministrativeAction,
            -> {
                // Do not fight the server: surface and stop (§6.1).
                _status.value = RealtimeStatus.Stopped(reason)
                startDegradedCountdown() // state still flows via HTTP while stopped
            }
            else -> {
                _status.value = RealtimeStatus.Reconnecting
                startDegradedCountdown()
            }
        }
    }

    private suspend fun refreshCredentialsAndReconnect() {
        // stop() may have fired before this launched coroutine ran — bail so a torn-down engine
        // can't resurrect the socket. Mirrors the same guard in onPostAction.
        if (!started.value) return
        val cfg = config ?: return
        val fresh = credentials.freshJwt()
        // The app-side kill-switch may have flipped us to poll-only while freshJwt()
        // suspended — don't resurrect the MQTT socket the kill-switch disabled.
        if (_status.value == RealtimeStatus.PollOnly) return
        if (fresh.isNullOrBlank()) {
            _status.value = RealtimeStatus.Stopped(DisconnectReason.NotAuthorized)
            return
        }
        val next = cfg.copy(password = fresh)
        config = next
        logger.d(TAG, "auth refused — reconnecting with refreshed JWT")
        transport.disconnect()
        _status.value = RealtimeStatus.Connecting
        transport.connect(next)
    }

    // ---- inbound snapshots ------------------------------------------------

    private suspend fun onMessage(message: TransportMessage) {
        val envelope = SnapshotEnvelope.parse(message.payload, logger) ?: return
        logger.d(
            TAG,
            "recv MQTT: eventType=${envelope.eventType} seq=${envelope.stateSeq} " +
                "epoch=${envelope.epoch} schema=${envelope.schemaVersion} " +
                "widgetPresent=${envelope.widget != null} widgetName=${envelope.widget?.get("widget_name")}",
        )
        if (envelope.eventType != SnapshotEnvelope.EVENT_STATE_SNAPSHOT) return
        if (envelope.schemaVersion > SnapshotEnvelope.SUPPORTED_SCHEMA_VERSION) {
            // LLD App B guard: newer envelope than we understand — trust HTTP instead.
            logger.w(TAG, "schema_version ${envelope.schemaVersion} > supported — discarding, reconciling")
            reconcileNow(ReconcileReason.VERSION_GAP)
            return
        }
        apply(envelope, SnapshotSource.MQTT)
    }

    private suspend fun apply(envelope: SnapshotEnvelope, source: SnapshotSource) {
        val applied = store.applyIfNewer(
            AppliedSnapshot(
                epoch = envelope.epoch,
                stateSeq = envelope.stateSeq,
                // Persist the full `current_state`-shaped envelope (widget_name/
                // widget_data lifted out + the sheet_warnings/gold_coins/state_seq
                // siblings), NOT just `widget` — the DB is now the single source the
                // read model projects, so it must hold everything a render needs.
                widgetJson = envelope.toRunnerStateJson(),
                source = source,
            ),
        )
        if (applied) {
            logger.d(TAG, "applied snapshot seq=${envelope.stateSeq} (source=$source)")
            snapshotSinceConnect.value = true
            // Telemetry/extension seam only. The read model is fed by the DB
            // projection (RunnerStateProjector observing the store), not this sink.
            sink.onApplied(envelope, source)
        } else {
            // Read the incumbent seq only on this (rare) path so the report can say WHY it lost —
            // "arrived but older" and "arrived but identical" are different bugs, and a re-publish of
            // the same seq is indistinguishable from a genuine duplicate without both numbers.
            val currentSeq = store.current()?.stateSeq ?: -1L
            // Stays `d` (release no-op) on purpose: duplicate snapshots may be common, and a warn per
            // discard would spam logcat on exactly the hot path we suspect. The analytics event is the
            // production signal — it is aggregatable and killable; a log line is neither.
            logger.d(
                TAG,
                "discarded snapshot seq=${envelope.stateSeq} <= current=$currentSeq (source=$source)",
            )
            discardReporter.onDiscarded(
                candidateSeq = envelope.stateSeq,
                currentSeq = currentSeq,
                source = source,
            )
        }
    }

    // ---- reconcile (LLD §6.4) --------------------------------------------

    suspend fun reconcileNow(reason: ReconcileReason) {
        // Coalesce concurrent triggers rather than DROP them: the in-flight fetch may have started
        // before this trigger, so its result can be stale relative to what the trigger is asking
        // for ("state as of now"). The old bare-return dedupe silently no-op'd triggers that have
        // no retry of their own — a foreground wake or PTR landing during a poll/ladder fetch
        // simply never refreshed, with a 10s throttle before the user could even cause another.
        // All concurrent triggers still collapse into at most ONE follow-up fetch.
        if (!reconcileInFlight.compareAndSet(expect = false, update = true)) {
            reconcileFollowUp.value = true
            return
        }
        try {
            // Jitter is herd protection for cohort-wide reconciles (CONNECT_GAP,
            // DEGRADED, POLL fire on every client at once). WAKE and POST_ACTION
            // are per-user (FCM data-message, user PTR, action-completed) — the
            // 0-2s delay just makes user-initiated refreshes feel laggy without
            // any herd to protect against, so PTR on the change-attendance sheet
            // took 2-4s to surface fresh sheet_warnings (bug: user sees no red
            // card for ~5s on first launch).
            if (reason != ReconcileReason.WAKE && reason != ReconcileReason.POST_ACTION) {
                delay(tuning.jitterMs())
            }
            do {
                val fetched = fetcher.fetch()
                if (fetched == null) {
                    logger.w(TAG, "reconcile($reason) fetch failed")
                } else {
                    apply(fetched, SnapshotSource.FETCH)
                }
            } while (reconcileFollowUp.getAndSet(false) && started.value)
        } finally {
            // Clear in `finally`, not just via the loop condition: a cancellation inside
            // fetcher.fetch() (degradedJob/pollJob/retainedWaitJob cancel, ladder supersede, stop())
            // never evaluates the `while`, which would leave the marker set — and the NEXT reconcile
            // would then do its own fetch plus an immediate jitter-free second one, re-reading the
            // same seq and emitting a spurious mqtt_snapshot_discarded.
            reconcileFollowUp.value = false
            reconcileInFlight.value = false
            // A trigger can slip in between the loop's last check and the release above; that
            // window is nanoseconds (vs. the old behaviour of dropping EVERY concurrent trigger),
            // and the next poll/rung/wake covers it.
        }
    }

    private companion object {
        const val TAG = "RealtimeStateEngine"
    }
}
