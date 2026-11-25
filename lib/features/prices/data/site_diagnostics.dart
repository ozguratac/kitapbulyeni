import 'dart:async';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'site_config.dart';
import 'site_scraper.dart' show defaultUserAgent;
import 'webview_fetcher.dart';

/// Bir sitenin ham sorgu sonucunun teşhis raporu (seçici ayıklamak için).
class SiteDiagnostic {
  SiteDiagnostic({required this.site, required this.requestedUrl});

  final SiteConfig site;
  final Uri requestedUrl;
  int? statusCode;
  Uri? finalUrl;
  String? contentType;
  int? bodyLength;
  String? title;
  bool? containsIsbn;
  bool? mentionsLira;
  int cssMatches = 0;
  String? cssFirstText;
  bool hasJsonLdPrice = false;
  bool hasMetaPrice = false;
  final List<String> candidates = [];
  String? error;

  bool get isWebView => site.fetchMode == FetchMode.webview;

  String get summary {
    if (error != null) return 'HATA';
    final mode = isWebView ? 'WebView' : 'HTTP $statusCode';
    return '$mode • CSS $cssMatches • ${candidates.length} aday';
  }

  String toReport() {
    final b = StringBuffer();
    final mode = isWebView ? ' [WebView]' : '';
    b.writeln('== ${site.name} (${site.id})$mode ==');
    b.writeln('URL: $requestedUrl');
    if (error != null) {
      b.writeln('HATA: $error');
      return b.toString();
    }
    final first = cssFirstText == null ? '' : ' (ilk: "$cssFirstText")';
    final status = isWebView ? 'WebView' : '$statusCode';
    b.writeln('Durum: $status | Son adres: $finalUrl');
    b.writeln('Tür: $contentType | Boyut: $bodyLength');
    b.writeln('Başlık: $title');
    b.writeln(
        'ISBN sayfada: ${_yn(containsIsbn)} | TL/₺ geçiyor: ${_yn(mentionsLira)}');
    b.writeln('CSS eşleşme: $cssMatches$first');
    b.writeln(
        'JSON-LD fiyat: ${hasJsonLdPrice ? "var" : "yok"} | Meta fiyat: ${hasMetaPrice ? "var" : "yok"}');
    if (candidates.isNotEmpty) {
      b.writeln('Aday fiyat öğeleri:');
      for (final c in candidates) {
        b.writeln('  - $c');
      }
    }
    return b.toString();
  }

  static String _yn(bool? v) => v == null ? '?' : (v ? 'evet' : 'hayır');
}

class SiteDiagnoser {
  SiteDiagnoser(this._dio, {WebViewFetcher? webView}) : _webView = webView;

  final Dio _dio;
  final WebViewFetcher? _webView;

  static final RegExp _priceRe = RegExp(
    r'(\d[\d.,]*\s*(TL|₺))|((TL|₺)\s*\d[\d.,]*)',
    caseSensitive: false,
  );

  Future<SiteDiagnostic> run(SiteConfig site, String isbn) async {
    final uri = site.searchUri(isbn);
    final d = SiteDiagnostic(site: site, requestedUrl: uri);
    try {
      final String body;

      if (site.fetchMode == FetchMode.webview) {
        final web = _webView;
        if (web == null) {
          d.error = 'WebView desteği bağlı değil';
          return d;
        }
        final page = await web.fetch(
          uri,
          userAgent: site.userAgent ?? defaultUserAgent,
          waitSelector: site.effectiveWaitSelector,
          timeout: Duration(seconds: site.webViewTimeoutSeconds),
        );
        if (page == null) {
          d.error = 'WebView sayfa döndürmedi';
          return d;
        }
        d.finalUrl = page.url;
        d.contentType = 'WebView (JS çalışmış HTML)';
        body = page.html;
      } else {
        final res = await _dio.getUri<String>(
          uri,
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: true,
            // 403/404 gibi durumlarda da gövdeyi görmek için hata fırlatma.
            validateStatus: (_) => true,
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'User-Agent': site.userAgent ?? defaultUserAgent,
              'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.5',
            },
          ),
        );
        d.statusCode = res.statusCode;
        d.finalUrl = res.realUri;
        d.contentType = res.headers.value('content-type');
        body = res.data ?? '';
      }

      d.bodyLength = body.length;
      if (body.isEmpty) return d;
      _analyze(d, site, isbn, body);
    } on TimeoutException {
      d.error = 'Zaman aşımı';
    } on DioException catch (e) {
      d.error = '${e.type.name}: ${e.error ?? e.message}';
    } catch (e) {
      d.error = '$e';
    }
    return d;
  }

  void _analyze(SiteDiagnostic d, SiteConfig site, String isbn, String body) {
    final doc = html_parser.parse(body);
    d.title = _clean(doc.querySelector('title')?.text, 100);
    d.containsIsbn = body.contains(isbn);
    d.mentionsLira = body.contains('₺') || RegExp(r'\bTL\b').hasMatch(body);

    final sel = site.priceSelector;
    if (sel != null && sel.isNotEmpty) {
      // "||" öncelik ayracı kullanıldıysa teşhiste virgül gibi say.
      final els = doc.querySelectorAll(sel.replaceAll('||', ','));
      d.cssMatches = els.length;
      if (els.isNotEmpty) d.cssFirstText = _clean(els.first.text, 60);
    }

    d.hasJsonLdPrice = doc
        .querySelectorAll('script[type="application/ld+json"]')
        .any((s) => s.text.contains('"price"') || s.text.contains('"lowPrice"'));
    d.hasMetaPrice = doc.querySelector(
            'meta[itemprop="price"], meta[property="product:price:amount"], meta[property="og:price:amount"]') !=
        null;

    d.candidates.addAll(_priceCandidates(doc));
  }

  /// "89,90 TL" gibi görünen en derindeki öğeleri ve CSS yollarını bulur.
  List<String> _priceCandidates(Document doc) {
    final out = <String>[];
    final seen = <String>{};
    var scanned = 0;
    for (final el in doc.querySelectorAll('body *')) {
      if (out.length >= 8 || ++scanned > 4000) break;
      final tag = el.localName;
      if (tag == 'script' || tag == 'style' || tag == 'noscript') continue;
      if (el.children.length > 4) continue;

      final text = el.text.trim();
      if (text.isEmpty || text.length > 40 || !_priceRe.hasMatch(text)) continue;

      // Çocuğu da fiyat gibi görünüyorsa çocuğu raporla (daha derin = daha net).
      final childMatches = el.children.any((c) {
        final t = c.text.trim();
        return t.isNotEmpty && t.length <= 40 && _priceRe.hasMatch(t);
      });
      if (childMatches) continue;

      final path = _path(el);
      if (seen.add(path)) out.add('$path: "${_clean(text, 40)}"');
    }
    return out;
  }

  String _path(Element el) {
    final parts = <String>[];
    Element? cur = el;
    for (var i = 0; i < 3 && cur != null; i++) {
      parts.insert(0, _label(cur));
      cur = cur.parent;
    }
    return parts.join(' > ');
  }

  String _label(Element e) {
    final id = e.id.isNotEmpty ? '#${e.id}' : '';
    final cls = e.classes.isNotEmpty ? '.${e.classes.join('.')}' : '';
    return '${e.localName}$id$cls';
  }
}

String _clean(String? s, int max) {
  if (s == null) return '';
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= max ? t : '${t.substring(0, max)}…';
}
