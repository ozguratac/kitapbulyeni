import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../home/ui/home_sections.dart' show NetImage;
import '../../prices/domain/book_info.dart';
import '../../search/domain/book_result.dart';
import '../providers.dart';

/// Anasayfada bir yazara dokununca açılır: yazarın kitapları listelenir.
/// Kitaba dokununca ISBN bulunur ve fiyat karşılaştırma ekranına geçilir.
class AuthorBooksScreen extends ConsumerWidget {
  const AuthorBooksScreen({super.key, required this.name, required this.url});
  final String name;
  final String url;

  String get _title => name.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> _open(BuildContext context, WidgetRef ref, BookResult item) async {
    if (item.pageUrl.isEmpty) {
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
      isbn = await ref.read(authorBooksServiceProvider).findIsbn(item.pageUrl);
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
        title: item.title,
        author: item.author,
        publisher: item.publisher,
        imageUrl: item.imageUrl,
        pageUrl: item.pageUrl,
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: const Center(child: Text('Yazar sayfası bulunamadı.')),
      );
    }

    final books = ref.watch(authorBooksProvider(url));
    void retry() => ref.invalidate(authorBooksProvider(url));

    return Scaffold(
      appBar: AppBar(
        title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: books.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Ürünler yükleniyor...'),
            ],
          ),
        ),
        error: (e, _) => _Message(
          text: 'Kitaplar yüklenemedi.',
          onRetry: retry,
          onBrowser: _openInBrowser,
        ),
        data: (list) {
          if (list.isEmpty) {
            return _Message(
              text: 'Bu yazarın kitapları listelenemedi.',
              onRetry: retry,
              onBrowser: _openInBrowser,
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${list.length} kitap'),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (context, i) => const Divider(height: 1),
                  itemBuilder: (context, i) => _BookTile(
                    item: list[i],
                    onTap: () => _open(context, ref, list[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.item, required this.onTap});
  final BookResult item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 72,
                height: 108,
                child: NetImage(item.imageUrl, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.author.isNotEmpty)
                    Text(
                      item.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: soft,
                          height: 1.2),
                    ),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  if (item.publisher.isNotEmpty)
                    Text(
                      item.publisher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: soft, height: 1.2),
                    ),
                  if (item.priceText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.priceText,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.onRetry,
    required this.onBrowser,
  });
  final String text;
  final VoidCallback onRetry;
  final VoidCallback onBrowser;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
            TextButton(
                onPressed: onBrowser, child: const Text('Tarayıcıda aç')),
          ],
        ),
      ),
    );
  }
}
