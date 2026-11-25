import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/isbn.dart';
import '../data/site_diagnostics.dart';
import '../providers.dart';
import '../../config/remote_config.dart' show exportBuiltInConfigJson;

/// Geliştirici aracı: tüm sitelere ISBN ile gidip ham durum raporu çıkarır.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  final _isbn = TextEditingController(text: '9786051738871');
  List<SiteDiagnostic> _results = const [];
  bool _running = false;

  @override
  void dispose() {
    _isbn.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final isbn = normalizeIsbn(_isbn.text);
    if (isbn == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Geçersiz ISBN')));
      return;
    }
    setState(() {
      _running = true;
      _results = const [];
    });
    final sites = ref.read(priceServiceProvider).sites;
    final diagnoser = SiteDiagnoser(
      ref.read(dioProvider),
      webView: ref.read(webViewFetcherProvider),
    );
    final results = await Future.wait(sites.map((s) => diagnoser.run(s, isbn)));
    if (!mounted) return;
    setState(() {
      _results = results;
      _running = false;
    });
  }

  Future<void> _copy() async {
    final report = _results.map((r) => r.toReport()).join('\n');
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapor panoya kopyalandı')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanılama'),
        actions: [
          IconButton(
            tooltip: 'Gömülü ayarı JSON olarak kopyala',
            icon: const Icon(Icons.data_object),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: exportBuiltInConfigJson()));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Ayar JSON'u panoya kopyalandı")),
              );
            },
          ),
          if (_results.isNotEmpty)
            IconButton(
              tooltip: 'Raporu kopyala',
              icon: const Icon(Icons.copy),
              onPressed: _copy,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _isbn,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'ISBN',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _running ? null : _run,
                  child: const Text('Çalıştır'),
                ),
              ],
            ),
          ),
          if (_running) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final r = _results[i];
                return ExpansionTile(
                  leading: Icon(
                    r.error == null && r.cssMatches > 0
                        ? Icons.check_circle
                        : Icons.warning_amber,
                  ),
                  title: Text(r.site.name),
                  subtitle: Text(r.summary),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        r.toReport(),
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
