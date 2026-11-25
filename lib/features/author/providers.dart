import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/remote_config.dart' show remoteConfigProvider;
import '../prices/providers.dart' show dioProvider, webViewFetcherProvider;
import '../search/domain/book_result.dart';
import 'data/author_books_service.dart';

final authorBooksServiceProvider = Provider<AuthorBooksService>((ref) {
  return AuthorBooksService(
    ref.watch(dioProvider),
    ref.watch(webViewFetcherProvider),
    site: ref.watch(remoteConfigProvider).authorPage,
  );
});

/// Yazar sayfası adresi -> o yazarın kitapları.
final authorBooksProvider = FutureProvider.autoDispose
    .family<List<BookResult>, String>((ref, url) {
  return ref.watch(authorBooksServiceProvider).fetchBooks(url);
});
