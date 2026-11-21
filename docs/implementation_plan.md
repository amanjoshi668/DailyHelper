# DailyHelper — Implementation Plan

## Architecture & Modules
1. **`daily_helper_app/` (Flutter Android + Web PWA + Tablet Split-View ≥900px)**
   - `lib/models/models.dart`: Immutable/serializable models (`AppUser`, `WorkerProfile`, `BookingRecord`, `AppNotificationItem`, `BugReportRecord`, `AiParseSuggestion`).
   - `lib/services/i18n.dart`: Full English (`en`) and Hindi (`hi` / `हिंदी`) localization strings.
   - `lib/services/auth_service.dart`: Session management (`visitor`, `customer`, `professional`), Email/Password + Google Sign-In + offline local session support.
   - `lib/services/vault_storage.dart`: Strict `userId`-isolated `SharedPreferences` vault (`dailyhelper_vault_v1_<userId>`), seeded starter professionals guarded by `defaultSeeded`, Real-Calendar stale booking auto-expiry, and background JSONB sync.
   - `lib/services/gcp_backend_service.dart`: Cloud Run API client + Closed-Loop Bug Triage reconciliation (`getOpenBugReportsForCurrentUser()` pruning `resolved` tickets).
   - `lib/services/ai_issue_parser.dart`: `$0.00` 3-Tier Hybrid AI pipeline (Tier 1 Hinglish/Hindi regex, Tier 2 compound splitter, Tier 3 Cloud Run `gemini-2.5-flash-lite` proxy).
   - `lib/services/notification_service.dart`: Native Android `MethodChannel('com.dailyhelper.app/native')` bridge for `AlarmManager` reminders and SAF `.csv` Khata export.
   - `lib/screens/`: Clean, uncluttered screens enforcing strict Customer vs Professional separation (`HomeShellScreen`, `LoginScreen`, `WorkerDetailSheet`, `SettingsScreen`, `BugReportScreen`, `UpiSettleScreen`).
2. **`daily_helper_backend/` (Node.js + Express + Cloud SQL PostgreSQL)**
   - Stateless API (`server.js`), `schema.sql`, `triage_bugs.js`, `Dockerfile`, `deploy_cloudshell.sh`.
