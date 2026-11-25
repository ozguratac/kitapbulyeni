/// Arama sonuç listesindeki bir kitap satırı.
class BookResult {
  const BookResult({
    required this.title,
    required this.author,
    required this.publisher,
    required this.imageUrl,
    required this.priceText,
    required this.pageUrl,
  });

  final String title;
  final String author;
  final String publisher;
  final String imageUrl;

  /// Sitede görünen fiyat metni (örn. "89,90 TL"); yoksa boş.
  final String priceText;

  /// Kitabın ürün sayfası (ISBN buradan bulunur).
  final String pageUrl;
}

/// Bir aramanın sonucu: liste + hangi siteden geldiği + (varsa) site hataları.
class SearchOutcome {
  const SearchOutcome({
    required this.results,
    this.siteName,
    this.errors = const [],
  });

  final List<BookResult> results;
  final String? siteName;
  final List<String> errors;
}
