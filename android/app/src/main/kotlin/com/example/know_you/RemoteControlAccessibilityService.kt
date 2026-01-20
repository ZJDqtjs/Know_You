package com.example.know_you

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.content.Context

class RemoteControlAccessibilityService : AccessibilityService() {

    companion object {
        var instance: RemoteControlAccessibilityService? = null
            private set
        
        fun isServiceEnabled(): Boolean = instance != null
    }

    private var screenWidth: Int = 0
    private var screenHeight: Int = 0

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        updateScreenSize()
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not needed for remote control
    }

    override fun onInterrupt() {
        // Handle interrupts
    }

    private fun updateScreenSize() {
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            screenWidth = bounds.width()
            screenHeight = bounds.height()
        } else {
            val displayMetrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getMetrics(displayMetrics)
            screenWidth = displayMetrics.widthPixels
            screenHeight = displayMetrics.heightPixels
        }
    }

    /**
     * Perform a click at the given normalized coordinates (0.0 - 1.0)
     */
    fun performClick(normalizedX: Double, normalizedY: Double): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }

        updateScreenSize()
        val x = (normalizedX * screenWidth).toFloat()
        val y = (normalizedY * screenHeight).toFloat()

        val path = Path()
        path.moveTo(x, y)

        val gestureBuilder = GestureDescription.Builder()
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, 100))

        return dispatchGesture(gestureBuilder.build(), null, null)
    }

    /**
     * Perform a swipe from start to end coordinates (normalized 0.0 - 1.0)
     */
    fun performSwipe(
        startX: Double, startY: Double,
        endX: Double, endY: Double,
        durationMs: Long
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }

        updateScreenSize()
        val x1 = (startX * screenWidth).toFloat()
        val y1 = (startY * screenHeight).toFloat()
        val x2 = (endX * screenWidth).toFloat()
        val y2 = (endY * screenHeight).toFloat()

        val path = Path()
        path.moveTo(x1, y1)
        path.lineTo(x2, y2)

        val gestureBuilder = GestureDescription.Builder()
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, durationMs))

        return dispatchGesture(gestureBuilder.build(), null, null)
    }

    /**
     * Perform the back action
     */
    fun performBack(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_BACK)
    }

    /**
     * Perform the home action
     */
    fun performHome(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_HOME)
    }

    /**
     * Perform the recents action
     */
    fun performRecents(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_RECENTS)
    }
}
