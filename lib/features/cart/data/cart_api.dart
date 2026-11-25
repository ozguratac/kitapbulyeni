import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/app_config.dart';
import '../../../core/price_parser.dart';
import '../domain/cart_item.dart';
import 'dart:convert';

/// true: `ad` alanı "Ad***Yazar***Yayınevi" olarak gönderilir. Eski uygulamadaki
/// biçimin aynısı; mevcut sunucu `ad` alanını olduğu gibi sakladığı için yazar
/// ve yayınevi şimdiden saklanıp geri okunur.
///
/// Sunucu yazar/yayınevi/... alanlarını AYRI saklamaya başlayınca bunu false
/// yapın; `ad` yalnızca kitap adı olur. Ayrı alanlar zaten HER ZAMAN gönderiliyor.
const bool packDetailsIntoName = true;

/// Sepet uçları: http://www.bilisimkalesi.com/mobil/
///  - sepetEkle.php   (ekle)
///  - sepetSil.php    (tek kitabı sil)
///  - sepetOku.php    (sepeti oku)
class CartApi {
  CartApi(this._dio);
  final Dio _dio;

  String get _base => '${AppConfig.serverBase}/mobil';

  Future<List<CartItem>> read(String deviceId) async {
    final res = await _dio.get<List<int>>(
      '$_base/sepetOku.php',
      queryParameters: {'cihazID': deviceId},
      options: Options(
        responseType: ResponseType.bytes,
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    return parseCartResponse(decodeTurkishBytes(res.data ?? const <int>[]));
  }

  Future<void> add(String deviceId, CartItem item) async {
    await _dio.get<String>(
      '$_base/sepetEkle.php',
      queryParameters: buildAddParams(deviceId, item),
      options: _options(),
    );
  }

  Future<void> remove(String deviceId, String numara) async {
    await _dio.get<String>(
      '$_base/sepetSil.php',
      queryParameters: {'cihazID': deviceId, 'numara': numara},
      options: _options(),
    );
  }

  Options _options() => Options(
        responseType: ResponseType.plain,
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      );
}

/// sepetEkle.php'ye gönderilecek parametreler.
///
/// Mevcut sunucunun bildikleri: cihazID, numara, ad, site, fiyat, resim, isbn.
/// Aşağıdakiler şimdilik sunucuda karşılanmıyor (yok sayılır), ileride
/// saklanmak üzere gönderiliyor: yazar, yayinevi, siteId, fiyatLink, kitapLink.
Map<String, String> buildAddParams(String deviceId, CartItem item) {
  final name = packDetailsIntoName
      ? '${item.title}***${item.author}***${item.publisher}'
      : item.title;
  return {
    'cihazID': deviceId,
    'numara': item.numara,
    'ad': escapeXml(name), // eski uygulamadaki gibi XML için kaçışlı
    'site': item.store, // kitapçı adı
    'fiyat': _priceParam(item.price), // "89,90" (TL'siz, eskisi gibi)
    'resim': item.imageUrl, // kapak adresi
    'isbn': item.isbn,
    // --- yeni alanlar (düz metin) ---
    'yazar': item.author,
    'yayinevi': item.publisher,
    'siteId': item.siteId, // kitapçı ayar kimliği (fiyat güncelleme için)
    'fiyatLink': item.priceLink, // fiyatın alındığı sayfa
    'kitapLink': item.bookLink, // kitabın ürün sayfası
  };
}

/// sepetOku.php yanıtını ayrıştırır. Kayıt biçimi:
/// <liste ad= site= fiyat= resim= numara= isbn= [yazar= yayinevi= siteId=
/// fiyatLink= kitapLink=]>. HTML ayrıştırıcı öznitelik adlarını küçük harfe
/// çevirir; burada da küçük harfle okunur.
List<CartItem> parseCartResponse(String body) {
  final doc = html_parser.parse(body);
  final out = <CartItem>[];
  for (final el in doc.querySelectorAll('liste')) {
    final a = el.attributes;
    final numara = (a['numara'] ?? '').trim();
    if (numara.isEmpty) continue;

    // "Ad***Yazar***Yayınevi" biçimi (eski kayıtlar ve packDetailsIntoName).
    // 'ad' ayrıştırması
    final parts = fixTurkishMojibake(unescapeXml(a['ad'] ?? ''))
        .split('***')
        .map((s) => s.trim())
        .toList();
    final title = parts.first;

    var author = fixTurkishMojibake(unescapeXml(a['yazar'] ?? '')).trim();
    var publisher = fixTurkishMojibake(unescapeXml(a['yayinevi'] ?? '')).trim();
    if (author.isEmpty && parts.length > 1) author = parts[1];
    if (publisher.isEmpty && parts.length > 2) publisher = parts[2];

    final priceText = (a['fiyat'] ?? '').trim();
    out.add(CartItem(
      numara: numara,
      title: title.isEmpty ? '(adsız kitap)' : title,
      author: author,
      publisher: publisher,
      store: fixTurkishMojibake((a['site'] ?? '').trim()),
      siteId: (a['siteid'] ?? '').trim(),
      price: parsePrice(priceText) ?? 0,
      priceText: priceText,
      imageUrl: (a['resim'] ?? '').trim(),
      isbn: (a['isbn'] ?? '').trim(),
      priceLink: (a['fiyatlink'] ?? '').trim(),
      bookLink: (a['kitaplink'] ?? '').trim(),
    ));
  }
  return out;
}

String _priceParam(double p) => p.toStringAsFixed(2).replaceAll('.', ',');

/// Metni XML özniteliği için kaçışlar. ASCII olmayan her harf &#NNN; koduna
/// çevrilir: sunucu Türkçe harfleri bozuyorsa (Ü -> Ã?) bile salt ASCII
/// gönderildiği için hiçbir şey kaybolmaz. & önce işlenir (çift kaçış olmasın).
String escapeXml(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    if (r == 0x26) {
      sb.write('&amp;');
    } else if (r == 0x3C) {
      sb.write('&lt;');
    } else if (r == 0x3E) {
      sb.write('&gt;');
    } else if (r == 0x22) {
      sb.write('&quot;');
    } else if (r == 0x27) {
      sb.write('&apos;');
    } else if (r > 127) {
      sb.write('&#$r;');
    } else {
      sb.writeCharCode(r);
    }
  }
  return sb.toString();
}

/// Okurken savunmacı çözme: sunucu ikinci kez kaçışladıysa da düzgün çıkar.
String unescapeXml(String s) {
  final decoded = s.replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m[2]!, radix: m[1] == 'x' ? 16 : 10);
    if (code == null || code > 0x10FFFF) return m[0]!;
    return String.fromCharCode(code);
  });
  return decoded
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}


