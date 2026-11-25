import 'search_site.dart';

/// Ad / yazar / yayınevi araması için kullanılan siteler.
/// Adresler ve seçiciler ESKİ Android kodundan (MainActivity.java) taşındı.
///
/// Sırayla denenir: ilk sitede sonuç çıkarsa onunla devam edilir; çıkmazsa ya da
/// hata verirse sıradaki siteye geçilir. Sırayı değiştirmek için blokları
/// yukarı/aşağı taşıyın; bir siteyi kapatmak için enabled: false yazın.
///
/// NOT: Seçiciler henüz canlı sayfalara karşı DOĞRULANMADI.
const List<SearchSite> searchSites = [
  SearchSite(
    id: 'istanbulkitapcisi',
    name: 'İstanbul Kitapçısı',
    urlTemplate: 'https://www.istanbulkitapcisi.com/arama?q={q}',
    queryStyle: QueryStyle.plus,
    titleSelector: 'a.col-12.product-title',
    imageSelector: 'picture.image-inner img',
    imageAttr: 'data-src',
    authorSelector: 'a.col-12.fw-bold.text-body.model-title',
    publisherSelector: 'a.col-12.fw-semibold.text-primary.brand-title',
    linkSelector: 'a.image-wrapper.image-animate-zoom',
  ),
  SearchSite(
    id: 'kitapyurdu',
    name: 'Kitapyurdu',
    urlTemplate:
        'https://www.kitapyurdu.com/index.php?route=product/search&sort=purchased&order=DESC&filter_name={q}&fuzzy=0&filter_product_type=1',
    removeSelectors: ['div.price-old.price-passive'],
    titleSelector: 'div#product-table div.name.ellipsis',
    imageSelector: 'div#product-table div.image img',
    imageFrom: 'wi:100',
    imageTo: 'wi:200',
    priceSelector: 'div#product-table div.price span.value',
    priceSuffix: ' TL',
    authorSelector: 'div#product-table div.author.compact.ellipsis',
    publisherSelector: 'div#product-table div.publisher',
    linkSelector: 'div#product-table div.image a',
  ),
  SearchSite(
    id: 'kitapsec',
    name: 'Kitapseç',
    urlTemplate: 'https://www.kitapsec.com/Arama/index.php?a={q}',
    titleSelector: 'tbody tr td a.text',
    imageSelector: 'tbody tr td a.img img',
    priceSelector: 'tbody tr td span.fiyat font.satis',
    authorSelector: 'tbody tr td span[itemprop="author"] span',
    publisherSelector: 'tbody tr td span.yynImg span',
    linkSelector: 'tbody tr td a.img',
    stripAuthorPublisherFromTitle: true,
  ),

];
