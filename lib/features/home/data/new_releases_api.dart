import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import '../../config/remote_config.dart' show remoteConfigProvider;
import '../../prices/data/site_scraper.dart' show defaultUserAgent;
import '../../prices/providers.dart' show dioProvider;
import '../../search/data/book_search_service.dart' show parseResults;
import '../../search/data/search_site.dart';
import '../domain/home_models.dart';

/// Bölümde en çok kaç kitap gösterilsin.
const int _maxItems = 30;

class NewReleasesApi {
  NewReleasesApi(this._dio, {required this.url, required this.site});
  final Dio _dio;

  /// "Yeni çıkanlar" sayfası (uzaktan ayardan ya da gömülü).
  final String url;

  /// Sayfadaki kitapları okuyan etiketler (arama sitelerinden biri).
  final SearchSite site;

  Future<List<HomeBook>> fetch() async {
    final res = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent': defaultUserAgent,
          'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.5',
        },
      ),
    );

    final results =
        parseResults(html_parser.parse(res.data ?? ''), site, res.realUri);

    return results
        .take(_maxItems)
        .map((r) => HomeBook(
              title: r.title,
              author: r.author,
              publisher: r.publisher,
              imageUrl: r.imageUrl,
              isbn: '', // listede yok; dokununca ürün sayfasından bulunur
              pageUrl: r.pageUrl,
            ))
        .toList();
  }
}

final newReleasesProvider = FutureProvider<List<HomeBook>>((ref) {
  final cfg = ref.watch(remoteConfigProvider);
  // Etiketler, ayarda belirtilen arama sitesinden alınır (varsayılan:
  // 'istanbulkitapcisi'). Böyle bir site yoksa bölüm "Yüklenemedi" gösterir.
  final site = cfg.searchSites.firstWhere((s) => s.id == cfg.newReleasesSiteId);
  return NewReleasesApi(
    ref.watch(dioProvider),
    url: cfg.newReleasesUrl,
    site: site,
  ).fetch();
});
