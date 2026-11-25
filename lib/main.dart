import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/config/remote_config.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Önceki oturumda sunucudan indirilen ayar varsa hemen kullan (ağ beklemeden).
  final cached = await loadCachedRemoteConfig();

  final container = ProviderContainer(
    overrides: [initialRemoteConfigProvider.overrideWithValue(cached)],
  );
  // Sunucudaki ayar dosyasını arka planda yenilemeye başlar.
  container.read(remoteConfigProvider);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const KitapbulApp(),
  ));
}
