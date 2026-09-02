package com.snabbit.runner.debug

import android.app.Activity
import android.app.AlertDialog
import android.app.Application
import android.content.Context
import android.content.Intent
import com.chuckerteam.chucker.api.Chucker
import com.chuckerteam.chucker.api.ChuckerInterceptor
import com.snabbit.runner.MainActivity
import com.snabbit.runner.shared.core.network.ApiHttpInterceptors
import io.flutter.embedding.engine.FlutterEngine
import org.koin.core.module.Module
import org.koin.dsl.module

/**
 * DEBUG source set — the real Chucker wiring.
 *
 * - [networkModule] supplies the Chucker OkHttp interceptor to the shared Ktor engine (all KMP/CMP
 *   traces), via [ApiHttpInterceptors].
 * - [armFloatingButton] shows the single draggable button over every Activity; its tap → [openChooser].
 * - [openChooser] → the Chucker dashboard (KMP/CMP traces) OR the Flutter `chucker_flutter` inspector
 *   (Dio traces) via the [registerFlutterBridge] MethodChannel. The two inspectors stay separate
 *   behind one button because Chucker's own store API is `internal` (can't ingest the Dio traces).
 *
 * The `release` source set provides a no-op twin, so nothing Chucker ships in release.
 */
object ChuckerDebug {
    private var floatingButton: ChuckerFloatingButton? = null

    fun networkModule(context: Context): Module = module {
        single {
            // Logs when the shared engine resolves this → confirms the interceptor attached.
            android.util.Log.d("ChuckerDebug", "KMP OkHttp Chucker interceptor provided to the shared engine")
            ApiHttpInterceptors(listOf(ChuckerInterceptor.Builder(context).build()))
        }
    }

    fun launchIntent(context: Context): Intent? = Chucker.getLaunchIntent(context)

    fun armFloatingButton(app: Application) {
        floatingButton = ChuckerFloatingButton().also { app.registerActivityLifecycleCallbacks(it) }
    }

    /** Register the [ChuckerBridgePlugin] on the FlutterEngine so the bridge channel's lifecycle
     *  follows the engine's (attach/detach). Call from `configureFlutterEngine`. */
    fun registerFlutterBridge(engine: FlutterEngine) {
        engine.plugins.add(ChuckerBridgePlugin())
    }

    /** Dart signalled the chucker_flutter route closed → re-show the NET button. */
    fun onInspectorClosed() {
        floatingButton?.setVisible(true)
    }

    /** Button tap → pick which inspector to open. */
    fun openChooser(activity: Activity) {
        AlertDialog.Builder(activity)
            .setTitle("Network traces")
            .setItems(arrayOf("KMP / CMP  (Chucker)", "Flutter  (Dio)")) { _, which ->
                when (which) {
                    0 -> launchIntent(activity)?.let { activity.startActivity(it) }
                    1 -> showFlutterInspector(activity)
                }
            }
            .show()
    }

    private fun showFlutterInspector(activity: Activity) {
        floatingButton?.setVisible(false) // hide the NET button while the chucker_flutter route is open
        // Only reorder Flutter to the front when the tap came from a NON-Flutter (CMP) screen: on a
        // Flutter screen chucker_flutter is already visible, and reordering there disrupts the back
        // stack (the reported "back brings Flutter forward" bug).
        if (activity.javaClass.name != MainActivity::class.java.name) {
            activity.packageManager.getLaunchIntentForPackage(activity.packageName)?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                activity.startActivity(it)
            }
        }
        ChuckerBridgePlugin.openFlutterInspector()
    }
}
