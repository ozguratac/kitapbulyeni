import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../prices/data/site_scraper.dart' show defaultUserAgent;
import '../../prices/data/webview_fetcher.dart';
import '../../search/data/book_search_service.dart' show parseResults, extractIsbn;
import '../../search/data/search_site.dart';
import '../../search/domain/book_result.dart';

/// Kitapyurdu yazar sayfasındaki kitap listesinin etiketleri.
/// Eski uygulamadaki yazarBilgiOku sınıfından; arama sonucu listesiyle aynı
/// satır yapısı, ama "div#product-table" öneki YOK.
const SearchSite authorPageSite = SearchSite(
  id: 'kitapyurdu-yazar',
  name: 'Kitapyurdu (yazar sayfası)',
  urlTemplate: '', // kullanılmaz; adres sunucudan gelir
  removeSelectors: ['div.price-old.price-passive'],
  titleSelector: 'div.ky-product-labels a.ky-product-title',
  imageSelector: 'a.ky-product-cover img',
  priceSelector: 'div.price span.value',
  priceSuffix: ' TL',
  authorSelector: 'div.ky-product-labels span.ky-product-author',
  publisherSelector: 'div.ky-product-labels span.ky-product-publisher',
  linkSelector: 'div.ky-product-labels a.ky-product-title',
);

/// Yazar sayfasındaki kitapları listeler ve seçilen kitabın ISBN'ini bulur.
///
/// Site düz HTTP isteğini engellediği için iki aşamalı çalışır:
///  1) Hızlı yol: düz HTTP. Sonuç çıkarsa bitti.
///  2) Engellendiyse / boş döndüyse: görünmez WebView ile gerçek tarayıcı gibi
///     yükle (JavaScript çalışır), oluşan HTML'i aynı etiketlerle oku.
class AuthorBooksService {
  AuthorBooksService(this._dio, this._web, {SearchSite? site})
      : _site = site ?? authorPageSite;

  /// Yazar sayfası etiketleri (varsayılan: gömülü; uzaktan ayarla değişebilir).
  final SearchSite _site;

  final Dio _dio;
  final WebViewFetcher _web;

  Future<List<BookResult>> fetchBooks(String pageUrl) async {
    final page = await _load(
      pageUrl,
      waitSelector: _site.titleSelector,
      usable: (html) => parseResults(
              html_parser.parse(html), _site, Uri.parse(pageUrl))
          .isNotEmpty,
    );
    if (page == null) return const [];
    return parseResults(html_parser.parse(page.html), _site, page.url);
  }

  /// Kitabın ürün sayfasından ISBN bulur (aynı iki aşamalı yöntem).
  Future<String?> findIsbn(String pageUrl) async {
    final page = await _load(pageUrl, usable: (html) => extractIsbn(html) != null);
    return page == null ? null : extractIsbn(page.html);
  }

  Future<WebPage?> _load(
    String pageUrl, {
    required bool Function(String html) usable,
    String? waitSelector,
  }) async {
    // 1) Hızlı yol: düz HTTP
    try {
      final res = await _dio.get<String>(
        pageUrl,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': defaultUserAgent,
            'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.5',
          },
        ),
      );
      final body = res.data ?? '';
      if (body.isNotEmpty && usable(body)) {
        return WebPage(html: body, url: res.realUri);
      }
    } catch (_) {
      // 403 / zaman aşımı / engel sayfası: WebView'a geç.
    }

    // 2) Görünmez WebView
    return _web.fetch(
      Uri.parse(pageUrl),
      userAgent: defaultUserAgent,
      waitSelector: waitSelector,
      timeout: const Duration(seconds: 25),
    );
  }
}
