# DailyHelper — Cloud Run & Cloud SQL Deployment Guide

## 1. Secret Manager Setup
Store secrets in Google Cloud Secret Manager (`JWT_SECRET`, `DATABASE_URL`, `GEMINI_API_KEY`, `GOOGLE_CLIENT_ID`):
```bash
printf "replace-with-strong-random-jwt-secret" | gcloud secrets create JWT_SECRET --data-file=-
printf "postgresql://postgres:PASS@/dailyhelper?host=/cloudsql/PROJECT:REGION:INSTANCE" | gcloud secrets create DATABASE_URL --data-file=-
printf "AIza..." | gcloud secrets create GEMINI_API_KEY --data-file=-
printf "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com" | gcloud secrets create GOOGLE_CLIENT_ID --data-file=-
```

## 2. Database Schema Initialization
Apply `daily_helper_backend/schema.sql` against your Cloud SQL PostgreSQL database:
```bash
psql "$DATABASE_URL" -f daily_helper_backend/schema.sql
```

## 3. Deploy Stateless API to Cloud Run
```bash
cd daily_helper_backend
GCP_PROJECT_ID="<your-gcp-project>" GCP_REGION="asia-south1" ./deploy_cloudshell.sh
```

## 4. Point Flutter Client to Production URL
Pass `--dart-define=DAILYHELPER_API_URL=https://daily-helper-api-xxxx.a.run.app` during release builds:
```bash
cd daily_helper_app
flutter build appbundle --release --dart-define=DAILYHELPER_API_URL=https://daily-helper-api-xxxx.a.run.app
flutter build apk --release --dart-define=DAILYHELPER_API_URL=https://daily-helper-api-xxxx.a.run.app
```
