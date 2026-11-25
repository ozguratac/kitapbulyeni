import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:kitapbul/features/prices/data/book_detail_service.dart';

void main() {
  group('beğeni yanıtı', () {
    test('sayı ve beğendi bayrağı', () {
      expect(parseLikeCount('###12---000 1---'), 12);
      expect(parseLikedFlag('###12---000 1---'), isTrue);
      expect(parseLikedFlag('###1000---000 0---'), isFalse);
      expect(parseLikeCount('hata'), 0);
    });
  });

  group('parseDescription', () {
    test('Kitapyurdu: özet metni çıkar', () {
      final doc = html_parser.parse(
          '<div class="pr_description"><span class="info__text">  Güzel   bir\n kitap.  </span></div>');
      expect(parseDescription(doc, 'https://www.kitapyurdu.com/kitap/x/1.html'),
          'Güzel bir kitap.');
    });
    test('Kitapseç: h2 / strong / mağaza bilgisi silinir', () {
      final doc = html_parser.parse('''
        <div class="TabDivList"><div id="tab1">
          <h2>Başlık</h2><strong>Kalın</strong>
          <div class="magaza-bilgi">Mağaza</div>
          Asıl özet metni.
        </div></div>''');
      expect(parseDescription(doc, 'https://www.kitapsec.com/x'),
          'Asıl özet metni.');
    });
    test('tanımsız site için null', () {
      expect(parseDescription(html_parser.parse('<p>x</p>'), 'https://bilinmeyen.com/x'),
          isNull);
      expect(DescriptionService.supports('https://www.kitapyurdu.com/x'), isTrue);
      expect(DescriptionService.supports('https://bilinmeyen.com/x'), isFalse);
    });
  });
}
