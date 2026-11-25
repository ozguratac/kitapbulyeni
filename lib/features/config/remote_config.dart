import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';
import '../author/data/author_books_service.dart' show authorPageSite;
import '../prices/data/book_detail_service.dart'
    show applyDescriptionRules, descriptionRulesToJson;
import '../prices/data/site_config.dart';
import '../prices/data/site_registry.dart' show defaultSites;
import '../prices/providers.dart' show dioProvider;
import '../search/data/search_registry.dart' as registry;
import '../search/data/search_site.dart';

// ============================================================================
// Uzaktan ayar: kitap sitelerinin adresleri ve süzme etiketleri sunucudaki bir
// .json dosyasından okunur. Sıra: 1) sunucu  2) cihazdaki son başarılı kopya
// 3) uygulamaya gömülü liste. Bir site dosyada yoksa ya da bozuksa o site için
// gömülü ayar kullanılır.
// ============================================================================

/// Ayar dosyasının adresi. Dosyayı sunucuda bu yola koyun (ya da burayı değiştirin).
String get remoteConfigUrl => '${AppConfig.serverBase}/kitap/kitapbul_ayarlar.json';

/// Bu uygulama sürümünün anladığı en yüksek şema numarası. Dosyadaki "schema"
/// bundan büyükse dosya yok sayılır (eski uygulama yeni biçimi yanlış okumasın).
const int supportedSchema = 1;

const String defaultNewReleasesUrl =
    'https://www.istanbulkitapcisi.com/yeni-cikan-kitaplar';
const String defaultNewReleasesSiteId = 'istanbulkitapcisi';

const String _cacheKey = 'remote_config_json';

enum ConfigSource { builtIn, cache, server }

class RemoteConfigState {
  const RemoteConfigState({
    required this.priceSites,
    required this.searchSites,
    required this.authorPage,
    required this.newReleasesUrl,
    required this.newReleasesSiteId,
    this.descriptionRules = const [],
    this.source = ConfigSource.builtIn,
    this.version,
    this.rawJson,
  });

  final List<SiteConfig> priceSites;
  final List<SearchSite> searchSites;
  final SearchSite authorPage;
  final String newReleasesUrl;
  final String newReleasesSiteId;

  /// Doğrulanmış özet kuralları: {host, selector, remove?}
  final List<Map<String, dynamic>> descriptionRules;

  final ConfigSource source;
  final int? version;
  final String? rawJson;

  /// Uygulamaya gömülü (koddaki) ayar.
  factory RemoteConfigState.builtIn() => RemoteConfigState(
        priceSites: defaultSites,
        searchSites: registry.searchSites,
        authorPage: authorPageSite,
        newReleasesUrl: defaultNewReleasesUrl,
        newReleasesSiteId: defaultNewReleasesSiteId,
      );
}

// ---------------------------------------------------------------------------
// Ayrıştırma ve birleştirme (ağ yok, saf fonksiyonlar -> test edilebilir)
// ---------------------------------------------------------------------------

/// JSON metnini doğrular ve gömülü ayarla birleştirir. Dosya tamamen
/// kullanılamazsa null döner. Tek tek bozuk girdiler atlanır ve [warnings]'e
/// yazılır; o siteler için gömülü ayar geçerli kalır.
RemoteConfigState? parseRemoteConfig(
  String raw, {
  required ConfigSource source,
  List<String>? warnings,
}) {
  final warn = warnings ?? <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      warn.add('Dosyanın kökü bir nesne değil');
      return null;
    }
    final json = Map<String, dynamic>.from(decoded);
    final schema = json['schema'];
    if (schema is int && schema > supportedSchema) {
      warn.add('Şema $schema bu uygulama sürümünde desteklenmiyor');
      return null;
    }
    return mergeRemote(RemoteConfigState.builtIn(), json, warn,
        source: source, raw: raw);
  } catch (e) {
    warn.add('Ayrıştırma hatası: $e');
    return null;
  }
}

