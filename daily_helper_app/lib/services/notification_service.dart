import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationStatusSnapshot {
  final bool permissionGranted;
  final bool systemEnabled;
  final bool remindersScheduled;

  const NotificationStatusSnapshot({
    required this.permissionGranted,
    required this.systemEnabled,
    required this.remindersScheduled,
  });

  bool get isAllowed => permissionGranted && systemEnabled;
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const MethodChannel channel = MethodChannel('com.dailyhelper.app/native');

  Future<bool> configureReminders({
    required bool enabled,
    bool isProfessional = false,
    int amHour = 8,
    int amMinute = 30,
    int pmHour = 17,
    int pmMinute = 30,
  }) async {
    if (kIsWeb) return enabled;
    try {
      final res = await channel.invokeMethod<dynamic>('configureReminders', {
        'enabled': enabled,
        'isProfessional': isProfessional,
        'amHour': amHour,
        'amMinute': amMinute,
        'pmHour': pmHour,
        'pmMinute': pmMinute,
      });
      if (res is bool) return res;
      return enabled;
    } on MissingPluginException {
      return enabled;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
    bool highPriority = true,
  }) async {
    if (kIsWeb) return true;
    try {
      final res = await channel.invokeMethod<dynamic>('showNotification', {
        'id': id,
        'title': title,
        'body': body,
        'highPriority': highPriority,
      });
      if (res is bool) return res;
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> scheduleAppointmentReminder({
    required String bookingId,
    required DateTime triggerAt,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return true;
    if (triggerAt.isBefore(DateTime.now())) return false;
    try {
      final res = await channel.invokeMethod<dynamic>('scheduleAppointmentReminder', {
        'bookingId': bookingId,
        'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
        'title': title,
        'body': body,
      });
      if (res is bool) return res;
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> cancelAppointmentReminder(String bookingId) async {
    if (kIsWeb || bookingId.isEmpty) return;
    try {
      await channel.invokeMethod<dynamic>('cancelAppointmentReminder', {
        'bookingId': bookingId,
      });
    } on MissingPluginException {
      // No-op on unsupported platforms
    } on PlatformException {
      // Ignore platform errors
    }
  }

  Future<NotificationStatusSnapshot> getNotificationStatus() async {
    if (kIsWeb) {
      return const NotificationStatusSnapshot(
        permissionGranted: true,
        systemEnabled: true,
        remindersScheduled: true,
      );
    }
    try {
      final res = await channel.invokeMethod<dynamic>('getNotificationStatus');
      if (res is Map) {
        return NotificationStatusSnapshot(
          permissionGranted: res['permissionGranted'] != false,
          systemEnabled: res['systemEnabled'] != false,
          remindersScheduled: res['remindersScheduled'] == true,
        );
      }
      return const NotificationStatusSnapshot(
        permissionGranted: true,
        systemEnabled: true,
        remindersScheduled: true,
      );
    } on MissingPluginException {
      return const NotificationStatusSnapshot(
        permissionGranted: true,
        systemEnabled: true,
        remindersScheduled: true,
      );
    } on PlatformException {
      return const NotificationStatusSnapshot(
        permissionGranted: false,
        systemEnabled: false,
        remindersScheduled: false,
      );
    }
  }

  Future<bool> openNotificationSettings() async {
    if (kIsWeb) return false;
    try {
      final res = await channel.invokeMethod<dynamic>('openNotificationSettings');
      return res == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Parses `bookingDate` (`yyyy-MM-dd`, `Today`, or `Tomorrow`) + `slotWindow`
  /// (e.g. `09:00 - 11:00 AM`, `02:00 - 04:00 PM`) and returns the exact
  /// 60-minute-before-start reminder timestamp.
  static DateTime? compute60MinReminderTime(
    String bookingDate,
    String slotWindow, {
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    DateTime baseDate;
    final cleanDate = bookingDate.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cleanDate)) {
      final parts = cleanDate.split('-').map(int.parse).toList();
      baseDate = DateTime(parts[0], parts[1], parts[2]);
    } else if (cleanDate.toLowerCase() == 'tomorrow') {
      final t = now.add(const Duration(days: 1));
      baseDate = DateTime(t.year, t.month, t.day);
    } else {
      baseDate = DateTime(now.year, now.month, now.day);
    }

    int startHour = 9;
    int startMin = 0;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(slotWindow.trim());
    if (match != null) {
      startHour = int.tryParse(match.group(1)!) ?? 9;
      startMin = int.tryParse(match.group(2)!) ?? 0;
      final upper = slotWindow.toUpperCase();
      // Distinguish slots like "11:00 - 01:00 PM" (starts 11 AM) vs "02:00 - 04:00 PM" (starts 2 PM)
      if (upper.contains('PM') && startHour < 8) {
        startHour += 12;
      } else if (upper.contains('AM') && startHour == 12) {
        startHour = 0;
      }
    }

    final slotStart = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      startHour,
      startMin,
    );
    if (!slotStart.isAfter(now)) return null;

    final sixtyMinsBefore = slotStart.subtract(const Duration(minutes: 60));
    if (sixtyMinsBefore.isAfter(now.add(const Duration(seconds: 15)))) {
      return sixtyMinsBefore;
    }
    // Slot starts in under 60 minutes — notify in 1 minute so user still gets alerted
    return now.add(const Duration(minutes: 1));
  }

  Future<bool> saveExportDocument({
    required String filename,
    required String mimeType,
    required String content,
  }) async {
    if (kIsWeb) return true;
    try {
      final res = await channel.invokeMethod<dynamic>('saveExportDocument', {
        'filename': filename,
        'mimeType': mimeType,
        'content': content,
      });
      if (res is bool) return res;
      return true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }
}
