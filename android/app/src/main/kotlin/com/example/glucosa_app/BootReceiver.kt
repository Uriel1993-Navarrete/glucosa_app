package com.example.glucosa_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) return

        val prefs = context.getSharedPreferences("glucosa_alarms", Context.MODE_PRIVATE)
        val json  = prefs.getString("alarms", "[]") ?: "[]"
        val now   = System.currentTimeMillis()

        try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val alarm = arr.getJSONObject(i)
                val triggerAt = alarm.getLong("triggerAtMillis")
                if (triggerAt <= now) continue
                scheduleNative(
                    context      = context,
                    notifId      = alarm.getInt("id"),
                    triggerAt    = triggerAt,
                    title        = alarm.getString("title"),
                    body         = alarm.getString("body"),
                    channelId    = alarm.optString("channelId", "meds_channel")
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    companion object {
        fun scheduleNative(
            context  : Context,
            notifId  : Int,
            triggerAt: Long,
            title    : String,
            body     : String,
            channelId: String
        ) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = buildPendingIntent(context, notifId, title, body, channelId)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        }

        fun cancelNative(context: Context, notifId: Int) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context, notifId, intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) am.cancel(pi)
        }

        private fun buildPendingIntent(
            context  : Context,
            notifId  : Int,
            title    : String,
            body     : String,
            channelId: String
        ): PendingIntent {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("title",     title)
                putExtra("body",      body)
                putExtra("notifId",   notifId)
                putExtra("channelId", channelId)
            }
            return PendingIntent.getBroadcast(
                context, notifId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
