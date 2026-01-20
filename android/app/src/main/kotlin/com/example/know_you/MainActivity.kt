package com.example.know_you

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ACCESSIBILITY_CHANNEL = "com.example.know_you/accessibility"
    private val FOREGROUND_SERVICE_CHANNEL = "com.example.know_you/foreground_service"
    private val FLOATING_BALL_CHANNEL = "com.example.know_you/floating_ball"
    
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Floating ball channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_BALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startFloatingBall" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (!Settings.canDrawOverlays(this)) {
                            // 请求悬浮窗权限
                            try {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    android.net.Uri.parse("package:$packageName")
                                )
                                startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                                result.error("PERMISSION_REQUIRED", "Overlay permission is required", null)
                            } catch (e: Exception) {
                                result.error("PERMISSION_ERROR", "Failed to request permission: ${e.message}", null)
                            }
                            return@setMethodCallHandler
                        }
                    }
                    
                    try {
                        val intent = Intent(this, FloatingBallService::class.java)
                        // 不使用startForegroundService，因为悬浮球不需要前台服务
                        startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FAILED", "Failed to start floating ball: ${e.message}", null)
                    }
                }
                "stopFloatingBall" -> {
                    try {
                        val intent = Intent(this, FloatingBallService::class.java)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "getTextAtPosition" -> {
                    val x = call.argument<Double>("x") ?: 0.0
                    val y = call.argument<Double>("y") ?: 0.0
                    val service = RemoteControlAccessibilityService.instance
                    if (service != null) {
                        val text = service.getTextAtPosition(x, y)
                        result.success(text)
                    } else {
                        result.error("SERVICE_NOT_ENABLED", "Accessibility service is not enabled", null)
                    }
                }
                "hasOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Set channel for FloatingBallService
        FloatingBallService.setMethodChannel(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_BALL_CHANNEL)
        )

        // Accessibility service channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "click" -> {
                    val x = call.argument<Double>("x") ?: 0.0
                    val y = call.argument<Double>("y") ?: 0.0
                    val service = RemoteControlAccessibilityService.instance
                    if (service != null) {
                        val success = service.performClick(x, y)
                        result.success(success)
                    } else {
                        result.error("SERVICE_NOT_ENABLED", "Accessibility service is not enabled", null)
                    }
                }
                "swipe" -> {
                    val startX = call.argument<Double>("startX") ?: 0.0
                    val startY = call.argument<Double>("startY") ?: 0.0
                    val endX = call.argument<Double>("endX") ?: 0.0
                    val endY = call.argument<Double>("endY") ?: 0.0
                    val duration = call.argument<Int>("duration") ?: 300
                    val service = RemoteControlAccessibilityService.instance
                    if (service != null) {
                        val success = service.performSwipe(startX, startY, endX, endY, duration.toLong())
                        result.success(success)
                    } else {
                        result.error("SERVICE_NOT_ENABLED", "Accessibility service is not enabled", null)
                    }
                }
                "back" -> {
                    val service = RemoteControlAccessibilityService.instance
                    if (service != null) {
                        val success = service.performBack()
                        result.success(success)
                    } else {
                        result.error("SERVICE_NOT_ENABLED", "Accessibility service is not enabled", null)
                    }
                }
                "home" -> {
                    val service = RemoteControlAccessibilityService.instance
                    if (service != null) {
                        val success = service.performHome()
                        result.success(success)
                    } else {
                        result.error("SERVICE_NOT_ENABLED", "Accessibility service is not enabled", null)
                    }
                }
                "recents" -> {
                    val service = RemoteControlAccessibilityService.instance
                    if (service != null) {
                        val success = service.performRecents()
                        result.success(success)
                    } else {
                        result.error("SERVICE_NOT_ENABLED", "Accessibility service is not enabled", null)
                    }
                }
                "isAccessibilityEnabled" -> {
                    result.success(RemoteControlAccessibilityService.isServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Foreground service channel for screen capture
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    try {
                        val intent = Intent(this, ScreenCaptureForegroundService::class.java).apply {
                            action = ScreenCaptureForegroundService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stopForegroundService" -> {
                    try {
                        val intent = Intent(this, ScreenCaptureForegroundService::class.java).apply {
                            action = ScreenCaptureForegroundService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "isServiceRunning" -> {
                    result.success(ScreenCaptureForegroundService.isServiceRunning())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
