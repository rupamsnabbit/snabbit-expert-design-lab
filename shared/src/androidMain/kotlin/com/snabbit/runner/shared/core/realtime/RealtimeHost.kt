package com.snabbit.runner.shared.core.realtime

import android.content.Context
import android.os.SystemClock
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.connectivity.NetworkMonitor
import com.snabbit.runner.shared.core.database.snabbitDatabase
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.core.storage.StoreManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import org.koin.core.context.GlobalContext

class HostedRealtime(
    val engine: RealtimeStateEngine,
    val config: RealtimeConfig,
    /** Feature #1: false ⇒ the caller starts the engine in poll-only mode (no MQTT). */
    val appMqttEnabled: Boolean,
)

/**
 * Builds the production engine for SnabbitForegroundService (WS4). Pulls the
 * Koin-managed seams (config store, token store, reconciler, sink), hydrates
 * from encrypted storage — the LLD §6.2 cold-boot path: cached config +
 * cached JWT, no network round-trip before the socket opens.
 *
 * Returns null (and the service stops itself) when: Koin isn't up, no login
 * token exists, the runner isn't enrolled, or the backend kill-switch is on.
 */
object RealtimeHost {

    suspend fun create(context: Context, scope: CoroutineScope, logger: Logger): HostedRealtime? {
        val koin = GlobalContext.getOrNull() ?: run {
            logger.w(TAG, "Koin not started — KmpBootstrap must run before the service")
            return null
        }
        val configStore: RealtimeConfigStore = koin.get()
        val storeManager: StoreManager = koin.get()

        storeManager.hydrateAll()
        configStore.hydrate()

        val jwt = storeManager.tokenSnapshot() ?: run {
            logger.d(TAG, "no login token — logged out; realtime not started")
            return null
        }
        val config = configStore.toRealtimeConfig(jwt, configStore.installSuffix()) ?: run {
            logger.d(TAG, "no usable mqtt_config — not enrolled or kill-switched (LLD §3.2)")
            return null
        }

        val store = RoomSnapshotStore(
            dao = snabbitDatabase(context).runnerHomeStateDao(),
            runnerId = config.username.toLongOrNull() ?: 0L,
            nowMs = { System.currentTimeMillis() },
        )
        // Feature #1: the app-side MQTT kill-switch + poll cadence, hydrated from
        // the persisted RC values above (readable on the FCM cold-boot path).
        val appMqttEnabled = configStore.appMqttEnabled.value
        logger.d(
            TAG,
            "engine cold-boot: ${config.host}:${config.port} topic=${config.stateTopic} appMqttEnabled=$appMqttEnabled",
        )
        val pollSeconds = configStore.pollIntervalSeconds.value
        val connectTimeoutSeconds = configStore.connectTimeoutSeconds.value
        val postActionSeconds = configStore.postActionTimeoutSeconds.value
        // Feature #4 recovery ladder. Read off the NATIVE RC gateway rather than the
        // Dart-pushed configStore beside it: the ladder is a list, and threading a list
        // through `setMqttEnabled`'s positional method-channel signature would touch
        // Dart, the plugin and this store for one value. The Firebase SDK caches its own
        // activated values, so this still resolves on the FCM cold-boot path; if Firebase
        // is not up yet in that process the gateway returns the shipped ladder — today's
        // behaviour — rather than failing.
        val postActionLadderMs = PostActionLadder.parseMs(
            authored = koin.get<RemoteConfigGateway>().getString(PostActionLadder.KEY_SECS, ""),
            onAdjust = { logger.w(TAG, it) },
        )
        // Feature #4: fail-loud telemetry when the post-action fallback fires (MQTT was
        // connected but didn't publish the transition) — names the action so we see which.
        val analytics = koin.get<AnalyticsTracker>()
        // Debug-only diagnostics (Profile footer, non-prod): status mirror + MQTT count.
        val diagnostics = koin.get<RealtimeDiagnostics>()
        val engine = RealtimeStateEngine(
            transport = HiveMqttTransport(
                logger = logger,
                // Read the freshest JWT from encrypted storage on each reconnect — HiveMQ
                // drops credentials on auto-reconnect, and this also picks up a token
                // refreshed after login. Non-suspending hot-path read (StoreManager).
                jwtProvider = { storeManager.tokenSnapshot() },
            ),
            store = store,
            fetcher = koin.get<CurrentStateReconciler>(),
            credentials = CredentialsProvider { storeManager.tokenSnapshot() },
            // Telemetry seam only — the read model is fed by the DB projection below,
            // not by the sink (DB is now the single source of truth, LLD §5.1).
            sink = SnapshotSink { envelope, source ->
                logger.d(TAG, "applied seq=${envelope.stateSeq} source=$source")
            },
            scope = scope,
            logger = logger,
            // Poll/degraded cadence + connect-timeout + post-action deadline are all
            // Remote-Config-driven (features #1/#2/#4).
            tuning = EngineTuning(
                degradedIntervalMs = pollSeconds * 1000L,
                connectTimeoutMs = connectTimeoutSeconds * 1000L,
                postActionDeadlineMs = postActionSeconds * 1000L,
                postActionRetryDelaysMs = postActionLadderMs,
            ),
            // Feature #2: connectivity source for the offline-vs-poll fallback branch.
            network = koin.get<NetworkMonitor>(),
            // Feature #4: post-action MQTT-miss telemetry → analytics. KMP-originated
            // (native Mixpanel provider, in-process — never crosses to Dart), so routing
            // lives only in AnalyticsRoutesConfig; there is no Dart-side allowlist for it.
            postActionReporter = PostActionReporter { action, timeoutMs, status ->
                // Same kill-switch as every other realtime-health event. It matters MOST here: this
                // PR widened the event from the Connected branch alone to every transport branch, so
                // it is the one whose volume deliberately goes up — and it was the one that could
                // not have been silenced without a store release.
                if (!configStore.healthAnalyticsEnabled.value) return@PostActionReporter
                analytics.track(
                    ANALYTICS_POST_ACTION_FALLBACK,
                    mapOf("action" to action, "timeout_ms" to timeoutMs, "status" to status),
                )
            },
            // Separates "the snapshot never reached us" from "it reached us and we dropped it" —
            // the two remaining explanations for a stalled post-action screen, with different owners.
            // Gated by the SAME kill-switch as the other realtime-health events
            // (`expert_mqtt_health_analytics_enabled`, default on): this fires once per dropped
            // snapshot on a path we suspect is hot, so if the volume turns out to be pathological it
            // has to be silenceable without a build — the precedent this codebase already set for
            // connection-transition telemetry, and the reason a flaky-network drip stayed affordable.
            discardReporter = SnapshotDiscardReporter { candidateSeq, currentSeq, source ->
                if (!configStore.healthAnalyticsEnabled.value) return@SnapshotDiscardReporter
                analytics.track(
                    ANALYTICS_SNAPSHOT_DISCARDED,
                    mapOf(
                        "candidate_seq" to candidateSeq,
                        "current_seq" to currentSeq,
                        "source" to source.name.lowercase(),
                    ),
                )
            },
            // How the retry ladder ENDED. `resolved` is the number that matters: false after every
            // rung means the state was asked for repeatedly over tens of seconds and never moved —
            // the one signal that separates "the backend was slow" from "the backend never
            // published", which the fallback event alone conflated. `rungs_run` sizes the ladder:
            // if resolutions cluster on the last rung, it is too short. Same kill-switch as the
            // rest of the realtime-health family; fires at most once per missed action, so it is
            // strictly rarer than the fallback event it accompanies.
            postActionOutcomeReporter = PostActionOutcomeReporter { action, rungsRun, waitedMs, resolved, status ->
                if (!configStore.healthAnalyticsEnabled.value) return@PostActionOutcomeReporter
                analytics.track(
                    ANALYTICS_POST_ACTION_LADDER,
                    mapOf(
                        "action" to action,
                        "rungs_run" to rungsRun,
                        "waited_ms" to waitedMs,
                        "resolved" to resolved,
                        "status" to status,
                    ),
                )
            },
        )
        // Debug diagnostics (Profile footer, non-prod): mirror the engine status.
        engine.status.onEach { diagnostics.updateStatus(it) }.launchIn(scope)
        // Production connection-health telemetry (field visibility — nothing about MQTT health
        // reached analytics before, which is why the reconnect bug stayed invisible until a device
        // repro). Coarse: only meaningful transitions, off the status stream so the engine stays
        // pure. Gated by the `expert_mqtt_health_analytics_enabled` RC kill-switch (default on) so a
        // flaky-network drip can be silenced without a build; the flag is read live per transition.
        // `from_state_ms` (below) needs the dwell time, so the clock is stamped on EVERY real
        // status change — including ones that emit no event — and independently of the kill-switch,
        // or a silenced window would leave the next event reporting a dwell it never measured.
        scope.launch {
            var prev: RealtimeStatus? = null
            var enteredAtMs = SystemClock.elapsedRealtime()
            engine.status.collect { cur ->
                val previous = prev
                if (previous != null && previous != cur) {
                    val now = SystemClock.elapsedRealtime()
                    if (configStore.healthAnalyticsEnabled.value) {
                        reportConnectionTransition(analytics, previous, cur, now - enteredAtMs)
                    }
                    enteredAtMs = now
                }
                prev = cur
            }
        }
        // Project the version-gated store into the RunnerStateStore every KMP
        // surface observes. observe() replays the persisted row on subscription,
        // so this also cold-boot-seeds the last snapshot (LLD §7) — no separate step.
        RunnerStateProjector(store = store, target = koin.get<RunnerStateStore>()).start(scope)
        return HostedRealtime(engine, config, appMqttEnabled)
    }

