import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/isbn.dart';

/// Ana sayfanın üstündeki arama kutusu + arama düğmesi.
class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({super.key});

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    FocusScope.of(context).unfocus();

    if (text.isEmpty) {
      _snack('Aranacak bir metin giriniz.');
      return;
    }

    // ISBN de olsa ad da olsa aynı yol: önce arama sonuç listesi.
    // Geçerli bir ISBN ise tire/boşluk silinmiş ISBN-13 ile aranır.
    final query = normalizeIsbn(text) ?? text;
    context.push('/results?q=${Uri.encodeQueryComponent(query)}');
  }

  /// Önce doğrulanmış ISBN; kontrol hanesi hatalı olsa da 10/13 haneliyse kabul.
  String? _toIsbn(String raw) {
    final strict = normalizeIsbn(raw);
    if (strict != null) return strict;
    final digits = raw.replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^(\d{10}|\d{13})$').hasMatch(digits) ? digits : null;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Kitap Ad, Yazar, Yayınevi, Barkod',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _controller.clear,
                    ),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _submit,
              child: const Icon(Icons.search),
            ),
          ),
        ],
      ),
    );
  }
}