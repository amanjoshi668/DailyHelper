# DailyHelper — Google Play Store Publishing Plan

1. **Signing & SDK Compliance:**
   - Upload keystore (`upload-keystore.jks`) configured via gitignored `android/key.properties`.
   - `minSdkVersion 24`, `targetSdkVersion 36`, `compileSdk 36`.
   - Zero restricted permissions (`AlarmManager.setAndAllowWhileIdle` used instead of `SCHEDULE_EXACT_ALARM`).
2. **Store Assets (`store_assets/`):**
   - App Icon (`512×512` PNG), Feature Graphic (`1024×500` PNG), Phone & Tablet screenshots, and `PLAY_STORE_LISTING.md`.
3. **Closed Testing -> Production Promotion:**
   - Upload `build/app/outputs/bundle/release/app-release.aab` (`version: 1.0.0+1`) to Closed Testing track.
   - Link `/privacy` URL from the deployed Cloud Run backend in Play Console App Content -> Privacy Policy.
   - Complete Data Safety form matching `PLAY_STORE_LISTING.md`, run 20 testers × 14 days (for personal developer accounts), then promote to Production.