    private const val TAG = "RealtimeHost"

    /** Feature #4: emitted when the post-action fallback fires (MQTT missed a transition). */
    private const val ANALYTICS_POST_ACTION_FALLBACK = "mqtt_post_action_fallback"
    private const val ANALYTICS_SNAPSHOT_DISCARDED = "mqtt_snapshot_discarded"
    private const val ANALYTICS_POST_ACTION_LADDER = "mqtt_post_action_ladder"

    // Connection-health events. `from`/`to` carry the coarse status names for funnel analysis.
    private const val ANALYTICS_MQTT_RECOVERED = "mqtt_recovered"
    private const val ANALYTICS_MQTT_DEGRADED = "mqtt_degraded"
    private const val ANALYTICS_MQTT_OFFLINE = "mqtt_offline"
    private const val ANALYTICS_MQTT_STOPPED = "mqtt_stopped"

    /**
     * Emit one coarse analytics event on a meaningful realtime-health transition (skips the
     * transient Connecting/Reconnecting churn and the very first connect).
     *
     * [fromStateMs] is how long the runner sat in [prev] before this transition — the missing
     * dimension that made "are runners mostly connected or mostly degraded?" unanswerable. The
     * events counted *episodes*, never their length, so 3 degraded episodes a day could equally
     * mean 1% or 10% of a shift on HTTP poll.
     *
     * Deliberately on every transition rather than a `degraded_ms` on recovery alone: ~14% of
     * degraded episodes never record a recovery (the app closes first, or the state moves on to
     * offline/stopped), and those are precisely the LONG ones. Measuring only recoveries would
     * therefore under-report degraded time exactly where it hurts. Pair it with `from` to read a
     * specific state's dwell — e.g. sum `from_state_ms` where `from=degraded`, across every event.
     */
    private fun reportConnectionTransition(
        analytics: AnalyticsTracker,
        prev: RealtimeStatus?,
        cur: RealtimeStatus,
        fromStateMs: Long,
    ) {
        if (prev == null || prev == cur) return
        val event = when (cur) {
            // Connected is only interesting as a RECOVERY (we were in trouble), not the cold connect.
            is RealtimeStatus.Connected ->
                if (prev is RealtimeStatus.Connecting || prev is RealtimeStatus.Idle) null else ANALYTICS_MQTT_RECOVERED
            is RealtimeStatus.Degraded -> ANALYTICS_MQTT_DEGRADED
            is RealtimeStatus.Offline -> ANALYTICS_MQTT_OFFLINE
            is RealtimeStatus.Stopped -> ANALYTICS_MQTT_STOPPED
            else -> null // Reconnecting / Connecting / PollOnly / Idle — transient or uninteresting
        } ?: return
        // from/to are fixed-vocabulary status names; the variable stop reason rides its own
        // property so it doesn't inflate the cardinality of from/to.
        val props = buildMap<String, Any?> {
            put("from", prev.telemetryName())
            put("to", cur.telemetryName())
            put("from_state_ms", fromStateMs)
            (cur as? RealtimeStatus.Stopped)?.let { put("reason", it.reason.telemetryName()) }
        }
        analytics.track(event, props)
    }

}
