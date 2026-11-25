import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/isbn.dart';

/// Barkod tarama: kitabın arkasındaki ISBN barkodu okununca, arama kutusuna
/// ISBN yazılıp "ara"ya basılmış gibi arama sonuçları açılır.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const String _defaultHint = 'Kitabın arkasındaki barkodu çerçeveye getirin';

  // Kitap barkodları (ISBN-13) EAN-13 biçimindedir.
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false; // arka arkaya birden çok kez açılmasın
  String _hint = _defaultHint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      // Geçerli bir ISBN-13 olmalı ve 978 / 979 ile başlamalı.
      final isbn = normalizeIsbn(raw);
      if (isbn == null || !(isbn.startsWith('978') || isbn.startsWith('979'))) {
        setState(() => _hint = 'Bu bir kitap (ISBN) barkodu değil: $raw');
        continue;
      }

      _handled = true;
      HapticFeedback.mediumImpact();
      // Arama kutusuna ISBN yazıp ara'ya basmakla aynı yol.
      context.pushReplacement('/results?q=${Uri.encodeQueryComponent(isbn)}');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barkod Tara')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              final denied =
                  error.errorCode == MobileScannerErrorCode.permissionDenied;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    denied
                        ? 'Kamera izni verilmedi. Telefon ayarlarından '
                        'KitapBul için kamera iznini açın.'
                        : 'Kamera açılamadı.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          // Görsel çerçeve (yalnızca yönlendirme için)
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}