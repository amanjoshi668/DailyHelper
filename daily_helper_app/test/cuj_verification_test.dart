import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_helper_app/main.dart';
import 'package:daily_helper_app/models/models.dart';
import 'package:daily_helper_app/services/auth_service.dart';
import 'package:daily_helper_app/services/gcp_backend_service.dart';
import 'package:daily_helper_app/services/notification_service.dart';
import 'package:daily_helper_app/services/vault_storage.dart';

class _FakeBackendClient extends http.BaseClient {
  final List<Map<String, dynamic>> serverBugs = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (request.method == 'POST' && path == '/api/v1/bugs') {
      final bodyStr = await request.finalize().bytesToString();
      final payload = jsonDecode(bodyStr) as Map<String, dynamic>;
      final created = {
        'id': 'srv_bug_${serverBugs.length + 1}',
        'description': payload['description'],
        'pageContext': payload['pageContext'],
        'appVersion': payload['appVersion'],
        'userEmail': payload['userEmail'],
        'status': 'open',
      };
      serverBugs.insert(0, created);
      final bytes = utf8.encode(jsonEncode({'success': true, 'bug': created}));
      return http.StreamedResponse(Stream.value(bytes), 201);
    }

    if (request.method == 'GET' && path == '/api/v1/bugs') {
      final bytes = utf8.encode(jsonEncode({'bugs': serverBugs}));
      return http.StreamedResponse(Stream.value(bytes), 200);
    }

    // Return 503 for other endpoints so offline-first vault/auth paths run deterministically
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 503);
  }
}

void setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> nativeCalls;
  late _FakeBackendClient fakeBackend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    nativeCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotificationService.channel, (MethodCall call) async {
      nativeCalls.add(call);
      return true;
    });
    fakeBackend = _FakeBackendClient();
    GcpBackendService.instance.httpClient = fakeBackend;
    await AuthService.instance.initialize();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotificationService.channel, null);
  });

  testWidgets('CUJ 1: Clean 360x800 Visitor -> Login Gate on Book -> Dismissible Top Notification',
      (WidgetTester tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(const DailyHelperApp());
    await tester.pumpAndSettle();

    // Verify clean home: no Guest Mode banner, no Khata anywhere
    expect(find.textContaining('Guest Mode'), findsNothing);
    expect(find.textContaining('Khata'), findsNothing);
    expect(find.text('Ramesh Kumar'), findsOneWidget);

    // Tap Book on Ramesh Kumar
    final bookBtn = find.byKey(const Key('book_worker_btn_w1'));
    await tester.ensureVisible(bookBtn);
    await tester.tap(bookBtn);
    await tester.pumpAndSettle();

    // Tap Confirm Booking while logged out -> routes to dedicated Login Screen
    final confirmBtn = find.byKey(const Key('confirm_booking_btn'));
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(find.text('Sign in to DailyHelper'), findsOneWidget);

    // Toggle to Create Account & register Customer
    final toggleBtn = find.byKey(const Key('login_toggle_mode_btn'));
    await tester.ensureVisible(toggleBtn);
    await tester.tap(toggleBtn);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_name_field')), 'Priya Menon');
    await tester.enterText(find.byKey(const Key('login_phone_field')), '+919845011223');
    await tester.enterText(find.byKey(const Key('login_email_field')), 'priya@example.com');
    await tester.enterText(find.byKey(const Key('login_password_field')), 'secret123');

    final submitBtn = find.byKey(const Key('login_submit_btn'));
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Booking automatically completed + Top Notification shown and dismissible!
    expect(find.text('Booking Requested'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dismiss_top_notification_btn')));
    await tester.pumpAndSettle();
    expect(find.text('Booking Requested'), findsNothing);
  });

  testWidgets(
      'CUJ 2 & 3: Strict Role Separation (No Khata for Customer, No Explore for Pro) + Job Completion & SAF Export',
      (WidgetTester tester) async {
    setMobileViewport(tester);
    await AuthService.instance.registerWithEmail(
      name: 'Priya Menon',
      email: 'priya@example.com',
      password: 'password123',
      phone: '+919845011223',
      role: UserRole.customer,
    );

    await tester.pumpWidget(const DailyHelperApp());
    await tester.pumpAndSettle();

    // Customer Settings must NEVER show Export Khata
    await tester.tap(find.byKey(const Key('header_user_icon_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings_export_khata_tile')), findsNothing);
    expect(find.textContaining('Khata'), findsNothing);

    // Sign Out Customer
    await tester.tap(find.byKey(const Key('settings_sign_out_btn')));
    await tester.pumpAndSettle();

    // Sign in / Register as Professional via User Icon -> Sign In
    await tester.tap(find.byKey(const Key('header_user_icon_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_sign_in_btn')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_role_pro_btn')));
    await tester.pumpAndSettle();
    final toggleBtn = find.byKey(const Key('login_toggle_mode_btn'));
    await tester.ensureVisible(toggleBtn);
    await tester.tap(toggleBtn);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_name_field')), 'Ramesh Pro');
    await tester.enterText(find.byKey(const Key('login_phone_field')), '+919900144556');
    await tester.enterText(find.byKey(const Key('login_email_field')), 'ramesh@example.com');
    await tester.enterText(find.byKey(const Key('login_password_field')), 'secret123');
    final submitBtn = find.byKey(const Key('login_submit_btn'));
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Professional must NEVER see Explore!
    expect(find.byKey(const Key('cust_tab_explore')), findsNothing);
    expect(find.text('Explore'), findsNothing);
    expect(find.byKey(const Key('pro_tab_jobs')), findsOneWidget);
    expect(find.byKey(const Key('pro_tab_khata')), findsOneWidget);

    // Accept starter job request -> Start Work -> Complete & Collect ₹400
    final acceptBtn = find.text('Accept').first;
    await tester.ensureVisible(acceptBtn);
    await tester.tap(acceptBtn);
    await tester.pumpAndSettle();
    expect(nativeCalls.any((c) => c.method == 'configureReminders'), isTrue);

    final startBtn = find.text('Start Work').first;
    await tester.ensureVisible(startBtn);
    await tester.tap(startBtn);
    await tester.pumpAndSettle();

    final completeBtn = find.text('Complete & Collect').first;
    await tester.ensureVisible(completeBtn);
    await tester.tap(completeBtn);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('settle_amount_field')), '400');
    await tester.pumpAndSettle();
    final confirmPayBtn = find.byKey(const Key('confirm_payment_received_btn'));
    await tester.ensureVisible(confirmPayBtn);
    await tester.tap(confirmPayBtn);
    await tester.pumpAndSettle();

    // Switch to Rates & Khata tab: verify ₹400 recorded and NO Export button on home
    await tester.tap(find.byKey(const Key('pro_tab_khata')));
    await tester.pumpAndSettle();
    expect(find.text('₹400'), findsWidgets);
    expect(find.text('Export Khata (.CSV)'), findsNothing);

    // Open Professional Settings -> Export Khata (.CSV) tucked under More Options!
    await tester.tap(find.byKey(const Key('header_user_icon_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings_export_khata_tile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings_export_khata_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('download_khata_csv_btn')));
    await tester.pumpAndSettle();
    expect(nativeCalls.any((c) => c.method == 'saveExportDocument'), isTrue);
  });

  testWidgets('CUJ 4 & 5: Multi-User Data Isolation + AI Hinglish Search + Hindi UI Zero Overflow',
      (WidgetTester tester) async {
    setMobileViewport(tester);

    // User A creates a booking
    await AuthService.instance.registerWithEmail(
      name: 'User A',
      email: 'usera@example.com',
      password: 'password123',
      phone: '+919000000001',
      role: UserRole.customer,
    );
    await tester.pumpWidget(const DailyHelperApp());
    await tester.pumpAndSettle();

    final bookBtn = find.byKey(const Key('book_worker_btn_w1'));
    await tester.ensureVisible(bookBtn);
    await tester.tap(bookBtn);
    await tester.pumpAndSettle();
    final confirmBtn = find.byKey(const Key('confirm_booking_btn'));
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();
    expect(find.text('Ramesh Kumar'), findsWidgets);

    // Sign out User A and register User B -> User B must see 0 bookings!
    await AuthService.instance.signOut();
    await AuthService.instance.registerWithEmail(
      name: 'User B',
      email: 'userb@example.com',
      password: 'password123',
      phone: '+919000000002',
      role: UserRole.customer,
    );
    await tester.pumpAndSettle();
    expect(find.text('No bookings yet. Select a helper to book an appointment.'), findsOneWidget);

    // Switch back to Explore & test $0.00 Hinglish AI Search
    await tester.tap(find.byKey(const Key('cust_tab_explore')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('explore_search_field')), 'kitchen tap paani leak');
    await tester.pumpAndSettle();
    expect(find.text('Suresh Yadav'), findsOneWidget);
    expect(find.text('Ramesh Kumar'), findsNothing);

    // Switch UI via Settings -> Language Preference picker (Hindi & Marathi) at 360x800 and verify persistence + zero overflow
    await tester.tap(find.byKey(const Key('header_user_icon_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_language_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lang_option_hi')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('खोजें'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Switch to Marathi and verify it persists even after signing out
    await tester.tap(find.byKey(const Key('header_user_icon_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_language_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lang_option_mr')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_sign_out_btn')));
    await tester.pumpAndSettle();
    expect(find.text('शोधा'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Spot-check Tamil, Telugu, and Kannada at 360x800 for zero overflow
    for (final code in ['ta', 'te', 'kn', 'en']) {
      await tester.tap(find.byKey(const Key('header_user_icon_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_language_tile')));
      await tester.pumpAndSettle();
      final opt = find.byKey(Key('lang_option_$code'));
      await tester.ensureVisible(opt);
      await tester.pumpAndSettle();
      await tester.tap(opt);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('CUJ 6: DB-Logged Bug Reporting Shows Open User Bugs Only & Hides Fixed Bugs',
      (WidgetTester tester) async {
    setMobileViewport(tester);
    // Seed another user's bug on server — must NOT appear for Priya
    fakeBackend.serverBugs.add({
      'id': 'srv_other',
      'description': 'Other user secret bug',
      'pageContext': 'Jobs',
      'appVersion': '1.0.0',
      'userEmail': 'someoneelse@example.com',
      'status': 'open',
    });

    await AuthService.instance.registerWithEmail(
      name: 'Priya Menon',
      email: 'priya@example.com',
      password: 'password123',
      phone: '+919845011223',
      role: UserRole.customer,
    );

    await tester.pumpWidget(const DailyHelperApp());
    await tester.pumpAndSettle();

    // Open Settings -> Report a Bug
    await tester.tap(find.byKey(const Key('header_user_icon_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_report_bug_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Other user secret bug'), findsNothing);

    // Submit bug report
    await tester.enterText(
      find.byKey(const Key('bug_description_field')),
      'Allow saving office PIN code',
    );
    await tester.tap(find.byKey(const Key('submit_bug_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Allow saving office PIN code'), findsOneWidget);

    // Simulate backend resolving the bug -> re-open Bug Report screen -> bug must be hidden!
    for (final b in fakeBackend.serverBugs) {
      if (b['userEmail'] == 'priya@example.com') {
        b['status'] = 'resolved';
      }
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_report_bug_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Allow saving office PIN code'), findsNothing);
    expect(find.textContaining('No open bugs'), findsOneWidget);
  });

  testWidgets('CUJ 7: Responsive Tablet/Web Split-View (>=900px) Enforces Role Separation',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DailyHelperApp());
    await tester.pumpAndSettle();

    // Visitor/Customer split view renders worker list + detail pane side-by-side with zero Khata
    expect(find.byKey(const Key('confirm_booking_btn')), findsOneWidget);
    expect(find.textContaining('Khata'), findsNothing);

    // Switch to logged-in Professional in split view -> Jobs + Rates & Khata side-by-side, zero Explore
    await AuthService.instance.registerWithEmail(
      name: 'Salim Master',
      email: 'salim@example.com',
      password: 'password123',
      phone: '+919820477889',
      role: UserRole.professional,
      trade: 'carpenter',
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsNothing);
    expect(find.text('Earnings Summary (0% Fee)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CUJ 8: Customer Cancel Booking + Professional Save Rate Card & UPI/PINs at 360x800',
      (WidgetTester tester) async {
    setMobileViewport(tester);

    // 1. Customer books & cancels cleanly
    await AuthService.instance.registerWithEmail(
      name: 'Neha Rao',
      email: 'neha@example.com',
      password: 'password123',
      phone: '+919845099887',
      role: UserRole.customer,
    );
    await tester.pumpWidget(const DailyHelperApp());
    await tester.pumpAndSettle();

    final bookBtn = find.byKey(const Key('book_worker_btn_w1'));
    await tester.ensureVisible(bookBtn);
    await tester.tap(bookBtn);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('booking_address_field')), 'Apt 12B, Indiranagar');
    final confirmBtn = find.byKey(const Key('confirm_booking_btn'));
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Dismiss top notification and tap Cancel on booking
    await tester.tap(find.byKey(const Key('dismiss_top_notification_btn')));
    await tester.pumpAndSettle();
    final cancelBtn = find.text('Cancel').first;
    await tester.ensureVisible(cancelBtn);
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();
    expect(find.text('CANCELLED'), findsOneWidget);

    // 2. Professional edits Visit Fee, Full-Day Rate, Custom Service Rates, UPI ID, and Serviceable PINs
    await AuthService.instance.signOut();
    await AuthService.instance.registerWithEmail(
      name: 'Vikram Pro',
      email: 'vikrampro@example.com',
      password: 'password123',
      phone: '+919900112233',
      role: UserRole.professional,
      trade: 'electrician',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pro_tab_khata')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('pro_visit_fee_field')), '179');
    await tester.enterText(find.byKey(const Key('pro_daily_rate_field')), '1050');
    await tester.enterText(find.byKey(const Key('pro_upi_field')), 'vikram@okaxis');
    await tester.enterText(find.byKey(const Key('pro_pins_field')), '560034, 560038');

    // Add a custom service rate item and verify it appears immediately
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final customSvcField = find.byKey(const Key('pro_custom_service_field'));
    await tester.ensureVisible(customSvcField);
    await tester.pumpAndSettle();
    await tester.enterText(customSvcField, 'Inverter Setup');
    await tester.enterText(find.byKey(const Key('pro_custom_price_field')), '350');
    await tester.pumpAndSettle();
    final addRateBtn = find.byKey(const Key('pro_add_rate_btn'));
    await tester.ensureVisible(addRateBtn);
    await tester.pumpAndSettle();
    await tester.tap(addRateBtn);
    await tester.pumpAndSettle();
    expect(find.text('Inverter Setup'), findsOneWidget);
    expect(find.text('₹350'), findsOneWidget);

    final saveBtn = find.byKey(const Key('pro_save_rates_btn'));
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Rate Card Updated'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 3. Sign out and verify Customer/Visitor immediately sees Vikram Pro's updated custom rate card!
    await AuthService.instance.signOut();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cust_tab_explore')));
    await tester.pumpAndSettle();
    final proCard = find.text('Vikram Pro');
    await tester.ensureVisible(proCard);
    await tester.pumpAndSettle();
    await tester.tap(proCard);
    await tester.pumpAndSettle();

    expect(find.text('Inverter Setup'), findsOneWidget);
    expect(find.text('₹350'), findsOneWidget);
    expect(find.textContaining('₹1050'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CUJ 9: Notifications — 60m Slot Parser, Test Alert on Settings, Permission Denied Sync & Clear All',
      (WidgetTester tester) async {
    setMobileViewport(tester);

    // 1. Deterministic 60-min reminder timestamp parser checks
    final fixedNow = DateTime(2026, 11, 25, 8, 30);
    expect(
      NotificationService.compute60MinReminderTime('2026-11-25', '11:00 - 01:00 PM',
          nowOverride: fixedNow),
      DateTime(2026, 11, 25, 10, 0),
    );
    expect(
      NotificationService.compute60MinReminderTime('2026-11-25', '02:00 - 04:00 PM',
          nowOverride: fixedNow),
      DateTime(2026, 11, 25, 13, 0),
    );
    expect(
      NotificationService.compute60MinReminderTime('2026-11-25', '09:00 - 11:00 AM',
          nowOverride: fixedNow),
      DateTime(2026, 11, 25, 8, 31),
    );
    expect(
      NotificationService.compute60MinReminderTime('2026-11-24', '09:00 - 11:00 AM',
          nowOverride: fixedNow),
      isNull,
    );

    // 2. Test Notification in Settings fires native OS showNotification & displays top banner immediately
    await tester.pumpWidget(const DailyHelperApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('header_user_icon_btn')));
    await tester.pumpAndSettle();

    final testNotifTile = find.byKey(const Key('settings_test_notif_tile'));
    await tester.ensureVisible(testNotifTile);
    await tester.pumpAndSettle();
    await tester.tap(testNotifTile);
    await tester.pumpAndSettle();

    expect(nativeCalls.any((c) => c.method == 'showNotification'), isTrue);
    expect(find.text('DailyHelper Alerts Ready'), findsOneWidget);

    // 3. Push a 2nd notification -> verify "+1" queued badge & "Clear all" clears every alert
    await VaultStorage.instance.pushTopNotification(
      title: 'Second Alert',
      body: 'Follow-up update for verification.',
    );
    await tester.pumpAndSettle();
    expect(find.text('+1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dismiss_all_notifications_btn')));
    await tester.pumpAndSettle();
    expect(find.text('Second Alert'), findsNothing);
    expect(find.text('DailyHelper Alerts Ready'), findsNothing);

    // 4. Simulate Android denying POST_NOTIFICATIONS -> switch stays OFF & reveals Open System Settings
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotificationService.channel, (MethodCall call) async {
      nativeCalls.add(call);
      if (call.method == 'configureReminders') return false;
      if (call.method == 'getNotificationStatus') {
        return {
          'permissionGranted': false,
          'systemEnabled': false,
          'remindersScheduled': false,
        };
      }
      return true;
    });

    await VaultStorage.instance.setRemindersEnabled(true);
    await tester.pumpAndSettle();

    expect(VaultStorage.instance.remindersEnabled, isFalse);
    expect(VaultStorage.instance.osNotificationBlocked, isTrue);
    expect(find.byKey(const Key('settings_open_os_notif_tile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings_open_os_notif_tile')));
    await tester.pumpAndSettle();
    expect(nativeCalls.any((c) => c.method == 'openNotificationSettings'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
