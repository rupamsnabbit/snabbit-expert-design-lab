package com.snabbit.runner.shared.features.kavach.sos.domain

import com.safetykavach.shield.core.ShieldController
import com.safetykavach.shield.core.event.ShieldEvent
import com.safetykavach.shield.core.model.MonitoringState
import com.safetykavach.shield.core.model.SafetyState
import com.snabbit.runner.shared.features.kavach.shared.data.ApiPreflight
import com.snabbit.runner.shared.features.kavach.shared.data.PreflightBlock
import com.snabbit.runner.shared.features.kavach.shared.domain.ActiveTrigger
import com.snabbit.runner.shared.features.kavach.shared.domain.ActiveTriggerHolder
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import com.snabbit.runner.shared.core.lifecycle.AppLifecycle
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.CurrentStateGateway
import com.snabbit.runner.shared.features.kavach.sos.data.remote.SosApi
import com.snabbit.runner.shared.features.kavach.sos.data.remote.SosUserAction
import com.snabbit.runner.shared.features.kavach.sos.data.store.SosLiveStore
import kotlin.concurrent.Volatile
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Cross-screen SOS state machine (Step 6, dedicated-coordinator choice). Owns the SOS
 * session: raise → alert → confirm/deny → active → resolve, driving the plugin
 * ([ShieldController]) + backend ([SosApi]). A Koin single, so [state] survives across the
 * `SafetyHome`/`SosActive` VMs, which observe it (nav is state-driven — a shared single-
 * consumer channel would race). Best-effort, 1:1 with the Flutter flow.
 *
 * NOTE: no app-side `PreSosSnapshot` — the plugin restores `previousState` on deny/deescalate
 * (D-15) and the UI mirrors it via plugin state-sync (6c).
 *
 * Owns a long-lived [scope] for autonomous work (plugin-event collection + the auto-deny
 * timer). ⚠ Collection self-starts on first injection; hoist to an app/job lifecycle point
 * for background-before-feature-load coverage (follow-up).
 *
 * DONE 6a (manual raise) + 6b.1 (detection raise, auto-deny timer, active-screen resolve)
 * + 6b.2 (`NotificationAction` UI-sync — the plugin already ran the handler, so we sync state
 * WITHOUT re-invoking the command). TODO 6b.3 `/sos/active` reconcile (E3).
 */
