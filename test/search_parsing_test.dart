import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:kitapbul/features/search/data/book_search_service.dart';
import 'package:kitapbul/features/search/data/search_registry.dart';

void main() {
  group('parseResults (Kitapyurdu)', () {
    test('alanlar sıraya göre eşleşir, eski fiyat atlanır', () {
      final doc = html_parser.parse('''
        <div id="product-table">
          <div class="image"><a href="/kitap/nutuk/1.html"><img src="https://img.test/wi:100/a.jpg"></a></div>
          <div class="name ellipsis"><a>Nutuk</a></div>
          <div class="author compact ellipsis">Mustafa Kemal Atatürk</div>
          <div class="publisher">Yayın A, </div>
          <div class="price">
            <div class="price-old price-passive"><span class="value">120,00</span></div>
            <span class="value">89,90</span>
          </div>
        </div>''');
      final r = parseResults(
          doc, searchSites.first, Uri.parse('https://www.kitapyurdu.com/'));
      expect(r.length, 1);
      expect(r.first.title, 'Nutuk');
      expect(r.first.author, 'Mustafa Kemal Atatürk');
      expect(r.first.publisher, 'Yayın A');
      expect(r.first.priceText, '89,90 TL');
      expect(r.first.imageUrl, 'https://img.test/wi:200/a.jpg');
      expect(r.first.pageUrl, 'https://www.kitapyurdu.com/kitap/nutuk/1.html');
    });
  });

  group('extractIsbn', () {
    test('ISBN etiketinin yanındaki tireli numara', () {
      expect(extractIsbn('<td>ISBN:</td><td>978-605-173-887-1</td>'),
          '9786051738871');
    });
    test('geçersiz numarayı atlayıp geçerliyi bulur', () {
      expect(extractIsbn('x 9786051738872 y 9786051738871 z'), '9786051738871');
    });
    test('yoksa null', () {
      expect(extractIsbn('<p>kitap</p>'), isNull);
    });
  });

  group('searchUri', () {
    test('Türkçe harfler ASCII, boşluk +', () {
      expect(searchSites.first.searchUri('Şeker Portakalı').toString(),
          contains('filter_name=Seker+Portakali'));
    });
    test('İstanbul Kitapçısı: boşluk -', () {
      final s = searchSites.firstWhere((s) => s.id == 'istanbulkitapcisi');
      expect(s.searchUri('kürk mantolu').toString(), contains('q=k%C3%BCrk-mantolu'));
    });
  });
}
