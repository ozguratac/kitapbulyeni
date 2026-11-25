import 'dart:convert';
import 'dart:math' as math;

import 'package:html/dom.dart';

import '../../../core/price_parser.dart';
import '../../../core/query_encoding.dart';
import 'site_config.dart';

class PriceHit {
  const PriceHit({required this.price, this.url, this.fromFallback = false});
  final double price;
  final Uri? url;
  final bool fromFallback;
}

/// Saf fonksiyon (ağ yok) -> kolay test edilir.
///
/// A) [SiteConfig.itemSelector] varsa: ürün kutuları gezilir; (istenirse ISBN'in
///    4.-12. haneleri kutunun HTML'inde geçmelidir); fiyat ve link o kutunun
///    İÇİNDEN okunur. Bu sitelerde sayfa geneline / yedek yönteme bakılmaz.
/// B) Yoksa: sayfanın geneli için CSS seçici, yedek olarak JSON-LD / meta.
///
/// Fiyat seçicisinde "a || b" öncelik sırasıdır (önce a, olmazsa b).
PriceHit? extractPrice(
  Document doc,
  SiteConfig site,
  Uri base, {
  String? isbn,
  String? title,
}) {
  final itemSel = site.itemSelector;
  if (itemSel != null && itemSel.isNotEmpty) {
    String? core;
    if (site.matchIsbnCore) {
      if (isbn == null || isbn.length < 12) return null;
      core = isbn.substring(3, 12);
    }
    final coreDigits = core;

    var items = doc
        .querySelectorAll(itemSel)
        .where((e) => coreDigits == null || e.outerHtml.contains(coreDigits))
        .toList();

    // ISBN kutuda yoksa: kutudaki kitap adı ile aranan adı karşılaştır.
    final tSel = site.matchTitleSelector;
    final wanted = (tSel != null && title != null) ? _normTitle(title) : '';
    if (tSel != null && wanted.isNotEmpty) {
      String titleOf(Element e) => _normTitle(e.querySelector(tSel)?.text ?? '');
      // Aranan ad kutudaki adın içinde geçiyorsa YA DA kutudaki ad aranan
      // adın içinde geçiyorsa kabul. Birebir eşleşme önceliği yok.
      items = items.where((e) {
        final t = titleOf(e);
        return t.isNotEmpty && (t.contains(wanted) || wanted.contains(t));
      }).toList();
    }

    for (final item in items) {
      final price = _priceIn(item.querySelectorAll, site);
      if (price != null) {
        return PriceHit(
            price: price, url: _linkOf(item.querySelector, site, base) ?? base);
      }
    }
    return null;
  }

  final price = _priceIn(doc.querySelectorAll, site);
  if (price != null) {
    return PriceHit(price: price, url: _linkOf(doc.querySelector, site, base) ?? base);
  }

  if (site.structuredFallback) {
    final p = _structuredPrice(doc);
    if (p != null) {
      return PriceHit(price: p, url: base, fromFallback: true);
    }
  }
  return null;
}

/// "a || b" parçalarını sırayla dener; her parça kendi içinde sayfa sırasıyla.
double? _priceIn(List<Element> Function(String) query, SiteConfig site) {
  final sel = site.priceSelector;
  if (sel == null || sel.trim().isEmpty) return null;
  for (final part in _alternatives(sel)) {
    for (final el in query(part)) {
      final p = _pick(parseAllPrices(_valueOf(el, site.priceAttr)), site.pick);
      if (p != null) return p;
    }
  }
  return null;
}

Iterable<String> _alternatives(String sel) =>
    sel.split('||').map((s) => s.trim()).where((s) => s.isNotEmpty);

String? _valueOf(Element el, String? attr) {
  if (attr != null) return el.attributes[attr];
  if (el.localName == 'meta') return el.attributes['content'];
  return el.text;
}

double? _pick(List<double> prices, PricePick pick) {
  if (prices.isEmpty) return null;
  switch (pick) {
    case PricePick.first:
      return prices.first;
    case PricePick.min:
      return prices.reduce(math.min);
  }
}

Uri? _linkOf(Element? Function(String) query, SiteConfig site, Uri base) {
  final sel = site.linkSelector;
  if (sel == null || sel.isEmpty) return null;
  final href = query(sel)?.attributes['href']?.trim();
  if (href == null || href.isEmpty || href == '#') return null;
  if (href.toLowerCase().startsWith('javascript:')) return null;
  try {
    return base.resolve(href);
  } catch (_) {
    return null;
  }
}

double? _structuredPrice(Document doc) {
  for (final s in doc.querySelectorAll('script[type="application/ld+json"]')) {
    try {
      final p = _findOfferPrice(jsonDecode(s.text));
      if (p != null) return p;
    } catch (_) {
      // Bozuk JSON-LD: sıradakine geç.
    }
  }
  const metaSelectors = [
    'meta[itemprop="price"]',
    'meta[property="product:price:amount"]',
    'meta[property="og:price:amount"]',
  ];
  for (final sel in metaSelectors) {
    final v = parsePrice(doc.querySelector(sel)?.attributes['content']);
    if (v != null) return v;
  }
  return null;
}

double? _findOfferPrice(dynamic node) {
  if (node is List) {
    for (final e in node) {
      final p = _findOfferPrice(e);
      if (p != null) return p;
    }
    return null;
  }
  if (node is Map) {
    final raw = node['price'] ?? node['lowPrice'];
    if (raw != null) {
      final v = parsePrice(raw.toString());
      if (v != null) return v;
    }
    for (final key in const ['offers', '@graph', 'mainEntity', 'itemListElement', 'item']) {
      if (node.containsKey(key)) {
        final p = _findOfferPrice(node[key]);
        if (p != null) return p;
      }
    }
  }
  return null;
}

/// Ad karşılaştırması için: Türkçe harfler ASCII, küçük harf, sadece harf/rakam.
String _normTitle(String s) =>
    foldTurkish(s).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
