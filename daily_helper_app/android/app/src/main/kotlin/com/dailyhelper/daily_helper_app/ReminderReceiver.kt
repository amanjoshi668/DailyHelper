package com.dailyhelper.daily_helper_app

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            ReminderScheduler.rescheduleSavedIfEnabled(context)
            return
        }

        if (action == ReminderScheduler.ACTION_AM || action == ReminderScheduler.ACTION_PM) {
            ReminderScheduler.scheduleNextOccurrence(context, action)
            ReminderScheduler.ensureChannel(context)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val granted = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED
                if (!granted) return
            }

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val contentPending = PendingIntent.getActivity(
                context,
                6100,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val isMorning = action == ReminderScheduler.ACTION_AM
            val title = if (isMorning) "DailyHelper — Today's Schedule" else "DailyHelper — Upcoming Bookings"
            val body = if (isMorning) {
                "Check your confirmed appointments and availability for today."
            } else {
                "Review upcoming service slots or update your Khata."
            }

            val notification = NotificationCompat.Builder(context, ReminderScheduler.CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(contentPending)
                .build()

            NotificationManagerCompat.from(context).notify(if (isMorning) 7001 else 7002, notification)
        }
    }
}
