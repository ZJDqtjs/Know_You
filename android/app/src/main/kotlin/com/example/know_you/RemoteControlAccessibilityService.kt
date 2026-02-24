package com.example.know_you

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.content.Context

class RemoteControlAccessibilityService : AccessibilityService() {

    companion object {
        var instance: RemoteControlAccessibilityService? = null
            private set
        
        fun isServiceEnabled(): Boolean = instance != null
    }

    private var screenWidth: Int = 0
    private var screenHeight: Int = 0
    private var lastEventTimestamp: Long = 0
    private var currentPackageName: String? = null

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
        // 记录事件时间，用于检测屏幕变化
        lastEventTimestamp = System.currentTimeMillis()
        val pkg = event?.packageName?.toString()
        if (!pkg.isNullOrBlank()) {
            currentPackageName = pkg
        }
    }

    override fun onInterrupt() {
        // Handle interrupts
    }
    
    /**
     * 获取指定坐标位置的文字内容
     */
    fun getTextAtPosition(normalizedX: Double, normalizedY: Double): String? {
        updateScreenSize()
        val x = (normalizedX * screenWidth).toInt()
        val y = (normalizedY * screenHeight).toInt()
        
        android.util.Log.d("AccessibilityService", "Getting text at position: x=$x, y=$y")
        
        val rootNode = rootInActiveWindow
        if (rootNode == null) {
            android.util.Log.e("AccessibilityService", "Root node is null")
            return null
        }
        
        val textAtPosition = findTextAtPosition(rootNode, x, y)
        rootNode.recycle()
        
        android.util.Log.d("AccessibilityService", "Found text: $textAtPosition")
        return textAtPosition
    }
    
    /**
     * 递归查找指定坐标位置的文字
     */
    private fun findTextAtPosition(node: AccessibilityNodeInfo, x: Int, y: Int): String? {
        val rect = Rect()
        node.getBoundsInScreen(rect)
        
        // 检查点击位置是否在这个节点内
        if (rect.contains(x, y)) {
            // 优先检查子节点（更精确的匹配）
            var childText: String? = null
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                val result = findTextAtPosition(child, x, y)
                child.recycle()
                if (result != null) {
                    childText = result
                }
            }
            
            // 如果子节点有文字，返回子节点的文字
            if (childText != null) {
                return childText
            }
            
            // 如果节点有文字内容，返回它
            val text = node.text?.toString()
            if (!text.isNullOrBlank()) {
                return text
            }
            
            // 检查contentDescription
            val contentDesc = node.contentDescription?.toString()
            if (!contentDesc.isNullOrBlank()) {
                return contentDesc
            }
        }
        
        return null
    }
    
    /**
     * 获取整个屏幕的所有文字内容
     */
    fun getAllScreenText(): String {
        val rootNode = rootInActiveWindow ?: return ""
        val allText = StringBuilder()
        collectAllText(rootNode, allText)
        rootNode.recycle()
        return allText.toString()
    }

    fun getCurrentPackageName(): String? {
        val rootPackage = rootInActiveWindow?.packageName?.toString()
        if (!rootPackage.isNullOrBlank()) {
            currentPackageName = rootPackage
            return rootPackage
        }
        return currentPackageName
    }
    
    private fun collectAllText(node: AccessibilityNodeInfo, result: StringBuilder) {
        // 获取当前节点的文字
        val text = node.text?.toString()
        if (!text.isNullOrBlank()) {
            if (result.isNotEmpty()) {
                result.append(" ")
            }
            result.append(text)
        }
        
        // 获取contentDescription
        val contentDesc = node.contentDescription?.toString()
        if (!contentDesc.isNullOrBlank() && contentDesc != text) {
            if (result.isNotEmpty()) {
                result.append(" ")
            }
            result.append(contentDesc)
        }
        
        // 递归收集子节点文字
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectAllText(child, result)
            child.recycle()
        }
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
