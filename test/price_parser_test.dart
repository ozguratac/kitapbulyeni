import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:kitapbul/core/isbn.dart';
import 'package:kitapbul/core/price_parser.dart';
import 'package:kitapbul/features/prices/data/price_extractor.dart';
import 'package:kitapbul/features/prices/data/site_config.dart';

void main() {
  group('parsePrice', () {
    test('Türkçe formatlar', () {
      expect(parsePrice('255,45 TL'), 255.45);
      expect(parsePrice('₺1.234,56'), 1234.56);
      expect(parsePrice('21.15 TL'), 21.15);
      expect(parsePrice('TL 89,90'), 89.9);
      expect(parsePrice('1.234 TL'), 1234.0);
      expect(parsePrice('0,125'), 0.125);
    });
    test('yüzde yok sayılır, ISBN fiyat değildir', () {
      expect(parseAllPrices('%25 İndirim 120,00 TL 90,00 TL'), [120.0, 90.0]);
      expect(parsePrice('9786051738871'), isNull);
      expect(parsePrice('-----'), isNull);
      expect(parsePrice(null), isNull);
    });
    test('formatTl', () => expect(formatTl(89.9), '89,90 TL'));
  });

  group('normalizeIsbn', () {
    test('ISBN-13 doğrular', () {
      expect(normalizeIsbn('978-605-173-887-1'), '9786051738871');
      expect(normalizeIsbn('9786051738872'), isNull); // hatalı kontrol hanesi
    });
    test('ISBN-10 -> ISBN-13', () {
      expect(normalizeIsbn('0306406152'), '9780306406157');
    });
    test('çöp girdi', () {
      expect(normalizeIsbn('abc'), isNull);
      expect(normalizeIsbn(''), isNull);
    });
  });

  group('extractPrice', () {
    const site = SiteConfig(
      id: 't',
      name: 'Test',
      searchUrl: 'https://x.test/?q={isbn}',
      priceSelector: 'ul#urunler li p.indirimliFiyat',
      linkSelector: 'ul#urunler li p.edebiyatIsim a',
    );
    final base = Uri.parse('https://x.test/Arama/');

    test('CSS ile fiyat ve göreli linki çözer', () {
      final doc = html_parser.parse('''
        <ul id="urunler"><li><div>
          <p class="edebiyatIsim"><a href="/kitap/abc">Kitap</a></p>
          <p class="indirimliFiyat">89,90 TL</p>
        </div></li></ul>''');
      final hit = extractPrice(doc, site, base)!;
      expect(hit.price, 89.9);
      expect(hit.url.toString(), 'https://x.test/kitap/abc');
      expect(hit.fromFallback, isFalse);
    });

    test('CSS bulamazsa JSON-LD yedeği', () {
      final doc = html_parser.parse('''
        <script type="application/ld+json">
        {"@type":"Product","offers":{"@type":"Offer","price":"120.50"}}
        </script>''');
      final hit = extractPrice(doc, site, base)!;
      expect(hit.price, 120.5);
      expect(hit.fromFallback, isTrue);
    });

    test('hiçbir şey yoksa null', () {
      expect(extractPrice(html_parser.parse('<p>yok</p>'), site, base), isNull);
    });
  });
}
