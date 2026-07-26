'use strict';

const axios = require('axios');
const cheerio = require('cheerio');
const crypto = require('crypto');

function temizle(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function fiyatDonustur(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  const raw = temizle(value).replace(/[^\d.,]/g, '');
  if (!raw) return null;

  let normalized = raw;
  const lastComma = normalized.lastIndexOf(',');
  const lastDot = normalized.lastIndexOf('.');

  if (lastComma > lastDot) {
    normalized = normalized.replace(/\./g, '').replace(',', '.');
  } else if (lastDot > lastComma) {
    normalized = normalized.replace(/,/g, '');
  } else {
    normalized = normalized.replace(',', '.');
  }

  const number = Number.parseFloat(normalized);
  return Number.isFinite(number) ? number : null;
}

function mutlakAdres(baseUrl, address) {
  const value = temizle(address);
  if (!value || value.startsWith('data:') || value.startsWith('javascript:')) {
    return '';
  }

  try {
    return new URL(value, baseUrl).toString();
  } catch (_) {
    return '';
  }
}

function hashOlustur(content) {
  return crypto.createHash('sha256').update(String(content || '')).digest('hex');
}

function metadanResim($, element, baseUrl) {
  const node = $(element);
  const img = node.is('img') ? node : node.find('img').first();
  const candidates = [
    img.attr('src'),
    img.attr('data-src'),
    img.attr('data-original'),
    img.attr('data-lazy-src'),
    img.attr('data-image'),
    img.attr('srcset'),
    node.attr('data-image')
  ];

  for (let candidate of candidates) {
    if (!candidate) continue;
    candidate = String(candidate).split(',')[0].trim().split(' ')[0].trim();
    const result = mutlakAdres(baseUrl, candidate);
    if (result) return result;
  }

  return '';
}

function linkBul($, element, baseUrl) {
  const node = $(element);
  const href = node.is('a')
    ? node.attr('href')
    : node.find('a[href]').first().attr('href');
  return mutlakAdres(baseUrl, href) || baseUrl;
}

function jsonLdUrunleriniBul($, config) {
  const products = [];

  $('script[type="application/ld+json"]').each((_, script) => {
    const raw = $(script).contents().text();
    if (!raw) return;

    try {
      const parsed = JSON.parse(raw);
      const queue = Array.isArray(parsed) ? [...parsed] : [parsed];

      while (queue.length) {
        const item = queue.shift();
        if (!item || typeof item !== 'object') continue;

        if (Array.isArray(item['@graph'])) queue.push(...item['@graph']);
        if (Array.isArray(item.itemListElement)) {
          for (const listItem of item.itemListElement) {
            if (listItem && listItem.item) queue.push(listItem.item);
            else queue.push(listItem);
          }
        }

        const type = Array.isArray(item['@type'])
          ? item['@type'].join(' ')
          : String(item['@type'] || '');

        if (!type.toLowerCase().includes('product')) continue;

        const offers = Array.isArray(item.offers) ? item.offers[0] : item.offers || {};
        const title = temizle(item.name);
        const currentPrice = fiyatDonustur(
          offers.price ?? offers.lowPrice ?? item.price
        );

        if (!title || currentPrice === null) continue;

        const image = Array.isArray(item.image) ? item.image[0] : item.image;
        products.push({
          title,
          currentPrice,
          oldPrice: null,
          imageUrl: mutlakAdres(config.url, image),
          officialUrl: mutlakAdres(config.url, item.url || offers.url) || config.url
        });
      }
    } catch (_) {
      // Geçersiz JSON-LD diğer ayrıştırma yöntemlerini engellemez.
    }
  });

  return products;
}

function domUrunleriniBul($, config) {
  const products = [];
  const selectors = [
    '[data-product]',
    '[data-product-id]',
    '.product-card',
    '.product-item',
    '.product-box',
    '.product',
    '[class*="product-card"]',
    '[class*="product-item"]',
    '[class*="productCard"]'
  ];

  $(selectors.join(',')).each((index, element) => {
    const node = $(element);
    const title = temizle(
      node.find('[itemprop="name"], .product-title, .product-name, [class*="product-name"], [class*="product-title"], h2, h3, h4')
        .first()
        .text()
    ) || temizle(node.find('img').first().attr('alt'));

    const fullText = temizle(node.text());
    const priceTexts = [];

    node.find('[itemprop="price"], .price, [class*="price"]').each((_, priceNode) => {
      const value = $(priceNode).attr('content') || $(priceNode).text();
      const parsed = fiyatDonustur(value);
      if (parsed !== null) priceTexts.push(parsed);
    });

    if (!priceTexts.length) {
      const matches = fullText.match(/(?:₺\s*)?(\d{1,3}(?:\.\d{3})*(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)\s*(?:₺|TL)/gi) || [];
      for (const match of matches) {
        const parsed = fiyatDonustur(match);
        if (parsed !== null) priceTexts.push(parsed);
      }
    }

    if (!title || !priceTexts.length) return;

    const uniquePrices = [...new Set(priceTexts)].sort((a, b) => a - b);
    const currentPrice = uniquePrices[0];
    const oldPrice = uniquePrices.length > 1
      ? uniquePrices[uniquePrices.length - 1]
      : null;

    products.push({
      title,
      currentPrice,
      oldPrice: oldPrice && oldPrice > currentPrice ? oldPrice : null,
      imageUrl: metadanResim($, element, config.url),
      officialUrl: linkBul($, element, config.url),
      index
    });
  });

  return products;
}

function metaUrunleriniBul($, config) {
  const title = temizle(
    $('meta[property="og:title"]').attr('content') ||
    $('title').text()
  );
  const price = fiyatDonustur(
    $('meta[property="product:price:amount"]').attr('content') ||
    $('[itemprop="price"]').first().attr('content')
  );

  if (!title || price === null) return [];

  return [{
    title,
    currentPrice: price,
    oldPrice: null,
    imageUrl: mutlakAdres(
      config.url,
      $('meta[property="og:image"]').attr('content')
    ),
    officialUrl: config.url
  }];
}

function benzersizUrunler(items, maxItems) {
  const seen = new Set();
  const result = [];

  for (const item of items) {
    const title = temizle(item.title);
    const currentPrice = fiyatDonustur(item.currentPrice);
    if (!title || currentPrice === null) continue;

    const key = `${title.toLocaleLowerCase('tr-TR')}|${currentPrice}`;
    if (seen.has(key)) continue;
    seen.add(key);

    result.push({ ...item, title, currentPrice });
    if (result.length >= maxItems) break;
  }

  return result;
}

function trendoraFormatinaCevir(items, config) {
  const now = new Date().toISOString();

  return items.map((item, index) => {
    const oldPrice = fiyatDonustur(item.oldPrice);
    const currentPrice = fiyatDonustur(item.currentPrice);
    const discountRate =
      oldPrice && currentPrice && oldPrice > currentPrice
        ? Math.round(((oldPrice - currentPrice) / oldPrice) * 100)
        : null;

    const stableId = hashOlustur(
      `${config.source}|${item.title}|${item.officialUrl || config.url}`
    ).slice(0, 18);

    return {
      id: `${config.source}-${stableId}`,
      title: temizle(item.title),
      description: `${config.seller} resmî internet sitesinde yayımlanan fırsat ürünü.`,
      category: 'market',
      source: config.source,
      store: config.source,
      currentPrice,
      oldPrice: oldPrice && oldPrice > currentPrice ? oldPrice : null,
      discountRate,
      seller: config.seller,
      shipping: '',
      imageUrl: mutlakAdres(config.url, item.imageUrl),
      officialUrl: mutlakAdres(config.url, item.officialUrl) || config.url,
      url: mutlakAdres(config.url, item.officialUrl) || config.url,
      catalogStartDate: null,
      catalogEndDate: null,
      verifiedAt: now,
      active: true,
      badge: discountRate ? `%${discountRate} indirim` : 'Market fırsatı',
      stockWarning: 'Fiyat ve stok; mağaza, bölge ve teslimat adresine göre değişebilir.'
    };
  });
}

async function marketUrunleriniGetir(config, previousState = {}) {
  const headers = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.7',
    Referer: new URL(config.url).origin + '/'
  };

  if (previousState.etag) headers['If-None-Match'] = previousState.etag;
  if (previousState.lastModified) {
    headers['If-Modified-Since'] = previousState.lastModified;
  }

  const response = await axios.get(config.url, {
    timeout: config.timeout || 30000,
    headers,
    maxRedirects: 5,
    responseType: 'text',
    validateStatus: status => status === 200 || status === 304
  });

  if (response.status === 304) {
    return {
      changed: false,
      reason: 'not-modified',
      items: [],
      state: {
        ...previousState,
        checkedAt: new Date().toISOString()
      }
    };
  }

  const html = String(response.data || '');
  const contentHash = hashOlustur(html);

  if (previousState.contentHash && previousState.contentHash === contentHash) {
    return {
      changed: false,
      reason: 'same-hash',
      items: [],
      state: {
        ...previousState,
        etag: response.headers.etag || previousState.etag || '',
        lastModified:
          response.headers['last-modified'] || previousState.lastModified || '',
        checkedAt: new Date().toISOString()
      }
    };
  }

  const $ = cheerio.load(html);
  const rawItems = [
    ...jsonLdUrunleriniBul($, config),
    ...domUrunleriniBul($, config),
    ...metaUrunleriniBul($, config)
  ];

  const unique = benzersizUrunler(rawItems, config.maxItems || 60);
  const items = trendoraFormatinaCevir(unique, config);

  return {
    changed: true,
    reason: 'content-changed',
    items,
    state: {
      contentHash,
      etag: response.headers.etag || '',
      lastModified: response.headers['last-modified'] || '',
      checkedAt: new Date().toISOString(),
      itemCount: items.length
    }
  };
}

module.exports = {
  marketUrunleriniGetir
};
