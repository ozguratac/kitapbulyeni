import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/book_detail_service.dart';
import 'providers.dart' show dioProvider, webViewFetcherProvider;

final likeApiProvider = Provider<LikeApi>((ref) {
  return LikeApi(ref.watch(dioProvider));
});

final descriptionServiceProvider = Provider<DescriptionService>((ref) {
  return DescriptionService(
    ref.watch(dioProvider),
    ref.watch(webViewFetcherProvider),
  );
});

/// Ürün sayfası adresi -> özet metni (bulunamazsa null).
final descriptionProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, url) {
  return ref.watch(descriptionServiceProvider).fetch(url);
});
