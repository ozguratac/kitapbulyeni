import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefsKey = 'device_id';

/// Beğeni, kitaplık ve sepet sunucuda bu kimliğe bağlı tutulur.
///
/// Android: eski uygulamadaki ANDROID_ID (aynı imza anahtarıyla yayınlanan
/// güncellemede eski kullanıcıların verisi korunur). Diğer platformlarda ya da
/// okunamazsa: rastgele üretilip kalıcı saklanan bir kimlik.
Future<String> loadDeviceId() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final id = await const AndroidId().getId();
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {
      // Aşağıdaki yedek kimliğe düş.
    }
  }
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_prefsKey);
  if (saved != null && saved.isNotEmpty) return saved;

  final fresh = _randomId();
  await prefs.setString(_prefsKey, fresh);
  return fresh;
}

String _randomId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();
}

final deviceIdProvider = FutureProvider<String>((ref) => loadDeviceId());
