import '../../../core/price_parser.dart';

/// Sepetteki bir kitap (bir kitapçıdaki bir fiyat teklifi).
class CartItem {
  const CartItem({
    required this.numara,
    required this.title,
    required this.author,
    required this.publisher,
    required this.store,
    required this.siteId,
    required this.price,
    required this.priceText,
    required this.imageUrl,
    required this.isbn,
    required this.priceLink,
    required this.bookLink,
  });

  /// Benzersiz kimlik (eklenme anının milisaniye değeri; silmede kullanılır).
  final String numara;

  final String title;
  final String author;
  final String publisher;

  /// Kitapçı adı (gruplama bununla yapılır).
  final String store;

  /// Kitapçının ayar kimliği (örn. 'kitapyurdu'); fiyat güncellemede kullanılacak.
  final String siteId;

  /// Fiyat sayı olarak; okunamazsa 0.
  final double price;

  /// Sunucudan gelen ham fiyat metni.
  final String priceText;

  final String imageUrl;
  final String isbn;

  /// Fiyatın alındığı sayfa (fiyat güncelleme için).
  final String priceLink;

  /// Kitabın ürün sayfası.
  final String bookLink;

  /// Ekranda gösterilecek fiyat metni.
  String get priceLabel => price > 0 ? formatTl(price) : priceText;
}
