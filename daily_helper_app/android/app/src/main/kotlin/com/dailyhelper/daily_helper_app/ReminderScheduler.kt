package com.dailyhelper.daily_helper_app

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.util.Calendar

object ReminderScheduler {
    const val CHANNEL_ALERTS_ID = "daily_helper_booking_alerts"
    const val CHANNEL_REMINDERS_ID = "daily_helper_appointments"

    private const val PREFS_NAME = "daily_helper_native_reminders"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_IS_PRO = "isProfessional"
    private const val KEY_AM_H = "amHour"
    private const val KEY_AM_M = "amMinute"
    private const val KEY_PM_H = "pmHour"
    private const val KEY_PM_M = "pmMinute"
    private const val KEY_APPOINTMENTS = "scheduled_appointments_json"

    const val ACTION_AM = "com.dumbmonk.dailyhelper.REMINDER_AM"
    const val ACTION_PM = "com.dumbmonk.dailyhelper.REMINDER_PM"
    const val ACTION_APPOINTMENT = "com.dumbmonk.dailyhelper.APPOINTMENT_REMINDER"

    const val EXTRA_BOOKING_ID = "bookingId"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"
    const val EXTRA_TARGET = "notif_target"

    private const val REQ_AM = 5201
    private const val REQ_PM = 5202

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val alertsChannel = NotificationChannel(
                CHANNEL_ALERTS_ID,
                "Booking & Job Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Live booking updates, new job requests, and 60-minute appointment alerts"
                enableVibration(true)
            }
            mgr.createNotificationChannel(alertsChannel)

