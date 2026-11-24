import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'gcp_backend_service.dart';
import 'notification_service.dart';

class VaultStorage extends ChangeNotifier {
  VaultStorage._();
  static final VaultStorage instance = VaultStorage._();

  static const String _marketplaceBookingsKey = 'dailyhelper_marketplace_bookings_v1';
  static const String _marketplaceWorkersKey = 'dailyhelper_marketplace_workers_v1';
  static const String _globalLangKey = 'dailyhelper_preferred_lang_v1';

  static const List<String> standardSlots = [
    '09:00 - 11:00 AM',
    '11:00 - 01:00 PM',
    '02:00 - 04:00 PM',
    '04:00 - 06:00 PM',
  ];

  AppUser _activeUser = AppUser.visitor();
  String _sessionToken = 'local_visitor';

  String _lang = 'en';
  String _pinCode = '560034';
  String _savedAddress = '';
  bool _remindersEnabled = true;
  bool _osNotificationBlocked = false;
  bool _defaultSeeded = false;
  bool _proStarterSeeded = false;

  List<String> _savedWorkerIds = [];
  List<WorkerProfile> _workers = [];
  List<BookingRecord> _userBookings = [];
  List<AppNotificationItem> _notifications = [];

  // Getters
  String get lang => _lang;
  String get pinCode => _pinCode;
  String get savedAddress => _savedAddress;
  bool get remindersEnabled => _remindersEnabled;
  bool get osNotificationBlocked => _osNotificationBlocked;
  List<String> get savedWorkerIds => List.unmodifiable(_savedWorkerIds);
  List<WorkerProfile> get workers => List.unmodifiable(_workers);
  List<BookingRecord> get bookings => List.unmodifiable(_userBookings);

  bool isWorkerSaved(String workerId) => _savedWorkerIds.contains(workerId);

  List<AppNotificationItem> get unreadNotifications =>
      _notifications.where((n) => !n.isDismissed).toList(growable: false);

  int get unreadNotificationCount => unreadNotifications.length;

  AppNotificationItem? get activeTopNotification {
    for (final n in _notifications) {
      if (!n.isDismissed) return n;
    }
    return null;
  }

  String _vaultKeyFor(String userId) => 'dailyhelper_vault_v1_$userId';

