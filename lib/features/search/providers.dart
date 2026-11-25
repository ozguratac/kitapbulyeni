import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/remote_config.dart' show remoteConfigProvider;
import '../prices/providers.dart' show dioProvider;
import 'data/book_search_service.dart';
import 'domain/book_result.dart';

/// Arama siteleri uzaktan ayardan (yoksa gömülü listeden) gelir.
final bookSearchServiceProvider = Provider<BookSearchService>((ref) {
  return BookSearchService(
    ref.watch(dioProvider),
    sites: ref.watch(remoteConfigProvider).searchSites,
  );
});

/// Aranan metin -> sonuç listesi. Ekran kapanınca bellekten silinir.
final searchResultsProvider =
    FutureProvider.autoDispose.family<SearchOutcome, String>((ref, query) {
  return ref.watch(bookSearchServiceProvider).search(query);
});
