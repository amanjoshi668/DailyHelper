# DailyHelper — Backend Architecture & Deployment Guide

## 1. Stateless Cloud Run Service (`daily_helper_backend/`)
- **Runtime:** Node.js 22 + Express (`server.js`), stateless container (`Dockerfile`) listening on `$PORT` (`8080`).
- **Database:** Cloud SQL for PostgreSQL (`schema.sql`) via `DATABASE_URL` or Unix socket `/cloudsql/<INSTANCE_CONNECTION_NAME>`, with automatic **zero-DB in-memory fallback** for instant local execution and CI testing.
- **Authentication:** Salted `scrypt` Email/Password (`POST /api/v1/auth/register`, `POST /api/v1/auth/login`) + Google Identity Services (`POST /api/v1/auth/google`) + Android external browser handoff (`/api/v1/auth/mobile-google/*`), issuing 30-day JWTs carrying `{ id, email, role, name }`.
- **Hybrid `$0.00` AI Endpoint:** `POST /api/v1/dailyhelper/ai-parse` proxies ambiguous repair descriptions (`≥10` words) to free-tier `gemini-2.5-flash-lite` (`2.6 s` timeout) and falls back deterministically when offline or unconfigured.
- **Worker Rate Card & User Preferences (`v1.2.0`):** `PUT /api/v1/workers/me` persists `visitFeeInr`, `hourlyRateInr`, `dailyRateInr`, `customRates` (`JSONB`), `upiId`, `servicePins`, `isOnline`, and `blockedSlots`; `PUT /api/v1/users/me/preferences` persists `preferredLang` (`en`, `hi`, `mr`, `ta`, `te`, `kn`).
- **Real-Time Notifications (`v1.2.1`):** Booking events (`requested`, `confirmed`, `declined`, `in_progress`, `cancelled`, `completed`) create user-scoped notifications queried via `GET /api/v1/notifications`, individually dismissible via `PATCH /api/v1/notifications/:id/dismiss`, or bulk-dismissible via `POST /api/v1/notifications/dismiss-all`.
- **Closed-Loop Bug Triage:** `POST /api/v1/bugs`, `GET /api/v1/bugs?status=open|resolved|all`, `PATCH /api/v1/bugs/:id`, managed via `node triage_bugs.js`.