RemoteConfigState mergeRemote(
  RemoteConfigState base,
  Map<String, dynamic> json,
  List<String> warnings, {
  required ConfigSource source,
  String? raw,
}) {
  // --- fiyat siteleri ---
  final price = <SiteConfig>[];
  for (final e in _maps(json['priceSites'])) {
    try {
      final c = SiteConfig.fromJson(e);
      if (!_isHttp(c.searchUrl)) {
        throw const FormatException('searchUrl http(s) ile başlamalı');
      }
      price.add(c);
    } catch (err) {
      warnings.add('priceSites[${e['id']}] atlandı: $err');
    }
  }

  // --- arama siteleri ---
  final search = <SearchSite>[];
  for (final e in _maps(json['searchSites'])) {
    try {
      final s = SearchSite.fromJson(e);
      if (!_isHttp(s.urlTemplate) || !s.urlTemplate.contains('{q}')) {
        throw const FormatException('urlTemplate http(s) ile başlamalı ve {q} içermeli');
      }
      if (s.titleSelector.trim().isEmpty) {
        throw const FormatException('titleSelector boş');
      }
      search.add(s);
    } catch (err) {
      warnings.add('searchSites[${e['id']}] atlandı: $err');
    }
  }

  // --- yazar sayfası etiketleri ---
  var author = base.authorPage;
  final a = json['authorPage'];
  if (a is Map) {
    try {
      final s = SearchSite.fromJson(<String, dynamic>{
        'id': base.authorPage.id,
        'name': base.authorPage.name,
        'urlTemplate': '',
        ...Map<String, dynamic>.from(a),
      });
      if (s.titleSelector.trim().isEmpty) {
        throw const FormatException('titleSelector boş');
      }
      author = s;
    } catch (err) {
      warnings.add('authorPage atlandı: $err');
    }
  }

  // --- yeni çıkanlar ---
  var newUrl = base.newReleasesUrl;
  var newSite = base.newReleasesSiteId;
  final n = json['newReleases'];
  if (n is Map) {
    final u = n['url'];
    if (u is String && _isHttp(u)) {
      newUrl = u;
    } else if (u != null) {
      warnings.add('newReleases.url geçersiz, gömülü adres kullanılıyor');
    }
    final sid = n['siteId'];
    if (sid is String && sid.isNotEmpty) newSite = sid;
  }

  // --- özet kuralları ---
  final rules = <Map<String, dynamic>>[];
  for (final r in _maps(json['descriptionRules'])) {
    final host = r['host'];
    final sel = r['selector'];
    if (host is String && host.isNotEmpty && sel is String && sel.isNotEmpty) {
      rules.add({
        'host': host,
        'selector': sel,
        if (r['remove'] is List)
          'remove': [for (final x in r['remove'] as List) x.toString()],
      });
    } else {
      warnings.add('descriptionRules girdisi atlandı: $r');
    }
  }

  return RemoteConfigState(
    priceSites: _mergeById<SiteConfig>(base.priceSites, price, (s) => s.id),
    searchSites: _mergeById<SearchSite>(base.searchSites, search, (s) => s.id),
    authorPage: author,
    newReleasesUrl: newUrl,
    newReleasesSiteId: newSite,
    descriptionRules: rules,
    source: source,
    version: json['version'] is int ? json['version'] as int : null,
    rawJson: raw,
  );
}

/// Aynı id'li gömülü girdinin yerine uzak girdi geçer; uzakta olmayan gömülü
/// girdiler korunur. Sıra: önce uzak dosyadaki sıra, sonra kalan gömülüler.
List<T> _mergeById<T>(List<T> builtIn, List<T> remote, String Function(T) idOf) {
  final byId = <String, T>{for (final b in builtIn) idOf(b): b};
  final order = <String>[];
  for (final r in remote) {
    final id = idOf(r);
    if (!order.contains(id)) order.add(id);
    byId[id] = r;
  }
  for (final b in builtIn) {
    final id = idOf(b);
    if (!order.contains(id)) order.add(id);
  }
  return [for (final id in order) byId[id] as T];
}

