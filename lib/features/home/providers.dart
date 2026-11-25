import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prices/providers.dart' show dioProvider;
import 'data/home_api.dart';
import 'domain/home_models.dart';

final homeApiProvider = Provider<HomeApi>((ref) {
  return HomeApi(ref.watch(dioProvider));
});

/// Çok aranan / çok beğenilen / yazarlar (tek istek).
final homeFeedProvider = FutureProvider<HomeFeed>((ref) {
  return ref.watch(homeApiProvider).fetchFeed();
});

/// Okuma önerileri (ayrı istek; biri hata verse diğeri etkilenmez).
final recommendationsProvider = FutureProvider<List<HomeBook>>((ref) {
  return ref.watch(homeApiProvider).fetchRecommendations();
});
