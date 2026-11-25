import '../../../core/query_encoding.dart';
import '../domain/book_info.dart';

enum FetchMode {
  /// Düz HTTP isteği + HTML ayrıştırma (hızlı, çoğu site).
  http,

  /// Gizli WebView ile yükleme (bot korumalı / JS ile çizilen siteler). Aşama 3b.
  webview,
}

/// Fiyat çıkarırken metinde birden çok fiyat varsa hangisi seçilsin.
enum PricePick { first, min }

/// Bir sitenin nasıl sorgulanacağını tarif eden VERİ.
///
/// Kod değil veri olduğu için ileride sunucudan JSON olarak güncellenebilir
/// (site tasarımı değişince uygulama güncellemesi gerekmez). Bu bir vekil
/// değildir: sorguyu yine cihaz atar, sunucu yalnızca seçici listesini verir.
class SiteConfig {
  const SiteConfig({
    required this.id,
    required this.name,
    required this.searchUrl,
    this.itemSelector,
    this.matchIsbnCore = false,
    this.matchTitleSelector,
    this.priceSelector,
    this.linkSelector,
    this.priceAttr,
    this.pick = PricePick.first,
    this.structuredFallback = true,
    this.fetchMode = FetchMode.http,
    this.userAgent,
    this.timeoutSeconds = 8,
    this.waitSelector,
    this.webViewTimeoutSeconds = 20,
    this.enabled = true,
    this.note,
  });

  final String id;
  final String name;

  /// Yer tutucular: {isbn}, {query} (yazar + kitap adı), {title}, {author}, {publisher}.
  /// {title} / {author} / {publisher} kullanılırsa kitap bilgisi gerekir
  /// (Türkçe harfler ASCII'ye çevrilir, boşluk "+" olur).
  final String searchUrl;

  /// Sonuç sayfasındaki her ÜRÜN KUTUSUNU seçer (örn. Kitapyurdu:
  /// 'div.product-grid div.product-cr'). Verilirse fiyat ve link sayfanın
  /// geneline değil, uygun ürün kutusunun İÇİNE bakılarak okunur.
  final String? itemSelector;

  /// true ise ürün kutusunun HTML'inde ISBN'in 4.-12. haneleri (9 hane)
  /// geçmelidir. ISBN ile aranamayan sitelerde doğru kitabı bulmak içindir.
  final bool matchIsbnCore;

  /// Ürün kutusunun İÇİNDEKİ kitap adının seçicisi (örn. 'div.name'). Verilirse
  /// doğru kitap, kutudaki ad ile aranan kitabın adı karşılaştırılarak seçilir
  /// (büyük/küçük harf, Türkçe karakter ve noktalama önemsiz). Önce birebir
  /// eşleşen kutular, yoksa adı içeren/içerilen kutular kabul edilir.
  /// Site ISBN'i kutuya gömmüyorsa [matchIsbnCore] yerine bu kullanılır.
  final String? matchTitleSelector;

  /// Fiyatın bulunduğu öğe (CSS). Virgül "ya da" demektir (sayfa sırasına göre).
  /// "||" ile ayrılırsa ÖNCELİK SIRASIYLA denenir: "a || b" = önce a, yoksa b.
  final String? priceSelector;

  /// Ürün sayfasına giden <a> öğesi (CSS).
  final String? linkSelector;

  /// Fiyat metin yerine bir özniteliktedir (ör. meta content). Boşsa:
  /// <meta> için "content", diğerleri için öğenin metni kullanılır.
  final String? priceAttr;

  final PricePick pick;

  /// CSS bulamazsa JSON-LD / meta etiketlerinden fiyat aransın mı.
  final bool structuredFallback;

  final FetchMode fetchMode;
  final String? userAgent;
  final int timeoutSeconds;

  /// Yalnızca WebView modu: bu öğe sayfada belirene kadar beklenir (fiyat JS ile
  /// geç çiziliyorsa). Boşsa [priceSelector] beklenir; o da yoksa sabit süre.
  final String? waitSelector;

