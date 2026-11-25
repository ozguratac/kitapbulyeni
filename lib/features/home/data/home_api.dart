import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/app_config.dart';
import '../domain/home_models.dart';

/// Ana sayfa verilerini sunucudan çeker. Eski uygulamadaki Jsoup mantığının
/// aynısı: kayıt başına bir kapsayıcı etiket (<populer>, <sonarama>,
/// <yazarlar>, <kitap>) ve içinde <ad>, <yazar>, <resim>, <isbn>, <yayinevi>,
/// <adres> alt etiketleri vardır.
class HomeApi {
  HomeApi(this._dio);
  final Dio _dio;

  String get _base => '${AppConfig.serverBase}/kitap';

  /// kitaphersey.php  ->  çok aranan + çok beğenilen + yazarlar
  Future<HomeFeed> fetchFeed() async {
    final doc = await _getDoc('$_base/kitaphersey.php');
    return HomeFeed(
      popular: _books(doc, 'populer'),
      liked: _books(doc, 'sonarama'),
      authors: _authors(doc),
    );
  }

  /// tavsiyeOkuKarma.php  ->  okuma önerileri
  Future<List<HomeBook>> fetchRecommendations() async {
    final doc = await _getDoc('$_base/tavsiyeOkuKarma.php');
    return _books(doc, 'kitap');
  }

  Future<Document> _getDoc(String url) async {
    final res = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return html_parser.parse(res.data ?? '');
  }

  List<HomeBook> _books(Document doc, String recordTag) {
    final out = <HomeBook>[];
    for (final el in doc.querySelectorAll(recordTag)) {
      final title = _text(el, 'ad');
      if (title.isEmpty) continue;
      out.add(HomeBook(
        title: title,
        author: _text(el, 'yazar'),
        publisher: _text(el, 'yayinevi'),
        imageUrl: _imageUrl(_text(el, 'resim')),
        isbn: _text(el, 'isbn'),
        pageUrl: _text(el, 'adres'),
      ));
    }
    return out;
  }

  List<HomeAuthor> _authors(Document doc) {
    final out = <HomeAuthor>[];
    for (final el in doc.querySelectorAll('yazarlar')) {
      final name = _text(el, 'yazar');
      if (name.isEmpty) continue;
      out.add(HomeAuthor(
        name: name,
        imageUrl: _imageUrl(_text(el, 'resim')),
        pageUrl: _text(el, 'adres'),
      ));
    }
    return out;
  }

  String _text(Element el, String tag) =>
      el.querySelector(tag)?.text.trim() ?? '';

  String _imageUrl(String raw) {
    final s = raw.trim();
    if (s.startsWith('//')) return 'https:$s';
    return s;
  }
}
