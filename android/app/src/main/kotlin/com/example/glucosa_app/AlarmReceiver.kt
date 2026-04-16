package com.example.glucosa_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title    = intent.getStringExtra("title")    ?: return
        val body     = intent.getStringExtra("body")     ?: return
        val notifId  = intent.getIntExtra("notifId", 1)
        val channelId = intent.getStringExtra("channelId") ?: "meds_channel"

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager

        // Icono grande: muestra el ícono de la app en color dentro de la notificación expandida.
        // Icono pequeño (barra de estado): Android 5+ siempre lo renderiza en blanco monocromático.
        val largeIcon = BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher)

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(largeIcon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        nm.notify(notifId, notification)
    }
}
