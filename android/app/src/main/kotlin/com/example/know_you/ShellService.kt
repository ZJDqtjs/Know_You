package com.example.know_you

import android.util.Log
import kotlin.system.exitProcess

/**
 * Shizuku UserService 实现
 * 这个服务在 Shizuku 的 shell 权限下运行
 */
class ShellService() : IShellService.Stub() {
    
    companion object {
        private const val TAG = "ShellService"
    }
    
    /**
     * 执行命令并返回退出码
     */
    override fun executeCommand(command: String): Int {
        return try {
            Log.d(TAG, "Executing command: $command")
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
            val exitCode = process.waitFor()
            Log.d(TAG, "Command exit code: $exitCode")
            exitCode
        } catch (e: Exception) {
            Log.e(TAG, "Error executing command", e)
            -1
        }
    }
    
    /**
     * 执行命令并返回输出
     */
    override fun executeCommandWithOutput(command: String): String {
        return try {
            Log.d(TAG, "Executing command with output: $command")
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
            val output = process.inputStream.bufferedReader().readText()
            val error = process.errorStream.bufferedReader().readText()
            val exitCode = process.waitFor()
            Log.d(TAG, "Command exit code: $exitCode, output: $output, error: $error")
            
            if (exitCode == 0) {
                "SUCCESS:$output"
            } else {
                "ERROR:$error"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error executing command", e)
            "EXCEPTION:${e.message}"
        }
    }
    
    /**
     * 销毁服务
     */
    override fun destroy() {
        Log.d(TAG, "Service destroyed")
        exitProcess(0)
    }
}
