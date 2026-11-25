import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/ui/home_sections.dart' show NetImage;
import '../domain/book_result.dart';
import '../providers.dart';
import '../../prices/domain/book_info.dart';

/// Ad / yazar / yayınevi aramasının sonuç listesi. Bir kitaba dokununca ürün
/// sayfasından ISBN bulunur ve fiyat karşılaştırma ekranına geçilir.
class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({super.key, required this.query});
  final String query;

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
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    String? isbn;
    try {
      isbn = await ref.read(bookSearchServiceProvider).findIsbn(item.pageUrl);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(searchResultsProvider(query));
    void retry() => ref.invalidate(searchResultsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: outcome.when(
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
        error: (e, _) => _Message(text: 'Arama başarısız: $e', onRetry: retry),
        data: (o) {
          if (o.results.isEmpty) {
            final detail = o.errors.isEmpty ? '' : '\n\n${o.errors.join('\n')}';
            return _Message(
              text: 'Aradığınız kriterlere uygun kayıt bulunamadı.$detail',
              onRetry: retry,
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                    child: Text('${o.results.length} kitap'),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: o.results.length,
                  separatorBuilder: (context, i) => const Divider(height: 1),
                  itemBuilder: (context, i) => _ResultTile(
                    item: o.results[i],
                    onTap: () => _open(context, ref, o.results[i]),
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

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.item, required this.onTap});
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
                        height: 1.2,
                      ),
                    ),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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
  const _Message({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

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
          ],
        ),
      ),
    );
  }
}
