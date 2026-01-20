package com.example.know_you

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Shizuku 辅助类，用于通过 ADB/Shizuku 保活无障碍服务
 * 
 * 核心原理：
 * 1. 通过 Shizuku UserService 执行 shell 命令
 * 2. 使用 pm grant 授予 WRITE_SECURE_SETTINGS 权限
 * 3. 使用 settings put 命令启用无障碍服务
 */
class ShizukuHelper(private val context: Context) {
    
    companion object {
        private const val TAG = "ShizukuHelper"
        const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"
        const val REQUEST_CODE_SHIZUKU = 1001
        
        // 无障碍服务分隔符
        private const val ENABLED_ACCESSIBILITY_SERVICES_SEPARATOR = ':'
    }
    
    private var binderReceivedListener: Shizuku.OnBinderReceivedListener? = null
    private var binderDeadListener: Shizuku.OnBinderDeadListener? = null
    private var permissionResultListener: Shizuku.OnRequestPermissionResultListener? = null
    
    /**
     * 检查 Shizuku 是否已安装
     */
    fun isShizukuInstalled(): Boolean {
        return try {
            context.packageManager.getPackageInfo(SHIZUKU_PACKAGE, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
    
    /**
     * 检查 Shizuku 服务是否正在运行
     */
    fun isShizukuRunning(): Boolean {
        return try {
            Shizuku.pingBinder()
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Shizuku status", e)
            false
        }
    }
    
    /**
     * 检查是否已获得 Shizuku 权限
     */
    fun hasShizukuPermission(): Boolean {
        return try {
            if (Shizuku.isPreV11()) {
                false
            } else {
                Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Shizuku permission", e)
            false
        }
    }
    
    /**
     * 请求 Shizuku 权限
     */
    fun requestShizukuPermission() {
        try {
            if (Shizuku.isPreV11()) {
                Log.w(TAG, "Shizuku version too old")
                return
            }
            if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
                Shizuku.requestPermission(REQUEST_CODE_SHIZUKU)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting Shizuku permission", e)
        }
    }
    
    /**
     * 初始化 Shizuku 监听器
     */
    fun initShizukuListeners(
        onBinderReceived: () -> Unit,
        onBinderDead: () -> Unit,
        onPermissionResult: (granted: Boolean) -> Unit
    ) {
        binderReceivedListener = Shizuku.OnBinderReceivedListener {
            Log.d(TAG, "Shizuku binder received")
            onBinderReceived()
        }
        
        binderDeadListener = Shizuku.OnBinderDeadListener {
            Log.d(TAG, "Shizuku binder dead")
            onBinderDead()
        }
        
        permissionResultListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
            if (requestCode == REQUEST_CODE_SHIZUKU) {
                val granted = grantResult == PackageManager.PERMISSION_GRANTED
                Log.d(TAG, "Shizuku permission result: $granted")
                onPermissionResult(granted)
            }
        }
        
        Shizuku.addBinderReceivedListener(binderReceivedListener!!)
        Shizuku.addBinderDeadListener(binderDeadListener!!)
        Shizuku.addRequestPermissionResultListener(permissionResultListener!!)
    }
    
    /**
     * 移除 Shizuku 监听器
     */
    fun removeShizukuListeners() {
        binderReceivedListener?.let { Shizuku.removeBinderReceivedListener(it) }
        binderDeadListener?.let { Shizuku.removeBinderDeadListener(it) }
        permissionResultListener?.let { Shizuku.removeRequestPermissionResultListener(it) }
    }
    
    /**
     * 通过 Shizuku 执行 shell 命令
     * 使用 transactRemote 方式执行
     */
    fun executeShellCommand(command: String): Pair<Boolean, String> {
        if (!hasShizukuPermission()) {
            return Pair(false, "No Shizuku permission")
        }
        
        return try {
            // 使用反射调用 Shizuku.newProcess（虽然标记为私有，但可以通过反射调用）
            val method = Shizuku::class.java.getDeclaredMethod(
                "newProcess",
                Array<String>::class.java,
                Array<String>::class.java,
                String::class.java
            )
            method.isAccessible = true
            
            val process = method.invoke(null, arrayOf("sh", "-c", command), null, null) as Process
            val output = process.inputStream.bufferedReader().readText()
            val error = process.errorStream.bufferedReader().readText()
            val exitCode = process.waitFor()
            
            Log.d(TAG, "Shell command: $command")
            Log.d(TAG, "Exit code: $exitCode, Output: $output, Error: $error")
            
            if (exitCode == 0) {
                Pair(true, output.trim())
            } else {
                Pair(false, error.ifEmpty { output }.trim())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error executing shell command via Shizuku", e)
            Pair(false, e.message ?: "Unknown error")
        }
    }
    
    /**
     * 检查应用是否拥有 WRITE_SECURE_SETTINGS 权限
     */
    fun hasWriteSecureSettingsPermission(): Boolean {
        return try {
            context.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) == 
                PackageManager.PERMISSION_GRANTED
        } catch (e: Exception) {
            Log.e(TAG, "Error checking WRITE_SECURE_SETTINGS", e)
            false
        }
    }
    
    /**
     * 已经有权限，直接返回 true；否则尝试通过 Shizuku 授权
     */
    fun grantWriteSecureSettingsPermission(): Boolean {
        // 已经有权限，直接返回
        if (hasWriteSecureSettingsPermission()) {
            Log.d(TAG, "Already has WRITE_SECURE_SETTINGS permission")
            return true
        }
        
        // 尝试通过 shell 命令授予权限
        Log.d(TAG, "Trying to grant WRITE_SECURE_SETTINGS via shell command...")
        val command = "pm grant ${context.packageName} android.permission.WRITE_SECURE_SETTINGS"
        val (success, output) = executeShellCommand(command)
        
        if (success) {
            // 等待权限生效
            Thread.sleep(300)
            val hasPermission = hasWriteSecureSettingsPermission()
            Log.d(TAG, "Grant result: $hasPermission")
            return hasPermission
        } else {
            Log.e(TAG, "Failed to grant permission: $output")
            return false
        }
    }
    
    /**
     * 通过 shell 命令直接启用无障碍服务
     */
    fun enableAccessibilityViaShellCommand(): Boolean {
        val serviceName = "${context.packageName}/${context.packageName}.RemoteControlAccessibilityService"
        
        // 先启用无障碍总开关
        val (enableSuccess, _) = executeShellCommand("settings put secure accessibility_enabled 1")
        if (!enableSuccess) {
            Log.e(TAG, "Failed to enable accessibility via shell")
            // 继续尝试，可能已经启用
        }
        
        // 获取当前已启用的服务
        val (getSuccess, currentServices) = executeShellCommand("settings get secure enabled_accessibility_services")
        
        val newServices = if (getSuccess && currentServices.isNotEmpty() && currentServices != "null" && currentServices.trim().isNotEmpty()) {
            if (currentServices.contains(serviceName)) {
                Log.d(TAG, "Service already in list")
                return true
            }
            "${currentServices.trim()}:$serviceName"
        } else {
            serviceName
        }
        
        // 设置无障碍服务
        val (putSuccess, output) = executeShellCommand("settings put secure enabled_accessibility_services '$newServices'")
        Log.d(TAG, "Enable accessibility via shell result: $putSuccess, output: $output")
        
        return putSuccess
    }
    
    /**
     * 获取当前已启用的无障碍服务列表
     */
    fun getEnabledAccessibilityServices(): String {
        return Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: ""
    }
    
    /**
     * 获取当前已启用的无障碍服务集合
     */
    fun getSecureA11yServices(): MutableSet<ComponentName> {
        val value = getEnabledAccessibilityServices()
        if (value.isEmpty()) return mutableSetOf()
        return value.split(ENABLED_ACCESSIBILITY_SERVICES_SEPARATOR)
            .mapNotNull { ComponentName.unflattenFromString(it) }
            .toHashSet()
    }
    
    /**
     * 设置已启用的无障碍服务列表
     * 需要 WRITE_SECURE_SETTINGS 权限
     */
    fun putSecureA11yServices(services: Set<ComponentName>): Boolean {
        return try {
            val servicesStr = services.joinToString(ENABLED_ACCESSIBILITY_SERVICES_SEPARATOR.toString()) { 
                it.flattenToShortString() 
            }
            Settings.Secure.putString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
                servicesStr
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to put accessibility services", e)
            false
        }
    }
    
    /**
     * 设置无障碍服务总开关
     * 需要 WRITE_SECURE_SETTINGS 权限
     */
    fun putSecureA11yEnabled(enabled: Boolean): Boolean {
        return try {
            Settings.Secure.putInt(
                context.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED,
                if (enabled) 1 else 0
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to put accessibility enabled", e)
            false
        }
    }
    
    /**
     * 通过 WRITE_SECURE_SETTINGS 权限启用无障碍服务
     * 这是 GKD 使用的核心方法
     */
    fun enableAccessibilityServiceViaSecureSettings(serviceName: String): Boolean {
        // 首先检查是否有 WRITE_SECURE_SETTINGS 权限
        if (!hasWriteSecureSettingsPermission()) {
            Log.e(TAG, "No WRITE_SECURE_SETTINGS permission")
            return false
        }
        
        val fullComponentName = ComponentName(context.packageName, serviceName)
        val services = getSecureA11yServices()
        
        Log.d(TAG, "Current services: $services")
        Log.d(TAG, "Enabling: $fullComponentName")
        
        // 已经启用则直接返回
        if (services.contains(fullComponentName)) {
            Log.d(TAG, "Service already enabled")
            return true
        }
        
        // 先确保无障碍总开关已开启
        if (!putSecureA11yEnabled(true)) {
            Log.e(TAG, "Failed to enable accessibility")
            return false
        }
        
        // 添加我们的服务到列表
        services.add(fullComponentName)
        
        // 写入设置
        val result = putSecureA11yServices(services)
        Log.d(TAG, "Enable result: $result")
        return result
    }
    
    /**
     * 通过 Shizuku 启用无障碍服务
     * 优先使用 shell 命令，失败则尝试 Settings.Secure API
     */
    fun enableAccessibilityService(serviceName: String): Boolean {
        Log.d(TAG, "Trying to enable accessibility service: $serviceName")
        
        // 方式一：直接使用 shell 命令（最可靠）
        if (hasShizukuPermission()) {
            Log.d(TAG, "Trying shell command method...")
            if (enableAccessibilityViaShellCommand()) {
                Log.d(TAG, "Successfully enabled via shell command")
                return true
            }
            Log.w(TAG, "Shell command method failed, trying Settings.Secure method...")
        }
        
        // 方式二：通过 WRITE_SECURE_SETTINGS 权限
        if (!hasWriteSecureSettingsPermission()) {
            Log.d(TAG, "No WRITE_SECURE_SETTINGS permission, trying to grant...")
            if (!grantWriteSecureSettingsPermission()) {
                Log.e(TAG, "Failed to grant WRITE_SECURE_SETTINGS permission")
                return false
            }
        }
        
        // 使用 Settings.Secure API 启用无障碍服务
        val result = enableAccessibilityServiceViaSecureSettings(serviceName)
        Log.d(TAG, "Enable accessibility service result: $result")
        
        return result
    }
    
    /**
     * 重启无障碍服务（先移除再添加）
     * 用于修复无障碍服务异常
     */
    suspend fun restartAccessibilityService(): Boolean {
        if (!hasWriteSecureSettingsPermission()) {
            // 先尝试获取权限
            if (!grantWriteSecureSettingsPermission()) {
                Log.e(TAG, "Cannot restart: no WRITE_SECURE_SETTINGS permission")
                return false
            }
        }
        
        val serviceName = "${context.packageName}.RemoteControlAccessibilityService"
        val componentName = ComponentName(context.packageName, serviceName)
        val services = getSecureA11yServices()
        
        // 先确保无障碍总开关已开启
        putSecureA11yEnabled(true)
        
        // 如果已经在列表中，先移除（重启服务）
        if (services.any { it.className.endsWith("RemoteControlAccessibilityService") }) {
            Log.d(TAG, "Service in list, removing first to restart")
            services.removeAll { it.className.endsWith("RemoteControlAccessibilityService") }
            putSecureA11yServices(services)
            // 等待服务停止
            kotlinx.coroutines.delay(1000)
        }
        
        // 添加服务
        services.add(componentName)
        val result = putSecureA11yServices(services)
        
        // 等待服务启动
        kotlinx.coroutines.delay(2000)
        
        Log.d(TAG, "Restart accessibility service result: $result, running: ${isOurAccessibilityServiceEnabled()}")
        return result && isOurAccessibilityServiceEnabled()
    }
    
    /**
     * 检查我们的无障碍服务是否已启用
     */
    fun isOurAccessibilityServiceEnabled(): Boolean {
        val componentName = ComponentName(context.packageName, "${context.packageName}.RemoteControlAccessibilityService")
        val services = getSecureA11yServices()
        return services.any { 
            it.packageName == context.packageName && 
            it.className.endsWith("RemoteControlAccessibilityService") 
        }
    }
    
    /**
     * 通过 Shizuku 保活无障碍服务（定期检查并重新启用）
     */
    fun keepAccessibilityServiceAlive(): Boolean {
        if (!isOurAccessibilityServiceEnabled()) {
            Log.d(TAG, "Accessibility service not enabled, trying to enable via Shizuku")
            return enableAccessibilityService("${context.packageName}.RemoteControlAccessibilityService")
        }
        return true
    }
    
    /**
     * 禁用我们的无障碍服务
     */
    fun disableAccessibilityService(): Boolean {
        if (!hasWriteSecureSettingsPermission()) {
            Log.e(TAG, "No WRITE_SECURE_SETTINGS permission")
            return false
        }
        
        val componentName = ComponentName(context.packageName, "${context.packageName}.RemoteControlAccessibilityService")
        val services = getSecureA11yServices()
        
        services.removeAll { 
            it.packageName == context.packageName && 
            it.className.endsWith("RemoteControlAccessibilityService") 
        }
        
        return putSecureA11yServices(services)
    }
    
    /**
     * 获取 Shizuku 状态信息
     */
    fun getShizukuStatus(): Map<String, Any> {
        return mapOf(
            "installed" to isShizukuInstalled(),
            "running" to isShizukuRunning(),
            "hasPermission" to hasShizukuPermission(),
            "hasWriteSecureSettings" to hasWriteSecureSettingsPermission(),
            "accessibilityEnabled" to isOurAccessibilityServiceEnabled()
        )
    }
}

/**
 * 无线调试保活辅助类
 */
class WirelessAdbHelper(private val context: Context) {
    
    companion object {
        private const val TAG = "WirelessAdbHelper"
    }
    
    /**
     * 获取无线调试的 ADB 命令
     */
    fun getEnableAccessibilityCommand(): String {
        val serviceName = "${context.packageName}/.RemoteControlAccessibilityService"
        return "adb shell settings put secure enabled_accessibility_services '$serviceName' && adb shell settings put secure accessibility_enabled 1"
    }
    
    /**
     * 获取设备的 IP 地址
     */
    fun getDeviceIpAddress(): String? {
        return try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
            val ipInt = wifiManager.connectionInfo.ipAddress
            if (ipInt == 0) return null
            String.format(
                "%d.%d.%d.%d",
                ipInt and 0xff,
                (ipInt shr 8) and 0xff,
                (ipInt shr 16) and 0xff,
                (ipInt shr 24) and 0xff
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error getting IP address", e)
            null
        }
    }
    
    /**
     * 获取无线调试连接指南
     */
    fun getWirelessDebugGuide(): Map<String, String> {
        val ip = getDeviceIpAddress() ?: "设备IP"
        val serviceName = "${context.packageName}/.RemoteControlAccessibilityService"
        
        return mapOf(
            "step1" to "在手机设置中开启「开发者选项」",
            "step2" to "开启「无线调试」功能",
            "step3" to "在电脑上执行: adb connect $ip:端口号",
            "step4" to "配对成功后执行以下命令启用无障碍服务:",
            "command" to "adb shell settings put secure enabled_accessibility_services '$serviceName'\nadb shell settings put secure accessibility_enabled 1",
            "deviceIp" to (ip ?: "未获取到IP")
        )
    }
}
