import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Alt menü: Anasayfa (0), Barkod (1), Sepet (2).
/// Sıra, router.dart içindeki dal sırasıyla AYNI olmalı:
/// 0 /home, 1 /scan (hiç açılmaz, Barkod tam ekran sayfa olarak açılır), 2 /cart
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) {
          if (i == 1) {
            // Barkod: sekme değiştirmek yerine tam ekran tarayıcıyı aç.
            context.push('/scanner');
            return;
          }
          navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Anasayfa'),
          NavigationDestination(
              icon: Icon(Icons.qr_code_scanner), label: 'Barkod'),
          NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'Sepet'),
        ],
      ),
    );
  }
}