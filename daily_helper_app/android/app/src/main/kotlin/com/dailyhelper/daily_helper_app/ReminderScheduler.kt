package com.dailyhelper.daily_helper_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object ReminderScheduler {
    const val CHANNEL_ID = "daily_helper_appointments"
    private const val PREFS_NAME = "daily_helper_native_reminders"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_AM_H = "amHour"
    private const val KEY_AM_M = "amMinute"
    private const val KEY_PM_H = "pmHour"
    private const val KEY_PM_M = "pmMinute"

    const val ACTION_AM = "com.dailyhelper.daily_helper_app.REMINDER_AM"
    const val ACTION_PM = "com.dailyhelper.daily_helper_app.REMINDER_PM"
    private const val REQ_AM = 5201
    private const val REQ_PM = 5202

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Appointment & Schedule Reminders",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "60-minute appointment alerts and daily schedule summaries"
            }
            mgr.createNotificationChannel(channel)
        }
    }

    fun saveAndApply(
        context: Context,
        enabled: Boolean,
        amHour: Int,
        amMinute: Int,
        pmHour: Int,
        pmMinute: Int
    ) {
        ensureChannel(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putInt(KEY_AM_H, amHour)
            .putInt(KEY_AM_M, amMinute)
            .putInt(KEY_PM_H, pmHour)
            .putInt(KEY_PM_M, pmMinute)
            .apply()

        if (enabled) {
            scheduleSingle(context, ACTION_AM, REQ_AM, amHour, amMinute, false)
            scheduleSingle(context, ACTION_PM, REQ_PM, pmHour, pmMinute, false)
        } else {
            cancelSingle(context, ACTION_AM, REQ_AM)
            cancelSingle(context, ACTION_PM, REQ_PM)
        }
    }

    fun rescheduleSavedIfEnabled(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        ensureChannel(context)
        scheduleSingle(
            context,
            ACTION_AM,
            REQ_AM,
            prefs.getInt(KEY_AM_H, 8),
            prefs.getInt(KEY_AM_M, 30),
            false
        )
        scheduleSingle(
            context,
            ACTION_PM,
            REQ_PM,
            prefs.getInt(KEY_PM_H, 17),
            prefs.getInt(KEY_PM_M, 30),
            false
        )
    }

    fun scheduleNextOccurrence(context: Context, action: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        if (action == ACTION_AM) {
            scheduleSingle(
                context,
                ACTION_AM,
                REQ_AM,
                prefs.getInt(KEY_AM_H, 8),
                prefs.getInt(KEY_AM_M, 30),
                true
            )
        } else if (action == ACTION_PM) {
            scheduleSingle(
                context,
                ACTION_PM,
                REQ_PM,
                prefs.getInt(KEY_PM_H, 17),
                prefs.getInt(KEY_PM_M, 30),
                true
            )
        }
    }

    private fun scheduleSingle(
        context: Context,
        action: String,
        reqCode: Int,
        hour: Int,
        minute: Int,
        forceTomorrow: Boolean
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java).apply { this.action = action }
        val pending = PendingIntent.getBroadcast(
            context,
            reqCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val nowPlus = System.currentTimeMillis() + 5000L
        if (forceTomorrow || cal.timeInMillis <= nowPlus) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }

        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pending)
    }

    private fun cancelSingle(context: Context, action: String, reqCode: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java).apply { this.action = action }
        val pending = PendingIntent.getBroadcast(
            context,
            reqCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pending)
    }
}
