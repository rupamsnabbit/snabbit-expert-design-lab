package com.snabbit.runner.shared.core.background

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import com.snabbit.runner.shared.core.defaultLogger
import com.snabbit.runner.shared.core.realtime.CredentialsProvider
import com.snabbit.runner.shared.core.realtime.CurrentStateFetcher
import com.snabbit.runner.shared.core.realtime.HiveMqttTransport
import com.snabbit.runner.shared.core.database.snabbitDatabase
import com.snabbit.runner.shared.core.realtime.RoomSnapshotStore
import com.snabbit.runner.shared.core.realtime.RealtimeConfig
import com.snabbit.runner.shared.core.realtime.RealtimeConfigStore
import com.snabbit.runner.shared.core.realtime.RealtimeStateEngine
import com.snabbit.runner.shared.core.realtime.RealtimeHost
import com.snabbit.runner.shared.core.realtime.RealtimeStatus
import com.snabbit.runner.shared.core.realtime.WakeReason
import com.snabbit.runner.shared.core.realtime.SnapshotSink
import com.snabbit.runner.shared.core.realtime.RunnerStateProjector
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import org.koin.core.context.GlobalContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * The unified foreground-runtime host (LLD §5.4). WS0 scope: hosts the MQTT
 * transport as its first (and only) job so the Doze/OEM soak protocol can run
 * against the real service shape. The plug-in job API, engine wiring and
 * login/logout lifecycle land in WS4.
 *
 * Driven by intent extras so the spike scripts (spike/scripts/) can operate it over adb.
 * Emits structured logcat markers (`SPIKE_MARKER ...`, tag [TAG]) that the
 * scripts parse — treat the marker format as an interface.
 *
 * FGS type is `location` (was dataSync): the service hosts the MQTT keepalive today and
 * absorbs the periodic location→backend upload when the Flutter location FGS is retired,
 * so it reuses the app's already-declared FOREGROUND_SERVICE_LOCATION — no separate Play
 * declaration, and not dataSync (which Android 15 force-stops after ~6h/24h). While this
 * service runs, the process is exempt from Doze network suspension — the property WS0
 * exists to validate on OEM devices (§6.10). A location-typed FGS throws on start without
 * location permission (Android 14+): [RealtimePlugin] pre-checks it and [goForeground]
 * catches the revocation race.
 */
class SnabbitForegroundService : Service() {

