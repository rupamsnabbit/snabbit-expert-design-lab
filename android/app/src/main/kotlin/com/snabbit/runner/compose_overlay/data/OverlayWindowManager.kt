package com.snabbit.runner.compose_overlay.data

import android.graphics.PixelFormat
import android.view.Gravity
import android.view.View
import android.view.WindowManager

/**
 * Manages the system-level overlay window that displays above all other apps.
 *
 * Wraps [WindowManager] operations (addView / removeView / updateViewLayout)
 * with safety checks so callers never crash from double-add or detached-view
 * errors. Only one overlay view is active at a time — calling any `show*()`
 * method dismisses the previous view first.
 *
 * Three layout modes are supported:
 *  - **Dialog**: centred, full-width, wraps content — used for breach countdown.
 *  - **Banner**: top-anchored, full-width — used for re-entered state.
 *  - **Mini**: top-centred, draggable pill — shown after user acknowledges breach.
 */
class OverlayWindowManager(
    private val windowManager: WindowManager,
) {
    private var currentView: View? = null
    private var currentParams: WindowManager.LayoutParams? = null

    /**
     * Show a full-screen centred dialog overlay (breach countdown).
     * Dismisses any existing overlay first.
     */
    fun showDialog(view: View) {
        dismiss()
        val params = createDialogParams()
        addViewSafely(view, params)
    }

    /**
     * Show a top-anchored banner overlay (re-entered state).
     * Dismisses any existing overlay first.
     */
    fun showBanner(view: View) {
        dismiss()
        val params = createBannerParams()
        addViewSafely(view, params)
    }

    /**
     * Show a compact draggable mini overlay (post-acknowledgement).
     * Dismisses any existing overlay first.
     */
    fun showMini(view: View) {
        dismiss()
        val params = createMiniParams()
        addViewSafely(view, params)
    }

    fun swap(newView: View, isBanner: Boolean) {
        dismiss()
        if (isBanner) {
            showBanner(newView)
        } else {
            showDialog(newView)
        }
    }

    /**
     * Remove the current overlay view from the window.
     * Safe to call multiple times — no-ops if no view is attached.
     */
    fun dismiss() {
        currentView?.let { view ->
            try {
                // Use removeViewImmediate to ensure pending draw operations (e.g., ripple
                // animations) complete synchronously before the view is detached. Without
                // this, adding a new overlay view on the same frame can crash with
                // "Target already set!" from RenderNodeAnimator.
                windowManager.removeViewImmediate(view)
            } catch (e: IllegalArgumentException) {
                // Expected: view was already detached (e.g., service killed).
                android.util.Log.d("OverlayWindowManager", "View already detached: ${e.message}")
            } catch (e: Exception) {
                android.util.Log.e("OverlayWindowManager", "Unexpected error in dismiss", e)
            }
        }
        currentView = null
        currentParams = null
    }

    /** Update the overlay position by a delta (used for drag gestures on mini overlay). */
    fun updatePosition(dx: Int, dy: Int) {
        val params = currentParams ?: return
        val view = currentView ?: return
        params.x += dx
        params.y += dy
        try {
            windowManager.updateViewLayout(view, params)
        } catch (e: IllegalArgumentException) {
            android.util.Log.d("OverlayWindowManager", "updatePosition: view not attached: ${e.message}")
        } catch (e: Exception) {
            android.util.Log.e("OverlayWindowManager", "updatePosition failed", e)
        }
    }

    fun isShowing(): Boolean = currentView != null

    /**
     * Safely adds a view to the WindowManager. If the permission was revoked
     * between the check and this call (TOCTOU race), the SecurityException
     * is caught and logged instead of crashing the app.
     */
    private fun addViewSafely(view: View, params: WindowManager.LayoutParams) {
        try {
            windowManager.addView(view, params)
            currentView = view
            currentParams = params
        } catch (e: SecurityException) {
            android.util.Log.e("OverlayWindowManager", "Overlay permission revoked before addView", e)
        } catch (e: Exception) {
            android.util.Log.e("OverlayWindowManager", "Failed to add overlay view", e)
        }
    }

    private fun createDialogParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.CENTER
        }
    }

    private fun createMiniParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = 40
        }
    }

    private fun createBannerParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP
        }
    }
}
