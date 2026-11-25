const Map<String, String> _turkishToAscii = {
  'ü': 'u', 'Ü': 'U', 'ö': 'o', 'Ö': 'O', 'ı': 'i', 'İ': 'I',
  'ğ': 'g', 'Ğ': 'G', 'ş': 's', 'Ş': 'S', 'ç': 'c', 'Ç': 'C',
};

/// Türkçe harfleri ASCII'ye çevirir (ü->u, ş->s ...).
String foldTurkish(String s) =>
    s.split('').map((c) => _turkishToAscii[c] ?? c).join();

/// Arama adresine konacak metin: harfler olduğu gibi kalır (Türkçe karakterler
/// dahil), tarayıcıdaki gibi UTF-8 yüzde kodlanır; boşluk "%20" olur.
/// (ı -> %C4%B1, boşluk -> %20. Tarayıcı adres çubuğunda ı olarak gösterir.)
String encodeSearchText(String s) =>
    Uri.encodeComponent(s.trim().replaceAll(RegExp(r'\s+'), ' '));
