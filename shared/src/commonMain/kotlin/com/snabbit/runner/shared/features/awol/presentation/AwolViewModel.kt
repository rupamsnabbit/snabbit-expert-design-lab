package com.snabbit.runner.shared.features.awol.presentation

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.awol.domain.localized
import com.snabbit.runner.shared.core.permissions.PermissionManager
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import com.snabbit.runner.shared.features.awol.data.toAwolSnapshot
import com.snabbit.runner.shared.features.awol.domain.AwolFlags
import com.snabbit.runner.shared.features.awol.domain.AwolPhase
import com.snabbit.runner.shared.features.awol.domain.AwolSnapshot
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.features.job.domain.JobClock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Process-lived AWOL coordinator — a Koin **single** with its own scope, never
 * a per-screen factory (TRD §8): episode memory must survive screens
 * mounting/unmounting, the launcher and the overlay spec need the routing
 * signal when no UI exists at all (backgrounded / killed-revived), and both
 * surfaces reading one [uiState] is what makes FR-09 structural.
 *
 * It collects [RunnerStateSource], maps via [toAwolSnapshot], runs the 1-Hz
 * `deadline − now` recompute while a payload is present (TR-03 — recompute,
 * never accumulate; restart-safe by construction), owns the §9 surface
 * routing, and keeps the per-episode dismissed memory. No window /
 * permission-request / alarm / network code lives here.
 *
 * Episode memory (FR-05/06): dismissal is keyed on `(event_id, phase)` and the
 * dismissed set resets **only on a new event_id** — never on a same-episode
 * payload refresh (legacy `overlay_provider` rule). A phase flip within the
 * episode uses a different key, so the new state's alert shows once (FR-06).
 * A missing event_id derives episode identity from payload transitions
 * (`detected_at`, legacy behaviour).
 */
