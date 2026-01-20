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
        
        // 初始化TTS
        tts = TextToSpeech(this, this)
        
        createFloatingView()
    }
    
    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val result = tts?.setLanguage(Locale.CHINESE)
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                // 尝试使用默认语言
                tts?.setLanguage(Locale.getDefault())
            }
            ttsInitialized = true
            android.util.Log.d("FloatingBallService", "TTS initialized successfully")
        } else {
            android.util.Log.e("FloatingBallService", "TTS initialization failed")
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
        if (ttsInitialized && tts != null) {
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "utterance_${System.currentTimeMillis()}")
            android.util.Log.d("FloatingBallService", "Speaking: $text")
        } else {
            // 尝试重新初始化TTS
            tts = TextToSpeech(this, this)
            Toast.makeText(this, "语音引擎初始化中...", Toast.LENGTH_SHORT).show()
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
