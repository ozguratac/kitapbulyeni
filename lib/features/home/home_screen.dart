import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/home_search_bar.dart';
import 'domain/home_models.dart';
import 'providers.dart';
import 'ui/home_sections.dart';
import 'ui/new_releases_section.dart';
import 'data/new_releases_api.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:go_router/go_router.dart';
/// Uygulama açılışında gelen sayfa: yatay kaydırmalı kitap bölümleri.
/// (Orijinal: ÇOK ARANANLAR, ÇOK BEĞENİLENLER, POPÜLER YAZARLAR, OKUMA ÖNERİLERİ)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(newReleasesProvider);
    ref.invalidate(homeFeedProvider);
    ref.invalidate(recommendationsProvider);
    try {
      await Future.wait([
        ref.read(homeFeedProvider.future),
        ref.read(recommendationsProvider.future),
      ]);
    } catch (_) {
      // Hata, bölümlerin kendi "Tekrar dene" alanında gösterilir.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    final recs = ref.watch(recommendationsProvider);

    void retryFeed() => ref.invalidate(homeFeedProvider);
    void retryRecs() => ref.invalidate(recommendationsProvider);
      return Scaffold(
      appBar: AppBar(
        //title: const Text('Kitap Bul'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Tanılama (geliştirici)',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () => context.push('/diagnostics'),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(10),
          child: HomeSearchBar(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const NewReleasesSection(),
            AsyncSection<HomeBook>(
              title: 'ÇOK ARANANLAR',
              value: feed.whenData((f) => f.popular),
              height: 285,
              onRetry: retryFeed,
              itemBuilder: (context, b) => FeaturedBookCard(
                book: b,
                onTap: () => openBook(context, b),
              ),
            ),
            AsyncSection<HomeBook>(
              title: 'ÇOK BEĞENİLENLER',
              value: feed.whenData((f) => f.liked),
              height: 165,
              onRetry: retryFeed,
              itemBuilder: (context, b) => CoverTile(
                imageUrl: b.imageUrl,
                width: 110,
                height: 165,
                onTap: () => openBook(context, b),
              ),
            ),
            AsyncSection<HomeAuthor>(
              title: 'POPÜLER YAZARLAR',
              value: feed.whenData((f) => f.authors),
              height: 164,
              onRetry: retryFeed,
              itemBuilder: (context, a) => AuthorTile(
                author: a,
                onTap: () => openAuthor(context, a),
              ),
            ),
            AsyncSection<HomeBook>(
              title: 'OKUMA ÖNERİLERİ',
              value: recs,
              height: 150,
              onRetry: retryRecs,
              itemBuilder: (context, b) => CoverTile(
                imageUrl: b.imageUrl,
                width: 105,
                height: 150,
                onTap: () => openBook(context, b),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
