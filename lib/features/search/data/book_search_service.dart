import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/isbn.dart';
import '../../prices/data/site_scraper.dart' show defaultUserAgent;
import '../domain/book_result.dart';
import 'search_registry.dart';
import 'search_site.dart';

/// Ad / yazar / yayınevi ile kitap arar ve seçilen kitabın ISBN'ini bulur.
class BookSearchService {
  BookSearchService(this._dio, {List<SearchSite> sites = searchSites})
      : _sites = sites.where((s) => s.enabled).toList(growable: false);

  final Dio _dio;
  final List<SearchSite> _sites;

  /// Siteleri sırayla dener; ilk sonuç veren sitenin listesini döndürür.
  Future<SearchOutcome> search(String query) async {
    final errors = <String>[];
    for (final site in _sites) {
      try {
        final res = await _dio.getUri<String>(
          site.searchUri(query),
          options: _options(),
        );
        final doc = html_parser.parse(res.data ?? '');
        final results = parseResults(doc, site, res.realUri);
        if (results.isNotEmpty) {
          return SearchOutcome(
              results: results, siteName: site.name, errors: errors);
        }
      } catch (e) {
        errors.add('${site.name}: ${_short(e)}');
      }
    }
    return SearchOutcome(results: const [], errors: errors);
  }

  /// Kitabın ürün sayfasını açıp ISBN'ini bulur; bulunamazsa null.
  Future<String?> findIsbn(String pageUrl) async {
    final res = await _dio.get<String>(pageUrl, options: _options());
    return extractIsbn(res.data ?? '');
  }

  Options _options() => Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent': defaultUserAgent,
          'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.5',
        },
      );

  String _short(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      return code != null ? 'HTTP $code' : e.type.name;
    }
    final s = '$e';
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }
}

/// Saf fonksiyon (ağ yok) -> test edilebilir.
/// Eski uygulamadaki gibi her alan tüm sayfada ayrı toplanır, sıra numarasına
/// göre eşleştirilir; başlık sayısı satır sayısını belirler.
List<BookResult> parseResults(Document doc, SearchSite site, Uri base) {
  for (final sel in site.removeSelectors) {
    for (final el in doc.querySelectorAll(sel)) {
      el.remove();
    }
  }

  final titles = doc.querySelectorAll(site.titleSelector);
  final images = _all(doc, site.imageSelector);
  final authors = _all(doc, site.authorSelector);
  final publishers = _all(doc, site.publisherSelector);
  final prices = _all(doc, site.priceSelector);
  final links = _all(doc, site.linkSelector);

  final out = <BookResult>[];
  for (var i = 0; i < titles.length; i++) {
    final rawTitle = _clean(titles[i].text);
    if (rawTitle.isEmpty) continue;

    final author = i < authors.length ? _clean(authors[i].text) : '';
    final publisher =
        i < publishers.length ? _clean(publishers[i].text.replaceAll(',', '')) : '';

    var title = rawTitle;
    if (site.stripAuthorPublisherFromTitle) {
      if (author.isNotEmpty) title = title.replaceAll(author, '');
      if (publisher.isNotEmpty) title = title.replaceAll(publisher, '');
      title = _clean(title);
      if (title.isEmpty) title = rawTitle;
    }

    final rawPrice = i < prices.length ? _clean(prices[i].text) : '';

    out.add(BookResult(
      title: title,
      author: author,
      publisher: publisher,
      imageUrl: i < images.length ? _imageUrl(images[i], site, base) : '',
      priceText: rawPrice.isEmpty ? '' : '$rawPrice${site.priceSuffix}',
      pageUrl: i < links.length ? _link(links[i], base) : '',
    ));
  }
  return out;
}

List<Element> _all(Document doc, String? selector) =>
    selector == null ? <Element>[] : doc.querySelectorAll(selector);

String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String _link(Element el, Uri base) {
  final href = el.attributes['href']?.trim();
  if (href == null || href.isEmpty || href.toLowerCase().startsWith('javascript:')) {
    return '';
  }
  return base.resolve(href).toString();
}

String _imageUrl(Element el, SearchSite site, Uri base) {
  final attrs = <String>{site.imageAttr, 'data-src', 'data-original', 'src'};
  for (final a in attrs) {
    final v = el.attributes[a]?.trim();
    if (v == null || v.isEmpty || v.startsWith('data:')) continue;
    var url = v.startsWith('//') ? 'https:$v' : base.resolve(v).toString();
    if (site.imageFrom != null && site.imageTo != null) {
      url = url.replaceAll(site.imageFrom!, site.imageTo!);
    }
    return url;
  }
  return '';
}

final RegExp _isbnNearLabel = RegExp(
  r'isbn[\s\S]{0,80}?(97[89](?:[-\s]?\d){10})',
  caseSensitive: false,
);
final RegExp _isbnAnywhere = RegExp(r'97[89](?:[-\s]?\d){10}');

/// Ürün sayfası HTML'inden ISBN-13 bulur.
/// 1) "ISBN" yazısının yakınındaki, 2) sayfadaki ilk geçerli 978/979 numarası,
/// 3) hiçbiri kontrol hanesini tutturamazsa ilk 13 haneli 978/979 numarası.
String? extractIsbn(String html) {
  for (final m in _isbnNearLabel.allMatches(html)) {
    final v = normalizeIsbn(m.group(1)!);
    if (v != null) return v;
  }
  String? lenient;
  for (final m in _isbnAnywhere.allMatches(html)) {
    final raw = m.group(0)!;
    final v = normalizeIsbn(raw);
    if (v != null) return v;
    lenient ??= raw.replaceAll(RegExp(r'[^0-9]'), '');
  }
  return lenient;
}
