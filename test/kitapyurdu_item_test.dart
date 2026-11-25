import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:kitapbul/features/prices/data/price_extractor.dart';
import 'package:kitapbul/features/prices/data/site_config.dart';
import 'package:kitapbul/features/prices/domain/book_info.dart';

const _ky = SiteConfig(
  id: 'kitapyurdu',
  name: 'Kitapyurdu',
  searchUrl:
      'https://www.kitapyurdu.com/index.php?route=product/search&filter_name={title}&limit=200',
  itemSelector: 'div.product-grid div.product-cr',
  matchIsbnCore: true,
  priceSelector: 'div.price-new span.value || span.price-old span.value',
  linkSelector: 'a.pr-img-link',
  structuredFallback: false,
);

void main() {
  final base = Uri.parse('https://www.kitapyurdu.com/index.php');

  test('adres: kitap adı ASCII ve + ile kodlanır', () {
    const info = BookInfo(
        title: 'Şeker Portakalı',
        author: 'J. M. de Vasconcelos',
        publisher: 'Can',
        imageUrl: '',
        pageUrl: '');
    final uri = _ky.searchUri('9786051738871', info: info).toString();
    expect(uri, contains('filter_name=%C5%9Eeker%20Portakal%C4%B1&limit=200'));
    expect(_ky.needsBookInfo, isTrue);
  });

  test('{query}: yazar önce, %20 ile, Türkçe karakter korunur', () {
    const site = SiteConfig(
      id: 'k',
      name: 'K',
      searchUrl:
          'https://www.kitapyurdu.com/index.php?route=product/list&filter_name={query}',
    );
    const info = BookInfo(
        title: 'Simyacı',
        author: 'Paulo Coelho',
        publisher: '',
        imageUrl: '',
        pageUrl: '');
    expect(
      site.searchUri('9789750726439', info: info).toString(),
      'https://www.kitapyurdu.com/index.php?route=product/list&filter_name=Paulo%20Coelho%20Simyac%C4%B1',
    );
    expect(site.needsBookInfo, isTrue);
  });

  test('ISBN çekirdeği (4.-12. hane) tutan kutu seçilir, diğeri atlanır', () {
    final doc = html_parser.parse('''
      <div class="product-grid">
        <div class="product-cr">
          <a class="pr-img-link" href="/kitap/baska/1.html"><img src="/img/9789753638029.jpg"></a>
          <div class="price-new"><span class="value">50,00</span></div>
        </div>
        <div class="product-cr">
          <a class="pr-img-link" href="/kitap/dogru/2.html"><img src="/img/9786051738871.jpg"></a>
          <div class="price-new"><span class="value">89,90</span></div>
        </div>
      </div>''');
    final hit = extractPrice(doc, _ky, base, isbn: '9786051738871')!;
    expect(hit.price, 89.9);
    expect(hit.url.toString(), 'https://www.kitapyurdu.com/kitap/dogru/2.html');
  });

  test('price-new yoksa price-old kullanılır (öncelik sırası)', () {
    final doc = html_parser.parse('''
      <div class="product-grid"><div class="product-cr">
        <a class="pr-img-link" href="/kitap/x/3.html"><img src="/img/9786051738871.jpg"></a>
        <span class="price-old"><span class="value">120,00</span></span>
      </div></div>''');
    expect(extractPrice(doc, _ky, base, isbn: '9786051738871')!.price, 120.0);
  });

  test('eşleşen kutu yoksa null (başka kitabın fiyatı alınmaz)', () {
    final doc = html_parser.parse('''
      <div class="product-grid"><div class="product-cr">
        <a class="pr-img-link" href="/kitap/x/1.html"><img src="/img/9789753638029.jpg"></a>
        <div class="price-new"><span class="value">50,00</span></div>
      </div></div>''');
    expect(extractPrice(doc, _ky, base, isbn: '9786051738871'), isNull);
  });
}
