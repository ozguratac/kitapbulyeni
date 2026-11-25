/// Ana sayfadaki bir kitap kartı (sunucudan gelen XML kaydı).
class HomeBook {
  const HomeBook({
    required this.title,
    required this.author,
    required this.publisher,
    required this.imageUrl,
    required this.isbn,
    required this.pageUrl,
  });

  final String title;
  final String author;
  final String publisher;
  final String imageUrl;
  final String isbn;
  final String pageUrl;
}

/// "Popüler yazarlar" bölümündeki bir yazar.
class HomeAuthor {
  const HomeAuthor({
    required this.name,
    required this.imageUrl,
    required this.pageUrl,
  });

  final String name;
  final String imageUrl;
  final String pageUrl;
}

/// kitaphersey.php yanıtı: üç bölümü tek istekte getirir.
class HomeFeed {
  const HomeFeed({
    required this.popular,
    required this.liked,
    required this.authors,
  });

  /// ÇOK ARANANLAR  (<populer>)
  final List<HomeBook> popular;

  /// ÇOK BEĞENİLENLER  (<sonarama>)
  final List<HomeBook> liked;

  /// POPÜLER YAZARLAR  (<yazarlar>)
  final List<HomeAuthor> authors;
}
