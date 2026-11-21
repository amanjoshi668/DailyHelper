# DailyHelper — Design Specification

## 1. Visual & UX Philosophy
- **Calm, Uncluttered Surfaces:** Generous spacing (`16px`–`20px` padding, `16px` rounded cards), concise worker cards showing only high-signal details (Avatar, Name, Verified checkmark, Trade & Experience, Star Rating, Visit Fee in `₹`, and `Book` CTA).
- **Clean App Header:** Displays only `DailyHelper` + `📍 PIN <code >` on the left and a circular **User Icon** on the top right (zero "Customer Mode / Helper Mode" text clutter).
- **Silent Visitor Browsing -> Login on Booking:** Visitors browse `Explore` without any "Guest Mode" banner; tapping **Confirm Booking** while signed out transitions cleanly to the **Login / Sign-Up Screen** and completes the booking immediately after authentication.
- **Strict Role Separation:**
  - **Customers:** `Explore` + `Bookings` tabs only. Settings includes Profile, Notifications, Language (`English` / `हिंदी`), Report a Bug, and Policy (**never** `Khata` or `Export Khata`).
  - **Professionals:** `Jobs` + `Rates & Khata` tabs only (**never** `Explore`). `Export Khata (.CSV)` is tucked cleanly under `Settings -> More Options`.
- **Dismissible Top Notifications:** Floating top banner with bell icon, title, subtitle, and explicit `✕` dismiss button.

## 2. Responsive Breakpoints & Small-Screen Safety
- **Compact Android (`360×800`):** Zero horizontal or vertical `RenderFlex` overflow across both English and Hindi (`हिंदी`) strings; `Expanded`/`Flexible` text wrappers and `Wrap`/horizontal chip lists.
- **Tablet & Desktop Web (`≥900 px`):** Two-column master-detail layout (Customer: Worker list on left + Worker Detail & Slot Picker on right; Professional: Job Requests & Schedule on left + Rates & Khata on right).
