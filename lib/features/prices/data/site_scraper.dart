import 'dart:async';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../domain/book_info.dart';
import '../domain/site_price.dart';
import 'price_extractor.dart';
import 'site_config.dart';
import 'webview_fetcher.dart';

const String defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

/// Tek bir siteye ISBN ile gidip fiyatı çıkarır. Hiçbir zaman exception
/// fırlatmaz; her durumda bir [SitePrice] döner.
///
/// fetchMode http   -> Dio ile düz istek
/// fetchMode webview-> görünmez WebView (JavaScript çalışmış HTML)
/// Her iki durumda da fiyat aynı seçici sistemiyle ([extractPrice]) çıkarılır.
class SiteScraper {
  SiteScraper(this._dio, {WebViewFetcher? webView}) : _webView = webView;

  final Dio _dio;
  final WebViewFetcher? _webView;

  Future<SitePrice> fetch(SiteConfig site, String isbn, {BookInfo? info}) async {
    // Adreste {title} vb. geçen siteler (örn. Kitapyurdu) ISBN ile aranamaz;
    // kitap adı yoksa boşuna istek atma.
    if (site.needsBookInfo && (info == null || info.title.trim().isEmpty)) {
      return _notFound(site, 'Bu site kitap adıyla aranır (ISBN ile aranamaz)');
    }

    try {
      final String html;
      final Uri base;

      if (site.fetchMode == FetchMode.webview) {
        final web = _webView;
        if (web == null) {
          return SitePrice(
            siteId: site.id,
            siteName: site.name,
            status: PriceStatus.unsupported,
            message: 'WebView desteği bağlı değil',
          );
        }
        final page = await web.fetch(
          site.searchUri(isbn, info: info),
          userAgent: site.userAgent ?? defaultUserAgent,
          waitSelector: site.effectiveWaitSelector,
          timeout: Duration(seconds: site.webViewTimeoutSeconds),
        );
        if (page == null) return _notFound(site, 'Boş yanıt (WebView)');
        html = page.html;
        base = page.url;
      } else {
        final res = await _dio.getUri<String>(
          site.searchUri(isbn, info: info),
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: true,
            sendTimeout: Duration(seconds: site.timeoutSeconds),
            receiveTimeout: Duration(seconds: site.timeoutSeconds),
            headers: {
              'User-Agent': site.userAgent ?? defaultUserAgent,
              'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.5',
            },
          ),
        );
        final body = res.data;
        if (body == null || body.isEmpty) return _notFound(site, 'Boş yanıt');
        html = body;
        base = res.realUri;
      }

      final doc = html_parser.parse(html);
      final hit = extractPrice(doc, site, base, isbn: isbn, title: info?.title);
      if (hit == null) return _notFound(site, null);

      return SitePrice(
        siteId: site.id,
        siteName: site.name,
        status: PriceStatus.found,
        price: hit.price,
        url: hit.url,
        fromFallback: hit.fromFallback,
      );
    } on TimeoutException {
      return _error(site, 'Zaman aşımı');
    } on DioException catch (e) {
      return _error(site, _describe(e));
    } catch (e) {
      return _error(site, 'Beklenmeyen hata: $e');
    }
  }

  SitePrice _notFound(SiteConfig s, String? msg) => SitePrice(
        siteId: s.id,
        siteName: s.name,
        status: PriceStatus.notFound,
        message: msg,
      );

  SitePrice _error(SiteConfig s, String msg) => SitePrice(
        siteId: s.id,
        siteName: s.name,
        status: PriceStatus.error,
        message: msg,
      );

  String _describe(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Zaman aşımı';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 403 || code == 429) return 'Site isteği engelledi ($code)';
        return 'Sunucu hatası ($code)';
      case DioExceptionType.connectionError:
        return 'Bağlantı kurulamadı';
      case DioExceptionType.badCertificate:
        return 'Geçersiz sertifika';
      default:
        final detail = '${e.error ?? e.message ?? e.type.name}';
        return 'İstek başarısız: ${detail.length > 100 ? detail.substring(0, 100) : detail}';
    }
  }
}
