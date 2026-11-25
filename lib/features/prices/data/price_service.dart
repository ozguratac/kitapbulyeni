import 'dart:async';
import 'dart:collection';

import '../domain/book_info.dart';
import '../domain/site_price.dart';
import 'site_config.dart';
import 'site_scraper.dart';

/// Tüm siteleri PARALEL (sınırlı eşzamanlılıkla) tarar; sonuçlar bittikçe akar.
/// Eski uygulama siteleri zincirleme, sırayla sorguluyordu.
class PriceService {
  PriceService(this._scraper, List<SiteConfig> sites, {this.concurrency = 6})
      : _sites = _order(sites);

  /// Etkin siteler; önce HTTP, sonra WebView (WebView yavaş, HTTP'yi bekletmesin).
  static List<SiteConfig> _order(List<SiteConfig> sites) {
    final enabled = sites.where((s) => s.enabled);
    return [
      ...enabled.where((s) => s.fetchMode != FetchMode.webview),
      ...enabled.where((s) => s.fetchMode == FetchMode.webview),
    ];
  }

  final SiteScraper _scraper;
  final List<SiteConfig> _sites;
  final int concurrency;

  List<SiteConfig> get sites => _sites;

  Stream<SitePrice> lookup(String isbn, {BookInfo? info}) {
    final controller = StreamController<SitePrice>();
    final queue = Queue<SiteConfig>.of(_sites);
    final total = _sites.length;
    var active = 0;
    var finished = 0;
    var cancelled = false;

    void emit(SitePrice r) {
      if (!cancelled && !controller.isClosed) controller.add(r);
    }

    void pump() {
      while (!cancelled && active < concurrency && queue.isNotEmpty) {
        final site = queue.removeFirst();
        active++;
        _scraper.fetch(site, isbn, info: info).then(emit).catchError((Object e) {
          emit(SitePrice(
            siteId: site.id,
            siteName: site.name,
            status: PriceStatus.error,
            message: '$e',
          ));
        }).whenComplete(() {
          active--;
          finished++;
          if (cancelled) return;
          if (finished >= total) {
            controller.close();
          } else {
            pump();
          }
        });
      }
    }

    controller.onListen = () {
      if (total == 0) {
        controller.close();
      } else {
        pump();
      }
    };
    controller.onCancel = () {
      cancelled = true;
      queue.clear();
    };
    return controller.stream;
  }
}
