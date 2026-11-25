import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// WebView'ın yüklediği sayfa: JavaScript çalıştıktan SONRAKİ HTML.
class WebPage {
  const WebPage({required this.html, required this.url});
  final String html;
  final Uri url;
}

/// Görünmez (headless) bir WebView ile sayfa yükleyip oluşan HTML'i döndürür.
/// JavaScript ile çizilen veya basit bot koruması olan siteler için.
///
/// Aynı anda en fazla [maxConcurrent] WebView açılır (her biri ağırdır).
class WebViewFetcher {
  WebViewFetcher({int maxConcurrent = 2}) : _gate = _Gate(maxConcurrent);

  final _Gate _gate;

  /// [waitSelector] verilirse o öğe sayfada belirene kadar (en fazla [timeout])
  /// beklenir. Verilmezse sayfa yüklendikten sonra [settle] kadar beklenir.
  ///
  /// Sayfa hiç yüklenmezse TimeoutException fırlatır. Seçici belirmezse süre
  /// dolunca eldeki HTML yine de döndürülür (yedek yöntem/teşhis için).
  Future<WebPage?> fetch(
    Uri uri, {
    required String userAgent,
    String? waitSelector,
    Duration timeout = const Duration(seconds: 20),
    Duration settle = const Duration(milliseconds: 2500),
  }) async {
    await _gate.acquire();
    HeadlessInAppWebView? headless;
    try {
      final loaded = Completer<void>();
      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(uri.toString())),
        initialSettings: InAppWebViewSettings(
          userAgent: userAgent,
          javaScriptEnabled: true,
        ),
        onLoadStop: (controller, url) {
          if (!loaded.isCompleted) loaded.complete();
        },
      );

      final deadline = DateTime.now().add(timeout);
      await headless.run();
      await loaded.future.timeout(timeout);

      final controller = headless.webViewController;
      if (controller == null) return null;

      if (waitSelector == null) {
        await Future<void>.delayed(settle);
      } else {
        final js = 'document.querySelector(${jsonEncode(waitSelector)}) !== null';
        while (DateTime.now().isBefore(deadline)) {
          try {
            final r = await controller.evaluateJavascript(source: js);
            if (r == true || r?.toString() == 'true') {
              // Metnin yerleşmesi için kısa pay.
              await Future<void>.delayed(const Duration(milliseconds: 400));
              break;
            }
          } catch (_) {
            // Sayfa yönlendirme sırasında olabilir; tekrar dene.
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }

      final raw = await controller
          .evaluateJavascript(source: 'document.documentElement.outerHTML');
      final html = _asString(raw);
      if (html == null || html.isEmpty) return null;

      final current = await controller.getUrl();
      final finalUrl =
          current == null ? uri : (Uri.tryParse(current.toString()) ?? uri);
      return WebPage(html: html, url: finalUrl);
    } finally {
      try {
        await headless?.dispose();
      } catch (_) {}
      _gate.release();
    }
  }

  /// Bazı platformlar sonucu JSON metni olarak (tırnaklı, \u003C kaçışlı) verir.
  String? _asString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      if (raw.length > 1 &&
          raw.startsWith('"') &&
          raw.endsWith('"') &&
          raw.contains(r'\u003C')) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is String) return decoded;
        } catch (_) {}
      }
      return raw;
    }
    return raw.toString();
  }
}

/// Basit eşzamanlılık sınırlayıcı (semafor).
class _Gate {
  _Gate(this.max);
  final int max;
  int _active = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  Future<void> acquire() async {
    if (_active < max) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future; // yer, release() tarafından devredildi
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _active--;
    }
  }
}
