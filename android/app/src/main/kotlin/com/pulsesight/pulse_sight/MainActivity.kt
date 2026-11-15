package com.pulsesight.pulse_sight

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  companion object {
    private const val METHOD_CHANNEL = "pulsesight/status_bar"
    private const val NOTIFICATION_CHANNEL_ID = "heart_rate_status"
    private const val NOTIFICATION_ID = 10086
    private const val PERMISSION_REQUEST_CODE = 10086
  }

  private var pendingPermissionResult: MethodChannel.Result? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "requestPermission" -> handlePermissionRequest(result)
          "setEnabled" -> {
            val enabled = call.arguments as? Boolean ?: false
            if (!enabled) {
              getSystemService(NotificationManager::class.java)
                .cancel(NOTIFICATION_ID)
            }
            result.success(null)
          }
          "update" -> {
            val args = call.arguments as? Map<*, *>
            if (args != null) {
              showHeartRateNotification(
                bpm = args["bpm"] as? Int,
                status = args["status"] as? String ?: "disconnected",
              )
            }
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray,
  ) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    if (requestCode == PERMISSION_REQUEST_CODE) {
      val granted =
        grantResults.isNotEmpty() &&
          grantResults[0] == PackageManager.PERMISSION_GRANTED
      pendingPermissionResult?.success(granted)
      pendingPermissionResult = null
    }
  }

  private fun handlePermissionRequest(result: MethodChannel.Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
      result.success(true)
      return
    }
    val granted =
      ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
        PackageManager.PERMISSION_GRANTED
    if (granted) {
      result.success(true)
    } else {
      pendingPermissionResult = result
      requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST_CODE)
    }
  }

  private fun ensureNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val manager = getSystemService(NotificationManager::class.java)
      if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) == null) {
        val channel = NotificationChannel(
          NOTIFICATION_CHANNEL_ID,
          "状态栏心率",
          NotificationManager.IMPORTANCE_LOW,
        ).apply {
          description = "通过持续通知展示实时心率"
          setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
      }
    }
  }

  private fun showHeartRateNotification(bpm: Int?, status: String) {
    ensureNotificationChannel()
    val text = when (status) {
      "connected" -> "❤ ${bpm ?: "--"} bpm · 已连接(模拟)"
      "connecting" -> "正在连接手环(模拟)…"
      else -> "已断开连接"
    }
    val intent = Intent(this, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
    }
    val pendingIntent = PendingIntent.getActivity(
      this,
      0,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
      .setSmallIcon(R.drawable.ic_heart)
      .setContentTitle("PulseSight")
      .setContentText(text)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .setShowWhen(false)
      .setContentIntent(pendingIntent)
      .setCategory(NotificationCompat.CATEGORY_STATUS)
      .build()
    getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
  }
}
