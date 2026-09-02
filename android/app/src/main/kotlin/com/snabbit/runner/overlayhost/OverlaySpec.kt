package com.snabbit.runner.overlayhost

import android.content.Intent
import androidx.compose.runtime.Composable
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.Flow

/** How the host builds the overlay window for a spec. */
enum class OverlayWindowStyle {
    /** Full-screen translucent window, dimmed behind, content centred — the modal card. */
    DimModal,

    /** Top-anchored wrap-height window, no scrim. */
    Banner,

    /** Wrap-sized floating window, no scrim. */
    Pill,
}

/**
 * One host presentation: what the host gives a spec for the lifetime of its
 * window, and what the spec may ask of it. CTAs must be fully handled
 * natively/shared-side (engine-independence rule).
 */
interface OverlayHostSession {
    /**
     * The start intent (feature extras ride here, e.g. the job i18n labels).
     * Named to avoid colliding with `Activity.getIntent()` on activity-backed sessions.
     */
    val startIntent: Intent?

    /** Host-owned UI scope — cancelled when the window is torn down. */
    val scope: CoroutineScope

    /** Remove the window and stop the service. */
    fun dismissAndStop()

    /** Open the app (REORDER_TO_FRONT) — permitted via the SYSTEM_ALERT_WINDOW exemption. */
    fun bringAppToForeground()
}

/**
 * A feature's pluggable overlay (TRD §8 "generic-in-Dart ⇒ generic-in-KMP"):
 * [ComposeOverlayHost] owns all window plumbing once; features contribute
 * Koin-registered specs resolved by [key] from the start intent. Each spec
 * depends on its own feature + core — never on another spec; cross-feature
 * precedence is the host-internal [priority] comparison (replaces the legacy
 * `OverlayService.instance` cross-feature check).
 */
interface OverlaySpec {
    /** Stable id carried in the start intent (`"awol"`, `"new_job"`). */
    val key: String

    val window: OverlayWindowStyle

    /** Higher wins while a window is up — AWOL (penalty) beats new-job (opportunity). */
    val priority: Int

    /**
     * When true, the launcher draws this overlay OVER the app even while it is in the
     * FOREGROUND (not just backgrounded/locked) — for alerts that must be unmissable
     * regardless of what the runner is doing (AWOL). Default false: features whose
     * foreground state is served by an in-app surface (new-job) opt out, so the
     * launcher's foreground bail still suppresses the draw-over for them.
     */
    val drawsOverForegroundApp: Boolean get() = false

    /**
     * Store-driven launch predicate for the generic launcher (M5): should this
     * spec's overlay be presented for [state] (already gated by the launcher on
     * background + flag + permission)? Default false — features with their own
     * launcher (the job plugin) opt out of generic triggering.
     */
    fun shouldTrigger(state: RunnerState?): Boolean = false

    /**
     * Launcher-side suppression: the launcher skips presenting a spec whose
     * feature has already dismissed this [state]'s alert — without it every
     * store emission restarts the host FGS (and its dim window) only for
     * [visible] to replay false and tear it straight down. Implementations
     * must answer DETERMINISTICALLY from the emission plus process-lived
     * memory (no async work, no race on another collector processing the same
     * emission first) — on a cold killed-state start that memory is empty, so
     * nothing is suppressed and the killed-state launch path is unaffected.
     * Default false — features without dismissal memory never suppress.
     */
    fun suppressedFor(state: RunnerState?): Boolean = false

    /**
     * Emits false → the host self-dismisses (feed-driven dismissal; the
     * new-job pattern of tearing down the moment the state moves on).
     */
    fun visible(session: OverlayHostSession): Flow<Boolean>

    /** The window content. The host wraps it in a MaterialTheme; specs apply SnabbitTheme. */
    @Composable
    fun Content(session: OverlayHostSession)
}
