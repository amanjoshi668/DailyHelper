# DailyHelper — Cloud Run & Play Store Deployment Guide

## 1. Pre-Configured GCP Infrastructure (`bullet-journal-514307`)
- **GCP Project ID:** `bullet-journal-514307` (`us-central1`)
- **Cloud Run Service:** `dailyhelper-backend`
- **Live Cloud Run URL (Web App + REST API):** `https://dailyhelper-backend-676039463235.us-central1.run.app`
- **Live Privacy Policy URL:** `https://dailyhelper-backend-676039463235.us-central1.run.app/privacy`
- **Cloud SQL PostgreSQL Instance:** `keystone-postgres` -> isolated database `dailyhelper_db` (auto-created by `deploy_cloudshell.sh`, tables auto-migrated from `schema.sql` on server startup).
- **Secret Manager Entries:**
  - `dailyhelper-jwt-secret` (auto-generated 256-bit secret)
  - `keystone-gemini-key` (shared `$0.00` free-tier `gemini-2.5-flash-lite` key)
  - `starlist-db-password` / `dailyhelper-db-password` (Cloud SQL `postgres` password)

## 2. One-Command Cloud Shell Deployment
Open Google Cloud Shell (`bullet-journal-514307`) and run:
```bash
git clone https://github.com/amanjoshi668/DailyHelper.git
cd DailyHelper/daily_helper_backend
./deploy_cloudshell.sh
```
For subsequent updates:
```bash
cd ~/DailyHelper && git pull && cd daily_helper_backend && ./deploy_cloudshell.sh
```

## 3. Google Play Console Release Uploads (`release_uploads/`)
All Play Console artifacts are compiled against `https://dailyhelper-backend-676039463235.us-central1.run.app` (`minSdk 24`, `targetSdk 36`) and staged in `release_uploads/`:
1. `release_uploads/app-release.aab` — Signed Android App Bundle
2. `release_uploads/native-debug-symbols.zip` — Native debug symbols (`⋮` -> *Upload native debug symbols (.zip)*)
3. `release_uploads/app-release.apk` — Direct-install Android APK
