import 'site_config.dart';

/// Siteler ve seçiciler ESKİ Android kodundan (MainActivity.java) taşındı.
///
/// ÖNEMLİ: Seçiciler henüz canlı sayfalara karşı DOĞRULANMADI. Site tasarımı
/// değişmiş olabilir. Bir site "Bulunamadı" veriyorsa fiyat ekranındaki durum
/// mesajına bakın; gerekirse seçiciyi buradan güncelleyin (Aşama 3'te bu liste
/// sunucudan JSON olarak güncellenebilir hale gelecek).
const List<SiteConfig> defaultSites = [
  // ---- Düz HTTP ile çalışması beklenenler --------------------------------
  SiteConfig(
    id: 'trendyol',
    name: 'Trendyol',
    searchUrl: 'https://www.trendyol.com/sr?wc=91&os=1&sk=1&q={isbn}&sst=PRICE_BY_ASC',
    fetchMode: FetchMode.webview,          // <- WebView ile aç
    priceSelector: 'div.single-price, div.sale-price, span.price-value ',   // <- aynı süzme etiketi
    linkSelector: 'a.product-link',        // isteğe bağlı
    waitSelector: 'span.product-price',    // isteğe bağlı: bu öğe belirene kadar bekle
    webViewTimeoutSeconds: 10,             // isteğe bağlı: en çok kaç sn beklesin
  ),
  SiteConfig(
    id: 'hepsiburada',
    name: 'Hepsiburada',
    searchUrl: 'https://www.hepsiburada.com/ara?q={isbn}',
    priceSelector: 'div.price-module_finalPrice__LtjvY',
    linkSelector: 'adres',
    fetchMode: FetchMode.webview,
    webViewTimeoutSeconds: 10,

  ),
  SiteConfig(
    id: 'amazon',
    name: 'Amazon',
    fetchMode: FetchMode.webview,
    searchUrl: 'https://www.amazon.com.tr/s?k={isbn}',
    priceSelector: 'span.a-offscreen, div[data-cy=secondary-offer-recipe] span.a-color-base',
    linkSelector: '',
    webViewTimeoutSeconds: 10,
  ),
  SiteConfig(
    id: 'idefix',
    name: 'İdefix',
    searchUrl: 'https://www.idefix.com/search/?q={isbn}',
    fetchMode: FetchMode.webview,          // <- WebView ile aç
    priceSelector: 'span.inline-flex.items-baseline.whitespace-nowrap.text-title-sm-semibold.text-secondary-500',   // <- aynı süzme etiketi
    linkSelector: 'a.product-link',        // isteğe bağlı
    waitSelector: 'span.product-price',    // isteğe bağlı: bu öğe belirene kadar bekle
    webViewTimeoutSeconds: 5,             // isteğe bağlı: en çok kaç sn beklesin
  ),
  SiteConfig(
    id: 'kitapsec',
    name: 'Kitapseç',
    searchUrl: 'https://www.kitapsec.com/Arama/index.php?a={isbn}',
    priceSelector: 'span.fiyat font.satis',
    linkSelector: '',
  ),
  SiteConfig(
    id: 'tamadres',
    name: 'Tam Adres',
    searchUrl: 'https://tamadres.com/arama?q={isbn}',
    priceSelector: 'span.font-bold.text-primary.tabular-nums.min-w-0',
    linkSelector: '',
  ),
  SiteConfig(
    id: 'kitapzen',
    name: 'Kitapzen',
    searchUrl: 'https://www.kitapzen.com/search?p=Products&q_field_active=0&ctg_id=&q={isbn}',
    priceSelector: 'span.prd_view_price_value.final_price',
    linkSelector: '',
  ),
  /*
  SiteConfig(
    //web ile alınacak
    id: 'nadir',
    name: 'nadir',
    searchUrl: 'https://www.nadirkitap.com/kitapara.php?ara=aramayap&ref=detayliara&kategori=0&kitap_Adi=&yazar=&ceviren=&hazirlayan=&siralama=S%C4%B1ralama&satici=0&ortakkargo=0&yayin_Evi=&yayin_Yeri=&fiyat1=&fiyat2=&tarih1=0&tarih2=0&guzelciltli=0&birincibaski=0&imzali=0&eskiyeni=0&cilt=0&listele=&tip=kitap&dil=0&siralama=fiyatartan&isbn={isbn}',
    priceSelector: 'div.nkPriceWrap.d-block',
    linkSelector: '',
  ),
   */
  SiteConfig(
    id: 'n11',
    name: 'N11',
    searchUrl: 'https://www.n11.com/arama?srt=PRICE_LOW&q={isbn}',
    priceSelector: 'div.price-area h3.price-currency',
    linkSelector: '',
  ),
  SiteConfig(
    id: 'indekskitap',
    name: 'İndeks Kitap',
    searchUrl: 'https://www.indekskitap.com/sayfa/arama?q={isbn}',
    fetchMode: FetchMode.webview,          // <- WebView ile aç
    priceSelector: 'iks-results-grid.row div.showcase-price-new',   // <- aynı süzme etiketi
    linkSelector: 'a.product-link',        // isteğe bağlı
    waitSelector: 'span.product-price',    // isteğe bağlı: bu öğe belirene kadar bekle
    webViewTimeoutSeconds: 5,             // isteğe bağlı: en çok kaç sn beklesin
  ),
  SiteConfig(
    id: 'tercihkitabevi',
    name: 'Tercih Kitabevi',
    searchUrl: 'https://www.tercihkitabevi.com/arama?tip=1&kat=0&word={isbn}',
    priceSelector: 'div.urun_kdvdahil_fiyati',
    linkSelector: '',
  ),

  SiteConfig(
    id: 'kitapsepeti',
    name: 'Kitap Sepeti',
    searchUrl: 'https://www.kitapsepeti.com/arama?q={isbn}',
    fetchMode: FetchMode.webview,          // <- WebView ile aç
    priceSelector: 'span.product-price',   // <- aynı süzme etiketi
    linkSelector: 'a.product-link',        // isteğe bağlı
    waitSelector: 'span.product-price',    // isteğe bağlı: bu öğe belirene kadar bekle
    webViewTimeoutSeconds: 10,           // isteğe bağlı: en çok kaç sn beklesin
  ),
  SiteConfig(
    id: 'bkm',
    name: 'BKM Kitap',
    searchUrl: 'https://www.bkmkitap.com/arama?q={isbn}',
    priceSelector: 'span.product-price',
    linkSelector: 'ul#urunler li p.edebiyatIsim a',
  ),
  SiteConfig(
    id: 'dr',
    name: 'D&R',
    searchUrl: 'https://www.dr.com.tr/Search?q={isbn}',
    priceSelector: 'span.current-price',
    linkSelector: 'ul#urunler li p.edebiyatIsim a',
  ),

  SiteConfig(
    id: 'kitapyurdu',
    name: 'Kitapyurdu',
    searchUrl:
    'https://www.kitapyurdu.com/index.php?route=product/search&filter_name={title}&limit=200',
    itemSelector: 'div.ky-product',
    matchIsbnCore: false,                  // site ISBN'i kutuya gömmüyor
    matchTitleSelector: 'a.ky-product-title',        // kutunun içindeki kitap adı
    priceSelector: 'span.ky-product-price.ky-product-sell-price',
    linkSelector: '',
    structuredFallback: false,
    fetchMode: FetchMode.webview,
  ),
  SiteConfig(
    id: 'babil',
    name: 'Babil',
    searchUrl: 'https://babil.com/ara?q={isbn}',
    fetchMode: FetchMode.webview,          // <- WebView ile aç
    priceSelector: 'span.ui-price__current',   // <- aynı süzme etiketi
    linkSelector: '',        // isteğe bağlı
    waitSelector: '',    // isteğe bağlı: bu öğe belirene kadar bekle
    webViewTimeoutSeconds: 10,             // isteğe bağlı: en çok kaç sn beklesin
  ),
  SiteConfig(
    id: 'dost',
    name: 'Dost Kitabevi',
    searchUrl: 'https://dostkitabevi.com/search?q={isbn}&spellCheck=false',
    fetchMode: FetchMode.webview,          // <- WebView ile aç
    priceSelector: 'div.prices span.price.actual-price',   // <- aynı süzme etiketi
    linkSelector: '',        // isteğe bağlı
    waitSelector: '',    // isteğe bağlı: bu öğe belirene kadar bekle
    webViewTimeoutSeconds: 10,             // isteğe bağlı: en çok kaç sn beklesin
  ),
  SiteConfig(
    id: 'istanbulkitapcisi',
    name: 'İstanbul Kitapçısı',
    searchUrl: 'https://www.istanbulkitapcisi.com/arama?q={isbn}',
    priceSelector: 'div.current-price',
    linkSelector: 'a.image-wrapper',
  ),
  SiteConfig(
    id: 'ucuzkitapal',
    name: 'Ucuz Kitap Al',
    searchUrl: 'https://www.ucuzkitapal.com/{isbn}',
    priceSelector:
        'div#product_code_view_pagination_contents div.ty-column4 span.ty-price',
    linkSelector:
        'div#product_code_view_pagination_contents div.ut2-gl__image a',
  ),
  SiteConfig(
    id: 'kitappaketi',
    name: 'Kitap Paketi',
    searchUrl: 'https://kitappaketi.com/arama?q={isbn}',
    priceSelector: 'span.price-new',
    linkSelector: '',
  ),
];