Iterable<Map<String, dynamic>> _maps(dynamic v) sync* {
  if (v is! List) return;
  for (final e in v) {
    if (e is Map) yield Map<String, dynamic>.from(e);
  }
}

bool _isHttp(String s) =>
    (s.startsWith('http://') || s.startsWith('https://')) && s.length < 2000;

// ---------------------------------------------------------------------------
// Önbellek (cihazda saklanan son başarılı kopya)
// ---------------------------------------------------------------------------

Future<RemoteConfigState?> loadCachedRemoteConfig() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    return parseRemoteConfig(raw, source: ConfigSource.cache);
  } catch (_) {
    return null;
  }
}

Future<void> _saveCachedRaw(String raw) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, raw);
  } catch (_) {
    // Önbellek yazılamazsa sorun değil.
  }
}

void _log(String message) {
  if (kDebugMode) debugPrint('[AYAR] $message');
}

// ---------------------------------------------------------------------------
// Riverpod
// ---------------------------------------------------------------------------

/// main() önbellekten okuduğu ayarı buraya verir (açılışta ağ beklenmesin).
final initialRemoteConfigProvider = Provider<RemoteConfigState?>((ref) => null);

final remoteConfigProvider =
    NotifierProvider<RemoteConfigNotifier, RemoteConfigState>(
        RemoteConfigNotifier.new);

class RemoteConfigNotifier extends Notifier<RemoteConfigState> {
  @override
  RemoteConfigState build() {
    final initial =
        ref.read(initialRemoteConfigProvider) ?? RemoteConfigState.builtIn();
    applyDescriptionRules(initial.descriptionRules);
    _log('başlangıç kaynağı: ${initial.source.name}'
        '${initial.version != null ? " (sürüm ${initial.version})" : ""}');
    Future.microtask(_refreshFromServer);
    return initial;
  }

  /// Arka planda sunucudaki dosyayı indirir; geçerliyse önbelleğe yazar ve uygular.
  Future<void> _refreshFromServer() async {
    final raw = await _fetchRaw();
    if (raw == null) {
      _log('sunucuya ulaşılamadı; kaynak: ${state.source.name}');
      return;
    }
    if (raw == state.rawJson) {
      _log('sunucudaki dosya değişmemiş');
      return;
    }

    final warnings = <String>[];
    final parsed =
        parseRemoteConfig(raw, source: ConfigSource.server, warnings: warnings);
    for (final w in warnings) {
      _log('UYARI: $w');
    }
    if (parsed == null) {
      _log('sunucudaki dosya geçersiz, yok sayıldı');
      return;
    }

    await _saveCachedRaw(raw);
    applyDescriptionRules(parsed.descriptionRules);
    state = parsed;
    _log('sunucu ayarı uygulandı (sürüm ${parsed.version ?? "-"}, '
        '${parsed.priceSites.length} fiyat sitesi, ${parsed.searchSites.length} arama sitesi)');
  }

  Future<String?> _fetchRaw() async {
    try {
      final res = await ref.read(dioProvider).get<String>(
            remoteConfigUrl,
            options: Options(
              responseType: ResponseType.plain,
              sendTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
              headers: {'Cache-Control': 'no-cache'},
            ),
          );
      final body = res.data;
      return (body == null || body.trim().isEmpty) ? null : body;
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Dışa aktarma: koddaki (gömülü) ayarı sunucuya koyulacak JSON'a çevirir.
// ---------------------------------------------------------------------------

String exportBuiltInConfigJson() {
  final b = RemoteConfigState.builtIn();
  final map = <String, dynamic>{
    'schema': supportedSchema,
    'version': 1,
    'priceSites': [for (final s in b.priceSites) s.toJson()],
    'searchSites': [for (final s in b.searchSites) s.toJson()],
    'descriptionRules': descriptionRulesToJson(),
    'authorPage': b.authorPage.toJson(),
    'newReleases': {'url': b.newReleasesUrl, 'siteId': b.newReleasesSiteId},
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}
