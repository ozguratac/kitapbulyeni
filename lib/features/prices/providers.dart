import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import 'data/price_service.dart';
import 'data/site_config.dart';
import 'data/site_registry.dart';
import 'data/site_scraper.dart';
import 'data/webview_fetcher.dart';
import 'domain/book_info.dart';
import 'domain/site_price.dart';
import '../config/remote_config.dart' show remoteConfigProvider;

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    maxRedirects: 5,
  ));
});

/// Görünmez WebView'lar için tek, paylaşılan sınırlayıcı.
final webViewFetcherProvider = Provider<WebViewFetcher>((ref) {
  return WebViewFetcher(maxConcurrent: AppConfig.webViewConcurrency);
});

/// Şimdilik koddaki liste; ileride sunucudan gelen JSON ile değişecek.
final siteConfigsProvider = Provider<List<SiteConfig>>(
      (ref) => ref.watch(remoteConfigProvider).priceSites,
);

final priceServiceProvider = Provider<PriceService>((ref) {
  return PriceService(
    SiteScraper(
      ref.watch(dioProvider),
      webView: ref.watch(webViewFetcherProvider),
    ),
    ref.watch(siteConfigsProvider),
    concurrency: AppConfig.priceConcurrency,
  );
});

/// Fiyat sorgusu: ISBN + (varsa) kitap bilgisi. Kitapyurdu gibi ISBN ile
/// aranamayan siteler kitap adını buradan alır. Provider anahtarı olduğu için
/// == ve hashCode tanımlı (aynı kitap için akış yeniden başlamasın).
class PriceQuery {
  const PriceQuery(this.isbn, [this.info]);
  final String isbn;
  final BookInfo? info;

  @override
  bool operator ==(Object other) =>
      other is PriceQuery &&
      other.isbn == isbn &&
      other.info?.title == info?.title &&
      other.info?.author == info?.author &&
      other.info?.publisher == info?.publisher;

  @override
  int get hashCode =>
      Object.hash(isbn, info?.title, info?.author, info?.publisher);
}

/// Sonuçlar geldikçe ucuzdan pahalıya sıralı liste yayınlar.
final priceResultsProvider = StreamProvider.autoDispose
    .family<List<SitePrice>, PriceQuery>((ref, query) {
  final service = ref.watch(priceServiceProvider);
  final acc = <SitePrice>[];
  return service.lookup(query.isbn, info: query.info).map((r) {
    acc.add(r);
    return [...acc]..sort(comparePrices);
  });
});
