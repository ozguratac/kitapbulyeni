import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device_id.dart';
import '../prices/providers.dart' show dioProvider;
import 'data/cart_api.dart';
import 'domain/cart_item.dart';

final cartApiProvider = Provider<CartApi>((ref) {
  return CartApi(ref.watch(dioProvider));
});

/// Sunucudaki sepet. Cihaz kimliğine bağlıdır.
final cartProvider =
    AsyncNotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

class CartNotifier extends AsyncNotifier<List<CartItem>> {
  @override
  Future<List<CartItem>> build() => _load();

  Future<List<CartItem>> _load() async {
    final id = await ref.read(deviceIdProvider.future);
    return ref.read(cartApiProvider).read(id);
  }

  /// Sepeti sunucudan yeniden okur.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _load());
    } catch (e, st) {
      state = AsyncError<List<CartItem>>(e, st);
    }
  }

  /// Sepete ekler (fiyat ekranından çağrılır). Hata olursa istisna fırlatır.
  Future<void> add(CartItem item) async {
    final id = await ref.read(deviceIdProvider.future);
    await ref.read(cartApiProvider).add(id, item);
    ref.invalidateSelf(); // sepet listesi yeniden okunsun
  }

  /// Listeden hemen kaldırır, sunucudan siler; başarısız olursa geri koyar.
  Future<void> remove(CartItem item) async {
    final before = state.valueOrNull ?? const <CartItem>[];
    state = AsyncData([...before.where((e) => e.numara != item.numara)]);
    try {
      final id = await ref.read(deviceIdProvider.future);
      await ref.read(cartApiProvider).remove(id, item.numara);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}
