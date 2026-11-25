import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/price_parser.dart';
import '../home/ui/home_sections.dart' show NetImage;
import 'domain/cart_item.dart';
import 'providers.dart';

/// Sepet: kitaplar kitapçıya göre gruplanır; her grubun ve sepetin toplamı
/// gösterilir; çöp kutusuyla kitap sepetten silinir.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  Future<void> _remove(BuildContext context, WidgetRef ref, CartItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text('"${item.title}" sepetten silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return; // Vazgeç'e basıldı ya da pencere dışına dokunuldu

    try {
      await ref.read(cartProvider.notifier).remove(item);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kitap sepetten silinemedi, tekrar deneyin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    Future<void> refresh() => ref.read(cartProvider.notifier).refresh();

    return Scaffold(
      appBar: AppBar(title: const Text('Sepet')),
      body: cart.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sepet yüklenemedi.'),
                const SizedBox(height: 8),
                TextButton(onPressed: refresh, child: const Text('Tekrar dene')),
              ],
            ),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: refresh,
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Sepetiniz boş.')),
                  ],
                )
              : _CartList(
                  items: items,
                  onRemove: (item) => _remove(context, ref, item),
                ),
        ),
      ),
    );
  }
}

class _CartList extends StatelessWidget {
  const _CartList({required this.items, required this.onRemove});
  final List<CartItem> items;
  final void Function(CartItem item) onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Kitapçıya göre grupla (ilk görülme sırası korunur).
    final groups = <String, List<CartItem>>{};
    for (final it in items) {
      (groups[it.store.isEmpty ? 'Diğer' : it.store] ??= []).add(it);
    }
    final total = items.fold<double>(0, (s, e) => s + e.price);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'SEPET TOPLAMI  (${items.length} kitap)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Text(
                  formatTl(total),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final entry in groups.entries) ...[
          Container(
            margin: const EdgeInsets.only(top: 12),
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'TOPLAM : ${formatTl(entry.value.fold<double>(0, (s, e) => s + e.price))}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          for (var i = 0; i < entry.value.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _CartTile(
              item: entry.value[i],
              onRemove: () => onRemove(entry.value[i]),
            ),
          ],
        ],
      ],
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({required this.item, required this.onRemove});
  final CartItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final soft = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 60,
              height: 90,
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
                        fontSize: 13, fontWeight: FontWeight.bold, color: soft),
                  ),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, height: 1.2),
                ),
                if (item.publisher.isNotEmpty)
                  Text(
                    item.publisher,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: soft),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.priceLabel,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sepetten sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