/// Yanıt baytlarını çözer: geçerli UTF-8 ise UTF-8, değilse ISO-8859-9 (Türkçe).
String decodeTurkishBytes(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.writeCharCode(_latin5[b] ?? b);
    }
    return sb.toString();
  }
}

/// ISO-8859-9'un Latin-1'den farklı olan 6 Türkçe harfi.
const Map<int, int> _latin5 = {
  0xD0: 0x011E, // Ğ
  0xDD: 0x0130, // İ
  0xDE: 0x015E, // Ş
  0xF0: 0x011F, // ğ
  0xFD: 0x0131, // ı
  0xFE: 0x015F, // ş
};

/// "Ã¼", "Ä±", "ÅŸ" gibi bozuk görünen metni (UTF-8 baytları yanlışlıkla
/// Latin-1/Windows-1252 sanılmış) düzeltir. Bozuk değilse metne dokunmaz.
String fixTurkishMojibake(String s) {
  if (!s.contains(RegExp('[ÃÄÅ]'))) return s;
  final bytes = <int>[];
  for (final r in s.runes) {
    final b = r < 256 ? r : _cp1252[r];
    if (b == null) return s; // dönüştürülemeyen karakter: dokunma
    bytes.add(b);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return s;
  }
}

/// Windows-1252'nin 0x80-0x9F aralığındaki karakterlerinin bayt karşılıkları.
const Map<int, int> _cp1252 = {
  0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85,
  0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A,
  0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92,
  0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
  0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C,
  0x017E: 0x9E, 0x0178: 0x9F,
};
