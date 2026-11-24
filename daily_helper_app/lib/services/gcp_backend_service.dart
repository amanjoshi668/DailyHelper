import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class AuthApiResult {
  final Map<String, dynamic>? data;
  final String? error;
  final bool isOffline;

  const AuthApiResult({this.data, this.error, this.isOffline = false});
}

class GcpBackendService {
  GcpBackendService._();
  static final GcpBackendService instance = GcpBackendService._();

  static const String baseUrl = String.fromEnvironment(
    'DAILYHELPER_API_URL',
    defaultValue: 'https://dailyhelper-backend-676039463235.us-central1.run.app',
  );
  static const String appVersion = '1.2.1';
  static const String _localBugsKey = 'dailyhelper_bug_reports_v1';

  http.Client httpClient = http.Client();

  Future<AuthApiResult> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    String trade = 'electrician',
    String pin = '560034',
  }) async {
    try {
      final resp = await httpClient
          .post(
            Uri.parse('$baseUrl/api/v1/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'phone': phone,
              'role': userRoleToString(role),
              'trade': trade,
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 4));
      final body = resp.body.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(resp.body) as Map)
          : <String, dynamic>{};
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        return AuthApiResult(data: body);
      }
      if (resp.statusCode >= 400 && resp.statusCode < 500) {
        return AuthApiResult(error: (body['error'] ?? 'Registration failed').toString());
      }
      return const AuthApiResult(isOffline: true);
    } catch (_) {
      return const AuthApiResult(isOffline: true);
    }
  }

  Future<AuthApiResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final resp = await httpClient
          .post(
            Uri.parse('$baseUrl/api/v1/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 4));
      final body = resp.body.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(resp.body) as Map)
          : <String, dynamic>{};
      if (resp.statusCode == 200) {
        return AuthApiResult(data: body);
      }
      if (resp.statusCode >= 400 && resp.statusCode < 500) {
        return AuthApiResult(error: (body['error'] ?? 'Invalid email or password').toString());
      }
      return const AuthApiResult(isOffline: true);
    } catch (_) {
      return const AuthApiResult(isOffline: true);
    }
  }

  Future<Map<String, dynamic>?> initMobileGoogleAuth(UserRole role) async {
    try {
      final resp = await httpClient
          .post(
            Uri.parse('$baseUrl/api/v1/auth/mobile-google/init'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'role': userRoleToString(role)}),
          )
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> pollMobileGoogleAuth(String sessionId) async {
    try {
      final resp = await httpClient
          .get(Uri.parse('$baseUrl/api/v1/auth/mobile-google/poll?session=$sessionId'))
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
    } catch (_) {}
    return null;
  }

  // --- Live Multi-Device Marketplace Endpoints ---
  Future<List<WorkerProfile>?> fetchWorkers() async {
    try {
      final resp = await httpClient
          .get(Uri.parse('$baseUrl/api/v1/workers'))
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rows = (data['workers'] as List<dynamic>? ?? []);
        return rows
            .map((e) => WorkerProfile.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<WorkerProfile?> updateMyWorkerProfile(
    String token, {
    int? visitFeeInr,
    int? hourlyRateInr,
    int? dailyRateInr,
    List<ServiceRateItem>? customRates,
    String? upiId,
    List<String>? servicePins,
    bool? isOnline,
    List<String>? blockedSlots,
  }) async {
    if (token.startsWith('local_')) return null;
    try {
      final payload = <String, dynamic>{};
      if (visitFeeInr != null) payload['visitFeeInr'] = visitFeeInr;
      if (hourlyRateInr != null) payload['hourlyRateInr'] = hourlyRateInr;
      if (dailyRateInr != null) payload['dailyRateInr'] = dailyRateInr;
      if (customRates != null) {
        payload['customRates'] = customRates.map((r) => r.toMap()).toList();
      }
      if (upiId != null) payload['upiId'] = upiId;
      if (servicePins != null) payload['servicePins'] = servicePins;
      if (isOnline != null) payload['isOnline'] = isOnline;
      if (blockedSlots != null) payload['blockedSlots'] = blockedSlots;

      final resp = await httpClient
          .put(
            Uri.parse('$baseUrl/api/v1/workers/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['worker'] is Map) {
          return WorkerProfile.fromMap(Map<String, dynamic>.from(data['worker'] as Map));
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateUserLanguage(String token, String preferredLang) async {
    if (token.startsWith('local_')) return;
    try {
      await httpClient
          .put(
            Uri.parse('$baseUrl/api/v1/users/me/preferences'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'preferredLang': preferredLang}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<List<BookingRecord>?> fetchBookings(String token) async {
    if (token.startsWith('local_')) return null;
    try {
      final resp = await httpClient.get(
        Uri.parse('$baseUrl/api/v1/bookings'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rows = (data['bookings'] as List<dynamic>? ?? []);
        return rows
            .map((e) => BookingRecord.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<BookingRecord?> createCloudBooking(String token, BookingRecord booking) async {
    if (token.startsWith('local_')) return null;
    try {
      final resp = await httpClient
          .post(
            Uri.parse('$baseUrl/api/v1/bookings'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'id': booking.id,
              'customerName': booking.customerName,
              'customerPhone': booking.customerPhone,
              'workerId': booking.workerId,
              'workerName': booking.workerNameEn,
              'workerPhone': booking.workerPhone,
              'trade': booking.trade,
              'pinCode': booking.pinCode,
              'locality': booking.locality,
              'fullAddress': booking.fullAddress,
              'bookingDate': booking.bookingDate,
              'slotWindow': booking.slotWindow,
              'issueNote': booking.issueNote,
              'visitFeeInr': booking.visitFeeInr,
            }),
          )
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['booking'] is Map) {
          return BookingRecord.fromMap(Map<String, dynamic>.from(data['booking'] as Map));
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateCloudBooking(
    String token,
    String bookingId, {
    String? status,
    int? finalAmountInr,
    String? paymentMethod,
    int? customerRating,
  }) async {
    if (token.startsWith('local_')) return;
    try {
      final payload = <String, dynamic>{};
      if (status != null) payload['status'] = status;
      if (finalAmountInr != null) payload['finalAmountInr'] = finalAmountInr;
      if (paymentMethod != null) payload['paymentMethod'] = paymentMethod;
      if (customerRating != null) payload['customerRating'] = customerRating;

      await httpClient
          .patch(
            Uri.parse('$baseUrl/api/v1/bookings/$bookingId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<List<AppNotificationItem>?> fetchNotifications(String token) async {
    if (token.startsWith('local_')) return null;
    try {
      final resp = await httpClient.get(
        Uri.parse('$baseUrl/api/v1/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rows = (data['notifications'] as List<dynamic>? ?? []);
        return rows
            .map((e) => AppNotificationItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<void> dismissCloudNotification(String token, String id) async {
    if (token.startsWith('local_') || id.startsWith('notif_')) return;
    try {
      await httpClient.patch(
        Uri.parse('$baseUrl/api/v1/notifications/$id/dismiss'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> dismissAllCloudNotifications(String token) async {
    if (token.startsWith('local_')) return;
    try {
      await httpClient.post(
        Uri.parse('$baseUrl/api/v1/notifications/dismiss-all'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> fetchVaultSnapshot(String token) async {
    if (token.startsWith('local_')) return null;
    try {
      final resp = await httpClient.get(
        Uri.parse('$baseUrl/api/v1/dailyhelper/state'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return body['snapshot'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> pushVaultSnapshot(String token, Map<String, dynamic> snapshot) async {
    if (token.startsWith('local_')) return;
    try {
      await httpClient
          .post(
            Uri.parse('$baseUrl/api/v1/dailyhelper/state'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'snapshot': snapshot}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  // --- Closed-Loop Bug Triage (Local-First + DB Sync + Prune Resolved) ---
  String _normalizeOwnerEmail(String rawEmail) {
    final trimmed = rawEmail.trim().toLowerCase();
    return trimmed.isEmpty ? 'anonymous@tester.local' : trimmed;
  }

  Future<List<BugReportRecord>> _loadLocalBugs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localBugsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => BugReportRecord.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalBugs(List<BugReportRecord> bugs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localBugsKey, jsonEncode(bugs.map((b) => b.toMap()).toList()));
  }

  Future<String?> _postBugToCloud(BugReportRecord record) async {
    try {
      final resp = await httpClient
          .post(
            Uri.parse('$baseUrl/api/v1/bugs'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'description': record.description,
              'pageContext': record.pageContext,
              'appVersion': record.appVersion,
              'userEmail': record.userEmail,
            }),
          )
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final bug = data['bug'] as Map<String, dynamic>?;
        return bug?['id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<BugReportRecord> submitBugReport({
    required String description,
    required String pageContext,
    required String userEmail,
  }) async {
    final ownerEmail = _normalizeOwnerEmail(userEmail);
    final tempId = 'local_bug_${DateTime.now().millisecondsSinceEpoch}';
    var record = BugReportRecord(
      id: tempId,
      description: description.trim(),
      pageContext: pageContext,
      appVersion: appVersion,
      userEmail: ownerEmail,
      createdAt: DateTime.now().toIso8601String(),
      syncedToCloud: false,
      status: 'open',
    );

    final serverId = await _postBugToCloud(record);
    if (serverId != null && serverId.isNotEmpty) {
      record = record.copyWith(id: serverId, syncedToCloud: true);
    }

    final existing = await _loadLocalBugs();
    existing.insert(0, record);
    await _saveLocalBugs(existing);
    return record;
  }

  Future<List<BugReportRecord>> getOpenBugReportsForCurrentUser(String rawUserEmail) async {
    final ownerEmail = _normalizeOwnerEmail(rawUserEmail);
    final localList = await _loadLocalBugs();

    try {
      final resp = await httpClient
          .get(Uri.parse('$baseUrl/api/v1/bugs?status=all&limit=100'))
          .timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final rows = (body['bugs'] as List<dynamic>? ?? []);
        final resolvedIds = <String>{};
        final resolvedSigs = <String>{};
        final serverOpenForUser = <BugReportRecord>[];

        for (final r in rows) {
          final rec = BugReportRecord.fromMap(Map<String, dynamic>.from(r as Map))
              .copyWith(syncedToCloud: true);
          if (rec.status == 'resolved') {
            resolvedIds.add(rec.id);
            resolvedSigs.add(rec.signature);
          } else if (rec.userEmail.toLowerCase() == ownerEmail) {
            serverOpenForUser.add(rec);
          }
        }

        final prunedLocal = localList
            .where((b) =>
                b.status != 'resolved' &&
                !resolvedIds.contains(b.id) &&
                !resolvedSigs.contains(b.signature))
            .toList();
        if (prunedLocal.length != localList.length) {
          await _saveLocalBugs(prunedLocal);
        }

        final seenSigs = <String>{};
        final combined = <BugReportRecord>[];
        for (final s in serverOpenForUser) {
          if (seenSigs.add(s.signature)) combined.add(s);
        }
        for (final l in prunedLocal) {
          if (l.userEmail.toLowerCase() == ownerEmail && seenSigs.add(l.signature)) {
            combined.add(l);
          }
        }
        return combined;
      }
    } catch (_) {}

    return localList
        .where((b) => b.status != 'resolved' && b.userEmail.toLowerCase() == ownerEmail)
        .toList();
  }
}
