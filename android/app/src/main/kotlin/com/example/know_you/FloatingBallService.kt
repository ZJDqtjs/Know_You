package com.example.know_you

import android.accessibilityservice.AccessibilityService
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.view.*
import android.widget.ImageView
import android.widget.Toast
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.util.*

class FloatingBallService : Service(), TextToSpeech.OnInitListener {
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var isReadMode = false
    private var tts: TextToSpeech? = null
    private var ttsInitialized = false
    private var pendingText: String? = null  // 保存待朗读的文本
    
    companion object {
        private var methodChannel: MethodChannel? = null
        private var serviceInstance: FloatingBallService? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
        
        fun getInstance(): FloatingBallService? = serviceInstance
    }

    override fun onCreate() {
        super.onCreate()
        serviceInstance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // 初始化TTS - 使用系统默认引擎
        initTTS()
        
        createFloatingView()
    }
    
    private fun initTTS() {
        CoroutineScope(Dispatchers.Main).launch {
            // 给系统服务绑定时间
            delay(500)
            
            // 使用系统默认TTS引擎初始化，不指定特定引擎
            tts = TextToSpeech(this@FloatingBallService, this@FloatingBallService)
            
            android.util.Log.d("FloatingBallService", "TTS instance created, waiting for onInit callback")
        }
    }
    
    override fun onInit(status: Int) {
        android.util.Log.d("FloatingBallService", "TTS onInit called with status: $status")
        if (status == TextToSpeech.SUCCESS) {
            // 获取当前默认引擎信息
            val defaultEngine = tts?.defaultEngine
            android.util.Log.d("FloatingBallService", "Default TTS engine: $defaultEngine")
            
            // 获取可用引擎列表
            val engines = tts?.engines
            android.util.Log.d("FloatingBallService", "Available TTS engines: ${engines?.map { it.name }}")
            
            // 尝试设置中文
            var result = tts?.setLanguage(Locale.CHINESE)
            android.util.Log.d("FloatingBallService", "setLanguage CHINESE result: $result")
            
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                // 尝试简体中文
                result = tts?.setLanguage(Locale.SIMPLIFIED_CHINESE)
                android.util.Log.d("FloatingBallService", "setLanguage SIMPLIFIED_CHINESE result: $result")
            }
            
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                // 使用默认语言
                result = tts?.setLanguage(Locale.getDefault())
                android.util.Log.d("FloatingBallService", "setLanguage DEFAULT result: $result")
            }
            
            ttsInitialized = true
            android.util.Log.d("FloatingBallService", "TTS initialized successfully with engine: $defaultEngine")
            