class SosCoordinator(
    private val shield: ShieldController,
    private val sosApi: SosApi,
    private val remoteConfig: RemoteConfigGateway,
    private val lifecycle: AppLifecycle,
    private val currentState: CurrentStateGateway,
    private val analytics: AnalyticsTracker,
    dispatchers: AppDispatchers,
    private val activeTrigger: ActiveTriggerHolder = ActiveTriggerHolder(),
    // Persisted "an SOS may still be open" marker. [_state] is in-memory only, so without this the
    // foreground reconcile has no way to know a killed process left an SOS behind — and it is the
    // reason gate that keeps /sos/active off the normal app launch. Optional so existing test
    // constructions keep working with a throwaway store.
    private val sosLiveStore: SosLiveStore? = null,
    // Refuses a raise that cannot possibly register (no token / offline). Optional — absent means
    // allow, so existing test constructions are unaffected.
    private val preflight: ApiPreflight? = null,
) {
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.default)

    private val _state = MutableStateFlow(SosState())
    val state: StateFlow<SosState> = _state.asStateFlow()

    // @Volatile: published across the scope(default) writer ↔ viewModelScope(main) readers (#R-C).
    @Volatile private var inProgress = false
    @Volatile private var alertTimer: Job? = null
    // Guards the single-raise check+set — raiseManual (viewModelScope) and raiseDetected (the
    // event collector on `scope`) can run on different dispatcher threads (R-comment #3).
    private val raiseMutex = Mutex()
    // Serialize the resolve paths (confirm/deny/deescalate). Without this a racing timeout/
    // notification deny + a user confirm both pass their entry guard, both suspend at resolve(),
    // then issue conflicting plugin+backend commands and collapse each other's state (a live SOS
    // silently reset to IDLE). Under the lock the loser re-checks phase after acquiring → no-ops (#3205).
    private val resolveMutex = Mutex()

    private fun track(event: String, vararg props: Pair<String, Any?>) = analytics.track(event, props.toMap())

    // Persisted-flag helpers. Called explicitly at each transition rather than derived from [_state]:
    // a flow-based sync would emit the initial IDLE at construction and wipe the flag before the
    // foreground reconcile ever reads it.
    private suspend fun markSosLive() = sosLiveStore?.markLive()
    private suspend fun clearSosLive() = sosLiveStore?.clear()

    init {
        scope.launch {
            shield.events.collect { event ->
                when (event) {
                    is ShieldEvent.SoSTriggered ->
                        raiseDetected(event.source.name.lowercase(), event.triggerType.name.lowercase())
                    is ShieldEvent.NotificationAction -> handleNotificationAction(event.action)
                    else -> {}
                }
            }
        }
    }

    /**
     * Manual raise (UI): move the plugin into SoS, register the backend SOS, show the alert.
     * Throws [SosRaiseBlockedException] when the pre-flight refuses (no token / offline) so the
     * caller's existing error path surfaces a toast — the runner must not be left believing an
     * unregistered SOS went out.
     */
    suspend fun raiseManual(jobId: Int? = null) {
        raise(SOURCE_MANUAL, TRIGGER_NON_ML, jobId, manual = true)?.let { throw SosRaiseBlockedException(it) }
    }

    /**
     * Detection raise (plugin `SoSTriggered`): plugin already in SoS — don't re-trigger.
     * Never throws: this runs on the un-guarded `shield.events` collector, so a throw here would
     * complete the flow and kill SOS detection for the rest of the process. A blocked raise is
     * already recorded by the pre-flight's analytics.
     */
    suspend fun raiseDetected(source: String, triggerType: String, jobId: Int? = null) {
        raise(source, triggerType, jobId, manual = false)
    }

    /** @return the reason the raise was refused, or null if it proceeded. */
    private suspend fun raise(source: String, triggerType: String, jobId: Int?, manual: Boolean): PreflightBlock? {
        // Pre-flight BEFORE the plugin call: with no token / no network the backend can never
        // register this SOS, and triggerManualSoS() would strand the plugin in SOS_PENDING —
        // alert tone and notification up, with no sosId anything can resolve against.
        preflight?.check("sos_initiate")?.let { block ->
            track("expert_shield_sos_raise_blocked", "source" to source, "trigger_type" to triggerType, "reason" to block.name.lowercase(), "manual" to manual)
            // Manual raise: hard-stop so the runner isn't told an unregistered SOS went out.
            // Detected raise (manual=false): the plugin is ALREADY in on-device SoS (siren up) — hard-stopping
            // leaves the app IDLE while it keeps sirening. Fall through to a best-effort ALERT + live marker
            // (same as the sosId==null path) so the UI matches the plugin and reconcile can recover on
            // reconnect. initiate() self-preflights, so it just returns null offline (no throw). Note: this
            // does not itself re-register the SOS backend-side — a reconnect re-initiate is a separate follow-up.
            if (manual) return block
        }
        // Atomic single-raise guard across threads: check + claim under a mutex so a manual and a
        // detected raise on different dispatcher threads can't both pass the IDLE check (#3).
        raiseMutex.withLock {
            if (inProgress || _state.value.phase != SosPhase.IDLE) {
                track("expert_shield_sos_concurrent_overridden", "source" to source, "trigger_type" to triggerType, "active_sos_id" to _state.value.sosId)
                return null
            }
            inProgress = true
            _state.update { it.copy(phase = SosPhase.INITIATING, source = source) }
        }
        // A cold SOS start (shield not already ARMED) becomes the session trigger (Flutter's
        // startShield(trigger: sos)). During an armed session, leave manual/auto untouched — matches
        // Flutter's triggerManualSoS() path, so a later resume keeps its original trigger.
        // Armed, not recording: Flutter branches on isShieldRecording, which is also true in
        // MONITORING_ONLY — testing recordingState here would clobber an armed monitoring-only
        // session's manual/auto trigger. Same expression as endForJob's armed guard.
        val armed = shield.monitoringState.value == MonitoringState.ACTIVE ||
            shield.shieldState.value == SafetyState.MONITORING ||
            shield.shieldState.value == SafetyState.MONITORING_ONLY
        val stampedColdSos = !armed
        if (stampedColdSos) activeTrigger.current = ActiveTrigger.SOS
        val effectiveJobId = jobId ?: currentState.currentJobId()
        try {
            if (manual) shield.triggerManualSoS()
            // Attach the active job (parity with Flutter, which always sends _currentJobId).
            val sosId = sosApi.initiate(source, triggerType, effectiveJobId)
            // Best-effort: advance to ALERT even if the backend initiate failed (sosId == null) — the
            // emergency sheet + confirm/deny must still work through a network blip. But flag a failed
            // registration distinctly instead of a misleading 'initiated' with a null id (#222861).
            // Set the in-memory ALERT (which drives the UI) BEFORE the persisted marker, and make the
            // marker best-effort: a markLive() store-write failure must not fall into the catch and tear
            // down an SOS the backend + plugin already registered.
            _state.update { it.copy(phase = SosPhase.ALERT, sosId = sosId, jobId = effectiveJobId) }
            runCatching { markSosLive() }   // §16 recovery aid; non-fatal if the store write fails
            if (sosId != null) {
                track("expert_shield_sos_initiated", "source" to source, "trigger_type" to triggerType, "sos_id" to sosId)
            } else {
                track("expert_shield_sos_initiate_failed", "source" to source, "trigger_type" to triggerType, "reason" to "null_sos_id", "job_id" to effectiveJobId)
            }
            startAlertTimer()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            // Cold SOS never started a recording session → drop the stamped 'sos' so it can't mislabel a
            // later lifecycle event (no job-end here to clear it).
            if (stampedColdSos) activeTrigger.current = null
            // #S3: on the manual path triggerManualSoS() already moved the plugin to SOS_PENDING
            // (siren + notification). Resetting the app to IDLE without it leaves the plugin sirening
            // with the UI gone. Bring the plugin back to match — best-effort (denySoS no-ops unless
            // it is actually in SOS_PENDING). Detected raises don't call triggerManualSoS(), so the
            // plugin's SoS there is genuine on-device detection and must not be torn down here.
            if (manual) runCatching { shield.denySoS() }
            track("expert_shield_sos_initiate_failed", "source" to source, "trigger_type" to triggerType, "job_id" to effectiveJobId)
            clearSosLive()
            _state.update { SosState() }
        } finally {
            inProgress = false
        }
        return null
    }

    /**
     * Alert → confirm. [pluginAlreadyActed] = the plugin ran `confirmSoS` itself (a notification
     * button tap) — sync state + hit the backend, but don't re-invoke the plugin.
     */
    suspend fun confirm(pluginAlreadyActed: Boolean = false) = resolveMutex.withLock {
        confirmInner(pluginAlreadyActed)
    }

    private suspend fun confirmInner(pluginAlreadyActed: Boolean) {
        if (_state.value.phase != SosPhase.ALERT) return
        cancelAlertTimer()
        val sosId = _state.value.sosId
        val source = _state.value.source
        val action = if (pluginAlreadyActed) ACTION_NOTIFICATION else ACTION_USER
        try {
            val outcome = sosApi.resolve(sosId, SosUserAction.CONFIRM)
            if (!pluginAlreadyActed) shield.confirmSoS()
            // A concurrent deny/end (notification action on `scope`) may have reset us to IDLE during
            // the resolve() window — don't resurrect to ACTIVE with a stale/null id; pin the id (#2).
            if (_state.value.phase != SosPhase.ALERT) return
            // Advance to ACTIVE even when the call didn't land — a runner who said "I'm in danger"
            // must see the active screen through a blip. But record it: a confirm the backend never
            // got is a live emergency nobody was told about.
            _state.update { it.copy(phase = SosPhase.ACTIVE, sosId = sosId, phoneNumber = outcome.phoneNumber) }
            if (outcome.delivered) {
                track("expert_shield_sos_confirmed", "sos_id" to sosId, "source" to source, "action_type" to action)
            } else {
                track("expert_shield_sos_confirm_api_failed", "sos_id" to sosId, "source" to source, "action_type" to action, "reason" to "not_delivered")
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            track("expert_shield_sos_confirm_api_failed", "sos_id" to sosId, "source" to source, "action_type" to action, "error" to e.message)
            // stay in ALERT — retryable
        }
    }

    /** Alert → deny (also the auto-deny target). [pluginAlreadyActed] as in [confirm]. */
    suspend fun deny(pluginAlreadyActed: Boolean = false, actionType: String = ACTION_USER) = resolveMutex.withLock {
        denyInner(pluginAlreadyActed, actionType)
    }

    private suspend fun denyInner(pluginAlreadyActed: Boolean, actionType: String) {
        if (_state.value.phase != SosPhase.ALERT) return
        cancelAlertTimer()
        val sosId = _state.value.sosId
        val source = _state.value.source
        try {
            val outcome = sosApi.resolve(sosId, SosUserAction.DENY)
            if (!pluginAlreadyActed) shield.denySoS()
            if (outcome.delivered) {
                track("expert_shield_sos_denied", "sos_id" to sosId, "source" to source, "action_type" to if (pluginAlreadyActed) ACTION_NOTIFICATION else actionType)
                clearSosLive()
            } else {
                // The backend still has this SOS open. Keep the marker so the next foreground
                // reconcile rediscovers it — clearing here silently dropped an unresolved SOS.
                track("expert_shield_sos_deny_api_failed", "sos_id" to sosId, "source" to source, "action_type" to if (pluginAlreadyActed) ACTION_NOTIFICATION else actionType, "reason" to "not_delivered")
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            track("expert_shield_sos_deny_api_failed", "sos_id" to sosId, "source" to source, "action_type" to if (pluginAlreadyActed) ACTION_NOTIFICATION else actionType, "error" to e.message)
        }
        // Local state resets either way — leaving the alert sheet up on a failed deny would strand
        // the runner. Recovery is the retained marker + reconcile, not a stuck UI.
        _state.update { SosState() }
    }

    /** Active → deescalate ("I am safe" / notification "End SoS"). [pluginAlreadyActed] as above. */
    suspend fun deescalate(pluginAlreadyActed: Boolean = false) = resolveMutex.withLock {
        deescalateInner(pluginAlreadyActed)
    }

    private suspend fun deescalateInner(pluginAlreadyActed: Boolean) {
        if (_state.value.phase != SosPhase.ACTIVE) return
        val sosId = _state.value.sosId
        val source = _state.value.source
        try {
            val outcome = sosApi.resolve(sosId, SosUserAction.DISMISS)
            if (!pluginAlreadyActed) shield.deescalateSoS()
            if (outcome.delivered) {
                track("expert_shield_sos_deescalated", "sos_id" to sosId, "source" to source, "action_type" to "user_dismissed")
                clearSosLive()
            } else {
                // Same as deny: backend still holds it open — keep the marker for reconcile.
                track("expert_shield_sos_deescalate_error", "sos_id" to sosId, "source" to source, "reason" to "not_delivered")
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            track("expert_shield_sos_deescalate_error", "sos_id" to sosId, "source" to source, "error" to e.message)
        }
        _state.update { SosState() }
    }

    /**
     * Reconcile the SOS session with the backend (E3 `/sos/active`). Best-effort (null → no
     * change). Drives phase from the backend `status`: initiated → alert, pending → active,
     * denied / no-active → idle. TODO(6b.3-trigger): call on app-resume / job-start (needs the
     * lifecycle hook); auto-nav-to-active on restore belongs to §16 state-restore.
     */
    suspend fun reconcile() {
        val active = sosApi.active() ?: return
        if (!active.hasActiveSos) {
            // Self-heal: clear unconditionally, even when local is already IDLE. A flag orphaned by a
            // crash between resolve and clear would otherwise re-arm the launch reconcile forever.
            clearSosLive()
            if (_state.value.phase != SosPhase.IDLE) {
                // Local thinks SOS is live but the backend has none — desync (recover to idle).
                track("expert_shield_sos_state_desync", "local_sos_mode" to true, "backend_has_active_sos" to false, "sos_id" to _state.value.sosId, "job_id" to currentState.currentJobId())
                cancelAlertTimer()
                _state.update { SosState() }
            }
            return
        }
        // Backend says an SOS is open — keep the marker set so a kill before resolve still recovers.
        markSosLive()
        when (active.status) {
            // Flutter emits sos_synced only for status=initiated (_handleSyncInitiated). Fire it inside the
            // IDLE guard so an already-ALERT re-reconcile doesn't double-count.
            STATUS_INITIATED -> if (_state.value.phase == SosPhase.IDLE) {
                track("expert_shield_sos_synced", "sos_id" to active.sosId, "source" to (_state.value.source ?: "backend_sync"))
                _state.update {
                    SosState(phase = SosPhase.ALERT, sosId = active.sosId, phoneNumber = active.phoneNumber)
                }
                startAlertTimer()
            }
            // Same edge-guard as STATUS_INITIATED above: adopt only on a genuine transition into
            // ACTIVE. Unguarded, this re-fired sync_confirmed on EVERY foreground reconcile for the
            // whole life of an active SOS — inflating the event and making a real backend-driven
            // confirm indistinguishable from a routine re-poll.
            STATUS_PENDING -> if (_state.value.phase != SosPhase.ACTIVE) {
                // Backend confirmed while we were showing the alert — the auto-deny timer must not
                // outlive that transition (it no-ops on the phase guard today, but leaving it armed
                // is one refactor away from auto-denying a confirmed SOS).
                cancelAlertTimer()
                _state.update {
                    it.copy(phase = SosPhase.ACTIVE, sosId = active.sosId, phoneNumber = active.phoneNumber)
                }
                track("expert_shield_sos_sync_confirmed", "sos_id" to active.sosId, "action_type" to "backend", "source" to (_state.value.source ?: "backend_sync"))
            }
            STATUS_DENIED -> {
                track("expert_shield_sos_sync_denied", "sos_id" to active.sosId, "action_type" to "backend", "source" to (_state.value.source ?: "unknown"))
                cancelAlertTimer()
                clearSosLive()
                _state.update { SosState() }
            }
            else -> {}
        }
    }

    /**
     * "Call SoS Team" / notification "Escalate": dial (E4). Repeatable, no state change (O-3).
     * Returns false (no throw) when the resolved phone is blank or the API rejects — the caller
     * surfaces that as a visible error instead of a silent no-op.
     */
    suspend fun callSosTeam(): Boolean {
        val phone = _state.value.phoneNumber
            ?: remoteConfig.getString("expert_shield_sos_fallback_phone", "")
        return sosApi.callSosTeam(phone)
    }

    /**
     * Route a plugin `NotificationAction`. The plugin already ran the handler + updated its own
     * state (D-15), so confirm/deny/end_sos SYNC state without re-invoking the plugin command.
     */
    suspend fun handleNotificationAction(action: String) {
        // A killed/backgrounded revival can cold-start SosCoordinator with a fresh IDLE state, so the
        // phase-guarded confirm/deny/deescalate below would no-op and never reach the backend. For an
        // action that RESUMES an existing session, rehydrate the live SOS from the backend first (§4
        // process-revival path) so the action reaches sosApi.resolve() and ESCALATE dials the real
        // number, not the RC fallback. Guarded on IDLE so the normal alive path skips the extra fetch.
        if (action != ACTION_SOS_BUTTON && _state.value.phase == SosPhase.IDLE) reconcile()
        when (action) {
            ACTION_SOS_BUTTON -> raiseDetected(SOURCE_NOTIFICATION_BUTTON, TRIGGER_NON_ML)
            ACTION_CONFIRM -> {
                track("expert_shield_sos_notification_confirm_tap", "sos_id" to _state.value.sosId, "source" to _state.value.source)
                confirm(pluginAlreadyActed = true)
            }
            ACTION_DENY -> deny(pluginAlreadyActed = true)
            ACTION_END_SOS -> deescalate(pluginAlreadyActed = true)
            ACTION_ESCALATE -> callSosTeam()
            else -> {}
        }
    }

    /**
     * Apply a drained FCM push action (from [com.snabbit.runner.shared.features.kavach.data.SosPushStore]).
     * The caller runs [reconcile] FIRST so the phase is synced from the backend; then the
     * phase-guarded confirm/deny fire with `pluginAlreadyActed=true` (the notification already ran
     * the plugin handler). Stale-guard: ignore a push for a different sos than the current session.
     */
    suspend fun applyPush(action: String, sosId: Int) {
        val current = _state.value.sosId
        if (current != null && current != sosId) return   // stale push
        track("expert_shield_sos_push_drained", "sos_id" to sosId, "action" to action)
        when (action) {
            PUSH_CONFIRM, PUSH_AUTO_CONFIRM -> confirm(pluginAlreadyActed = true)
            PUSH_DENY, PUSH_EXPIRED -> deny(pluginAlreadyActed = true)
            else -> {}
        }
    }

    private fun startAlertTimer() {
        cancelAlertTimer()
        alertTimer = scope.launch {
            val secs = remoteConfig.getInt("expert_shield_sos_alert_display_secs", DEFAULT_ALERT_SECS)
            delay(secs * 1000L)
            // Only auto-deny while foregrounded. Backgrounded (call/app-switch) → leave in ALERT so
            // the runner is re-prompted on resume instead of a silent deny (safety; parity w/ Flutter
            // _appWasBackgrounded). The foreground reconcile re-surfaces the pending SOS.
            // Run deny on `scope`, NOT as this timer coroutine: deny() calls cancelAlertTimer(),
            // which would cancel THIS coroutine mid-resolve and leave the SOS stuck in ALERT (#1).
            if (_state.value.phase == SosPhase.ALERT && lifecycle.foreground.value) {
                scope.launch { deny(actionType = ACTION_TIMEOUT) }
            }
        }
    }

    private fun cancelAlertTimer() {
        alertTimer?.cancel()
        alertTimer = null
    }

    private companion object {
        const val SOURCE_MANUAL = "manual"
        const val SOURCE_NOTIFICATION_BUTTON = "notification_button"
        const val TRIGGER_NON_ML = "non_ml"
        const val DEFAULT_ALERT_SECS = 20

        // Analytics action_type values.
        const val ACTION_USER = "user"
        const val ACTION_NOTIFICATION = "notification"
        const val ACTION_TIMEOUT = "timeout"

        // FCM push action strings (drained by SosPushStore).
        const val PUSH_CONFIRM = "confirm"
        const val PUSH_AUTO_CONFIRM = "auto_confirm"
        const val PUSH_DENY = "deny"
        const val PUSH_EXPIRED = "expired"

        // Plugin ShieldEvent.NotificationAction.action strings (verified in AndroidShieldController).
        const val ACTION_SOS_BUTTON = "sosButton"
        const val ACTION_CONFIRM = "confirm"
        const val ACTION_DENY = "deny"
        const val ACTION_END_SOS = "end_sos"
        const val ACTION_ESCALATE = "escalate"

        // E3 /sos/active `status` values.
        const val STATUS_INITIATED = "initiated"
        const val STATUS_PENDING = "pending"
        const val STATUS_DENIED = "denied"
    }
}

/** Current SOS session. */
data class SosState(
    val phase: SosPhase = SosPhase.IDLE,
    val sosId: Int? = null,
    val phoneNumber: String? = null,
    val source: String? = null,
    // Job the SOS was raised on (captured at raise; drives is_on_job analytics). Null for a
    // backend-restored SOS — GET /sos/active doesn't return job_id.
    val jobId: Int? = null,
)

enum class SosPhase { IDLE, INITIATING, ALERT, ACTIVE }

/**
 * A manual SOS was refused before anything was started — no auth token, or no network. Thrown so the
 * caller's existing error path shows a toast; nothing was sent and the plugin was never touched.
 */
class SosRaiseBlockedException(val reason: PreflightBlock) :
    Exception("SOS raise blocked: ${reason.name.lowercase()}")
