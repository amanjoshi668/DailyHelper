import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const MethodChannel channel = MethodChannel('com.dailyhelper.app/native');

  Future<bool> configureReminders({
    required bool enabled,
    int amHour = 8,
    int amMinute = 30,
    int pmHour = 17,
    int pmMinute = 30,
  }) async {
    if (kIsWeb) return enabled;
    try {
      final res = await channel.invokeMethod<bool>('configureReminders', {
        'enabled': enabled,
        'amHour': amHour,
        'amMinute': amMinute,
        'pmHour': pmHour,
        'pmMinute': pmMinute,
      });
      return res ?? enabled;
    } on MissingPluginException {
      return enabled;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> saveExportDocument({
    required String filename,
    required String mimeType,
    required String content,
  }) async {
    if (kIsWeb) return true;
    try {
      final res = await channel.invokeMethod<bool>('saveExportDocument', {
        'filename': filename,
        'mimeType': mimeType,
        'content': content,
      });
      return res ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }
}
