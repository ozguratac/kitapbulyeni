import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:kitapbul/features/author/data/author_books_service.dart';
import 'package:kitapbul/features/search/data/book_search_service.dart';

void main() {
  test('yazar sayfası: önek olmadan alanlar eşleşir, eski fiyat atlanır', () {
    final doc = html_parser.parse('''
      <div class="product-cr">
        <div class="image"><a href="/kitap/elveda/1.html"><img src="https://img.test/a.jpg"></a></div>
        <div class="name ellipsis"><a>Elveda Güzel Vatanım</a></div>
        <div class="author compact ellipsis">Ahmet Ümit</div>
        <div class="publisher">Everest, </div>
        <div class="price">
          <div class="price-old price-passive"><span class="value">100,00</span></div>
          <span class="value">75,00</span>
        </div>
      </div>''');
    final r = parseResults(doc, authorPageSite,
        Uri.parse('https://www.kitapyurdu.com/yazar/ahmet-umit/1.html'));
    expect(r.length, 1);
    expect(r.first.title, 'Elveda Güzel Vatanım');
    expect(r.first.author, 'Ahmet Ümit');
    expect(r.first.publisher, 'Everest');
    expect(r.first.priceText, '75,00 TL');
    expect(r.first.imageUrl, 'https://img.test/a.jpg');
    expect(r.first.pageUrl, 'https://www.kitapyurdu.com/kitap/elveda/1.html');
  });
}
