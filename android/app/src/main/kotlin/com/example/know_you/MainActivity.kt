package com.example.know_you

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.os.Bundle
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ACCESSIBILITY_CHANNEL = "com.example.know_you/accessibility"
    private val FOREGROUND_SERVICE_CHANNEL = "com.example.know_you/foreground_service"
    private val FLOATING_BALL_CHANNEL = "com.example.know_you/floating_ball"
    private val SETTINGS_CHANNEL = "com.example.know_you/settings"
    private val SHIZUKU_CHANNEL = "com.example.know_you/shizuku"
    
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1001
    private val TTS_CHECK_CODE = 1002
    
    private lateinit var shizukuHelper: ShizukuHelper
    private lateinit var wirelessAdbHelper: WirelessAdbHelper
    private var shizukuMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        shizukuHelper = ShizukuHelper(this)
        wirelessAdbHelper = WirelessAdbHelper(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Shizuku channel
        shizukuMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHIZUKU_CHANNEL)
        shizukuMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getShizukuStatus" -> {
                    result.success(shizukuHelper.getShizukuStatus())
                }
                "isShizukuInstalled" -> {
                    result.success(shizukuHelper.isShizukuInstalled())
                }
                "isShizukuRunning" -> {
                    result.success(shizukuHelper.isShizukuRunning())
                }
                "hasShizukuPermission" -> {
                    result.success(shizukuHelper.hasShizukuPermission())
                }
                "requestShizukuPermission" -> {
                    shizukuHelper.requestShizukuPermission()
                    result.success(true)
                }
                "enableAccessibilityViaShizuku" -> {
                    val serviceName = call.argument<String>("serviceName") 
                        ?: "${packageName}.RemoteControlAccessibilityService"
                    val success = shizukuHelper.enableAccessibilityService(serviceName)
                    result.success(success)
                }
                "keepAccessibilityAlive" -> {
                    val success = shizukuHelper.keepAccessibilityServiceAlive()
                    result.success(success)
                }
                "isAccessibilityEnabled" -> {
                    result.success(shizukuHelper.isOurAccessibilityServiceEnabled())
                }
                "hasWriteSecureSettings" -> {
                    result.success(shizukuHelper.hasWriteSecureSettingsPermission())
                }
                "grantWriteSecureSettings" -> {
                    val success = shizukuHelper.grantWriteSecureSettingsPermission()
                    result.success(success)
                }
                "restartAccessibilityService" -> {
                    Thread {
                        try {
                            val success = kotlinx.coroutines.runBlocking {
                                shizukuHelper.restartAccessibilityService()
                            }
                            runOnUiThread {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("RESTART_FAILED", e.message, null)
                            }
                        }
                    }.start()
                }
                "disableAccessibilityService" -> {
                    val success = shizukuHelper.disableAccessibilityService()
                    result.success(success)
                }
                "getWirelessDebugGuide" -> {
                    result.success(wirelessAdbHelper.getWirelessDebugGuide())
                }
                "getAdbCommand" -> {
                    result.success(wirelessAdbHelper.getEnableAccessibilityCommand())
                }
                "openShizukuApp" -> {
                    try {
                        val intent = context.packageManager.getLaunchIntentForPackage(ShizukuHelper.SHIZUKU_PACKAGE)
                        if (intent != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("OPEN_FAILED", e.message, null)
                    }
                }
                "openShizukuDownload" -> {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://shizuku.rikka.app/download/"))
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_FAILED", e.message, null)
                    }
                }
                "initShizukuListeners" -> {
                    shizukuHelper.initShizukuListeners(
                        onBinderReceived = {
                            runOnUiThread {
                                shizukuMethodChannel?.invokeMethod("onShizukuBinderReceived", null)
                            }
                        },
                        onBinderDead = {
                            runOnUiThread {
                                shizukuMethodChannel?.invokeMethod("onShizukuBinderDead", null)
                            }
                        },
                        onPermissionResult = { granted ->
                            runOnUiThread {
                                shizukuMethodChannel?.invokeMethod("onShizukuPermissionResult", mapOf("granted" to granted))
                            }
                        }
                    )
                    result.success(true)
                }
                "removeShizukuListeners" -> {
                    shizukuHelper.removeShizukuListeners()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

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
        
        // Settings channel for TTS and other system settings
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openTtsSettings" -> {
                    try {
                        val intent = Intent("com.android.settings.TTS_SETTINGS")
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // 尝试备用方式
                        try {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("OPEN_FAILED", e2.message, null)
                        }
                    }
                }
                "checkTtsData" -> {
                    // 检查 TTS 数据是否可用
                    try {
                        val checkIntent = Intent(TextToSpeech.Engine.ACTION_CHECK_TTS_DATA)
                        startActivityForResult(checkIntent, TTS_CHECK_CODE)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CHECK_FAILED", e.message, null)
                    }
                }
                "installTtsData" -> {
                    // 安装 TTS 数据
                    try {
                        val installIntent = Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)
                        installIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(installIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == TTS_CHECK_CODE) {
            if (resultCode != TextToSpeech.Engine.CHECK_VOICE_DATA_PASS) {
                // TTS 数据不可用，引导用户安装
                android.util.Log.d("MainActivity", "TTS data not available, prompting install")
                try {
                    val installIntent = Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)
                    startActivity(installIntent)
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to start TTS install: ${e.message}")
                }
            } else {
                android.util.Log.d("MainActivity", "TTS data is available")
            }
        }
    }
}
