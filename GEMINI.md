# DailyHelper — Workspace Engineering & Documentation Rules

1. **Strict Role-Based UI Separation:**
   - **Customer accounts (`role == 'customer'`)** only render `Explore` and `Bookings` (plus Customer Settings: Account, Notifications, Language, Report a Bug, Policy). Customers must **never** see `Khata` or `Export Khata`.
   - **Professional accounts (`role == 'professional'`)** only render `Jobs` and `Rates & Khata` (plus Professional Settings including `Export Khata (.CSV)`). Professionals must **never** see `Explore`.
2. **Calm, Uncluttered UX:**
   - No "Guest Mode" banners on the landing screen; unauthenticated visitors browse freely and are routed to the dedicated **Login / Sign-Up Screen** when confirming a booking.
   - Top app bar displays only the brand/PIN selector on the left and a clean **User Icon** on the top right (no "Customer Mode / Helper Mode" header labels).
   - In-app notifications appear at the **top** of the screen and are explicitly **dismissible (`✕`)**.
3. **Closed-Loop Bug Triage:**
   - Bug reports (`POST /api/v1/bugs`) are accessed under **Settings → Report a Bug**, display only the current user's **open** tickets, and prune `resolved` tickets automatically upon sync.
4. **Documentation & Release Parity:**
   - Whenever shipping features, resolving reported bugs, or bumping `pubspec.yaml` versions, keep `docs/*.md`, `/privacy` on the backend, and `store_assets/PLAY_STORE_LISTING.md` synchronized, and pass `flutter analyze` (`0` issues) + `flutter test` (`360×800` CUJ suite) before building signed `.aab`/`.apk` artifacts.
