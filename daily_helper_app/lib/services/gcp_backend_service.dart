import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class GcpBackendService {
  GcpBackendService._();
  static final GcpBackendService instance = GcpBackendService._();

  static const String baseUrl = String.fromEnvironment(
    'DAILYHELPER_API_URL',
    defaultValue: 'https://dailyhelper-backend-676039463235.us-central1.run.app',
  );
  static const String appVersion = '1.0.0';
  static const String _localBugsKey = 'dailyhelper_bug_reports_v1';

  http.Client httpClient = http.Client();

  Future<Map<String, dynamic>?> register({
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
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> login({
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
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
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
          .timeout(const Duration(seconds: 3));
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
          final rec = BugReportRecord.fromMap(Map<String, dynamic>.from(r as Map)).copyWith(syncedToCloud: true);
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
