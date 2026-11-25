enum PriceStatus { found, notFound, error, unsupported }

/// Tek bir sitenin fiyat sorgusunun sonucu.
class SitePrice {
  const SitePrice({
    required this.siteId,
    required this.siteName,
    required this.status,
    this.price,
    this.url,
    this.message,
    this.fromFallback = false,
  });

  final String siteId;
  final String siteName;
  final PriceStatus status;
  final double? price;
  final Uri? url;
  final String? message;

  /// true ise fiyat CSS seçiciyle değil yedek yöntemle (JSON-LD/meta) bulundu;
  /// seçici bozulmuş olabilir, sonuç daha az güvenilirdir.
  final bool fromFallback;

  bool get hasPrice => status == PriceStatus.found && price != null;
}

/// Ucuzdan pahalıya; fiyatı olmayanlar sona (ada göre).
int comparePrices(SitePrice a, SitePrice b) {
  if (a.hasPrice && b.hasPrice) return a.price!.compareTo(b.price!);
  if (a.hasPrice) return -1;
  if (b.hasPrice) return 1;
  return a.siteName.compareTo(b.siteName);
}
