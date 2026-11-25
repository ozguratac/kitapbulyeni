import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/prices/domain/book_info.dart';

import '../features/cart/cart_screen.dart';
import '../features/home/home_screen.dart';
//import '../features/library/library_screen.dart';
import '../features/prices/ui/diagnostics_screen.dart';
import '../features/prices/ui/price_screen.dart';
import '../features/scan/scan_screen.dart';
//import '../features/search/search_screen.dart';
import '../features/shell/shell_scaffold.dart';

import '../features/search/ui/search_results_screen.dart';
import '../features/author/ui/author_books_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      // 5 sekmeli alt menü (Anasayfa, Ara, Kitaplık, Barkod, Sepet)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
          ]),
        ],
      ),
      // Alt menüsüz tam ekran
      GoRoute(
        path: '/diagnostics',
        builder: (context, state) => const DiagnosticsScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => SearchResultsScreen(
          query: state.uri.queryParameters['q'] ?? '',
        ),
      ),
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        path: '/author',
        builder: (context, state) => AuthorBooksScreen(
          name: state.uri.queryParameters['name'] ?? '',
          url: state.uri.queryParameters['url'] ?? '',
        ),
      ),
      GoRoute(
        path: '/prices/:isbn',
        builder: (context, state) {
          final extra = state.extra;
          return PriceScreen(
            isbn: state.pathParameters['isbn']!,
            info: extra is BookInfo ? extra : null,
          );
        },
      ),
    ],
  );
});
