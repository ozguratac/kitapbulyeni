import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitapbul/features/config/remote_config.dart';
import 'package:kitapbul/features/prices/data/site_config.dart';
import 'package:kitapbul/features/prices/data/site_registry.dart';
import 'package:kitapbul/features/search/data/search_registry.dart' as registry;
import 'package:kitapbul/features/search/data/search_site.dart';

void main() {
  test('gömülü ayar boş değil', () {
    final b = RemoteConfigState.builtIn();
    expect(b.priceSites, isNotEmpty);
    expect(b.searchSites, isNotEmpty);
    expect(b.source, ConfigSource.builtIn);
  });

  test('uzak girdi gömülüyü id ile değiştirir, yenisini ekler, bozuğu atlar', () {
    final warnings = <String>[];
    final raw = jsonEncode({
      'schema': 1,
      'version': 7,
      'priceSites': [
        {
          'id': 'pandora',
          'name': 'Pandora (uzak)',
          'searchUrl': 'https://p.test/?q={isbn}',
          'priceSelector': 'span.x',
        },
        {
          'id': 'yeni',
          'name': 'Yeni',
          'searchUrl': 'https://y.test/?q={isbn}',
          'priceSelector': 'span.y',
        },
        {'id': 'bozuk', 'name': 'Bozuk', 'searchUrl': 'ftp://x'},
        {'name': 'idsiz'},
      ],
    });
    final s = parseRemoteConfig(raw,
        source: ConfigSource.server, warnings: warnings)!;

    expect(s.version, 7);
    expect(s.source, ConfigSource.server);
    expect(s.priceSites.first.id, 'pandora'); // uzak dosyadaki sıra önce
    expect(s.priceSites.firstWhere((c) => c.id == 'pandora').name, 'Pandora (uzak)');
    expect(s.priceSites.any((c) => c.id == 'yeni'), isTrue);
    expect(s.priceSites.any((c) => c.id == 'bozuk'), isFalse);
    expect(warnings.length, greaterThanOrEqualTo(2));
    // Uzakta olmayan gömülü siteler korunur.
    for (final b in defaultSites) {
      expect(s.priceSites.any((c) => c.id == b.id), isTrue, reason: b.id);
    }
  });

  test('enabled:false ile site kapatılabilir', () {
    final first = defaultSites.first;
    final raw = jsonEncode({
      'schema': 1,
      'priceSites': [
        {
          'id': first.id,
          'name': first.name,
          'searchUrl': first.searchUrl,
          'enabled': false,
        },
      ],
    });
    final s = parseRemoteConfig(raw, source: ConfigSource.server)!;
    expect(s.priceSites.firstWhere((c) => c.id == first.id).enabled, isFalse);
  });

  test('bozuk JSON, kök nesne değil ya da yeni şema -> null', () {
    expect(parseRemoteConfig('{bozuk', source: ConfigSource.server), isNull);
    expect(parseRemoteConfig('[1,2]', source: ConfigSource.server), isNull);
    expect(parseRemoteConfig('<html>hata</html>', source: ConfigSource.server), isNull);
    expect(
        parseRemoteConfig('{"schema": 99}', source: ConfigSource.server), isNull);
  });

  test('boş nesne gömülü ayarı aynen verir', () {
    final s = parseRemoteConfig('{}', source: ConfigSource.server)!;
    expect(s.priceSites.length, defaultSites.length);
    expect(s.searchSites.length, registry.searchSites.length);
  });

  test('özet kuralları doğrulanır', () {
    final w = <String>[];
    final s = parseRemoteConfig(
        jsonEncode({
          'descriptionRules': [
            {'host': 'a.com', 'selector': 'div.x', 'remove': ['h2']},
            {'host': '', 'selector': 'div.y'},
          ],
        }),
        source: ConfigSource.server,
        warnings: w)!;
    expect(s.descriptionRules.length, 1);
    expect(s.descriptionRules.first['remove'], ['h2']);
    expect(w, isNotEmpty);
  });

  test('yeni çıkanlar adresi: http(s) değilse gömülü kalır', () {
    final s = parseRemoteConfig(
        jsonEncode({
          'newReleases': {'url': 'javascript:alert(1)', 'siteId': 'kitapsec'},
        }),
        source: ConfigSource.server)!;
    expect(s.newReleasesUrl, defaultNewReleasesUrl);
    expect(s.newReleasesSiteId, 'kitapsec');
  });

  test('SearchSite ve SiteConfig JSON gidiş-dönüş', () {
    for (final s in registry.searchSites) {
      final back = SearchSite.fromJson(s.toJson());
      expect(back.id, s.id);
      expect(back.urlTemplate, s.urlTemplate);
      expect(back.titleSelector, s.titleSelector);
      expect(back.queryStyle, s.queryStyle);
      expect(back.imageAttr, s.imageAttr);
      expect(back.removeSelectors, s.removeSelectors);
    }
    for (final s in defaultSites) {
      final back = SiteConfig.fromJson(s.toJson());
      expect(back.id, s.id);
      expect(back.searchUrl, s.searchUrl);
      expect(back.priceSelector, s.priceSelector);
      expect(back.itemSelector, s.itemSelector);
      expect(back.fetchMode, s.fetchMode);
      expect(back.enabled, s.enabled);
    }
  });
}
