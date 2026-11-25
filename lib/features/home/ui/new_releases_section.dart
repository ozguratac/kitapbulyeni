import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../prices/domain/book_info.dart';
import '../../search/providers.dart' show bookSearchServiceProvider;
import '../data/new_releases_api.dart';
import '../domain/home_models.dart';
import 'home_sections.dart' show AsyncSection, FeaturedBookCard;

/// Ana sayfadaki "YENİ ÇIKANLAR" bölümü ("ÇOK ARANANLAR" ile aynı görünüm).
/// Kitaba dokununca ürün sayfasından ISBN bulunur ve fiyat listesi açılır.
class NewReleasesSection extends ConsumerWidget {
  const NewReleasesSection({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, HomeBook book) async {
    if (book.pageUrl.isEmpty) {
      _snack(context, 'Bu kitabın sayfa adresi bulunamadı.');
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Kitap bilgisi alınıyor...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    String? isbn;
    try {
      isbn = await ref.read(bookSearchServiceProvider).findIsbn(book.pageUrl);
    } catch (_) {
      isbn = null;
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // yükleniyor penceresi

    if (isbn == null) {
      _snack(context, 'Bu kitabın ISBN numarası bulunamadı.');
      return;
    }
    context.push(
      '/prices/$isbn',
      extra: BookInfo(
        title: book.title,
        author: book.author,
        publisher: book.publisher,
        imageUrl: book.imageUrl,
        pageUrl: book.pageUrl,
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Büyütme oranı: 1.0 = ÇOK ARANANLAR ile aynı boyut.
  // Biraz büyük: 1.15 • Önerilen: 1.25 • Daha büyük: 1.4
  static const double _scale = 1.1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncSection<HomeBook>(
      title: 'YENİ ÇIKANLAR',
      value: ref.watch(newReleasesProvider),
      height: 285 * _scale, // bölümün yüksekliği orana göre büyür
      onRetry: () => ref.invalidate(newReleasesProvider),
      itemBuilder: (context, b) => SizedBox(
        width: 220 * _scale, // kart genişliği
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 220,
            child: FeaturedBookCard(
              book: b,
              onTap: () => _open(context, ref, b),
            ),
          ),
        ),
      ),
    );
  }
}