  String get todayIso {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, String>> get upcomingDateChoices {
    final now = DateTime.now();
    final d1 = now.add(const Duration(days: 1));
    final d2 = now.add(const Duration(days: 2));
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return [
      {'id': fmt(now), 'en': 'Today', 'hi': 'आज'},
      {'id': fmt(d1), 'en': 'Tomorrow', 'hi': 'कल'},
      {'id': fmt(d2), 'en': '${d2.day}/${d2.month}', 'hi': '${d2.day}/${d2.month}'},
    ];
  }

  void _clearInMemory() {
    _lang = 'en';
    _pinCode = '560034';
    _savedAddress = '';
    _remindersEnabled = true;
    _osNotificationBlocked = false;
    _defaultSeeded = false;
    _proStarterSeeded = false;
    _savedWorkerIds = [];
    _workers = [];
    _userBookings = [];
    _notifications = [];
  }

  static List<WorkerProfile> _starterWorkers() => const [
        WorkerProfile(
          id: 'w1',
          nameEn: 'Ramesh Kumar',
          nameHi: 'रमेश कुमार',
          trade: 'electrician',
          skillsEn: ['Switchboard & MCB Repair', 'Ceiling Fan & Regulator', 'Geyser Point Wiring'],
          skillsHi: ['स्विचबोर्ड और एमसीबी रिपेयर', 'पंखा और रेगुलेटर', 'गीज़र वायरिंग'],
          servicePins: ['560034', '110001', '400050'],
          experienceYears: 8,
          visitFeeInr: 149,
          hourlyRateInr: 250,
          dailyRateInr: 950,
          customRates: [
            ServiceRateItem(service: 'Ceiling Fan Install / Repair', priceInr: 180),
            ServiceRateItem(service: 'Switchboard / MCB Replacement', priceInr: 220),
          ],
          upiId: 'ramesh.elec@okaxis',
          phone: '+91 99001 44556',
          languages: 'Hindi, English',
          verified: true,
          isOnline: true,
          ratingAvg: 4.9,
          jobsCompleted: 64,
          khataTodayInr: 450,
          khataMonthInr: 18400,
        ),
        WorkerProfile(
          id: 'w2',
          nameEn: 'Suresh Yadav',
          nameHi: 'सुरेश यादव',
          trade: 'plumber',
          skillsEn: ['Tap & Mixer Leak', 'Flush Tank Repair', 'Kitchen Sink Unclog'],
          skillsHi: ['नल और मिक्सर लीक', 'फ्लश टैंक रिपेयर', 'किचन सिंक अनब्लॉक'],
          servicePins: ['560034', '110001', '400050'],
          experienceYears: 6,
          visitFeeInr: 129,
          hourlyRateInr: 220,
          dailyRateInr: 850,
          customRates: [
            ServiceRateItem(service: 'Tap / Mixer Replacement', priceInr: 150),
            ServiceRateItem(service: 'Flush Tank Repair', priceInr: 250),
          ],
          upiId: 'suresh.plumb@paytm',
          phone: '+91 98112 33445',
          languages: 'Hindi, English',
          verified: true,
          isOnline: true,
          ratingAvg: 4.7,
          jobsCompleted: 41,
          khataTodayInr: 300,
          khataMonthInr: 15200,
        ),
        WorkerProfile(
          id: 'w3',
          nameEn: 'Salim Ansari',
          nameHi: 'सलीम अंसारी',
          trade: 'carpenter',
          skillsEn: ['Door Lock & Hinge Fix', 'Wardrobe Sliding Track', 'Curtain Rod & Drill'],
          skillsHi: ['दरवाजा लॉक और कब्जा', 'अलमारी स्लाइडिंग रिपेयर', 'पर्दा रॉड और ड्रिलिंग'],
          servicePins: ['560034', '110001', '400050'],
          experienceYears: 14,
          visitFeeInr: 149,
          hourlyRateInr: 300,
          dailyRateInr: 1100,
          customRates: [
            ServiceRateItem(service: 'Door Lock & Hinge Fix', priceInr: 200),
            ServiceRateItem(service: 'Curtain Rod Drilling', priceInr: 180),
          ],
          upiId: 'salim.wood@ybl',
          phone: '+91 98204 77889',
          languages: 'Hindi, English',
          verified: true,
          isOnline: true,
          blockedSlots: ['11:00 - 01:00 PM'],
          ratingAvg: 4.8,
          jobsCompleted: 92,
          khataTodayInr: 600,
          khataMonthInr: 24500,
        ),
        WorkerProfile(
          id: 'w4',
          nameEn: 'Vikram Sharma',
          nameHi: 'विक्रम शर्मा',
          trade: 'appliance',
          skillsEn: ['Split AC Servicing', 'Washing Machine Repair', 'RO Water Purifier'],
          skillsHi: ['स्प्लिट एसी सर्विस', 'वाशिंग मशीन रिपेयर', 'आरओ वाटर प्यूरीफायर'],
          servicePins: ['560034', '110001', '400050'],
          experienceYears: 9,
          visitFeeInr: 199,
          hourlyRateInr: 350,
          dailyRateInr: 1300,
          customRates: [
            ServiceRateItem(service: 'Split AC Jet Service', priceInr: 499),
            ServiceRateItem(service: 'RO Filter Service', priceInr: 299),
          ],
          upiId: 'vikram.cool@okicici',
          phone: '+91 97390 55661',
          languages: 'Hindi, English',
          verified: true,
          isOnline: true,
          ratingAvg: 4.9,
          jobsCompleted: 78,
          khataTodayInr: 898,
          khataMonthInr: 29100,
        ),
        WorkerProfile(
          id: 'w5',
          nameEn: 'Manoj Verma',
          nameHi: 'मनोज वर्मा',
          trade: 'painter',
          skillsEn: ['Dampness & Putty Patch', 'Single Room Repaint', 'Wood Touch-up'],
          skillsHi: ['सीलन और पुट्टी रिपेयर', 'एक कमरा पेंटिंग', 'लकड़ी पॉलिश'],
          servicePins: ['560034', '110001', '400050'],
          experienceYears: 11,
          visitFeeInr: 99,
          hourlyRateInr: 200,
          dailyRateInr: 800,
          customRates: [
            ServiceRateItem(service: 'Dampness Putty Patch', priceInr: 350),
            ServiceRateItem(service: 'Single Wall Touch-up', priceInr: 450),
          ],
          upiId: 'manoj.paint@ybl',
          phone: '+91 96501 88990',
          languages: 'Hindi',
          verified: true,
          isOnline: true,
          ratingAvg: 4.6,
          jobsCompleted: 29,
          khataTodayInr: 0,
          khataMonthInr: 16800,
        ),
      ];

  Map<String, dynamic> exportSnapshotMap() => {
        'lang': _lang,
        'pinCode': _pinCode,
        'savedAddress': _savedAddress,
        'remindersEnabled': _remindersEnabled,
        'defaultSeeded': _defaultSeeded,
        'proStarterSeeded': _proStarterSeeded,
        'savedWorkerIds': _savedWorkerIds,
        'bookings': _userBookings.map((b) => b.toMap()).toList(),
        'notifications': _notifications.map((n) => n.toMap()).toList(),
      };

  void _hydrateFromMap(Map<String, dynamic> map) {
    _lang = (map['lang'] ?? 'en').toString();
    _pinCode = (map['pinCode'] ?? '560034').toString();
    _savedAddress = (map['savedAddress'] ?? '').toString();
    _remindersEnabled = map['remindersEnabled'] != false;
    _defaultSeeded = map['defaultSeeded'] == true;
    _proStarterSeeded = map['proStarterSeeded'] == true;
    _savedWorkerIds =
        ((map['savedWorkerIds'] as List<dynamic>?) ?? const []).map((e) => e.toString()).toList();

    final bList = (map['bookings'] as List<dynamic>? ?? []);
    _userBookings = bList
        .map((e) => BookingRecord.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final nList = (map['notifications'] as List<dynamic>? ?? []);
    _notifications = nList
        .map((e) => AppNotificationItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<WorkerProfile>> _loadSharedWorkers(SharedPreferences prefs) async {
    final raw = prefs.getString(_marketplaceWorkersKey);
    if (raw == null || raw.isEmpty) {
      final starters = _starterWorkers();
      await prefs.setString(
        _marketplaceWorkersKey,
        jsonEncode(starters.map((w) => w.toMap()).toList()),
      );
      return List<WorkerProfile>.from(starters);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => WorkerProfile.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return List<WorkerProfile>.from(_starterWorkers());
    }
  }

  Future<void> _saveSharedWorkers(SharedPreferences prefs) async {
    await prefs.setString(
      _marketplaceWorkersKey,
      jsonEncode(_workers.map((w) => w.toMap()).toList()),
    );
  }

  Future<List<BookingRecord>> _loadAllMarketplaceBookings(SharedPreferences prefs) async {
    final raw = prefs.getString(_marketplaceBookingsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => BookingRecord.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAllMarketplaceBookings(
    SharedPreferences prefs,
    List<BookingRecord> all,
  ) async {
    await prefs.setString(
      _marketplaceBookingsKey,
      jsonEncode(all.map((b) => b.toMap()).toList()),
    );
  }

  Future<void> loadForUser(AppUser user, {required String token}) async {
    _clearInMemory();
    _activeUser = user;
    _sessionToken = token;

    final prefs = await SharedPreferences.getInstance();
    _workers = await _loadSharedWorkers(prefs);

    final vaultRaw = prefs.getString(_vaultKeyFor(user.id));
    if (vaultRaw != null && vaultRaw.isNotEmpty) {
      try {
        _hydrateFromMap(Map<String, dynamic>.from(jsonDecode(vaultRaw) as Map));
      } catch (_) {}
    }

    final savedGlobalLang = prefs.getString(_globalLangKey);
    if (savedGlobalLang != null && savedGlobalLang.isNotEmpty) {
      _lang = savedGlobalLang;
    }

    if (!_defaultSeeded) {
      _defaultSeeded = true;
    }

    // Ensure Professional account has its own WorkerProfile + starter request once
    if (!user.isGuest && user.role == UserRole.professional) {
      final hasProfile = _workers.any((w) => w.id == user.id);
      if (!hasProfile) {
        _workers.insert(
          0,
          WorkerProfile(
            id: user.id,
            nameEn: user.name,
            nameHi: user.name,
            trade: user.trade,
            skillsEn: const ['Inspection & Repair', 'Installation & Maintenance'],
            skillsHi: const ['जांच और रिपेयर', 'फिटिंग और मेंटेनेंस'],
            servicePins: [_pinCode, '560034'],
            experienceYears: 5,
            visitFeeInr: 149,
            hourlyRateInr: 250,
            upiId: '${user.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@upi',
            phone: user.phone.isEmpty ? '+91 99001 44556' : user.phone,
            languages: 'Hindi, English',
            verified: true,
            isOnline: true,
          ),
        );
        await _saveSharedWorkers(prefs);
      }

      final allBookings = await _loadAllMarketplaceBookings(prefs);
      if (!_proStarterSeeded) {
        _proStarterSeeded = true;
        final hasStarter = allBookings.any((b) => b.id == 'BK-1048-${user.id}');
        if (!hasStarter) {
          final starter = BookingRecord(
            id: 'BK-1048-${user.id}',
            customerId: 'seed_customer_arjun',
            customerName: 'Arjun Nair',
            customerPhone: '+91 98802 66771',
            workerId: user.id,
            workerNameEn: user.name,
            workerNameHi: user.name,
            workerPhone: user.phone,
            trade: user.trade,
            pinCode: _pinCode,
            locality: 'PIN $_pinCode',
            fullAddress: 'House #18, 2nd Cross',
            bookingDate: todayIso,
            slotWindow: '11:00 - 01:00 PM',
            issueNote: 'Switchboard tripping on load',
            visitFeeInr: 149,
            status: 'requested',
            createdAt: DateTime.now().toIso8601String(),
          );
          allBookings.insert(0, starter);
          await _saveAllMarketplaceBookings(prefs, allBookings);
          _notifications.insert(
            0,
            AppNotificationItem(
              id: 'notif_seed_${user.id}',
              title: 'New Booking Request',
              body: 'Arjun Nair requested Today, 11:00 - 01:00 PM in PIN $_pinCode.',
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
        }
      }
      _userBookings = allBookings.where((b) => b.workerId == user.id).toList();
    } else if (!user.isGuest && user.role == UserRole.customer) {
      final allBookings = await _loadAllMarketplaceBookings(prefs);
      final sharedForUser = allBookings.where((b) => b.customerId == user.id).toList();
      if (sharedForUser.isNotEmpty) {
        _userBookings = sharedForUser;
      }
    }

    // Real-Calendar Resilience: auto-expire stale unanswered requests from past ISO dates
    final today = todayIso;
    for (int i = 0; i < _userBookings.length; i++) {
      final b = _userBookings[i];
      if (b.status == 'requested' &&
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(b.bookingDate) &&
          b.bookingDate.compareTo(today) < 0) {
        _userBookings[i] = b.copyWith(status: 'expired');
      }
    }

    await prefs.setString(_vaultKeyFor(user.id), jsonEncode(exportSnapshotMap()));
    notifyListeners();

    // Sync real OS notification permission state & schedule alarms cleanly
    syncNotificationStatus();

    // Live Cloud Run Sync (Workers, Bookings, Notifications, Vault)
    refreshFromCloud();
  }

  Future<void> syncNotificationStatus({bool ensureScheduledIfAllowed = false}) async {
    final status = await NotificationService.instance.getNotificationStatus();
    final blocked = !status.isAllowed;
    bool changed = false;

    if (_osNotificationBlocked != blocked) {
      _osNotificationBlocked = blocked;
      changed = true;
    }
    if (blocked && _remindersEnabled) {
      _remindersEnabled = false;
      changed = true;
    } else if (!blocked && _remindersEnabled && (!status.remindersScheduled || ensureScheduledIfAllowed)) {
      await NotificationService.instance.configureReminders(
        enabled: true,
        isProfessional: _activeUser.role == UserRole.professional,
      );
      await _scheduleUpcomingConfirmedReminders();
    }

    if (changed) {
      await _persistToDisk(syncCloud: false);
      notifyListeners();
    }
  }

  Future<void> _scheduleReminderForBooking(BookingRecord b) async {
    if (!_remindersEnabled || _osNotificationBlocked) return;
    final triggerAt = NotificationService.compute60MinReminderTime(
      b.bookingDate,
      b.slotWindow,
    );
    if (triggerAt == null) return;
    final isPro = _activeUser.role == UserRole.professional;
    final title = isPro ? 'Upcoming Job in 60 mins' : 'Helper Arriving Soon (60m)';
    final body = isPro
        ? '${b.customerName} · ${b.slotWindow} (${b.fullAddress})'
        : '${b.localizedWorkerName(_lang)} · ${b.slotWindow} (PIN ${b.pinCode})';
    await NotificationService.instance.scheduleAppointmentReminder(
      bookingId: b.id,
      triggerAt: triggerAt,
      title: title,
      body: body,
    );
  }

  Future<void> _scheduleUpcomingConfirmedReminders() async {
    if (!_remindersEnabled || _osNotificationBlocked) return;
    for (final b in _userBookings) {
      if (b.status == 'confirmed') {
        await _scheduleReminderForBooking(b);
      }
    }
  }

  Future<void> refreshFromCloud() async {
    bool dirty = false;
    final prefs = await SharedPreferences.getInstance();

    // 1. Live workers list from Cloud Run (works even for visitors!)
    final cloudWorkers = await GcpBackendService.instance.fetchWorkers();
    if (cloudWorkers != null && cloudWorkers.isNotEmpty) {
      final cloudIds = cloudWorkers.map((w) => w.id).toSet();
      final merged = [
        ...cloudWorkers,
        ..._workers.where((w) => !cloudIds.contains(w.id)),
      ];
      _workers = merged;
      await _saveSharedWorkers(prefs);
      dirty = true;
    }

    if (!_activeUser.isGuest && !_sessionToken.startsWith('local_')) {
      // 2. Pull vault preferences if empty locally
      if (_userBookings.isEmpty) {
        final cloudSnap = await GcpBackendService.instance.fetchVaultSnapshot(_sessionToken);
        if (cloudSnap != null && cloudSnap.isNotEmpty) {
          _hydrateFromMap(cloudSnap);
          dirty = true;
        }
      }

      // 3. Pull live multi-device bookings from Cloud Run PostgreSQL
      final cloudBookings = await GcpBackendService.instance.fetchBookings(_sessionToken);
      if (cloudBookings != null) {
        final prevStatusById = {for (final b in _userBookings) b.id: b.status};
        final cloudIds = cloudBookings.map((b) => b.id).toSet();
        final localOnly = _userBookings.where((b) => !cloudIds.contains(b.id)).toList();
        _userBookings = [...cloudBookings, ...localOnly];
        dirty = true;

        // Schedule 60m reminders for newly confirmed bookings & cancel for closed ones
        for (final cb in cloudBookings) {
          if (cb.status == 'confirmed' && prevStatusById[cb.id] != 'confirmed') {
            await _scheduleReminderForBooking(cb);
          } else if (cb.status == 'cancelled' || cb.status == 'declined' || cb.status == 'completed') {
            await NotificationService.instance.cancelAppointmentReminder(cb.id);
          }
        }
      }

      // 4. Pull live undismissed notifications from Cloud Run PostgreSQL & deliver OS alerts
      final cloudNotifs = await GcpBackendService.instance.fetchNotifications(_sessionToken);
      if (cloudNotifs != null) {
        final cloudIds = cloudNotifs.map((n) => n.id).toSet();
        // Reconcile server-originated alerts dismissed on another device
        for (int i = 0; i < _notifications.length; i++) {
          final existing = _notifications[i];
          if (!existing.isDismissed &&
              !existing.id.startsWith('notif_') &&
              !cloudIds.contains(existing.id)) {
            _notifications[i] = existing.copyWith(isDismissed: true);
            dirty = true;
          }
        }

        final existingIds = _notifications.map((n) => n.id).toSet();
        for (final cn in cloudNotifs.reversed) {
          if (!existingIds.contains(cn.id)) {
            _notifications.insert(0, cn);
            dirty = true;
            if (_remindersEnabled && !_osNotificationBlocked) {
              await NotificationService.instance.showNotification(
                id: 7200 + (cn.id.hashCode.abs() % 1000),
                title: cn.title,
                body: cn.body,
                highPriority: true,
              );
            }
          }
        }
      }
    }

    if (dirty) {
      await _persistToDisk(syncCloud: false);
      notifyListeners();
    }
  }

  Future<void> upgradeOrLoadUser(
    AppUser newUser, {
    required String token,
    Map<String, dynamic>? guestSnapshot,
  }) async {
    await loadForUser(newUser, token: token);
    if (guestSnapshot != null) {
      final guestLang = guestSnapshot['lang']?.toString();
      final guestPin = guestSnapshot['pinCode']?.toString();
      if (guestLang != null && guestLang.isNotEmpty) _lang = guestLang;
      if (guestPin != null && guestPin.isNotEmpty) _pinCode = guestPin;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_vaultKeyFor('local_guest_vault'));
      await _persistToDisk();
      notifyListeners();
    }
  }

  Future<void> clearOnSignOut() async {
    _clearInMemory();
    _activeUser = AppUser.visitor();
    _sessionToken = 'local_visitor';
    final prefs = await SharedPreferences.getInstance();
    final savedGlobalLang = prefs.getString(_globalLangKey);
    if (savedGlobalLang != null && savedGlobalLang.isNotEmpty) {
      _lang = savedGlobalLang;
    }
    _workers = await _loadSharedWorkers(prefs);
    notifyListeners();
  }

  Future<void> _persistToDisk({bool syncCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final snap = exportSnapshotMap();
    await prefs.setString(_vaultKeyFor(_activeUser.id), jsonEncode(snap));
    if (syncCloud && !_activeUser.isGuest && !_sessionToken.startsWith('local_')) {
      GcpBackendService.instance.pushVaultSnapshot(_sessionToken, snap);
    }
  }

  // --- User Preferences & Top Notifications ---
  Future<void> setLanguage(String newLang) async {
    _lang = newLang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalLangKey, newLang);
    await _persistToDisk();
    GcpBackendService.instance.updateUserLanguage(_sessionToken, newLang);
    notifyListeners();
  }

  Future<void> setPinCode(String newPin) async {
    final clean = newPin.trim();
    if (clean.length != 6) return;
    _pinCode = clean;
    await _persistToDisk();
    notifyListeners();
  }

  Future<void> toggleSavedWorker(String workerId) async {
    if (_savedWorkerIds.contains(workerId)) {
      _savedWorkerIds.remove(workerId);
    } else {
      _savedWorkerIds.add(workerId);
    }
    await _persistToDisk();
    notifyListeners();
  }

  Future<bool> setRemindersEnabled(bool enabled) async {
    final applied = await NotificationService.instance.configureReminders(
      enabled: enabled,
      isProfessional: _activeUser.role == UserRole.professional,
    );
    if (enabled) {
      _remindersEnabled = applied;
      _osNotificationBlocked = !applied;
      if (applied) {
        await _scheduleUpcomingConfirmedReminders();
      }
    } else {
      _remindersEnabled = false;
      _osNotificationBlocked = false;
    }
    await _persistToDisk();
    notifyListeners();
    return _remindersEnabled;
  }

  Future<bool> sendTestNotification() async {
    final enabled = await setRemindersEnabled(true);
    if (!enabled) {
      await pushTopNotification(
        title: 'Notifications Blocked',
        body: 'Allow DailyHelper notifications in Android Settings to receive booking alerts.',
      );
      return false;
    }
    const title = 'DailyHelper Alerts Ready';
    const body = 'Booking updates and 60-minute appointment reminders are active.';
    await NotificationService.instance.showNotification(
      id: 7999,
      title: title,
      body: body,
      highPriority: true,
    );
    await pushTopNotification(title: title, body: body);
    return true;
  }

  Future<void> pushTopNotification({
    required String title,
    required String body,
    bool alsoShowOsNotification = false,
  }) async {
    final id = 'notif_${DateTime.now().microsecondsSinceEpoch}';
    _notifications.insert(
      0,
      AppNotificationItem(
        id: id,
        title: title,
        body: body,
        isDismissed: false,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    if (alsoShowOsNotification && _remindersEnabled && !_osNotificationBlocked) {
      await NotificationService.instance.showNotification(
        id: 7300 + (id.hashCode.abs() % 1000),
        title: title,
        body: body,
        highPriority: true,
      );
    }
    await _persistToDisk();
    notifyListeners();
  }

  Future<void> dismissTopNotification(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].copyWith(isDismissed: true);
      await _persistToDisk();
      notifyListeners();
      await GcpBackendService.instance.dismissCloudNotification(_sessionToken, id);
    }
  }

  Future<void> dismissAllTopNotifications() async {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isDismissed) {
        _notifications[i] = _notifications[i].copyWith(isDismissed: true);
        changed = true;
      }
    }
    if (changed) {
      await _persistToDisk();
      notifyListeners();
    }
    await GcpBackendService.instance.dismissAllCloudNotifications(_sessionToken);
  }

  // --- Customer Booking Creation, Cancel & Rating ---
  Future<BookingRecord> createBooking({
    required WorkerProfile worker,
    required String dateStr,
    required String slotWindow,
    required String issueNote,
    required String fullAddress,
  }) async {
    final cleanAddress = fullAddress.trim();
    if (cleanAddress.isNotEmpty) {
      _savedAddress = cleanAddress;
    }

    final booking = BookingRecord(
      id: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      customerId: _activeUser.id,
      customerName: _activeUser.name,
      customerPhone: _activeUser.phone.isEmpty ? '+91 98450 11223' : _activeUser.phone,
      workerId: worker.id,
      workerNameEn: worker.nameEn,
      workerNameHi: worker.nameHi,
      workerPhone: worker.phone,
      trade: worker.trade,
      pinCode: _pinCode,
      locality: 'PIN $_pinCode',
      fullAddress: cleanAddress.isEmpty ? 'PIN $_pinCode' : cleanAddress,
      bookingDate: dateStr,
      slotWindow: slotWindow,
      issueNote: issueNote.trim().isEmpty ? 'General inspection & repair' : issueNote.trim(),
      visitFeeInr: worker.visitFeeInr,
      status: 'requested',
      createdAt: DateTime.now().toIso8601String(),
    );

    _userBookings.insert(0, booking);
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAllMarketplaceBookings(prefs);
    all.insert(0, booking);
    await _saveAllMarketplaceBookings(prefs, all);

    await GcpBackendService.instance.createCloudBooking(_sessionToken, booking);

    if (_remindersEnabled) {
      await NotificationService.instance.configureReminders(
        enabled: true,
        isProfessional: false,
      );
    }

    await pushTopNotification(
      title: 'Booking Requested',
      body: '${worker.localizedName(_lang)} · $dateStr, $slotWindow',
      alsoShowOsNotification: true,
    );
    return booking;
  }

  Future<void> cancelBooking(String bookingId) async {
    final idx = _userBookings.indexWhere((b) => b.id == bookingId);
    if (idx < 0) return;
    final updated = _userBookings[idx].copyWith(status: 'cancelled');
    _userBookings[idx] = updated;

    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAllMarketplaceBookings(prefs);
    final mIdx = all.indexWhere((b) => b.id == bookingId);
    if (mIdx >= 0) {
      all[mIdx] = updated;
      await _saveAllMarketplaceBookings(prefs, all);
    }
    await NotificationService.instance.cancelAppointmentReminder(bookingId);
    await GcpBackendService.instance.updateCloudBooking(_sessionToken, bookingId, status: 'cancelled');
    await pushTopNotification(
      title: 'Booking Cancelled',
      body: '${updated.localizedWorkerName(_lang)} · ${updated.slotWindow}',
    );
  }

  Future<void> rateCompletedBooking(String bookingId, int stars) async {
    final idx = _userBookings.indexWhere((b) => b.id == bookingId);
    if (idx < 0) return;
    final updated = _userBookings[idx].copyWith(customerRating: stars);
    _userBookings[idx] = updated;

    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAllMarketplaceBookings(prefs);
    final mIdx = all.indexWhere((b) => b.id == bookingId);
    if (mIdx >= 0) {
      all[mIdx] = updated;
      await _saveAllMarketplaceBookings(prefs, all);
    }
    GcpBackendService.instance
        .updateCloudBooking(_sessionToken, bookingId, customerRating: stars);
    await _persistToDisk();
    notifyListeners();
  }

  // --- Professional Job Actions, Rate Card & Khata ---
  WorkerProfile get currentProfessionalProfile {
    final idx = _workers.indexWhere((w) => w.id == _activeUser.id);
    if (idx >= 0) return _workers[idx];
    return _workers.first;
  }

  Future<void> updateProfessionalProfile({
    int? visitFeeInr,
    int? hourlyRateInr,
    int? dailyRateInr,
    List<ServiceRateItem>? customRates,
    String? upiId,
    List<String>? servicePins,
    bool? isOnline,
    List<String>? blockedSlots,
    bool showSavedNotif = false,
  }) async {
    final targetId =
        _workers.any((w) => w.id == _activeUser.id) ? _activeUser.id : _workers.first.id;
    final idx = _workers.indexWhere((w) => w.id == targetId);
    if (idx < 0) return;

    _workers[idx] = _workers[idx].copyWith(
      visitFeeInr: visitFeeInr,
      hourlyRateInr: hourlyRateInr,
      dailyRateInr: dailyRateInr,
      customRates: customRates,
      upiId: upiId,
      servicePins: servicePins,
      isOnline: isOnline,
      blockedSlots: blockedSlots,
    );

    final prefs = await SharedPreferences.getInstance();
    await _saveSharedWorkers(prefs);

    GcpBackendService.instance.updateMyWorkerProfile(
      _sessionToken,
      visitFeeInr: visitFeeInr,
      hourlyRateInr: hourlyRateInr,
      dailyRateInr: dailyRateInr,
      customRates: customRates,
      upiId: upiId,
      servicePins: servicePins,
      isOnline: isOnline,
      blockedSlots: blockedSlots,
    );

    if (showSavedNotif) {
      await pushTopNotification(
        title: 'Rate Card Updated',
        body:
            'Visit ₹${_workers[idx].visitFeeInr} · Hourly ₹${_workers[idx].hourlyRateInr}/hr · Day ₹${_workers[idx].dailyRateInr}',
      );
    } else {
      await _persistToDisk();
      notifyListeners();
    }
  }

  Future<void> addCustomRateItem(String service, int priceInr) async {
    final clean = service.trim();
    if (clean.isEmpty || priceInr <= 0) return;
    final pro = currentProfessionalProfile;
    final next = List<ServiceRateItem>.from(pro.customRates)
      ..add(ServiceRateItem(service: clean, priceInr: priceInr));
    await updateProfessionalProfile(customRates: next);
  }

  Future<void> removeCustomRateItem(int index) async {
    final pro = currentProfessionalProfile;
    if (index < 0 || index >= pro.customRates.length) return;
    final next = List<ServiceRateItem>.from(pro.customRates)..removeAt(index);
    await updateProfessionalProfile(customRates: next);
  }

  Future<void> updateJobStatus(
    String bookingId,
    String newStatus, {
    int? finalAmountInr,
    String? paymentMethod,
  }) async {
    final idx = _userBookings.indexWhere((b) => b.id == bookingId);
    if (idx < 0) return;

    final updated = _userBookings[idx].copyWith(
      status: newStatus,
      finalAmountInr: finalAmountInr,
      paymentMethod: paymentMethod,
    );
    _userBookings[idx] = updated;

    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAllMarketplaceBookings(prefs);
    final mIdx = all.indexWhere((b) => b.id == bookingId);
    if (mIdx >= 0) {
      all[mIdx] = updated;
      await _saveAllMarketplaceBookings(prefs, all);
    }

    await GcpBackendService.instance.updateCloudBooking(
      _sessionToken,
      bookingId,
      status: newStatus,
      finalAmountInr: finalAmountInr,
      paymentMethod: paymentMethod,
    );

    if (newStatus == 'confirmed') {
      if (_remindersEnabled) {
        final ok = await NotificationService.instance.configureReminders(
          enabled: true,
          isProfessional: true,
        );
        _osNotificationBlocked = !ok;
        if (ok) {
          await _scheduleReminderForBooking(updated);
        }
      }
      await pushTopNotification(
        title: 'Slot Confirmed',
        body: 'Address unlocked: ${updated.fullAddress} · 60m reminder set.',
        alsoShowOsNotification: true,
      );
    } else if (newStatus == 'declined') {
      await NotificationService.instance.cancelAppointmentReminder(bookingId);
      await pushTopNotification(
        title: 'Request Declined',
        body: '${updated.customerName} · ${updated.slotWindow}',
      );
    } else if (newStatus == 'completed') {
      await NotificationService.instance.cancelAppointmentReminder(bookingId);
      final amt = finalAmountInr ?? updated.visitFeeInr;
      final pIdx = _workers.indexWhere((w) => w.id == _activeUser.id);
      if (pIdx >= 0) {
        final cur = _workers[pIdx];
        _workers[pIdx] = cur.copyWith(
          jobsCompleted: cur.jobsCompleted + 1,
          khataTodayInr: cur.khataTodayInr + amt,
          khataMonthInr: cur.khataMonthInr + amt,
        );
        await _saveSharedWorkers(prefs);
      }
      await pushTopNotification(
        title: 'Payment Logged to Khata',
        body: '₹$amt received via ${paymentMethod ?? 'Cash'} (0% commission).',
        alsoShowOsNotification: true,
      );
    } else {
      await _persistToDisk();
      notifyListeners();
    }
  }

  String generateKhataCsv() {
    final buffer = StringBuffer('BookingID,Date,Slot,Customer,AmountINR,PaymentMethod,Commission\n');
    for (final b in _userBookings.where((x) => x.status == 'completed')) {
      final amt = b.finalAmountInr ?? b.visitFeeInr;
      final method = b.paymentMethod ?? 'Cash';
      final safeCust = b.customerName.replaceAll('"', '""');
      buffer.writeln('${b.id},"${b.bookingDate}","${b.slotWindow}","$safeCust",$amt,$method,0%');
    }
    return buffer.toString();
  }
}
