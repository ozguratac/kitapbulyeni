import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device_id.dart';
import '../../home/ui/home_sections.dart' show NetImage;
import '../data/book_detail_service.dart';
import '../detail_providers.dart';
import '../domain/book_info.dart';

/// Fiyat ekranının üstü: kapak, kitap bilgileri, beğeni ve kısa özet.
class BookHeader extends ConsumerStatefulWidget {
  const BookHeader({
    super.key,
    required this.isbn,
    required this.info,
    required this.descriptionUrl,
    required this.descriptionPending,
  });

  final String isbn;
  final BookInfo? info;

  /// Özetin okunacağı ürün sayfası; henüz bilinmiyorsa null.
  final String? descriptionUrl;

  /// descriptionUrl henüz bulunamadı ama fiyatlar taranırken bulunabilir.
  final bool descriptionPending;

  @override
  ConsumerState<BookHeader> createState() => _BookHeaderState();
}

class _BookHeaderState extends ConsumerState<BookHeader> {
  static const int _collapsedLines = 6;
  static const int _longTextChars = 280;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final soft = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 100,
                    height: 140,
                    child: NetImage(info.imageUrl, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (info != null && info.author.isNotEmpty)
                      Text(
                        info.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold, color: soft),
                      ),
                    if (info != null && info.title.isNotEmpty)
                      Text(
                        info.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold, height: 1.2),
                      ),
                    if (info != null && info.publisher.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          info.publisher,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: soft),
                        ),
                      ),
                    if (info == null)
                      Text('ISBN: ${widget.isbn}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    LikeButton(isbn: widget.isbn),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDescription(context),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    final url = widget.descriptionUrl;

    if (url == null) {
      return widget.descriptionPending
          ? const _Hint('Kitap açıklaması aranıyor...')
          : const _Hint('Bu kitaba ait açıklama bulunamadı.');
    }

    final desc = ref.watch(descriptionProvider(url));
    return desc.when(
      loading: () => const _Hint('Kitap açıklaması yükleniyor...'),
      error: (e, _) => const _Hint('Bu kitaba ait açıklama bulunamadı.'),
      data: (text) {
        if (text == null || text.isEmpty) {
          return const _Hint('Bu kitaba ait açıklama bulunamadı.');
        }
        final isLong = text.length > _longTextChars;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kitap Açıklaması',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.justify,          // <- eklenen satır
              maxLines: _expanded ? null : _collapsedLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
            if (isLong)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Daha az göster' : 'Devamını oku'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Beğen düğmesi + "N Defa Beğenildi". Orijinaldeki gibi sunucuda cihaz
/// kimliğine bağlı tutulur; düğmeye basınca beğeni açılır/kapanır.
class LikeButton extends ConsumerStatefulWidget {
  const LikeButton({super.key, required this.isbn});
  final String isbn;

  @override
  ConsumerState<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<LikeButton> {
  int? _count;
  bool _liked = false;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await ref.read(deviceIdProvider.future);
      final state = await ref.read(likeApiProvider).read(widget.isbn, id);
      if (!mounted) return;
      setState(() {
        _count = state.count;
        _liked = state.liked;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await ref.read(deviceIdProvider.future);
      final api = ref.read(likeApiProvider);
      final LikeState state = _liked
          ? await api.unlike(widget.isbn, id)
          : await api.like(widget.isbn, id);
      if (!mounted) return;
      setState(() {
        _count = state.count;
        _liked = state.liked;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beğeni kaydedilemedi, tekrar deneyin.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final countText = _failed
        ? 'Beğeni bilgisi alınamadı'
        : _count == null
            ? 'Yükleniyor...'
            : '$_count Defa Beğenildi';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _failed || _busy ? null : _toggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? Colors.red : null,
                  size: 26,
                ),
                Text(_liked ? 'Beğenildi' : 'Beğen',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32, child: VerticalDivider(width: 16)),
        Flexible(
          child: Text(
            countText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
