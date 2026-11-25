/// Uygulama geneli sabitler.
///
/// NOT: Sunucu artık fiyat vekili olarak KULLANILMIYOR. Kitaplık, sepet,
/// istatistik, bildirim gibi işler için kalıyor (sonraki aşamalar).
class AppConfig {
  AppConfig._();

  /// iOS için HTTPS şart (App Transport Security). Sunucuda SSL açık olmalı.
  static const String serverBase = 'http://www.bilisimkalesi.com';

  /// Aynı anda en fazla kaç siteye (HTTP) istek atılsın.
  static const int priceConcurrency = 6;

  /// Aynı anda en fazla kaç görünmez WebView açılsın (her biri ağır).
  static const int webViewConcurrency = 2;
}