class AwolViewModel(
    private val source: RunnerStateSource,
    private val clock: JobClock,
    private val permissions: PermissionManager,
    private val analytics: AwolAnalytics,
    private val logger: Logger,
    private val store: LocalizationStore,
    private val strings: AwolStrings = AwolStrings(),
    private val scope: CoroutineScope,
    /**
     * Stops the host-owned breach alarm when the runner acknowledges the alert
     * (`core/alarm` seam, wired in [com.snabbit.runner.shared.features.awol.di.awolModule]).
     * A plain lambda rather than the controller itself, so tests stay DI-free;
     * the default no-op covers iOS and unit tests.
     */
    private val silenceAlarm: () -> Unit = {},
) {
    private val _uiState = MutableStateFlow(AwolUiState())
    val uiState: StateFlow<AwolUiState> = _uiState.asStateFlow()

    private val _effects = MutableSharedFlow<AwolEffect>(extraBufferCapacity = 8)
    val effects: SharedFlow<AwolEffect> = _effects.asSharedFlow()

    /** Host-pushed remote flags; defaults ship dark (TR-07). */
    private val _flags = MutableStateFlow(AwolFlags())

    /**
     * Read-only view for collectors. Only [setFlags] mutates it — a raw
     * `flags.value = …` write would skip `routingDirty` + [recompute], leaving
     * the routed surface stale, so the mutable stays private.
     */
    val flags: StateFlow<AwolFlags> = _flags.asStateFlow()

    // Host visibility. Defaults to foreground; before the host makes contact the
    // dark default flags (overlayEnabled=false) already keep routing on the
    // in-app surface, so no overlay can fire pre-handshake (FR-09, TR-07).
    private val foreground = MutableStateFlow(true)
    private val inPip = MutableStateFlow(false)

    private var snapshot: AwolSnapshot? = null

    /** `deadline` (server `trigger_at`, else receipt + remaining_seconds), or null → no meter. */
    private var anchorMillis: Long? = null

    /** One expiry pass per anchor — the analytics event and the re-fetch poll each fire once. */
    private var refreshRequestedForAnchor = false

    private var episodeId: String? = null
    private val dismissedPhases = mutableSetOf<AwolPhase>()

    private var ticker: Job? = null

    /** Post-expiry poll for the server's next penalty cycle — see [startExpiryRefresh]. */
    private var expiryRefreshJob: Job? = null

    // Surface routing is re-evaluated only when one of its inputs changes
    // (snapshot / flags / host visibility / dismissal) — never on a pure
    // countdown tick, so the 1-Hz loop does not hit the permission check.
    private var routingDirty = true
    private var lastSurface = AwolSurface.NONE

    /**
     * Serializes state derivation. [recompute] only signals here; a single
     * consumer applies [routeSurface] + [publish]. CONFLATED because only the
     * latest inputs matter — it coalesces the 1-Hz ticks with intent/flag
     * pushes, and (being one consumer) removes the out-of-order emit two
     * overlapping recomputes used to produce when [routeSurface] suspended on
     * the permission check before writing [_uiState].
     */
    private val deriveSignal = Channel<Unit>(Channel.CONFLATED)

    /**
     * One expiry pass per anchor. [recompute] detects the meter reaching zero
     * and signals here; a dedicated consumer runs the side effects (penalty
     * analytics + the post-expiry poll) off the state-derive path — they must
     * not ride the 1-Hz ticker's recompute.
     */
    private val expirySignal = Channel<AwolSnapshot>(Channel.BUFFERED)

    init {
        // Consumers first, so they are parked on receive before any signal fires.
        scope.launch {
            for (unit in deriveSignal) {
                deriveState()
            }
        }
        scope.launch {
            for (expired in expirySignal) {
                onAnchorExpired(expired)
            }
        }
        scope.launch {
            source.state.collect { envelope ->
                // Re-localize per snapshot (never a one-shot bake): reads the current
                // LocalizationStore, so title/warning/badge pick up the server map once Dart
                // pushes it (the store is empty at container-build). Absent key → English.
                onSnapshot(envelope.toAwolSnapshot(clock, logger, strings.localized(store)))
            }
        }
    }

    /** Host pushes RC-read flags (Android: the AWOL config channel). */
    fun setFlags(value: AwolFlags) {
        _flags.value = value
        routingDirty = true
        recompute()
    }

    /**
     * Host reports app visibility. [isInPip] routes picture-in-picture to the
     * in-app surface (§9 PiP rule — never stack an overlay window on the app's
     * own PiP window; the launcher brings the app to the foreground instead).
     */
    fun setHostVisibility(isForeground: Boolean, isInPip: Boolean = false) {
        foreground.value = isForeground
        inPip.value = isInPip
        routingDirty = true
        recompute()
    }

    fun onIntent(intent: AwolUiIntent) {
        when (intent) {
            AwolUiIntent.Dismiss -> {
                // "I understand" — the runner acknowledged, so the alarm stops on
                // the tap rather than running out its repeat count. The alarm is
                // host-owned (Dart), hence the seam; the breach itself is still
                // active, so the host silences WITHOUT clearing its de-dupe
                // episode — this breach must not re-alarm, a new one still must.
                silenceAlarm()
                snapshot?.let { dismissedPhases.add(it.phase) }
                routingDirty = true
                recompute()
            }
            AwolUiIntent.ShowDirections -> {
                val hotspot = snapshot?.hotspot ?: return
                val lat = hotspot.latitude ?: return
                val lng = hotspot.longitude ?: return
                _effects.tryEmit(AwolEffect.OpenDirections(lat, lng, hotspot.name))
            }
        }
    }

    /**
     * Whether [state]'s alert has already been dismissed this episode — the
     * launcher-side suppression query (the AWOL spec's `suppressedFor`): a
     * dismissed phase must not restart the overlay-host FGS on every store
     * refresh only for `visible` to replay false and tear it straight down.
     * Answers deterministically from the emission plus this process-lived
     * memory — the same [toAwolSnapshot] path the collector uses, so no async
     * work and no race on the coordinator processing the same emission first:
     * false when the emission carries no payload, false for another episode's
     * id (a new episode is never pre-dismissed, even before [onSnapshot] has
     * reset [dismissedPhases] for it), else whether the emission's phase is in
     * [dismissedPhases]. On a cold killed-state start the memory is empty, so
     * nothing is suppressed.
     */
    fun isPhaseDismissed(state: RunnerState?): Boolean {
        val next = state.toAwolSnapshot(clock, logger, strings) ?: return false
        return (next.eventId ?: derivedEpisodeId(next)) == episodeId &&
            next.phase in dismissedPhases
    }

    private fun onSnapshot(next: AwolSnapshot?) {
        if (next == null) {
            // Server say-so: the episode is over — everything clears (FR-05/15).
            snapshot = null
            anchorMillis = null
            episodeId = null
            dismissedPhases.clear()
            routingDirty = true
            lastSurface = AwolSurface.NONE
            stopTicker()
            stopExpiryRefresh()
            recompute()
            return
        }

        val nextEpisodeId = next.eventId ?: derivedEpisodeId(next)
        if (nextEpisodeId != episodeId) {
            // New episode only — dismissed memory never resets on a same-episode refresh.
            episodeId = nextEpisodeId
            dismissedPhases.clear()
        }

        val nextAnchor = next.deadlineMillis
            ?: next.remainingSeconds?.let { clock.nowMillis() + it * 1_000L }
        if (nextAnchor != anchorMillis) {
            // The next cycle landed — the post-expiry poll has what it was waiting for.
            anchorMillis = nextAnchor
            // Re-arm the one-shot expiry refresh only for an anchor that can still
            // expire. When the server omits `countdown.trigger_at` the anchor is
            // DERIVED as `now + remaining_seconds`, so it moves on every envelope —
            // and once remaining_seconds has reached 0 (the normal post-expiry steady
            // state, FR-07: warning persists, meter static at zero) an unconditional
            // re-arm loops: expiry fires requestRefresh() -> Dart re-fetches
            // current_state -> new envelope -> new derived anchor -> re-arm -> expiry
            // fires again, unthrottled, as fast as the round-trip allows, for the whole
            // breach. It would also re-emit `penaltyApplied` each iteration, inflating
            // the penalty dashboards. An already-expired anchor is never a new
            // countdown, so it must not re-arm; a genuinely new future deadline still does.
            if (nextAnchor == null || nextAnchor > clock.nowMillis()) {
                refreshRequestedForAnchor = false
                stopExpiryRefresh()
            }
        }

        snapshot = next
        routingDirty = true
        startTicker()
        recompute()
    }

    /**
     * Episode identity when the server omits `event_id` (legacy behaviour:
     * derive from payload transitions) — `detected_at` marks the episode; a
     * payload without either is one episode until the awol key clears.
     */
    private fun derivedEpisodeId(next: AwolSnapshot): String =
        "derived:${next.detectedAtMillis ?: "static"}"

    /**
     * 1-Hz recompute while a live countdown exists. Stops itself once the
     * anchor expires (the warning persists, FR-07, but the meter is static at
     * zero — nothing left to recompute) and restarts on the next payload.
     */
    private fun startTicker() {
        stopTicker()
        if (anchorMillis == null) return
        ticker = scope.launch {
            while (isActive && (anchorMillis ?: 0L) > clock.nowMillis()) {
                delay(1_000)
                recompute()
            }
        }
    }

    private fun stopTicker() {
        ticker?.cancel()
        ticker = null
    }

    /**
     * Poll `current_state` until the server publishes the next penalty cycle.
     *
     * A single fetch at zero races the backend: the penalty workflow that mints
     * the next `trigger_at` runs asynchronously, so the envelope answering a
     * fetch issued the instant the meter hits zero usually still carries the
     * anchor that just expired. [onSnapshot] then sees an unchanged anchor, the
     * ticker has already stopped (nothing left to count down), and the one-shot
     * refresh is spent — so nothing ever asks again and the card sits at 00:00
     * until the runner pulls to refresh by hand. The MQTT cohort is worst hit: a
     * healthy connection cancels the HTTP fallback loop, so there is no periodic
     * fetch to recover on and the card can stay stuck indefinitely.
     *
     * So keep asking, bounded: [EXPIRY_REFRESH_ATTEMPTS] fetches spaced
     * [EXPIRY_REFRESH_INTERVAL_MS] apart. The loop exits as soon as
     * [anchorMillis] moves off the expired anchor — which is exactly what
     * [onSnapshot] does on the payload it is waiting for — or when the episode
     * clears. Capped so a server that never mints a new cycle (the runner is
     * back in the hotspot, the episode is ending) can't leave it polling.
     */
    private fun startExpiryRefresh() {
        val expiredAnchor = anchorMillis
        expiryRefreshJob?.cancel()
        expiryRefreshJob = scope.launch {
            var attempts = 0
            while (isActive && attempts < EXPIRY_REFRESH_ATTEMPTS && anchorMillis == expiredAnchor) {
                source.requestRefresh()
                attempts++
                delay(EXPIRY_REFRESH_INTERVAL_MS)
            }
        }
    }

    private fun stopExpiryRefresh() {
        expiryRefreshJob?.cancel()
        expiryRefreshJob = null
    }

    /**
     * Signals a state derivation. Cheap and non-suspending — it never touches
     * [_uiState] itself. The [deriveSignal] consumer runs [deriveState], so
     * every recompute (ticker, intent, flag/visibility push, snapshot) is
     * applied by one serialized coroutine and can never emit out of order.
     */
    private fun recompute() {
        deriveSignal.trySend(Unit)
    }

    /**
     * The single, serialized state-derive pass. Reads the current snapshot,
     * detects meter expiry (handing the side effects to [expirySignal] — they
     * don't belong on this path), routes only when `routingDirty`, and
     * publishes. Runs on one consumer coroutine, so [routeSurface] suspending
     * on the permission check can't interleave two writes to [_uiState].
     */
    private suspend fun deriveState() {
        val current = snapshot
        if (current == null) {
            _uiState.value = AwolUiState()
            return
        }
        if (remainingSeconds() == 0 && !refreshRequestedForAnchor) {
            // Meter expiry → mark this anchor handled and hand the side effects
            // (post-expiry poll + penalty analytics) to the expiry channel; the
            // fresh-envelope re-fetch is polled, not one-shot, because the next
            // cycle is minted asynchronously (see startExpiryRefresh).
            refreshRequestedForAnchor = true
            expirySignal.trySend(current)
        }
        // Only routing suspends ([routeSurface]), and it runs solely when
        // `routingDirty` — which the 1 Hz tick never sets — so the tick path
        // stays synchronous and never re-hits the permission check.
        if (routingDirty) {
            lastSurface = routeSurface(current)
            routingDirty = false
        }
        publish(current)
    }

    /**
     * The once-per-anchor expiry side effects, off the state-derive path: poll
     * `current_state` for the server's next penalty cycle (see
     * [startExpiryRefresh]) and emit the penalty analytics so the new red-card
     * count shows in seconds, not up to 60 s (§10 audit note).
     */
    private fun onAnchorExpired(current: AwolSnapshot) {
        startExpiryRefresh()
        analytics.penaltyApplied(
            redCardsTotal = current.redCardsTotal,
            penaltyStage = current.breachCount,
            minutesOutOfHotspot = current.detectedAtMillis?.let {
                ((clock.nowMillis() - it) / 60_000L).toInt()
            },
        )
    }

    /** Seconds left on the current anchor, floored at zero; null with no anchor. */
    private fun remainingSeconds(): Int? = anchorMillis?.let {
        ((it - clock.nowMillis()) / 1_000L).coerceAtLeast(0L).toInt()
    }

    /**
     * The single [_uiState] write point. Reads the countdown fresh rather than
     * taking a captured value, so a derive pass that suspended in [routeSurface]
     * publishes the current tick, never one sampled before it was scheduled.
     */
    private fun publish(current: AwolSnapshot) {
        val remaining = remainingSeconds()
        _uiState.value = AwolUiState(
            snapshot = current,
            remainingSeconds = remaining,
            expired = remaining == 0,
            surface = lastSurface,
            imageUrl = resolveImageUrl(current),
        )
    }

    /**
     * Server `image_url` wins; else the phase's RC fallback (the legacy
     * `awol_overlay_converter` rule: breach/job → enter-hotspot, re-entered →
     * back-in-hotspot). Both null → the image slot keeps its placeholder.
     */
    private fun resolveImageUrl(current: AwolSnapshot): String? =
        current.imageUrl ?: when (current.phase) {
            AwolPhase.BREACH, AwolPhase.JOB -> flags.value.fallbackBreachImageUrl
            AwolPhase.RE_ENTERED -> flags.value.fallbackReEnteredImageUrl
        }

    /** The §9 routing table — the one decision point (FR-09/10). */
    private suspend fun routeSurface(current: AwolSnapshot): AwolSurface = when {
        // "I Understand" closed this state's alert; no reopen on refresh (FR-05).
        // In-app the pink card persists as the passive reminder (show-both);
        // backgrounded there is nothing left to show.
        current.phase in dismissedPhases ->
            if (foreground.value || inPip.value) AwolSurface.HOME_CARD else AwolSurface.NONE
        // PiP rule: never stack an overlay window on the app's own PiP window —
        // the in-app card carries the alert (§9).
        inPip.value -> AwolSurface.HOME_CARD
        // Overlay surface → it draws over the app whether open or backgrounded:
        // a safety alert must be unmissable (foreground show-both — the pink card
        // renders underneath and remains after dismissal). The permission gate
        // only matters for the surface this VM can't itself verify — the
        // foreground draw-over. Backgrounded/locked the presenting surface is
        // either the keyguard alert (needs NO overlay permission; routing NONE
        // here self-finished it — B8) or the launcher's window path, which
        // independently gates canDrawOverlays before starting the host — so
        // routing OVERLAY without the grant can never draw an unpermitted window.
        flags.value.overlayEnabled && (overlayGranted() || !foreground.value) ->
            AwolSurface.OVERLAY
        // Overlay unavailable: in the foreground the in-app pink card is the
        // fallback; backgrounded → degrade: alarm already fired (Dart), the
        // card shows on next open (TR-06).
        foreground.value -> AwolSurface.HOME_CARD
        else -> AwolSurface.NONE
    }

    private suspend fun overlayGranted(): Boolean = try {
        permissions.check(SnabbitPermission.Overlay) == PermissionStatus.GRANTED
    } catch (e: Exception) {
        logger.e(TAG, "overlay permission check failed; treating as denied", e)
        false
    }

    private companion object {
        const val TAG = "AwolViewModel"

        /** Post-expiry re-fetch cadence: quick enough to feel instant, slow enough not to hammer. */
        const val EXPIRY_REFRESH_INTERVAL_MS = 5_000L

        /** ~1 min of polling — past that, the next cycle isn't coming and the episode is resolving. */
        const val EXPIRY_REFRESH_ATTEMPTS = 12
    }
}