  /// Yalnızca WebView modu: en fazla kaç saniye beklensin.
  final int webViewTimeoutSeconds;

  final bool enabled;
  final String? note;

  /// WebView'ın bekleyeceği seçici ("||" ile ayrılmışsa virgüle çevrilir).
  String? get effectiveWaitSelector {
    final w = waitSelector ?? itemSelector ?? priceSelector;
    if (w == null || w.trim().isEmpty) return null;
    return w.replaceAll('||', ',');
  }

  /// Adreste {title}/{author}/{publisher} geçiyorsa kitap bilgisi gerekir.
  bool get needsBookInfo =>
      searchUrl.contains('{query}') ||
      searchUrl.contains('{title}') ||
      searchUrl.contains('{author}') ||
      searchUrl.contains('{publisher}');

  Uri searchUri(String isbn, {BookInfo? info}) {
    // {query} = "yazar kitap-adı" (yazar önce, boşlukla). Yazar yoksa sadece ad.
    final query = [info?.author ?? '', info?.title ?? '']
        .where((t) => t.trim().isNotEmpty)
        .join(' ');
    final url = searchUrl
        .replaceAll('{isbn}', Uri.encodeQueryComponent(isbn))
        .replaceAll('{query}', encodeSearchText(query))
        .replaceAll('{title}', encodeSearchText(info?.title ?? ''))
        .replaceAll('{author}', encodeSearchText(info?.author ?? ''))
        .replaceAll('{publisher}', encodeSearchText(info?.publisher ?? ''));
    return Uri.parse(url);
  }

  /// Sunucudan gelecek uzak yapılandırma için hazırlık (Aşama 3).
  factory SiteConfig.fromJson(Map<String, dynamic> j) {
    return SiteConfig(
      id: j['id'] as String,
      name: j['name'] as String,
      searchUrl: j['searchUrl'] as String,
      itemSelector: j['itemSelector'] as String?,
      matchIsbnCore: (j['matchIsbnCore'] as bool?) ?? false,
      matchTitleSelector: j['matchTitleSelector'] as String?,
      priceSelector: j['priceSelector'] as String?,
      linkSelector: j['linkSelector'] as String?,
      priceAttr: j['priceAttr'] as String?,
      pick: PricePick.values.byName((j['pick'] as String?) ?? 'first'),
      structuredFallback: (j['structuredFallback'] as bool?) ?? true,
      fetchMode: FetchMode.values.byName((j['fetchMode'] as String?) ?? 'http'),
      userAgent: j['userAgent'] as String?,
      timeoutSeconds: (j['timeoutSeconds'] as int?) ?? 8,
      waitSelector: j['waitSelector'] as String?,
      webViewTimeoutSeconds: (j['webViewTimeoutSeconds'] as int?) ?? 20,
      enabled: (j['enabled'] as bool?) ?? true,
      note: j['note'] as String?,
    );
  }

  /// Dışa aktarma için (varsayılan olan alanlar yazılmaz; fromJson ile uyumlu).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'searchUrl': searchUrl,
        if (itemSelector != null) 'itemSelector': itemSelector,
        if (matchIsbnCore) 'matchIsbnCore': true,
        if (matchTitleSelector != null) 'matchTitleSelector': matchTitleSelector,
        if (priceSelector != null) 'priceSelector': priceSelector,
        if (linkSelector != null) 'linkSelector': linkSelector,
        if (priceAttr != null) 'priceAttr': priceAttr,
        if (pick != PricePick.first) 'pick': pick.name,
        if (!structuredFallback) 'structuredFallback': false,
        if (fetchMode != FetchMode.http) 'fetchMode': fetchMode.name,
        if (userAgent != null) 'userAgent': userAgent,
        if (timeoutSeconds != 8) 'timeoutSeconds': timeoutSeconds,
        if (waitSelector != null) 'waitSelector': waitSelector,
        if (webViewTimeoutSeconds != 20)
          'webViewTimeoutSeconds': webViewTimeoutSeconds,
        if (!enabled) 'enabled': false,
        if (note != null) 'note': note,
      };
}
