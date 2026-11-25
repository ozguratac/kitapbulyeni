import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:kitapbul/features/prices/data/price_extractor.dart';
import 'package:kitapbul/features/prices/data/site_config.dart';

const _ky = SiteConfig(
  id: 'kitapyurdu',
  name: 'Kitapyurdu',
  searchUrl: 'https://x.test/?filter_name={title}',
  itemSelector: 'div.product-grid div.product-cr',
  matchTitleSelector: 'div.name',
  priceSelector: 'div.price-new span.value || span.price-old span.value',
  linkSelector: 'a.pr-img-link',
  structuredFallback: false,
);

String _box(String title, String price, String href) => '''
  <div class="product-cr">
    <a class="pr-img-link" href="$href"></a>
    <div class="name"><a>$title</a></div>
    <div class="price-new"><span class="value">$price</span></div>
  </div>''';

void main() {
  final base = Uri.parse('https://www.kitapyurdu.com/index.php');

  test('içeren ilk kutu seçilir (birebir önceliği yok)', () {
    final doc = html_parser.parse('<div class="product-grid">'
        '${_box('Nutuk (Cep Boy)', '30,00', '/a')}'
        '${_box('Nutuk', '89,90', '/b')}'
        '</div>');
    final hit = extractPrice(doc, _ky, base, title: 'NUTUK')!;
    expect(hit.price, 30.0);
    expect(hit.url.toString(), 'https://www.kitapyurdu.com/a');
  });

  test('Türkçe harf ve noktalama farkı önemsiz', () {
    final doc = html_parser.parse('<div class="product-grid">'
        '${_box('Şeker Portakalı', '45,00', '/s')}'
        '</div>');
    expect(extractPrice(doc, _ky, base, title: 'seker portakali')!.price, 45.0);
  });

  test('birebir yoksa içeren kutu kabul edilir', () {
    final doc = html_parser.parse('<div class="product-grid">'
        '${_box('Simyacı - Can Yayınları', '60,00', '/c')}'
        '</div>');
    expect(extractPrice(doc, _ky, base, title: 'Simyacı')!.price, 60.0);
  });

  test('hiçbir kutu uymuyorsa null (başka kitabın fiyatı alınmaz)', () {
    final doc = html_parser.parse('<div class="product-grid">'
        '${_box('Bambaşka Kitap', '10,00', '/d')}'
        '</div>');
    expect(extractPrice(doc, _ky, base, title: 'Nutuk'), isNull);
  });
}
