/// Kullanıcı girdisini (tire/boşluk içerebilir) doğrulanmış ISBN-13'e çevirir.
/// ISBN-10 verilirse ISBN-13'e dönüştürülür. Geçersizse null döner.
String? normalizeIsbn(String input) {
  final s = input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  if (RegExp(r'^\d{13}$').hasMatch(s)) return _isValid13(s) ? s : null;
  if (RegExp(r'^\d{9}[\dX]$').hasMatch(s)) return _isbn10To13(s);
  return null;
}

bool _isValid13(String s) {
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    final d = int.parse(s[i]);
    sum += i.isEven ? d : d * 3;
  }
  return sum % 10 == 0;
}

String? _isbn10To13(String s) {
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    final c = s[i];
    final v = c == 'X' ? 10 : int.parse(c);
    sum += v * (10 - i);
  }
  if (sum % 11 != 0) return null;

  final core = '978${s.substring(0, 9)}';
  var t = 0;
  for (var i = 0; i < 12; i++) {
    final d = int.parse(core[i]);
    t += i.isEven ? d : d * 3;
  }
  final check = (10 - t % 10) % 10;
  return '$core$check';
}
