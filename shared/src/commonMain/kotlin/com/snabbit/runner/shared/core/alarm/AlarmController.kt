package com.snabbit.runner.shared.core.alarm

/**
 * Silences the host-owned alert alarm when the runner **acknowledges** the event
 * that raised it.
 *
 * Alert audio (AWOL breach, delayed check-in / not-moving) is played by the
 * Flutter host on one shared player — `AwolAlarmService` / `LocalizedAudioService`
 * — not by `:shared`, which owns no audio and must stay iOS-compilable. So this
 * is a bind-style seam, the same shape as
 * [com.snabbit.runner.shared.core.runnerstate.RunnerStateStore.bind] and
 * `ProfileHostActions`: `commonMain` declares the hole, `:app` fills it with a
 * MethodChannel-backed lambda (`ProfileActionsPlugin::silenceAlarm`).
 *
 * **Core, not per-feature, on purpose.** An alarm is an app-wide capability, and
 * every alert shares one player — so "stop the noise" is inherently global.
 * Any feature whose CTA acknowledges an alerting event calls [silence]; this
 * never grows per-feature methods, and features never reach for the bridge
 * directly.
 *
 * Fire-and-forget by design. The acknowledging CTA (dismissing an overlay,
 * opening the check-in sheet) must not block on the host, and the Flutter engine
 * is routinely backgrounded while a Compose host is in front — a reply-shaped
 * bridge call can hang there (see `LanguagePlugin.invokeFlutter`'s timeout).
 *
 * Unbound is a silent no-op: iOS, unit tests, and the window before `:app`
 * binds. Silencing is best-effort — never load-bearing for correctness.
 */
class AlarmController {
    private var silencer: (() -> Unit)? = null

    /** `:app` wires the host action here at startup; pass null to unbind. */
    fun bind(silence: (() -> Unit)?) {
        silencer = silence
    }

    /** Stop any alert sound/vibration currently playing. Safe when nothing is. */
    fun silence() {
        silencer?.invoke()
    }
}
