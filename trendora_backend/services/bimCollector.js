const axios = require('axios');
const cheerio = require('cheerio');

const BIM_URL =
  'https://www.bim.com.tr/categories/100/aktuel-urunler.aspx';

function temizle(value) {
  return String(value || '')
    .replace(/\s+/g, ' ')
    .trim();
}

function fiyatDonustur(value) {
  const temizFiyat = String(value || '')
    .replace(/[^\d.,]/g, '')
    .replace(/\./g, '')
    .replace(',', '.');

  const fiyat = Number.parseFloat(temizFiyat);

  return Number.isFinite(fiyat) ? fiyat : null;
}

function mutlakAdres(adres) {
  const value = temizle(adres);

  if (!value || value.startsWith('data:')) {
    return '';
  }

  if (
    value.startsWith('http://') ||
    value.startsWith('https://')
  ) {
    return value;
  }

  if (value.startsWith('//')) {
    return `https:${value}`;
  }

  if (value.startsWith('/')) {
    return `https://www.bim.com.tr${value}`;
  }

  return `https://www.bim.com.tr/${value}`;
}

function resimAdresiniBul(kart) {
  const img = kart.find('img').first();

  const adaylar = [
    img.attr('src'),
    img.attr('data-src'),
    img.attr('data-original'),
    img.attr('data-lazy'),
    img.attr('data-lazy-src'),
    img.attr('data-image'),
    img.attr('data-url'),
    img.attr('srcset')
  ];

  for (const aday of adaylar) {
    if (!aday) {
      continue;
    }

    let adres = String(aday).trim();

    if (adres.includes(',')) {
      adres = adres.split(',')[0].trim();
    }

    if (adres.includes(' ')) {
      adres = adres.split(' ')[0].trim();
    }

    const mutlak = mutlakAdres(adres);

    if (mutlak) {
      return mutlak;
    }
  }

  const styleAdaylari = [
    kart.attr('style') || '',
    kart
      .find('[style*="background-image"]')
      .first()
      .attr('style') || ''
  ];

  for (const style of styleAdaylari) {
    const eslesme = style.match(
      /background-image\s*:\s*url\(['"]?([^'")]+)/
    );

    if (eslesme) {
      return mutlakAdres(eslesme[1]);
    }
  }

  return '';
}

function urunLinkiniBul($, kart) {
  const linkAdaylari = [];

  if (kart.is('a')) {
    linkAdaylari.push(kart.attr('href'));
  }

  kart.find('a').each((index, element) => {
    linkAdaylari.push($(element).attr('href'));
  });

  for (const aday of linkAdaylari) {
    const link = mutlakAdres(aday);

    if (
      link &&
      link !== 'https://www.bim.com.tr/' &&
      !link.toLowerCase().includes('javascript:')
    ) {
      return link;
    }
  }

  return BIM_URL;
}

function kelimeyiDuzenle(kelime) {
  const value = temizle(kelime);

  if (!value) {
    return '';
  }

  const tamamenSayi = /^\d+$/.test(value);
  const modelKodu = /^(?=.*\d)[a-z0-9]+$/i.test(value);
  const kisaKod = /^[a-z]{1,4}$/i.test(value);

  if (tamamenSayi || modelKodu || kisaKod) {
    return value.toUpperCase();
  }

  return value.charAt(0).toLocaleUpperCase('tr-TR') +
    value.slice(1).toLocaleLowerCase('tr-TR');
}

function linktenBaslikUret(link) {
  try {
    const uri = new URL(link);
    const parcalar = uri.pathname
      .split('/')
      .filter(Boolean);

    const slug = parcalar.find(
      parca => parca !== 'aktuel-urunler'
    );

    if (!slug) {
      return '';
    }

    const temizSlug = decodeURIComponent(slug)
      .replace(/-\d+-\d+$/i, '')
      .replace(/-aktuel$/i, '')
      .replace(/[-_]+/g, ' ');

    return temizSlug
      .split(' ')
      .filter(Boolean)
      .map(kelimeyiDuzenle)
      .join(' ');
  } catch (error) {
    return '';
  }
}

function adayBasliklariBul($, kart) {
  const adaylar = [];

  const seciciler = [
    '[itemprop="name"]',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    '.title',
    '.product-title',
    '.product-name',
    '.name',
    '[class*="title"]',
    '[class*="name"]'
  ];

  kart.find(seciciler.join(',')).each(
    (index, element) => {
      const metin = temizle($(element).text());

      if (metin) {
        adaylar.push(metin);
      }
    }
  );

  const img = kart.find('img').first();

  adaylar.push(
    temizle(img.attr('alt')),
    temizle(img.attr('title')),
    temizle(kart.attr('title')),
    temizle(kart.attr('aria-label'))
  );

  return adaylar.filter(Boolean);
}
function baslikKalitesiniHesapla(baslik) {
  const kelimeler = temizle(baslik)
    .split(' ')
    .filter(Boolean);

  let puan = baslik.length;

  if (kelimeler.length >= 3) {
    puan += 100;
  } else if (kelimeler.length === 2) {
    puan += 40;
  }

  if (/\d/.test(baslik)) {
    puan += 30;
  }

  return puan;
}

function urunBasliginiBul($, kart, link) {
  const sayfaAdaylari =
    adayBasliklariBul($, kart);

  const linkBasligi =
    linktenBaslikUret(link);

  const tumAdaylar = [
    ...sayfaAdaylari,
    linkBasligi
  ]
    .map(temizle)
    .filter(Boolean)
    .filter(
      baslik =>
        !/^\d{1,3}(?:\.\d{3})*(?:,\d{2})?\s*(?:₺|TL)$/i
          .test(baslik)
    );

  if (tumAdaylar.length === 0) {
    return '';
  }

  tumAdaylar.sort(
    (a, b) =>
      baslikKalitesiniHesapla(b) -
      baslikKalitesiniHesapla(a)
  );

  const secilen = tumAdaylar[0];

  if (
    linkBasligi &&
    secilen.split(' ').length === 1 &&
    linkBasligi
      .toLocaleLowerCase('tr-TR')
      .startsWith(
        secilen.toLocaleLowerCase('tr-TR')
      )
  ) {
    return linkBasligi;
  }

  return secilen;
}

function benzersizUrunler(items) {
  const sonuc = [];
  const kontrol = new Set();

  for (const item of items) {
    const anahtar = [
      item.officialUrl,
      item.title,
      item.currentPrice
    ]
      .join('|')
      .toLocaleLowerCase('tr-TR');

    if (!item.title || kontrol.has(anahtar)) {
      continue;
    }

    kontrol.add(anahtar);
    sonuc.push(item);
  }

  return sonuc;
}

function urunNesnesiOlustur({
  baslik,
  fiyat,
  resim,
  link,
  index
}) {
  const simdi = new Date().toISOString();

  return {
    id: `bim-${Date.now()}-${index}`,
    title: baslik,
    description:
      'BİM resmî aktüel ürün sayfasında yayımlanan ürün.',
    category: 'market',
    source: 'bim',
    currentPrice: fiyat,
    oldPrice: null,
    discountRate: null,
    seller: 'BİM',
    shipping: '',
    imageUrl: resim,
    officialUrl: link || BIM_URL,
    url: link || BIM_URL,
    catalogStartDate: null,
    catalogEndDate: null,
    verifiedAt: simdi,
    active: true,
    badge: 'Aktüel ürün',
    stockWarning:
      'Ürün ve mağaza stoğu bölgeye göre değişebilir.'
  };
}

async function bimUrunleriniGetir() {
  const response = await axios.get(
    BIM_URL,
    {
      timeout: 30000,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ' +
          'AppleWebKit/537.36 (KHTML, like Gecko) ' +
          'Chrome/126.0.0.0 Safari/537.36',

        Accept:
          'text/html,application/xhtml+xml,application/xml;' +
          'q=0.9,image/avif,image/webp,*/*;q=0.8',

        'Accept-Language':
          'tr-TR,tr;q=0.9,en;q=0.8',

        Referer:
          'https://www.bim.com.tr/'
      }
    }
  );

  const $ = cheerio.load(response.data);
  const urunler = [];

  const kartSecicileri = [
    '.product',
    '.product-item',
    '.product-card',
    '.aktuel-urun',
    '.aktuelUrun',
    '.item',
    '.card',
    '.product-box',
    '.productArea',
    '.product-area',
    '.col-md-3',
    '.col-md-4',
    '.col-sm-4',
    '.col-sm-6',
    '[class*="product"]',
    '[class*="urun"]'
  ];

  $(kartSecicileri.join(',')).each(
    (index, element) => {
      const kart = $(element);

      const kartMetni = temizle(
        kart.text()
      );

      const fiyatEslesmesi =
        kartMetni.match(
          /(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)\s*(?:₺|TL)/i
        );

      if (!fiyatEslesmesi) {
        return;
      }

      const fiyat = fiyatDonustur(
        fiyatEslesmesi[1]
      );

      if (fiyat === null) {
        return;
      }

      const link = urunLinkiniBul(
        $,
        kart
      );

      const baslik = urunBasliginiBul(
        $,
        kart,
        link
      );

      if (!baslik) {
        return;
      }

      const resim =
        resimAdresiniBul(kart);

      urunler.push(
        urunNesnesiOlustur({
          baslik,
          fiyat,
          resim,
          link,
          index
        })
      );
    }
  );

  return benzersizUrunler(
    urunler
  );
}

module.exports = {
  bimUrunleriniGetir
};