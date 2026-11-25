import 'package:flutter_test/flutter_test.dart';
import 'package:kitapbul/features/cart/data/cart_api.dart';
import 'package:kitapbul/features/cart/domain/cart_item.dart';

const _item = CartItem(
  numara: '1700000000000',
  title: 'Tom & Jerry',
  author: 'Yazar X',
  publisher: 'Yay',
  store: 'Kitapyurdu',
  siteId: 'kitapyurdu',
  price: 89.9,
  priceText: '89,90',
  imageUrl: 'https://img.test/a.jpg',
  isbn: '9786051738871',
  priceLink: 'https://www.kitapyurdu.com/kitap/x/1.html',
  bookLink: 'https://www.istanbulkitapcisi.com/x',
);

void main() {
  test('ekleme parametreleri: mevcut alanlar + yeni alanlar', () {
    final p = buildAddParams('cihaz1', _item);
    expect(p['cihazID'], 'cihaz1');
    expect(p['numara'], '1700000000000');
    expect(p['site'], 'Kitapyurdu');
    expect(p['fiyat'], '89,90'); // TL'siz
    expect(p['isbn'], '9786051738871');
    expect(p['resim'], 'https://img.test/a.jpg');
    // yeni alanlar
    expect(p['yazar'], 'Yazar X');
    expect(p['yayinevi'], 'Yay');
    expect(p['siteId'], 'kitapyurdu');
    expect(p['fiyatLink'], 'https://www.kitapyurdu.com/kitap/x/1.html');
    expect(p['kitapLink'], 'https://www.istanbulkitapcisi.com/x');
  });

  test('ad alanı: Ad***Yazar***Yayınevi ve & kaçışlanır', () {
    final p = buildAddParams('c', _item);
    expect(p['ad'], 'Tom &amp; Jerry***Yazar X***Yay');
  });

  test('sepet yanıtı: *** biçimi, ayrı öznitelikler, çift kaçış', () {
    const body = '''
      <liste ad="Simyacı***Paulo Coelho***Can Yayınları" site="Kitapyurdu"
             fiyat="89,90" resim="https://img.test/x.jpg" numara="1" isbn="9789750726439"/>
      <liste ad="Tom &amp;amp; Jerry" site="Pandora" fiyat="10,00" resim="" numara="2"
             isbn="" yazar="Yazar Y" yayinevi="Yay Z" siteId="pandora"
             fiyatLink="https://p.test/x" kitapLink="https://k.test/y"/>
      <liste ad="numarasız" site="X" fiyat="1"/>''';
    final items = parseCartResponse(body);
    expect(items.length, 2); // numarasız kayıt atlanır

    expect(items[0].title, 'Simyacı');
    expect(items[0].author, 'Paulo Coelho');
    expect(items[0].publisher, 'Can Yayınları');
    expect(items[0].price, 89.9);
    expect(items[0].store, 'Kitapyurdu');

    expect(items[1].title, 'Tom & Jerry');
    expect(items[1].author, 'Yazar Y');
    expect(items[1].publisher, 'Yay Z');
    expect(items[1].siteId, 'pandora');
    expect(items[1].priceLink, 'https://p.test/x');
    expect(items[1].bookLink, 'https://k.test/y');
  });

  test('escapeXml / unescapeXml gidiş-dönüş', () {
    const s = 'A & B <c> "d" \'e\'';
    expect(unescapeXml(escapeXml(s)), s);
  });

  test('fiyat etiketi: sayı varsa TL biçimi, yoksa ham metin', () {
    expect(_item.priceLabel, '89,90 TL');
    final raw = parseCartResponse('<liste ad="a" fiyat="bilinmiyor" numara="9"/>');
    expect(raw.first.priceLabel, 'bilinmiyor');
  });
}
