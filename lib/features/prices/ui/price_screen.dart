import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/price_parser.dart';
import '../data/book_detail_service.dart' show DescriptionService;
import '../domain/book_info.dart';
import '../domain/site_price.dart';
import '../providers.dart';
import 'book_header.dart';
import '../../cart/domain/cart_item.dart';
import '../../cart/providers.dart';

/// Üstte kitap bilgisi / beğeni / özet, altında site fiyatları.
class PriceScreen extends ConsumerWidget {
  const PriceScreen({super.key, required this.isbn, this.info});
  final String isbn;

  /// Fiyat satırındaki "Sepete ekle": kitabın tüm bilgisini sunucuya gönderir.
  Future<void> _addToCart(BuildContext context, WidgetRef ref, SitePrice p) async {
    final i = info;
    final item = CartItem(
      numara: DateTime.now().millisecondsSinceEpoch.toString(),
      title: (i != null && i.title.isNotEmpty) ? i.title : 'ISBN: $isbn',
      author: i?.author ?? '',
      publisher: i?.publisher ?? '',
      store: p.siteName,
      siteId: p.siteId,
      price: p.price ?? 0,
      priceText: '',
      imageUrl: i?.imageUrl ?? '',
      isbn: isbn,
      priceLink: p.url?.toString() ?? '',
      bookLink: i?.pageUrl ?? '',
    );
    try {
      await ref.read(cartProvider.notifier).add(item);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sepete eklendi: ${p.siteName}')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sepete eklenemedi, tekrar deneyin.')),
      );
    }
  }




  /// Anasayfadan / arama sonuçlarından gelirse dolu; ISBN ile açılırsa null.
  final BookInfo? info;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(priceServiceProvider).sites;
    final total = sites.length;
    final results = ref.watch(priceResultsProvider(PriceQuery(isbn, info)));
    final list = results.valueOrNull ?? const <SitePrice>[];
    final done = list.length;
    final finished = total > 0 && done >= total;
    // Satırlar: önce fiyatı bulunanlar (ucuzdan pahalıya), sonra henüz yanıt
    // gelmeyenler ("Fiyat Bekleniyor"), en sona bulunamayanlar.
    final doneIds = {for (final p in list) p.siteId};
    final found = [for (final p in list) if (p.hasPrice) p];
    final missing = [for (final p in list) if (!p.hasPrice) p];
    final waiting = [for (final s in sites) if (!doneIds.contains(s.id)) s];


    // Özet adresi: önce kitabın kendi sayfası; yoksa tarama BİTİNCE bulunan
    // fiyatlardan, özet seçicisi tanımlı ilk sitenin sayfası (adres sabit kalsın).
    final direct = info?.pageUrl ?? '';
    String? descUrl =
        direct.isNotEmpty && DescriptionService.supports(direct) ? direct : null;
    if (descUrl == null && finished) {
      for (final p in list) {
        final u = p.url?.toString();
        if (p.hasPrice && u != null && DescriptionService.supports(u)) {
          descUrl = u;
          break;
        }
      }
    }
    final descPending = descUrl == null && !finished;

    return Scaffold(
      appBar: AppBar(title: const Text('Fiyat Karşılaştırma')),
      body: ListView(
        children: [
          BookHeader(
            isbn: isbn,
            info: info,
            descriptionUrl: descUrl,
            descriptionPending: descPending,
          ),
          if (!finished)
            LinearProgressIndicator(value: total == 0 ? null : done / total),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(child: Text('ISBN: $isbn')),
                Text(finished
                    ? '$total site tarandı'
                    : '$done / $total site tarandı…'),
              ],
            ),
          ),
          if (results.hasError)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Hata: ${results.error}'),
            ),
          for (var i = 0; i < found.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _PriceTile(
              item: found[i],
              isBest: i == 0,
              onAddToCart: () => _addToCart(context, ref, found[i]),
            ),
          ],
          for (final w in waiting) ...[
            const Divider(height: 1),
            _WaitingTile(name: w.name),
          ],
          for (final m in missing) ...[
            const Divider(height: 1),
            _PriceTile(item: m, isBest: false),
          ],
        ],
      ),
    );
  }
}

class _PriceTile extends StatelessWidget {
  const _PriceTile({required this.item, required this.isBest, this.onAddToCart});
  final SitePrice item;
  final bool isBest;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canOpen = item.hasPrice && item.url != null;

    return ListTile(
      tileColor: isBest ? scheme.primaryContainer : null,
      leading: Icon(
        _icon(item.status),
        color: item.hasPrice ? scheme.primary : scheme.outline,
      ),
      title: Text(item.siteName),
      subtitle: _subtitle(item),
      trailing: item.hasPrice
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatTl(item.price!),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            tooltip: 'Sepete ekle',
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: onAddToCart,
          ),
        ],
      )
          : null,
      onTap: canOpen
          ? () => launchUrl(item.url!, mode: LaunchMode.externalApplication)
          : null,
    );
  }

  Widget? _subtitle(SitePrice i) {
    switch (i.status) {
      case PriceStatus.found:
             null;
      case PriceStatus.notFound:
        return Text('Bulunamadı');
      case PriceStatus.error:
        return Text('Bulunamadı');
      case PriceStatus.unsupported:
        return Text('Bulunamadı');
    }
  }

  /*
  Widget? _subtitle(SitePrice i) {
    switch (i.status) {
      case PriceStatus.found:
        return i.fromFallback
            ? const Text('Yedek yöntemle bulundu (az güvenilir)')
            : null;
      case PriceStatus.notFound:
        return Text(i.message ?? 'Bulunamadı');
      case PriceStatus.error:
        return Text(i.message ?? 'Hata');
      case PriceStatus.unsupported:
        return Text(i.message ?? 'Desteklenmiyor');
    }
  }
   */

  IconData _icon(PriceStatus s) {
    switch (s) {
      case PriceStatus.found:
        return Icons.check_circle;
      case PriceStatus.notFound:
        return Icons.search_off;
      case PriceStatus.error:
        return Icons.search_off;
      case PriceStatus.unsupported:
        return Icons.search_off;
    }
  }

  /*
   IconData _icon(PriceStatus s) {
    switch (s) {
      case PriceStatus.found:
        return Icons.check_circle;
      case PriceStatus.notFound:
        return Icons.search_off;
      case PriceStatus.error:
        return Icons.error_outline;
      case PriceStatus.unsupported:
        return Icons.hourglass_empty;
    }
  }
  */
}
class _WaitingTile extends StatelessWidget {
  const _WaitingTile({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: Text(name),
      subtitle: const Text('Fiyat Bekleniyor'),
    );
  }
}