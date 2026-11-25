/// Fiyat ekranının üstünde gösterilen kitap bilgisi. Anasayfadan ya da arama
/// sonuçlarından gelirken `extra` olarak taşınır; ISBN ile doğrudan açılan
/// ekranda null'dır.
class BookInfo {
  const BookInfo({
    required this.title,
    required this.author,
    required this.publisher,
    required this.imageUrl,
    required this.pageUrl,
  });

  final String title;
  final String author;
  final String publisher;
  final String imageUrl;

  /// Kitabın bir sitedeki ürün sayfası (özet buradan okunur).
  final String pageUrl;
}
