package com.example.glucosa_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.glucosa_app/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Batería ────────────────────────────────────────
                    "isIgnoring" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnore" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                            ).apply { data = Uri.parse("package:$packageName") }
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "clearNotifCache" -> {
                        applicationContext
                            .getSharedPreferences("notification_plugin_cache", MODE_PRIVATE)
                            .edit().remove("scheduled_notifications").apply()
                        result.success(null)
                    }

                    // ── AlarmManager nativo ────────────────────────────
                    "scheduleAlarm" -> {
                        try {
                            val id           = call.argument<Int>("id")!!
                            val triggerAt    = call.argument<Long>("triggerAtMillis")!!
                            val title        = call.argument<String>("title")!!
                            val body         = call.argument<String>("body")!!
                            val channelId    = call.argument<String>("channelId") ?: "meds_channel"

                            BootReceiver.scheduleNative(
                                applicationContext, id, triggerAt, title, body, channelId
                            )
                            saveAlarm(id, triggerAt, title, body, channelId)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SCHEDULE_ERROR", e.message, null)
                        }
                    }
                    "cancelAlarm" -> {
                        try {
                            val id = call.argument<Int>("id")!!
                            BootReceiver.cancelNative(applicationContext, id)
                            removeAlarm(id)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_ERROR", e.message, null)
                        }
                    }
                    "cancelAllAlarms" -> {
                        try {
                            val prefs = applicationContext.getSharedPreferences(
                                "glucosa_alarms", MODE_PRIVATE
                            )
                            val arr = JSONArray(prefs.getString("alarms", "[]") ?: "[]")
                            for (i in 0 until arr.length()) {
                                val id = arr.getJSONObject(i).getInt("id")
                                BootReceiver.cancelNative(applicationContext, id)
                            }
                            prefs.edit().remove("alarms").apply()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_ALL_ERROR", e.message, null)
                        }
                    }
                    "getPendingAlarmCount" -> {
                        try {
                            val prefs = applicationContext.getSharedPreferences(
                                "glucosa_alarms", MODE_PRIVATE
                            )
                            val arr = JSONArray(prefs.getString("alarms", "[]") ?: "[]")
                            val now = System.currentTimeMillis()
                            var count = 0
                            for (i in 0 until arr.length()) {
                                if (arr.getJSONObject(i).getLong("triggerAtMillis") > now) count++
                            }
                            result.success(count)
                        } catch (e: Exception) {
                            result.success(0)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Helpers de almacenamiento ──────────────────────────────

    private fun saveAlarm(
        id: Int, triggerAt: Long, title: String, body: String, channelId: String
    ) {
        val prefs = applicationContext.getSharedPreferences("glucosa_alarms", MODE_PRIVATE)
        val arr   = JSONArray(prefs.getString("alarms", "[]") ?: "[]")

        // Eliminar entrada previa con el mismo ID
        val updated = JSONArray()
        for (i in 0 until arr.length()) {
            if (arr.getJSONObject(i).getInt("id") != id) updated.put(arr.getJSONObject(i))
        }

        updated.put(JSONObject().apply {
            put("id", id)
            put("triggerAtMillis", triggerAt)
            put("title", title)
            put("body", body)
            put("channelId", channelId)
        })

        prefs.edit().putString("alarms", updated.toString()).apply()
    }

    private fun removeAlarm(id: Int) {
        val prefs   = applicationContext.getSharedPreferences("glucosa_alarms", MODE_PRIVATE)
        val arr     = JSONArray(prefs.getString("alarms", "[]") ?: "[]")
        val updated = JSONArray()
        for (i in 0 until arr.length()) {
            if (arr.getJSONObject(i).getInt("id") != id) updated.put(arr.getJSONObject(i))
        }
        prefs.edit().putString("alarms", updated.toString()).apply()
    }
}
