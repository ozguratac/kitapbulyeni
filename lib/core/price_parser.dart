/// Türkçe sitelerde görülen fiyat metinlerini sayıya çevirir.
///
/// Örnekler: "255,45 TL", "₺1.234,56", "21.15 TL", "TL 89,90".
/// Yüzde ifadeleri (%25) yok sayılır; ISBN gibi çok büyük sayılar fiyat sayılmaz.

final RegExp _numberToken = RegExp(r'\d[\d.,]*');
final RegExp _percent = RegExp(r'%\s*\d+([.,]\d+)?|\d+([.,]\d+)?\s*%');

/// Metindeki tüm fiyatları (görünme sırasıyla) döndürür.
List<double> parseAllPrices(String? raw) {
  if (raw == null) return const [];
  final cleaned = raw.replaceAll(_percent, ' ');
  final result = <double>[];
  for (final m in _numberToken.allMatches(cleaned)) {
    final v = _normalize(m.group(0)!);
    if (v != null) result.add(v);
  }
  return result;
}

/// Metindeki ilk fiyatı döndürür; yoksa null.
double? parsePrice(String? raw) {
  final all = parseAllPrices(raw);
  return all.isEmpty ? null : all.first;
}

/// 89.9 -> "89,90 TL"
String formatTl(double value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} TL';

double? _normalize(String token) {
  final s = token.replaceAll(RegExp(r'[.,]+$'), '');
  if (s.isEmpty) return null;

  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  String normalized;

  if (lastDot >= 0 && lastComma >= 0) {
    // Hangisi sonra geliyorsa ondalık ayracıdır.
    final decimalSep = lastDot > lastComma ? '.' : ',';
    final thousandSep = decimalSep == '.' ? ',' : '.';
    normalized = s.replaceAll(thousandSep, '').replaceAll(decimalSep, '.');
  } else if (lastComma >= 0) {
    normalized = _singleSeparator(s, ',');
  } else if (lastDot >= 0) {
    normalized = _singleSeparator(s, '.');
  } else {
    normalized = s;
  }

  final v = double.tryParse(normalized);
  if (v == null || v <= 0 || v > 1000000) return null;
  return v;
}

/// Tek tür ayraç varsa: "1.234" binlik, "21.15" ondalıktır.
String _singleSeparator(String s, String sep) {
  final parts = s.split(sep);
  if (parts.length > 2) return parts.join(); // 1.234.567
  final frac = parts.last;
  if (frac.length == 3 && parts.first.length <= 3 && parts.first != '0') {
    return parts.join(); // 1.234 -> 1234
  }
  return '${parts.first}.$frac';
}
