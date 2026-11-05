package com.mivoz.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createChannels()
    }

    /**
     * Canales de notificación. La Cloud Function elige el canal: las
     * solicitudes urgentes van a "mi_voz_urgent" y las demás (y los avisos de
     * solicitudes por aprobar) a "mi_voz_requests". Cada adulto puede ajustar
     * el sonido de cada canal en los ajustes de Android.
     */
    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_REQUESTS,
                "Solicitudes de Mi Voz",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Avisos cuando un niño necesita atención"
                enableVibration(true)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_URGENT,
                "Ayuda urgente",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Cuando un niño usa el botón de ayuda urgente"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 250, 600, 250, 600)
            },
        )
    }

    companion object {
        const val CHANNEL_REQUESTS = "mi_voz_requests"
        const val CHANNEL_URGENT = "mi_voz_urgent"
    }
}
