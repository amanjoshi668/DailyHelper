#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# DailyHelper — Cloud Shell 1-Click Deployment to Google Cloud Run
# Reuses GCP Project bullet-journal-514307 with isolated service & database
# =============================================================================

PROJECT_ID="${GCP_PROJECT_ID:-bullet-journal-514307}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="dailyhelper-backend"
OAUTH_CLIENT_ID="${GOOGLE_CLIENT_ID:-676039463235-1mslp6if9sec8qd9u7dc2c9i0ca1m0lq.apps.googleusercontent.com}"
DB_INSTANCE="${DB_INSTANCE:-keystone-postgres}"
DB_NAME="${DB_NAME:-dailyhelper_db}"
DB_USER="${DB_USER:-postgres}"

echo "=========================================================="
echo "🚀 Deploying DailyHelper (API + Web PWA) to Google Cloud Run"
echo "Project:  $PROJECT_ID"
echo "Region:   $REGION"
echo "Service:  $SERVICE_NAME"
echo "Database: $DB_INSTANCE ($DB_NAME)"
echo "=========================================================="

gcloud config set project "$PROJECT_ID"

echo "1. Enabling required Cloud Run, Build, SQL & Secret Manager APIs..."
gcloud services enable \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  sqladmin.googleapis.com \
  --project="$PROJECT_ID"

echo "2. Ensuring isolated PostgreSQL database '$DB_NAME' exists on '$DB_INSTANCE'..."
gcloud sql databases describe "$DB_NAME" --instance="$DB_INSTANCE" --project="$PROJECT_ID" &>/dev/null || \
  gcloud sql databases create "$DB_NAME" --instance="$DB_INSTANCE" --project="$PROJECT_ID"

echo "3. Ensuring Secret Manager entries exist (JWT_SECRET, GEMINI_API_KEY, DB_PASSWORD)..."
JWT_SECRET_NAME="dailyhelper-jwt-secret"
if ! gcloud secrets describe "$JWT_SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
  openssl rand -hex 32 | tr -d '\n' | gcloud secrets create "$JWT_SECRET_NAME" --data-file=- --project="$PROJECT_ID"
fi

GEMINI_SECRET_NAME="keystone-gemini-key"
if ! gcloud secrets describe "$GEMINI_SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
  echo -n "${GEMINI_API_KEY:-}" | gcloud secrets create "$GEMINI_SECRET_NAME" --data-file=- --project="$PROJECT_ID"
fi

# Reuse shared Cloud SQL password secret on keystone-postgres if present, else dailyhelper-db-password
if gcloud secrets describe "starlist-db-password" --project="$PROJECT_ID" &>/dev/null && [ -z "${DB_PASSWORD:-}" ]; then
  DB_PASS_SECRET_NAME="starlist-db-password"
else
  DB_PASS_SECRET_NAME="dailyhelper-db-password"
  if ! gcloud secrets describe "$DB_PASS_SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
    echo -n "${DB_PASSWORD:-}" | gcloud secrets create "$DB_PASS_SECRET_NAME" --data-file=- --project="$PROJECT_ID"
  elif [ -n "${DB_PASSWORD:-}" ]; then
    echo -n "$DB_PASSWORD" | gcloud secrets versions add "$DB_PASS_SECRET_NAME" --data-file=- --project="$PROJECT_ID"
  fi
fi

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
for SEC in "$JWT_SECRET_NAME" "$GEMINI_SECRET_NAME" "$DB_PASS_SECRET_NAME"; do
  gcloud secrets add-iam-policy-binding "$SEC" \
    --member="serviceAccount:$COMPUTE_SA" \
    --role="roles/secretmanager.secretAccessor" \
    --project="$PROJECT_ID" >/dev/null
done

echo "4. Building container & deploying '$SERVICE_NAME' to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --source . \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --set-secrets="JWT_SECRET=$JWT_SECRET_NAME:latest,GEMINI_API_KEY=$GEMINI_SECRET_NAME:latest,DB_PASSWORD=$DB_PASS_SECRET_NAME:latest" \
  --set-env-vars="NODE_ENV=production,GEMINI_FREE_MODEL=gemini-2.5-flash-lite,GOOGLE_CLIENT_ID=$OAUTH_CLIENT_ID,GCP_PROJECT_ID=$PROJECT_ID,INSTANCE_CONNECTION_NAME=$PROJECT_ID:$REGION:$DB_INSTANCE,DB_USER=$DB_USER,DB_NAME=$DB_NAME" \
  --add-cloudsql-instances="$PROJECT_ID:$REGION:$DB_INSTANCE" \
  --min-instances=0 \
  --max-instances=10 \
  --memory=512Mi \
  --cpu=1

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --project="$PROJECT_ID" --region "$REGION" --format 'value(status.url)')
echo "=========================================================="
echo "🎉 Live Cloud Run URL (Web App + API): $SERVICE_URL"
echo "🔒 Privacy Policy URL: $SERVICE_URL/privacy"
echo "🔍 Health check:"
curl -s "$SERVICE_URL/health" || true
echo ""
echo "=========================================================="