            // 如果有待朗读的文本，现在朗读
            pendingText?.let { text ->
                android.util.Log.d("FloatingBallService", "Speaking pending text: $text")
                CoroutineScope(Dispatchers.Main).launch {
                    delay(200)  // 短暂延迟确保引擎完全就绪
                    tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "utterance_pending")
                    pendingText = null
                }
            }
        } else {
            android.util.Log.e("FloatingBallService", "TTS initialization failed with status: $status")
            ttsInitialized = false
            // 提示用户去设置中激活TTS
            CoroutineScope(Dispatchers.Main).launch {
                Toast.makeText(this@FloatingBallService, "语音引擎未就绪，请在设置中启用", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun createFloatingView() {
        floatingView = LayoutInflater.from(this).inflate(R.layout.floating_ball_layout, null)
        
        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = 20
        params.y = 200

        val ballIcon = floatingView?.findViewById<ImageView>(R.id.floating_ball_icon)
        
        // 拖动逻辑
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false
        var clickStartTime = 0L

        floatingView?.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    clickStartTime = System.currentTimeMillis()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                        isDragging = true
                        params.x = initialX + dx.toInt()
                        params.y = initialY + dy.toInt()
                        windowManager?.updateViewLayout(floatingView, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val clickDuration = System.currentTimeMillis() - clickStartTime
                    if (!isDragging && clickDuration < 300) {
                        // 这是点击事件
                        toggleReadMode()
                    }
                    true
                }
                else -> false
            }
        }

        try {
            windowManager?.addView(floatingView, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun toggleReadMode() {
        isReadMode = !isReadMode
        updateBallAppearance()
        
        if (isReadMode) {
            // 进入点读模式，显示提示
            Toast.makeText(this, "点读模式已开启，点击屏幕任意文字朗读", Toast.LENGTH_SHORT).show()
            
            // 设置触摸监听来捕获屏幕点击
            setupTouchListener()
        } else {
            // 退出点读模式
            removeTouchListener()
        }
        
        // 通知Flutter端状态变化
        CoroutineScope(Dispatchers.Main).launch {
            methodChannel?.invokeMethod("onReadModeChanged", mapOf("isReadMode" to isReadMode))
        }
    }
    
    private var touchOverlay: View? = null
    
    private fun setupTouchListener() {
        if (touchOverlay != null) return
        
        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        
        // 创建透明覆盖层来捕获触摸
        touchOverlay = View(this).apply {
            setBackgroundColor(0x01000000) // 几乎透明但可以接收触摸
        }
        
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        )
        
        touchOverlay?.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_DOWN && isReadMode) {
                val x = event.rawX
                val y = event.rawY
                
                // 检查是否点击了悬浮球区域
                val ballParams = floatingView?.layoutParams as? WindowManager.LayoutParams
                if (ballParams != null) {
                    val ballX = ballParams.x.toFloat()
                    val ballY = ballParams.y.toFloat()
                    val ballSize = 56 * resources.displayMetrics.density
                    
                    if (x >= ballX && x <= ballX + ballSize && 
                        y >= ballY && y <= ballY + ballSize) {
                        // 点击了悬浮球，切换模式
                        toggleReadMode()
                        return@setOnTouchListener true
                    }
                }
                
                // 获取点击位置的文字
                readTextAtPosition(x, y)
                return@setOnTouchListener true
            }
            false
        }
        
        try {
            windowManager?.addView(touchOverlay, params)
        } catch (e: Exception) {
            android.util.Log.e("FloatingBallService", "Failed to add touch overlay", e)
        }
    }
    
    private fun removeTouchListener() {
        touchOverlay?.let {
            try {
                windowManager?.removeView(it)
            } catch (e: Exception) {
                android.util.Log.e("FloatingBallService", "Failed to remove touch overlay", e)
            }
        }
        touchOverlay = null
    }
    
    private fun readTextAtPosition(x: Float, y: Float) {
        // 通过AccessibilityService获取文字
        val accessibilityService = RemoteControlAccessibilityService.instance
        if (accessibilityService != null) {
            val screenWidth = resources.displayMetrics.widthPixels
            val screenHeight = resources.displayMetrics.heightPixels
            val normalizedX = x.toDouble() / screenWidth
            val normalizedY = y.toDouble() / screenHeight
            
            val text = accessibilityService.getTextAtPosition(normalizedX, normalizedY)
            if (!text.isNullOrEmpty()) {
                speakText(text)
            } else {
                Toast.makeText(this, "未找到文字", Toast.LENGTH_SHORT).show()
            }
        } else {
            Toast.makeText(this, "请先启用无障碍服务", Toast.LENGTH_SHORT).show()
        }
        
        // 退出点读模式
        isReadMode = false
        updateBallAppearance()
        removeTouchListener()
        
        CoroutineScope(Dispatchers.Main).launch {
            methodChannel?.invokeMethod("onReadModeChanged", mapOf("isReadMode" to false))
        }
    }
    
    private fun speakText(text: String) {
        android.util.Log.d("FloatingBallService", "speakText called: $text, ttsInitialized=$ttsInitialized")
        
        // 保存文本以便重试
        pendingText = text
        
        if (tts != null && ttsInitialized) {
            // 使用协程确保在主线程执行
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    // 尝试朗读
                    val result = tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "utterance_${System.currentTimeMillis()}")
                    android.util.Log.d("FloatingBallService", "TTS speak result: $result, Speaking: $text")
                    
                    if (result == TextToSpeech.SUCCESS) {
                        pendingText = null  // 成功后清除
                    } else {
                        android.util.Log.e("FloatingBallService", "TTS speak failed with result: $result")
                        // Android 12+ 可能需要重新绑定引擎
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            android.util.Log.d("FloatingBallService", "Android 12+, reinitializing TTS")
                            tts?.shutdown()
                            ttsInitialized = false
                            delay(300)
                            initTTS()
                            Toast.makeText(this@FloatingBallService, "正在重新连接语音引擎...", Toast.LENGTH_SHORT).show()
                        } else {
                            Toast.makeText(this@FloatingBallService, "语音引擎重新初始化中...", Toast.LENGTH_SHORT).show()
                            tts?.shutdown()
                            ttsInitialized = false
                            tts = TextToSpeech(this@FloatingBallService, this@FloatingBallService)
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("FloatingBallService", "TTS speak exception: ${e.message}")
                }
            }
        } else if (tts == null) {
            android.util.Log.e("FloatingBallService", "TTS is null, creating new instance")
            initTTS()
            Toast.makeText(this, "语音引擎初始化中...", Toast.LENGTH_SHORT).show()
        } else {
            // tts存在但未初始化完成
            android.util.Log.d("FloatingBallService", "TTS not ready yet, waiting for onInit")
            Toast.makeText(this, "语音引擎正在准备...", Toast.LENGTH_SHORT).show()
        }
    }

    private fun updateBallAppearance() {
        val ballIcon = floatingView?.findViewById<ImageView>(R.id.floating_ball_icon)
        if (isReadMode) {
            ballIcon?.setImageResource(android.R.drawable.ic_btn_speak_now)
            floatingView?.setBackgroundResource(R.drawable.floating_ball_bg_active)
        } else {
            ballIcon?.setImageResource(android.R.drawable.ic_menu_help)
            floatingView?.setBackgroundResource(R.drawable.floating_ball_bg_normal)
        }
    }

    fun hide() {
        floatingView?.visibility = View.GONE
    }

    fun show() {
        floatingView?.visibility = View.VISIBLE
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        removeTouchListener()
        floatingView?.let {
            windowManager?.removeView(it)
        }
        tts?.stop()
        tts?.shutdown()
        serviceInstance = null
    }
}
