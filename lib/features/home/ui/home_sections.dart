import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/isbn.dart';
import '../domain/home_models.dart';
import '../../prices/domain/book_info.dart';

/// Başlık + yatay kaydırmalı liste. Yükleniyor / hata / boş durumlarını yönetir.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.title,
    required this.value,
    required this.height,
    required this.itemBuilder,
    required this.onRetry,
  });

  final String title;
  final AsyncValue<List<T>> value;
  final double height;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => _frame(
        context,
        SizedBox(
          height: height,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => _frame(
        context,
        SizedBox(
          height: 110,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Yüklenemedi: ${_short(e)}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
              ],
            ),
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return _frame(
          context,
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              separatorBuilder: (context, i) => const SizedBox(width: 10),
              itemBuilder: (context, i) => itemBuilder(context, items[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _frame(BuildContext context, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
        child,
      ],
    );
  }

  String _short(Object e) {
    final s = '$e'.replaceAll('\n', ' ');
    return s.length > 90 ? '${s.substring(0, 90)}…' : s;
  }
}

/// Ağdan resim; yüklenirken ve hata olursa yer tutucu gösterir.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder(context, broken: false);
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(context, broken: false),
      errorBuilder: (context, error, stack) =>
          _placeholder(context, broken: true),
    );
  }

  Widget _placeholder(BuildContext context, {required bool broken}) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(broken ? Icons.broken_image_outlined : Icons.menu_book_outlined),
      ),
    );
  }
}

/// ÇOK ARANANLAR: büyük kart (resim + ad / yazar / yayınevi). Orijinal 220dp.
class FeaturedBookCard extends StatelessWidget {
  const FeaturedBookCard({super.key, required this.book, required this.onTap});
  final HomeBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const bold = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    final grey = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 190,
                width: double.infinity,
                child: ColoredBox(
                  color: const Color(0xFFE4DFDD),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: NetImage(book.imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(book.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,textAlign: TextAlign.center, style: bold),
                    Text(book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: grey)),
                    Text(book.publisher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ÇOK BEĞENİLENLER / OKUMA ÖNERİLERİ: sadece kapak resmi.
class CoverTile extends StatelessWidget {
  const CoverTile({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.onTap,
  });
  final String imageUrl;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xFFE4DFDD),
              child: NetImage(imageUrl, fit: BoxFit.contain),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

/// POPÜLER YAZARLAR: resim + altında ad.
class AuthorTile extends StatelessWidget {
  const AuthorTile({super.key, required this.author, required this.onTap});
  final HomeAuthor author;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 85,
                height: 120,
                child: NetImage(author.imageUrl),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              author.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kitaba dokununca ISBN ile fiyat karşılaştırma ekranına gider.
void openBook(BuildContext context, HomeBook book) {
  final isbn = _isbnFor(book.isbn);
  if (isbn == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu kitap için geçerli ISBN bulunamadı')),
    );
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

/// Yazara dokununca şimdilik yazar sayfasını tarayıcıda açar.
/// Yazara dokununca o yazarın kitap listesi açılır.
void openAuthor(BuildContext context, HomeAuthor author) {
  if (author.pageUrl.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yazar sayfası bulunamadı')),
    );
    return;
  }
  context.push(
    '/author?name=${Uri.encodeQueryComponent(author.name)}'
        '&url=${Uri.encodeQueryComponent(author.pageUrl)}',
  );
}

/// Önce doğrulanmış ISBN-13; sunucudaki kayıt kontrol hanesi hatalıysa bile
/// 10/13 haneli ise olduğu gibi kullanılır (eski uygulama da öyle yapıyordu).
String? _isbnFor(String raw) {
  final strict = normalizeIsbn(raw);
  if (strict != null) return strict;
  final digits = raw.replaceAll(RegExp(r'[\s-]'), '');
  if (RegExp(r'^(\d{10}|\d{13})$').hasMatch(digits)) return digits;
  return null;
}
