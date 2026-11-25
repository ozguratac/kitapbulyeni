import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/isbn.dart';

/// Alttaki "Ara" sekmesi: mevcut ISBN arama paneli.
/// (Ad/yazar ile arama Aşama 5'te bu ekrana eklenecek.)
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Aranacak bir metin girin');
      return;
    }
    setState(() => _error = null);
    final query = normalizeIsbn(text) ?? text;
    context.push('/results?q=${Uri.encodeQueryComponent(query)}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ara')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kitap ara',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Kitap Ad, Yazar, Yayınevi, Barkod',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Text('Fiyatları Karşılaştır'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/diagnostics'),
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Tanılama (geliştirici)'),
            ),
          ],
        ),
      ),
    );
  }
}
