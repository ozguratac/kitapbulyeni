import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/app_config.dart';
import 'site_scraper.dart' show defaultUserAgent;
import 'webview_fetcher.dart';

// ======================= BEĞENİ (sunucu) =======================

class LikeState {
  const LikeState({required this.count, required this.liked});
  final int count;
  final bool liked;
}

/// kitapBegenmeOku / kitapBegenme / kitapBegenmeVazgec uçları. Yanıt biçimi
/// (eski uygulamadaki gibi): beğeni sayısı "###SAYI---", beğendi mi ise
/// "000BAYRAK---" (içinde 1 varsa beğenmiş).
class LikeApi {
  LikeApi(this._dio);
  final Dio _dio;

  String get _base => '${AppConfig.serverBase}/kitap';

  Future<LikeState> read(String isbn, String deviceId) async {
    final body = await _get('kitapBegenmeOku.php', isbn, deviceId);
    return LikeState(count: parseLikeCount(body), liked: parseLikedFlag(body));
  }

  Future<LikeState> like(String isbn, String deviceId) async {
    final body = await _get('kitapBegenme.php', isbn, deviceId);
    return LikeState(count: parseLikeCount(body), liked: true);
  }

  Future<LikeState> unlike(String isbn, String deviceId) async {
    final body = await _get('kitapBegenmeVazgec.php', isbn, deviceId);
    return LikeState(count: parseLikeCount(body), liked: false);
  }

  Future<String> _get(String file, String isbn, String deviceId) async {
    final res = await _dio.get<String>(
      '$_base/$file',
      queryParameters: {'isbn': isbn, 'cihazid': deviceId},
      options: Options(
        responseType: ResponseType.plain,
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    return res.data ?? '';
  }
}

int parseLikeCount(String body) {
  final matches = RegExp(r'###(.*?)---').allMatches(body);
  if (matches.isEmpty) return 0;
  return int.tryParse(matches.last.group(1)!.trim()) ?? 0;
}

bool parseLikedFlag(String body) {
  final matches = RegExp(r'000(.*?)---').allMatches(body);
  if (matches.isEmpty) return false;
  return matches.last.group(1)!.contains('1');
}

// ======================= ÖZET (ürün sayfası) =======================

class _DescRule {
  const _DescRule(this.host, this.selector, [this.remove = const []]);
  final String host;
  final String selector;
  final List<String> remove;
}

/// Siteye göre özetin bulunduğu öğe. Eski uygulamadaki AciklamaAl sınıfından.
/// Hepsiburada, Babil, BKM gibi bazı siteler orijinalde WebView ile okunuyordu;
/// düz HTTP ile boş dönerse özet "bulunamadı" görünür.
const List<_DescRule> _rules = [
  _DescRule('istanbulkitapcisi.com', 'div#product-fullbody'),
  _DescRule('dr.com', 'div.product-description-header.section-cover.mb-40.fs-3_5', ['h2']),
  _DescRule('hepsiburada.com', 'div#productDescriptionContent'),
  _DescRule('kitapyurdu.com', 'span.ky-pd-about__description-content'),
  _DescRule('babil.com', 'div#description'),
  _DescRule('pandora.com', 'div.row.urunAciklama'),
  _DescRule('bkmkitap.com', 'div#productDetailTab'),
  _DescRule('kitapsec.com', 'div.TabDivList div#tab1', ['h2', 'strong', 'div.magaza-bilgi']),
  _DescRule('kidega.com', 'div.col-md-8.col-xs-12 div#bookDescription'),
  _DescRule('ucuzkitapal.com', 'div#content_description'),
  _DescRule('amazon.com', 'div#bookDescription_feature_div', ['div#psPlaceHolder']),
  _DescRule('kitapkolik.com', 'div#divOnyazi'),
];

/// Uzaktan ayardan gelen özet kuralları. Aynı host için gömülü kuralın ÖNÜNE geçer.
List<_DescRule> _remoteRules = const [];

/// remote_config.dart çağırır. [rules]: {host, selector, remove?} listesi.
void applyDescriptionRules(List<Map<String, dynamic>> rules) {
  _remoteRules = [
    for (final r in rules)
      _DescRule(
        r['host'] as String,
        r['selector'] as String,
        [for (final x in (r['remove'] as List? ?? const [])) x.toString()],
      ),
  ];
}

/// Gömülü kuralları JSON'a çevirir (dışa aktarma için).
List<Map<String, dynamic>> descriptionRulesToJson() => [
  for (final r in _rules)
    {
      'host': r.host,
      'selector': r.selector,
      if (r.remove.isNotEmpty) 'remove': r.remove,
    },
];

_DescRule? _ruleFor(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  for (final r in [..._remoteRules, ..._rules]) {
    if (host.contains(r.host)) return r;
  }
  return null;
}

/// Ürün sayfasından kitap özetini okur.
///
/// Bazı siteler (örn. Kitapyurdu) düz HTTP isteğini engelliyor. Bu yüzden iki
/// aşamalı çalışır:
///  1) Hızlı yol: düz HTTP. Özet bulunursa bitti.
///  2) Engellendiyse / boş döndüyse: görünmez WebView ile gerçek tarayıcı gibi
///     yükle, özet öğesi belirene kadar bekle, aynı seçiciyle oku.
class DescriptionService {
  DescriptionService(this._dio, this._web);

  final Dio _dio;
  final WebViewFetcher _web;

  /// Bu adresin sitesi için özet seçicisi tanımlı mı?
  static bool supports(String url) => _ruleFor(url) != null;

  Future<String?> fetch(String url) async {
    final rule = _ruleFor(url);
    if (rule == null) return null;

    // 1) Hızlı yol: düz HTTP
    try {
      final res = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': defaultUserAgent,
            'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.5',
          },
        ),
      );
      final text = parseDescription(html_parser.parse(res.data ?? ''), url);
      if (text != null) return text;
    } catch (_) {
      // 403 / zaman aşımı / engel sayfası: WebView'a geç.
    }

    // 2) Görünmez WebView
    try {
      final page = await _web.fetch(
        Uri.parse(url),
        userAgent: defaultUserAgent,
        waitSelector: rule.selector,
        timeout: const Duration(seconds: 20),
      );
      if (page == null) return null;
      return parseDescription(html_parser.parse(page.html), url);
    } catch (_) {
      return null;
    }
  }
}

/// Saf fonksiyon (ağ yok) -> test edilebilir.
String? parseDescription(Document doc, String url) {
  final rule = _ruleFor(url);
  if (rule == null) return null;

  final matches = doc.querySelectorAll(rule.selector);
  for (final el in matches) {
    for (final sel in rule.remove) {
      for (final junk in el.querySelectorAll(sel)) {
        junk.remove();
      }
    }
  }

  var best = '';
  for (final el in matches) {
    final t = el.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > best.length) best = t;
  }
  return best.isEmpty ? null : best;
}