            val remindersChannel = NotificationChannel(
                CHANNEL_REMINDERS_ID,
                "Daily Schedule Reminders",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Morning and evening schedule reminders"
            }
            mgr.createNotificationChannel(remindersChannel)
        }
    }

    fun hasNotificationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return false
        }
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    fun isRemindersEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_ENABLED, false)
    }

    fun isProfessionalMode(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_IS_PRO, false)
    }

    fun showInstantNotification(
        context: Context,
        notifId: Int,
        title: String,
        body: String,
        highPriority: Boolean = true,
        target: String = "home"
    ): Boolean {
        ensureChannels(context)
        if (!hasNotificationPermission(context)) return false

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_TARGET, target)
        }
        val contentPending = PendingIntent.getActivity(
            context,
            6100 + (notifId and 0xFF),
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val channelId = if (highPriority) CHANNEL_ALERTS_ID else CHANNEL_REMINDERS_ID
        val priority = if (highPriority) {
            NotificationCompat.PRIORITY_HIGH
        } else {
            NotificationCompat.PRIORITY_DEFAULT
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_stat_dailyhelper)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(priority)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(contentPending)
            .build()

        return try {
            NotificationManagerCompat.from(context).notify(notifId, notification)
            true
        } catch (_: SecurityException) {
            false
        }
    }

    fun saveAndApply(
        context: Context,
        enabled: Boolean,
        amHour: Int,
        amMinute: Int,
        pmHour: Int,
        pmMinute: Int,
        isProfessional: Boolean
    ) {
        ensureChannels(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putBoolean(KEY_IS_PRO, isProfessional)
            .putInt(KEY_AM_H, amHour)
            .putInt(KEY_AM_M, amMinute)
            .putInt(KEY_PM_H, pmHour)
            .putInt(KEY_PM_M, pmMinute)
            .apply()

        if (enabled) {
            scheduleSingleDaily(context, ACTION_AM, REQ_AM, amHour, amMinute, false)
            scheduleSingleDaily(context, ACTION_PM, REQ_PM, pmHour, pmMinute, false)
            rescheduleSavedAppointments(context)
        } else {
            cancelSingleDaily(context, ACTION_AM, REQ_AM)
            cancelSingleDaily(context, ACTION_PM, REQ_PM)
            cancelAllScheduledAppointments(context)
        }
    }

    fun scheduleAppointmentReminder(
        context: Context,
        bookingId: String,
        triggerAtMillis: Long,
        title: String,
        body: String
    ): Boolean {
        if (bookingId.isBlank()) return false
        ensureChannels(context)
        val now = System.currentTimeMillis()
        if (triggerAtMillis <= now) return false

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val map = loadAppointmentsJson(prefs)
        val entry = JSONObject().apply {
            put("triggerAtMillis", triggerAtMillis)
            put("title", title)
            put("body", body)
        }
        map.put(bookingId, entry)
        prefs.edit().putString(KEY_APPOINTMENTS, map.toString()).apply()

        setAppointmentAlarm(context, bookingId, triggerAtMillis, title, body)
        return true
    }

    fun cancelAppointmentReminder(context: Context, bookingId: String) {
        if (bookingId.isBlank()) return
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val map = loadAppointmentsJson(prefs)
        if (map.has(bookingId)) {
            map.remove(bookingId)
            prefs.edit().putString(KEY_APPOINTMENTS, map.toString()).apply()
        }
        cancelAppointmentAlarm(context, bookingId)
    }

    fun removeFiredAppointment(context: Context, bookingId: String) {
        if (bookingId.isBlank()) return
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val map = loadAppointmentsJson(prefs)
        if (map.has(bookingId)) {
            map.remove(bookingId)
            prefs.edit().putString(KEY_APPOINTMENTS, map.toString()).apply()
        }
    }

    fun rescheduleSavedIfEnabled(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        ensureChannels(context)
        scheduleSingleDaily(
            context,
            ACTION_AM,
            REQ_AM,
            prefs.getInt(KEY_AM_H, 8),
            prefs.getInt(KEY_AM_M, 30),
            false
        )
        scheduleSingleDaily(
            context,
            ACTION_PM,
            REQ_PM,
            prefs.getInt(KEY_PM_H, 17),
            prefs.getInt(KEY_PM_M, 30),
            false
        )
        rescheduleSavedAppointments(context)
    }

    fun scheduleNextOccurrence(context: Context, action: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        if (action == ACTION_AM) {
            scheduleSingleDaily(
                context,
                ACTION_AM,
                REQ_AM,
                prefs.getInt(KEY_AM_H, 8),
                prefs.getInt(KEY_AM_M, 30),
                true
            )
        } else if (action == ACTION_PM) {
            scheduleSingleDaily(
                context,
                ACTION_PM,
                REQ_PM,
                prefs.getInt(KEY_PM_H, 17),
                prefs.getInt(KEY_PM_M, 30),
                true
            )
        }
    }

    private fun rescheduleSavedAppointments(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val map = loadAppointmentsJson(prefs)
        val now = System.currentTimeMillis()
        val expiredKeys = mutableListOf<String>()
        val keys = map.keys()
        while (keys.hasNext()) {
            val bookingId = keys.next()
            val obj = map.optJSONObject(bookingId) ?: continue
            val triggerAt = obj.optLong("triggerAtMillis", 0L)
            val title = obj.optString("title", "Upcoming Appointment")
            val body = obj.optString("body", "Your DailyHelper appointment starts in 60 minutes.")
            if (triggerAt > now) {
                setAppointmentAlarm(context, bookingId, triggerAt, title, body)
            } else {
                expiredKeys.add(bookingId)
            }
        }
        if (expiredKeys.isNotEmpty()) {
            for (k in expiredKeys) map.remove(k)
            prefs.edit().putString(KEY_APPOINTMENTS, map.toString()).apply()
        }
    }

    private fun cancelAllScheduledAppointments(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val map = loadAppointmentsJson(prefs)
        val keys = map.keys()
        while (keys.hasNext()) {
            cancelAppointmentAlarm(context, keys.next())
        }
    }

    private fun appointmentRequestCode(bookingId: String): Int {
        return 8000 + ((bookingId.hashCode() and 0x7FFFFFFF) % 10000)
    }

    private fun setAppointmentAlarm(
        context: Context,
        bookingId: String,
        triggerAtMillis: Long,
        title: String,
        body: String
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ACTION_APPOINTMENT
            putExtra(EXTRA_BOOKING_ID, bookingId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            appointmentRequestCode(bookingId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
    }

    private fun cancelAppointmentAlarm(context: Context, bookingId: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ACTION_APPOINTMENT
            putExtra(EXTRA_BOOKING_ID, bookingId)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            appointmentRequestCode(bookingId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pending)
    }

    private fun loadAppointmentsJson(prefs: android.content.SharedPreferences): JSONObject {
        val raw = prefs.getString(KEY_APPOINTMENTS, null) ?: return JSONObject()
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
    }

    private fun scheduleSingleDaily(
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

    private fun cancelSingleDaily(context: Context, action: String, reqCode: Int) {
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
