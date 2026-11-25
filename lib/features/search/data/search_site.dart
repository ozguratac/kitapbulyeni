enum QueryStyle {
  /// Türkçe harfler ASCII'ye çevrilir, boşluk "+" olur (Kitapyurdu, Kitapseç).
  asciiPlus,

  /// Boşluklar "-" olur (İstanbul Kitapçısı).
  dash,

  /// Harfler olduğu gibi kalır (Türkçe dahil), UTF-8 yüzde kodlanır,
  /// boşluk "%20" olur.
  percent,
  plus,
}

/// Bir sitede ad/yazar/yayınevi ile arama nasıl yapılır ve sonuç sayfası nasıl
/// okunur. Eski uygulamadaki gibi her alan (başlık, resim, yazar...) sayfanın
/// tamamında ayrı bir CSS seçiciyle toplanır ve SIRA numarasına göre eşleştirilir.
class SearchSite {
  const SearchSite({
    required this.id,
    required this.name,
    required this.urlTemplate,
    required this.titleSelector,
    this.imageSelector,
    this.authorSelector,
    this.publisherSelector,
    this.priceSelector,
    this.linkSelector,
    this.imageAttr = 'src',
    this.imageFrom,
    this.imageTo,
    this.priceSuffix = '',
    this.removeSelectors = const [],
    this.queryStyle = QueryStyle.asciiPlus,
    this.stripAuthorPublisherFromTitle = false,
    this.enabled = true,
  });

  final String id;
  final String name;

  /// {q} yer tutucusu aranan metinle değişir.
  final String urlTemplate;

  final String titleSelector;
  final String? imageSelector;
  final String? authorSelector;
  final String? publisherSelector;
  final String? priceSelector;
  final String? linkSelector;

  /// Resim adresinin okunacağı öznitelik (bulunamazsa data-src, src denenir).
  final String imageAttr;

  /// Resim adresinde bir metni değiştir (Kitapyurdu: wi:100 -> wi:200).
  final String? imageFrom;
  final String? imageTo;

  /// Fiyat metnine eklenecek ek (Kitapyurdu: " TL").
  final String priceSuffix;

  /// Okumadan önce sayfadan silinecek öğeler (örn. eski/üstü çizili fiyat).
  final List<String> removeSelectors;

  final QueryStyle queryStyle;

  /// Başlık, yazar ve yayınevini de içeriyorsa onları başlıktan çıkar (Kitapseç).
  final bool stripAuthorPublisherFromTitle;

  final bool enabled;

  Uri searchUri(String query) =>
      Uri.parse(urlTemplate.replaceAll('{q}', _encode(query)));

  String _encode(String q) {
    final t = q.trim();
    switch (queryStyle) {
      case QueryStyle.asciiPlus:
        return Uri.encodeQueryComponent(_foldTurkish(t)); // boşluk -> "+"
      case QueryStyle.dash:
        return Uri.encodeComponent(t.replaceAll(RegExp(r'\s+'), '-'));
      case QueryStyle.percent:
        return Uri.encodeComponent(t.replaceAll(RegExp(r'\s+'), ' '));
      case QueryStyle.plus:
        return Uri.encodeQueryComponent(t.replaceAll(RegExp(r'\s+'), ' '));
    }
  }

  /// Sunucudaki ayar dosyasından okuma. Zorunlu: id, name, urlTemplate,
  /// titleSelector. Eksik/yanlış alan istisna fırlatır (çağıran atlar).
  factory SearchSite.fromJson(Map<String, dynamic> j) {
    return SearchSite(
      id: j['id'] as String,
      name: j['name'] as String,
      urlTemplate: j['urlTemplate'] as String,
      titleSelector: j['titleSelector'] as String,
      imageSelector: j['imageSelector'] as String?,
      authorSelector: j['authorSelector'] as String?,
      publisherSelector: j['publisherSelector'] as String?,
      priceSelector: j['priceSelector'] as String?,
      linkSelector: j['linkSelector'] as String?,
      imageAttr: (j['imageAttr'] as String?) ?? 'src',
      imageFrom: j['imageFrom'] as String?,
      imageTo: j['imageTo'] as String?,
      priceSuffix: (j['priceSuffix'] as String?) ?? '',
      removeSelectors: [
        for (final x in (j['removeSelectors'] as List? ?? const [])) x.toString(),
      ],
      queryStyle:
          QueryStyle.values.byName((j['queryStyle'] as String?) ?? 'asciiPlus'),
      stripAuthorPublisherFromTitle:
          (j['stripAuthorPublisherFromTitle'] as bool?) ?? false,
      enabled: (j['enabled'] as bool?) ?? true,
    );
  }

  /// Dışa aktarma için (varsayılan olan alanlar yazılmaz; fromJson ile uyumlu).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'urlTemplate': urlTemplate,
        'titleSelector': titleSelector,
        if (imageSelector != null) 'imageSelector': imageSelector,
        if (authorSelector != null) 'authorSelector': authorSelector,
        if (publisherSelector != null) 'publisherSelector': publisherSelector,
        if (priceSelector != null) 'priceSelector': priceSelector,
        if (linkSelector != null) 'linkSelector': linkSelector,
        if (imageAttr != 'src') 'imageAttr': imageAttr,
        if (imageFrom != null) 'imageFrom': imageFrom,
        if (imageTo != null) 'imageTo': imageTo,
        if (priceSuffix.isNotEmpty) 'priceSuffix': priceSuffix,
        if (removeSelectors.isNotEmpty) 'removeSelectors': removeSelectors,
        if (queryStyle != QueryStyle.asciiPlus) 'queryStyle': queryStyle.name,
        if (stripAuthorPublisherFromTitle) 'stripAuthorPublisherFromTitle': true,
        if (!enabled) 'enabled': false,
      };
}

const Map<String, String> _fold = {
  'ü': 'u', 'Ü': 'U', 'ö': 'o', 'Ö': 'O', 'ı': 'i', 'İ': 'I',
  'ğ': 'g', 'Ğ': 'G', 'ş': 's', 'Ş': 'S', 'ç': 'c', 'Ç': 'C',
};

String _foldTurkish(String s) => s.split('').map((c) => _fold[c] ?? c).join();
