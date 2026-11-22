# DailyHelper (`v1.0.0+1`)

**Hyperlocal booking marketplace connecting households & shops with local Electricians, Plumbers, Carpenters, AC Technicians & Painters — with upfront visit fees and `0%` commission.**

## Monorepo Layout

```text
DailyHelper/
├── daily_helper_app/          # Flutter client (Android minSdk 24 / targetSdk 36, Web PWA, Tablet Split-View)
├── daily_helper_backend/      # Stateless Node.js + Express API + Bundled Web PWA (Cloud Run + Cloud SQL)
├── docs/                      # PRD, Design Spec, Implementation Plan, Backend, Deploy Guide, Privacy Policy
├── store_assets/              # Play Store Listing, 512/1024 Icons, 1024x500 Feature Graphic
└── release_uploads/           # Gitignored local staging: app-release.aab, native-debug-symbols.zip, app-release.apk
```

## Quick Commands

```bash
# Verify Flutter static analysis & 360x800 + Split-View CUJ tests
cd daily_helper_app && flutter analyze && flutter test

# Run backend API tests
cd ../daily_helper_backend && npm test

# Deploy to Google Cloud Run (in GCP Cloud Shell for bullet-journal-514307)
cd daily_helper_backend && ./deploy_cloudshell.sh

# Triage user-submitted in-app bug reports
node daily_helper_backend/triage_bugs.js list open
```
