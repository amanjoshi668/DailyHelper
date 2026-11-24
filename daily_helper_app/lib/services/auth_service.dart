import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import 'gcp_backend_service.dart';
import 'vault_storage.dart';

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _sessionKey = 'dailyhelper_active_session_v1';
  static const String _localAccountsKey = 'dailyhelper_local_accounts_v1';

  AppUser _currentUser = AppUser.visitor();
  String _sessionToken = 'local_visitor';
  bool _initialized = false;

  AppUser get currentUser => _currentUser;
  String get sessionToken => _sessionToken;
  bool get isLoggedIn => !_currentUser.isGuest;
  bool get isInitialized => _initialized;

  String _hashLocalPassword(String email, String password) {
    final bytes = utf8.encode('dh_salt_${email.toLowerCase().trim()}:$password');
    return sha256.convert(bytes).toString();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _currentUser = AppUser.fromMap(Map<String, dynamic>.from(data['user'] as Map));
        _sessionToken = (data['token'] ?? 'local_${_currentUser.id}').toString();
      } catch (_) {
        _currentUser = AppUser.visitor();
        _sessionToken = 'local_visitor';
      }
    } else {
      _currentUser = AppUser.visitor();
      _sessionToken = 'local_visitor';
    }
    await VaultStorage.instance.loadForUser(_currentUser, token: _sessionToken);
    _initialized = true;
    notifyListeners();
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser.isGuest) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(
        _sessionKey,
        jsonEncode({'user': _currentUser.toMap(), 'token': _sessionToken}),
      );
    }
  }

  Future<String?> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    String trade = 'electrician',
    String pin = '560034',
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim();
    if (cleanName.isEmpty || !cleanEmail.contains('@') || password.length < 4) {
      return 'Please enter name, valid email, and password (min 4 chars).';
    }

    final guestSnapshot = _currentUser.isGuest ? VaultStorage.instance.exportSnapshotMap() : null;

    // 1. Try Cloud Run backend first
    final cloudRes = await GcpBackendService.instance.register(
      name: cleanName,
      email: cleanEmail,
      password: password,
      phone: cleanPhone,
      role: role,
      trade: trade,
      pin: pin,
    );

    if (cloudRes.error != null) {
      return cloudRes.error;
    }

    AppUser newUser;
    String newToken;
    if (cloudRes.data != null && cloudRes.data!['user'] != null) {
      final uMap = Map<String, dynamic>.from(cloudRes.data!['user'] as Map);
      uMap['trade'] = trade;
      newUser = AppUser.fromMap(uMap);
      newToken = (cloudRes.data!['token'] ?? 'local_${newUser.id}').toString();
    } else {
      // Offline-first fallback when Cloud Run is unreachable
      final prefs = await SharedPreferences.getInstance();
      final accountsRaw = prefs.getString(_localAccountsKey);
      final accounts = accountsRaw != null
          ? Map<String, dynamic>.from(jsonDecode(accountsRaw) as Map)
          : <String, dynamic>{};

      if (accounts.containsKey(cleanEmail)) {
        return 'An account with this email already exists. Please sign in.';
      }

      final uid = 'usr_${cleanEmail.hashCode.abs()}';
      newUser = AppUser(
        id: uid,
        name: cleanName,
        email: cleanEmail,
        phone: cleanPhone,
        role: role,
        isGuest: false,
        trade: trade,
      );
      newToken = 'local_$uid';
      accounts[cleanEmail] = {
        'user': newUser.toMap(),
        'passwordHash': _hashLocalPassword(cleanEmail, password),
      };
      await prefs.setString(_localAccountsKey, jsonEncode(accounts));
    }

    _currentUser = newUser;
    _sessionToken = newToken;
    await _persistSession();
    await VaultStorage.instance.upgradeOrLoadUser(
      newUser,
      token: newToken,
      guestSnapshot: guestSnapshot,
    );
    notifyListeners();
    return null;
  }

  Future<String?> signInWithEmail({
    required String email,
    required String password,
    required UserRole selectedRole,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@') || password.isEmpty) {
      return 'Please enter a valid email and password.';
    }

    final guestSnapshot = _currentUser.isGuest ? VaultStorage.instance.exportSnapshotMap() : null;

    // 1. Try Cloud Run backend first
    final cloudRes = await GcpBackendService.instance.login(
      email: cleanEmail,
      password: password,
    );

    if (cloudRes.error != null) {
      return cloudRes.error;
    }

    if (cloudRes.data != null && cloudRes.data!['user'] != null) {
      final newUser = AppUser.fromMap(Map<String, dynamic>.from(cloudRes.data!['user'] as Map));
      final newToken = (cloudRes.data!['token'] ?? 'local_${newUser.id}').toString();
      _currentUser = newUser;
      _sessionToken = newToken;
      await _persistSession();
      await VaultStorage.instance.upgradeOrLoadUser(
        newUser,
        token: newToken,
        guestSnapshot: guestSnapshot,
      );
      notifyListeners();
      return null;
    }

    // 2. Offline fallback local accounts
    final prefs = await SharedPreferences.getInstance();
    final accountsRaw = prefs.getString(_localAccountsKey);
    final accounts = accountsRaw != null
        ? Map<String, dynamic>.from(jsonDecode(accountsRaw) as Map)
        : <String, dynamic>{};

    if (accounts.containsKey(cleanEmail)) {
      final entry = Map<String, dynamic>.from(accounts[cleanEmail] as Map);
      final expectedHash = entry['passwordHash']?.toString() ?? '';
      if (expectedHash != _hashLocalPassword(cleanEmail, password)) {
        return 'Incorrect email or password.';
      }
      final newUser = AppUser.fromMap(Map<String, dynamic>.from(entry['user'] as Map));
      final newToken = 'local_${newUser.id}';
      _currentUser = newUser;
      _sessionToken = newToken;
      await _persistSession();
      await VaultStorage.instance.upgradeOrLoadUser(
        newUser,
        token: newToken,
        guestSnapshot: guestSnapshot,
      );
      notifyListeners();
      return null;
    }

    return 'Account not found. Please create an account first.';
  }

  Future<String?> signInWithGoogle({required UserRole role}) async {
    final guestSnapshot = _currentUser.isGuest ? VaultStorage.instance.exportSnapshotMap() : null;

    // 1. Attempt live Cloud Run external-browser Google Sign-In handoff
    final init = await GcpBackendService.instance.initMobileGoogleAuth(role);
    if (init != null && init['sessionId'] != null && init['authUrl'] != null) {
      final sessionId = init['sessionId'].toString();
      final authUri = Uri.parse('${GcpBackendService.baseUrl}${init['authUrl']}');
      bool launched = false;
      try {
        launched = await launchUrl(authUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
      if (launched) {
        for (int i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          final poll = await GcpBackendService.instance.pollMobileGoogleAuth(sessionId);
          if (poll == null) break;
          if (poll['status'] == 'complete' && poll['user'] != null && poll['token'] != null) {
            final newUser = AppUser.fromMap(Map<String, dynamic>.from(poll['user'] as Map));
            final newToken = poll['token'].toString();
            _currentUser = newUser;
            _sessionToken = newToken;
            await _persistSession();
            await VaultStorage.instance.upgradeOrLoadUser(
              newUser,
              token: newToken,
              guestSnapshot: guestSnapshot,
            );
            notifyListeners();
            return null;
          }
          if (poll['status'] == 'expired') {
            return 'Google Sign-In session expired. Please try again.';
          }
        }
        return 'Google Sign-In timed out. Complete sign-in in your browser or use Email/Password.';
      }
    }

    // 2. Offline / test fallback when Cloud Run or external browser is unavailable
    final isPro = role == UserRole.professional;
    final email = isPro ? 'ramesh.pro@gmail.com' : 'priya.customer@gmail.com';
    final name = isPro ? 'Ramesh Kumar' : 'Priya Menon';
    final uid = isPro ? 'w1' : 'usr_google_customer';

    final newUser = AppUser(
      id: uid,
      name: name,
      email: email,
      phone: isPro ? '+91 99001 44556' : '+91 98450 11223',
      role: role,
      isGuest: false,
      trade: 'electrician',
    );
    _currentUser = newUser;
    _sessionToken = 'local_$uid';
    await _persistSession();
    await VaultStorage.instance.upgradeOrLoadUser(
      newUser,
      token: _sessionToken,
      guestSnapshot: guestSnapshot,
    );
    notifyListeners();
    return null;
  }

  Future<void> signOut() async {
    _currentUser = AppUser.visitor();
    _sessionToken = 'local_visitor';
    await _persistSession();
    await VaultStorage.instance.clearOnSignOut();
    notifyListeners();
  }
}
