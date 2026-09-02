package com.snabbit.runner.debug

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Application
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import kotlin.math.abs

/**
 * DEBUG-only single draggable network-inspector button, shared across every Activity (Flutter
 * `MainActivity` + CMP `NavigationHostActivity`) via [Application.ActivityLifecycleCallbacks] — no
 * overlay permission needed. It is one logical button: its position lives in [posX]/[posY] and is
 * re-attached to whichever Activity is resumed, so it looks singular and consistent. Tap opens the
 * Chucker dashboard (all Flutter + KMP traces); drag repositions it. Release ships nothing (this
 * class only exists in the debug source set).
 */
internal class ChuckerFloatingButton : Application.ActivityLifecycleCallbacks {

    // Shared position across activities (NaN = not yet placed → defaults to bottom-right on first attach).
    private var posX = Float.NaN
    private var posY = Float.NaN
    private val attached = mutableMapOf<Activity, TextView>()
    private var visible = true

    /** Hide/show the button across all activities — used while a Flutter inspector route is open
     *  (chucker_flutter renders inside MainActivity, so it can't be caught by shouldSkip). */
    fun setVisible(v: Boolean) {
        visible = v
        attached.values.forEach { it.visibility = if (v) View.VISIBLE else View.GONE }
    }

    override fun onActivityResumed(activity: Activity) {
        if (shouldSkip(activity) || attached.containsKey(activity)) return
        val content = activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        val button = createButton(activity)
        content.addView(button)
        button.visibility = if (visible) View.VISIBLE else View.GONE
        attached[activity] = button
    }

    override fun onActivityPaused(activity: Activity) {
        attached.remove(activity)?.let { (it.parent as? ViewGroup)?.removeView(it) }
    }

    override fun onActivityDestroyed(activity: Activity) {
        attached.remove(activity)?.let { (it.parent as? ViewGroup)?.removeView(it) }
    }

    // Don't draw the button over Chucker's own dashboard.
    private fun shouldSkip(activity: Activity): Boolean =
        activity.javaClass.name.startsWith("com.chuckerteam.chucker")

    @SuppressLint("ClickableViewAccessibility") // debug tooling; performClick() invoked on tap below
    private fun createButton(activity: Activity): TextView {
        val density = activity.resources.displayMetrics.density
        val sizePx = (56 * density).toInt()
        return TextView(activity).apply {
            text = "NET"
            setTextColor(Color.WHITE)
            textSize = 12f
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xCC1B7DE9.toInt()) // brand-blue, ~80% opacity
            }
            layoutParams = FrameLayout.LayoutParams(sizePx, sizePx).apply {
                gravity = Gravity.TOP or Gravity.START
            }
            post {
                val parent = parent as? ViewGroup ?: return@post
                // Use the known size (the view's own width/height can still be 0 in this first post,
                // which would push the button off the right edge).
                if (posX.isNaN()) posX = (parent.width - sizePx - 16 * density).coerceAtLeast(0f)
                if (posY.isNaN()) posY = (parent.height - sizePx - 140 * density).coerceAtLeast(0f)
                translationX = posX
                translationY = posY
            }
            var downX = 0f
            var downY = 0f
            var startTx = 0f
            var startTy = 0f
            var dragged = false
            setOnTouchListener { v, e ->
                when (e.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        downX = e.rawX; downY = e.rawY
                        startTx = v.translationX; startTy = v.translationY
                        dragged = false
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = e.rawX - downX
                        val dy = e.rawY - downY
                        if (abs(dx) > 8 || abs(dy) > 8) dragged = true
                        v.translationX = startTx + dx
                        v.translationY = startTy + dy
                        posX = v.translationX; posY = v.translationY
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!dragged) v.performClick()
                        true
                    }
                    else -> false
                }
            }
            setOnClickListener {
                ChuckerDebug.openChooser(activity)
            }
        }
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
    override fun onActivityStarted(activity: Activity) = Unit
    override fun onActivityStopped(activity: Activity) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
}
