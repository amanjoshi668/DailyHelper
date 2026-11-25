package com.dailyhelper.daily_helper_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            ReminderScheduler.rescheduleSavedIfEnabled(context)
            return
        }

        if (action == ReminderScheduler.ACTION_APPOINTMENT) {
            val bookingId = intent.getStringExtra(ReminderScheduler.EXTRA_BOOKING_ID) ?: ""
            val title = intent.getStringExtra(ReminderScheduler.EXTRA_TITLE)
                ?: "Upcoming DailyHelper Appointment"
            val body = intent.getStringExtra(ReminderScheduler.EXTRA_BODY)
                ?: "Your confirmed appointment starts in 60 minutes."
            ReminderScheduler.removeFiredAppointment(context, bookingId)
            val notifId = 7100 + ((bookingId.hashCode() and 0x7FFFFFFF) % 1000)
            ReminderScheduler.showInstantNotification(
                context = context,
                notifId = notifId,
                title = title,
                body = body,
                highPriority = true,
                target = if (ReminderScheduler.isProfessionalMode(context)) "jobs" else "bookings"
            )
            return
        }

        if (action == ReminderScheduler.ACTION_AM || action == ReminderScheduler.ACTION_PM) {
            ReminderScheduler.scheduleNextOccurrence(context, action)
            val isMorning = action == ReminderScheduler.ACTION_AM
            val isPro = ReminderScheduler.isProfessionalMode(context)

            val title = if (isMorning) {
                if (isPro) "DailyHelper — Today's Jobs" else "DailyHelper — Today's Bookings"
            } else {
                if (isPro) "DailyHelper — Evening Schedule" else "DailyHelper — Upcoming Appointments"
            }

            val body = if (isMorning) {
                if (isPro) {
                    "Check new job requests and confirm your availability for today."
                } else {
                    "Review your confirmed home service appointments for today."
                }
            } else {
                if (isPro) {
                    "Review tomorrow's booked slots and keep your rate card up to date."
                } else {
                    "Check upcoming service slots or book a trusted local helper."
                }
            }

            ReminderScheduler.showInstantNotification(
                context = context,
                notifId = if (isMorning) 7001 else 7002,
                title = title,
                body = body,
                highPriority = false,
                target = if (isPro) "jobs" else "bookings"
            )
        }
    }
}