    // Single-threaded confinement: the engine's transport (HiveMQ `client`),
    // status, and job fields are not thread-safe, and the live kill-switch flip
    // (RealtimeStateEngine.setMqttEnabled) can arrive concurrently with the
    // transport-state collectors. limitedParallelism(1) serializes all engine
    // work onto one thread without blocking suspends (it's I/O-bound). (Review #2.)
    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    private val scope =
        CoroutineScope(SupervisorJob() + Dispatchers.Default.limitedParallelism(1))
    private var engine: RealtimeStateEngine? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var startedAtMs: Long = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            // -- Production entry points (WS4) --
            ACTION_START -> startProduction(wake = false)
            ACTION_WAKE -> startProduction(wake = true)
            ACTION_STOP -> {
                Log.i(TAG, "SPIKE_MARKER event=stop_requested")
                engine?.stop()
                activeEngine = null
                stopSelf()
            }
            // -- WS0 soak-spike entry point: DEBUG builds only --
            ACTION_START_SPIKE -> {
                val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
                if (!debuggable) {
                    Log.w(TAG, "spike entry refused on non-debuggable build")
                    stopSelf()
                    return START_NOT_STICKY
                }
                startSpike(intent)
            }
            else -> Log.w(TAG, "unknown action: ${intent?.action}")
        }
        return START_STICKY
    }

    /**
     * Production path: engine + config come from RealtimeHost (Koin seams,
     * hydrated encrypted config + JWT — LLD §6.2). Triggered at login /
     * cold-boot via RealtimePlugin ("start") and by the FCM data-message
     * killed-app path ("wake" — LLD §6.5: the Dart background isolate starts
     * this service with a wake intent; no bridge on the killed path).
     */
    private fun startProduction(wake: Boolean) {
        startedAtMs = SystemClock.elapsedRealtime()
        if (!goForeground()) {
            Log.w(TAG, "startProduction aborted — could not enter foreground (location permission?)")
            stopSelf()
            return
        }
        val existing = engine
        if (existing != null) {
            if (wake) existing.onWakeSignal(WakeReason.FCM_DATA)
            return
        }
        scope.launch {
            val hosted = RealtimeHost.create(applicationContext, scope, defaultLogger())
            if (hosted == null) {
                Log.i(TAG, "realtime not started (logged out / not enrolled / kill-switched)")
                stopSelf()
                return@launch
            }
            engine = hosted.engine
            launch {
                hosted.engine.status.collect { s ->
                    Log.i(TAG, "SPIKE_MARKER event=status status=$s elapsedMs=${elapsed()}")
                }
            }
            // Feature #1: the app-side MQTT kill-switch decides MQTT vs poll-only.
            if (hosted.appMqttEnabled) hosted.engine.start(hosted.config)
            else hosted.engine.startPollOnly(hosted.config)
            if (wake) hosted.engine.onWakeSignal(WakeReason.FCM_DATA)
            // Publish for the Dart-bridge live flip only AFTER start, then re-apply the
            // current flag in case a flip landed during the build/start window — a
            // no-op if the mode already matches. (Review #11/#12.)
            activeEngine = hosted.engine
            GlobalContext.getOrNull()?.get<RealtimeConfigStore>()?.appMqttEnabled?.value
                ?.let { hosted.engine.setMqttEnabled(it) }
        }
    }

    private fun startSpike(intent: Intent) {
        startedAtMs = SystemClock.elapsedRealtime()
        if (!goForeground()) {
            Log.w(TAG, "startSpike aborted — could not enter foreground (location permission?)")
            stopSelf()
            return
        }

        // Partial wakelock around connect/subscribe only (survival-harness rule,
        // LLD §5.6) — time-boxed, never held for the service's lifetime.
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$TAG:connect")
            .apply { acquire(WAKELOCK_TIMEOUT_MS) }

        val config = RealtimeConfig(
            host = intent.getStringExtra(EXTRA_HOST) ?: "10.0.2.2",
            port = intent.getIntExtra(EXTRA_PORT, 1883),
            useTls = intent.getBooleanExtra(EXTRA_TLS, false),
            username = intent.getStringExtra(EXTRA_USERNAME) ?: "",
            password = intent.getStringExtra(EXTRA_JWT) ?: "",
            clientId = intent.getStringExtra(EXTRA_CLIENT_ID) ?: "spike_${Build.MODEL}_${startedAtMs}",
            stateTopic = intent.getStringExtra(EXTRA_TOPIC) ?: "maestro/user/0/state",
        )
        Log.i(TAG, "SPIKE_MARKER event=start host=${config.host}:${config.port} tls=${config.useTls} topic=${config.stateTopic}")

        // WS0 hosts the REAL engine (WS3), not the bare transport: the soak
        // exercises the same apply-gate + reconcile-trigger code that ships.
        // Spike seams: in-memory store; no backend, so the fetcher just logs
        // (reconcile paths are validated in commonTest; HTTP lands in WS4).
        // WS5 (DB-source): the engine writes the version-gated snapshot to the DB
        // (RoomSnapshotStore) and RunnerStateProjector projects that store into
        // RunnerStateStore — the read model KMP surfaces observe. One write path,
        // DB is the source of truth; the sink is telemetry only.
        val koin = GlobalContext.getOrNull()
        val snapshotStore = RoomSnapshotStore(
            dao = snabbitDatabase(applicationContext).runnerHomeStateDao(),
            runnerId = 0L, // spike constant; production keys by user_id (WS4)
            nowMs = { System.currentTimeMillis() },
        )
        val runnerStateStore = koin?.get<RunnerStateStore>()
        val e = RealtimeStateEngine(
            transport = HiveMqttTransport(defaultLogger()),
            store = snapshotStore,
            fetcher = CurrentStateFetcher {
                Log.i(TAG, "SPIKE_MARKER event=reconcile_requested (no backend in spike)")
                null
            },
            credentials = CredentialsProvider { intent.getStringExtra(EXTRA_JWT) },
            // Telemetry seam only — the read model is fed by the DB projection below.
            sink = SnapshotSink { env, source ->
                Log.i(
                    TAG,
                    "SPIKE_MARKER event=applied seq=${env.stateSeq} epoch=${env.epoch} " +
                        "source=$source elapsedMs=${elapsed()}",
                )
            },
            scope = scope,
            logger = defaultLogger(),
        )
        engine = e
        // DB is the source of truth: project the version-gated store into
        // RunnerStateStore. observe() replays the persisted row on subscription, so
        // this cold-boot-seeds the last snapshot on its own — retiring the one-shot
        // "re-emit on Connected" seed the spike previously carried.
        runnerStateStore?.let { RunnerStateProjector(store = snapshotStore, target = it).start(scope) }
        scope.launch {
            e.status.collect { s ->
                Log.i(TAG, "SPIKE_MARKER event=status status=$s elapsedMs=${elapsed()}")
                if (s is RealtimeStatus.Connected) {
                    wakeLock?.takeIf { it.isHeld }?.release()
                }
            }
        }
        e.start(config)
    }

    /**
     * Enter the foreground as a `location`-typed FGS. Returns false instead of throwing
     * when `startForeground` is refused: on Android 14+ a location-typed FGS throws
     * (SecurityException / ForegroundServiceStartNotAllowedException) if location
     * permission is absent. [RealtimePlugin.startService] pre-checks the permission
     * before the startForegroundService promise, so this is the revocation-race backstop
     * — the caller stops the service cleanly rather than crashing (the promise is
     * satisfied by the start attempt, so stopping here is safe).
     */
    private fun goForeground(): Boolean {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Realtime updates", NotificationManager.IMPORTANCE_LOW),
            )
        }
        val notification: Notification = (
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION") Notification.Builder(this)
            }
            )
            .setContentTitle("Snabbit Expert")
            .setContentText("Staying connected for live updates")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(true)
            .build()
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "startForeground(location) refused; stopping service", e)
            false
        }
    }

    private fun elapsed(): Long = SystemClock.elapsedRealtime() - startedAtMs

    override fun onDestroy() {
        Log.i(TAG, "SPIKE_MARKER event=service_destroyed elapsedMs=${elapsed()}")
        engine?.stop()
        engine = null
        activeEngine = null
        wakeLock?.takeIf { it.isHeld }?.release()
        scope.cancel()
        super.onDestroy()
    }

    companion object {
        const val TAG = "MqttSoakSpike"

        /**
         * The live engine, so the Dart bridge (RealtimePlugin) can flip the
         * app-side MQTT kill-switch (feature #1) on the running engine without an
         * intent/service-start round-trip. Null when the service isn't running —
         * the flag is still persisted via RealtimeConfigStore, so the next start
         * reads the right mode.
         */
        @Volatile
        var activeEngine: RealtimeStateEngine? = null
        const val ACTION_START = "com.snabbit.runner.realtime.START"
        const val ACTION_WAKE = "com.snabbit.runner.realtime.WAKE"
        const val ACTION_START_SPIKE = "com.snabbit.runner.realtime.START_SPIKE"
        const val ACTION_STOP = "com.snabbit.runner.realtime.STOP"
        const val EXTRA_HOST = "host"
        const val EXTRA_PORT = "port"
        const val EXTRA_TLS = "tls"
        const val EXTRA_USERNAME = "username"
        const val EXTRA_JWT = "jwt"
        const val EXTRA_CLIENT_ID = "clientId"
        const val EXTRA_TOPIC = "topic"
        private const val CHANNEL_ID = "snabbit_realtime_spike"
        private const val NOTIFICATION_ID = 9100
        private const val WAKELOCK_TIMEOUT_MS = 30_000L
    }
}
