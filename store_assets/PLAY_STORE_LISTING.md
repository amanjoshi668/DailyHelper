# Google Play Store Listing — DailyHelper

## Title (≤ 30 characters)
`DailyHelper: Local Pros & Jobs`

## Short Description (≤ 80 characters)
`Book trusted local electricians, plumbers & carpenters — or get daily work!`

## Full Description
**DailyHelper** connects households and shops directly with trusted neighbourhood blue-collar professionals — **Electricians, Plumbers, Carpenters, AC & Appliance Technicians, and Painters** — with upfront visit fees and `0%` middleman commission.

### For Customers: Book Trusted Local Helpers
- **Hyperlocal PIN Discovery:** Find verified professionals serving your exact 6-digit PIN code.
- **Transparent Upfront Rates:** View base inspection/visit fees, hourly/full-day rates, and custom service rate cards before booking.
- **Multi-Language Indian UI & Smart Search:** Choose English, Hindi (`हिंदी`), Marathi (`मराठी`), Tamil (`தமிழ்`), Telugu (`తెలుగు`), or Kannada (`ಕನ್ನಡ`) in Settings, and describe repair issues in English, Hindi, or Hinglish to match the right trade instantly.
- **Slot-Based Appointments:** Pick a convenient 2-hour window and pay 100% directly to the professional via Cash or UPI after completion.

### For Professionals: Get Local Work & Keep 100% Earnings
- **Dedicated Professional Workspace:** Set your own visit fee, hourly rate, full-day rate, custom task rate card (e.g., Fan Install, Inverter Setup), UPI ID, and available slots in 2 minutes.
- **Instant Booking Requests:** Accept or decline nearby slot requests and get 60-minute appointment reminders.
- **Built-In Direct Khata:** Track daily & monthly earnings with `0%` commission and export portable `.CSV` records from Settings.

## Data Safety Summary
- **Data Collected:** Name, Email address, Phone number (Account functionality & booking coordination); Service address & booking records; Optional in-app bug reports.
- **Data Sharing:** Contact details are shared strictly between the customer and confirmed professional for an active booking. Never sold to third parties.
- **Security Practices:** Encrypted in transit (HTTPS/TLS); users can request account and data deletion.

## Release Notes (`v1.2.1+4`)
- Fixed Android notification delivery: upgraded booking alerts to a high-priority notification channel with a monochrome status-bar icon (`ic_stat_dailyhelper`), real 60-minute-before-slot `AlarmManager` scheduling/cancellation, and live OS alerts for incoming bookings & status changes.
- Fixed Settings Notifications toggle sync with Android `POST_NOTIFICATIONS` permission state, added **Send Test Notification** and 1-tap **Open System Notification Settings** fallback, and removed role-mismatched reminder copy.
- Fixed in-app top notification banners so they never cover top inputs, appear across Home, Settings, and Bug Report screens, show queued counts with **Clear all**, and poll live cross-device alerts every 20 seconds while active.

## Release Notes (`v1.2.0+3`)
- Added **Language Preference** picker in Settings supporting 6 Indian languages: English, Hindi (`हिंदी`), Marathi (`मराठी`), Tamil (`தமிழ்`), Telugu (`తెలుగు`), and Kannada (`ಕನ್ನಡ`) with persistent cross-session sync.
- Expanded **Worker Rate Card Editor** in Rates & Khata so professionals can customize their Visit Fee, Hourly Rate, Full-Day Rate, and add/remove custom per-service task rates synced live to customer profiles.
- Auto-provisions worker profiles for Professionals signing in via Google Sign-In and added clearer logged-out guidance for workers.

## Release Notes (`v1.1.0+2`)
- Live multi-device Cloud Run synchronization for workers, bookings, status updates, and dismissible top notifications.
- Added pull-to-refresh across Explore, Bookings, and Jobs, plus real Android Google Sign-In browser handoff.
- Added Customer booking cancellation, Trusted Helpers bookmarking, Book Again shortcut, saved customer address persistence, and PIN-prioritized discovery.
- Added Professional UPI ID & serviceable PIN code editing with an explicit Save Changes button in Rates & Khata.

## Release Notes (`v1.0.0+1`)
- Initial release of DailyHelper for Customers and Professionals!
- Direct hyperlocal booking by PIN code for Electricians, Plumbers, Carpenters, AC Repair, and Painters.
- Bilingual English & Hindi (`हिंदी`) interface, 60-minute native appointment reminders, direct UPI/Cash Khata, and in-app bug reporting.
