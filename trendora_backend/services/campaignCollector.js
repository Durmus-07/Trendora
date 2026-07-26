const axios = require('axios');
const cheerio = require('cheerio');
const crypto = require('crypto');

const BANK_SOURCES = [
  {
    key: 'akbank',
    name: 'Akbank',
    url: 'https://www.akbank.com/kampanyalar',
    color: '#E30613'
  },
  {
    key: 'garanti-bbva',
    name: 'Garanti BBVA',
    url: 'https://www.garantibbva.com.tr/kampanyalar',
    color: '#009640'
  },
  {
    key: 'bankkart',
    name: 'Bankkart',
    url: 'https://www.bankkart.com.tr/kampanyalar',
    color: '#C41230'
  }
];

const AUTOMOTIVE_SOURCES = [
  {
    key: 'kia',
    name: 'Kia',
    url: 'https://www.kia.com/tr/satis-merkezi/kampanyalar.html',
    color: '#05141F'
  },
  {
    key: 'volkswagen',
    name: 'Volkswagen',
    url: 'https://binekarac.vw.com.tr/tr/kampanyalar-ve-finansal-cozumler/satis-kampanyalari.html',
    color: '#001E50'
  },
  {
    key: 'renault',
    name: 'Renault',
    url: 'https://www.renault.com.tr/kampanyalar/satis-kampanyalari.html',
    color: '#FFCC00'
  },
  {
    key: 'toyota',
    name: 'Toyota',
    url: 'https://www.toyota.com.tr/kampanyalar',
    color: '#EB0A1E'
  }
];

const HTTP_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  Accept:
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.7',
  'Cache-Control': 'no-cache'
};

function cleanText(value) {
  return String(value || '')
    .replace(/\s+/g, ' ')
    .replace(/\u00a0/g, ' ')
    .trim();
}

function absoluteUrl(baseUrl, value) {
  const raw = cleanText(value);

  if (!raw || raw.startsWith('data:') || raw.startsWith('javascript:')) {
    return '';
  }

  try {
    return new URL(raw, baseUrl).toString();
  } catch (_) {
    return '';
  }
}

function firstImageFromSrcset(srcset) {
  const raw = cleanText(srcset);
  if (!raw) return '';

  const first = raw.split(',')[0] || '';
  return cleanText(first.split(/\s+/)[0]);
}

function imageFromElement($, element, baseUrl) {
  const node = $(element);
  const image = node.is('img') ? node : node.find('img').first();

  const candidates = [
    image.attr('src'),
    image.attr('data-src'),
    image.attr('data-lazy-src'),
    image.attr('data-original'),
    firstImageFromSrcset(image.attr('srcset')),
    firstImageFromSrcset(image.attr('data-srcset'))
  ];

  for (const candidate of candidates) {
    const result = absoluteUrl(baseUrl, candidate);
    if (result) return result;
  }

  const style = cleanText(node.attr('style'));
  const match = style.match(/background-image\s*:\s*url\((['"]?)(.*?)\1\)/i);
  if (match?.[2]) {
    return absoluteUrl(baseUrl, match[2]);
  }

  return '';
}

function pageMetaImage($, baseUrl) {
  const candidate =
    $('meta[property="og:image"]').attr('content') ||
    $('meta[name="twitter:image"]').attr('content') ||
    $('meta[itemprop="image"]').attr('content');

  return absoluteUrl(baseUrl, candidate);
}

function pageMetaDescription($) {
  return cleanText(
    $('meta[property="og:description"]').attr('content') ||
      $('meta[name="description"]').attr('content') ||
      $('meta[name="twitter:description"]').attr('content')
  );
}

function looksLikeCampaign(title, url, category) {
  const text = `${title} ${url}`.toLocaleLowerCase('tr-TR');

  const commonSignals = [
    'kampanya',
    'fırsat',
    'firsat',
    'indirim',
    'bonus',
    'chip-para',
    'puan',
    'iade',
    'taksit',
    'faiz',
    'kredi',
    'teklif',
    'avantaj',
    'kazandır',
    'kazandir',
    'tl',
    '%'
  ];

  const automotiveSignals = [
    'model',
    'araç',
    'arac',
    'satış',
    'satis',
    'servis',
    'bakım',
    'bakim',
    'takas'
  ];

  if (commonSignals.some(signal => text.includes(signal))) {
    return true;
  }

  return category === 'automotive' &&
    automotiveSignals.some(signal => text.includes(signal));
}

function isBadTitle(title) {
  const normalized = cleanText(title).toLocaleLowerCase('tr-TR');

  if (normalized.length < 6 || normalized.length > 180) return true;

  return [
    'detay',
    'incele',
    'daha fazla',
    'tüm kampanyalar',
    'tum kampanyalar',
    'kampanyalar',
    'hemen başvur',
    'hemen basvur',
    'teklif al',
    'keşfedin',
    'kesfedin'
  ].includes(normalized);
}

function stableId(category, sourceKey, title, officialUrl) {
  const hash = crypto
    .createHash('sha1')
    .update(`${category}|${sourceKey}|${title}|${officialUrl}`)
    .digest('hex')
    .slice(0, 20);

  return `${category}-${sourceKey}-${hash}`;
}

function titleFromContainer($, container) {
  const node = $(container);

  const heading = cleanText(
    node.find('h1, h2, h3, h4, h5, [class*="title"], [class*="baslik"]').first().text()
  );
  if (heading) return heading;

  const imageAlt = cleanText(node.find('img').first().attr('alt'));
  if (imageAlt) return imageAlt;

  const linkTitle = cleanText(node.find('a').first().attr('title'));
  if (linkTitle) return linkTitle;

  return cleanText(node.text()).slice(0, 180);
}

function descriptionFromContainer($, container, title) {
  const node = $(container);
  const paragraphs = node
    .find('p, [class*="description"], [class*="aciklama"], [class*="summary"]')
    .map((_, el) => cleanText($(el).text()))
    .get()
    .filter(Boolean);

  const description = paragraphs.find(text => text !== title) || '';
  return description.slice(0, 500);
}

function extractJsonLdCampaigns($, source, category) {
  const results = [];

  $('script[type="application/ld+json"]').each((_, element) => {
    const raw = $(element).contents().text();
    if (!raw) return;

    try {
      const parsed = JSON.parse(raw);
      const queue = Array.isArray(parsed) ? [...parsed] : [parsed];

      while (queue.length > 0) {
        const current = queue.shift();
        if (!current || typeof current !== 'object') continue;

        if (Array.isArray(current)) {
          queue.push(...current);
          continue;
        }

        for (const value of Object.values(current)) {
          if (value && typeof value === 'object') queue.push(value);
        }

        const title = cleanText(current.name || current.headline);
        const officialUrl = absoluteUrl(source.url, current.url);
        const imageValue = Array.isArray(current.image)
          ? current.image[0]
          : current.image?.url || current.image;
        const imageUrl = absoluteUrl(source.url, imageValue);
        const description = cleanText(current.description).slice(0, 500);

        if (
          title &&
          officialUrl &&
          !isBadTitle(title) &&
          looksLikeCampaign(title, officialUrl, category)
        ) {
          results.push({ title, officialUrl, imageUrl, description });
        }
      }
    } catch (_) {
      // Bazı siteler geçersiz JSON-LD döndürebilir; sayfa taraması devam eder.
    }
  });

  return results;
}

function extractDomCampaigns($, source, category) {
  const results = [];
  const selectors = [
    'article',
    '[class*="campaign"]',
    '[class*="kampanya"]',
    '[class*="promotion"]',
    '[class*="offer"]',
    '[class*="card"]',
    'a[href*="kampanya"]',
    'a[href*="campaign"]',
    'a[href*="teklif"]'
  ];

  $(selectors.join(',')).each((_, element) => {
    const node = $(element);
    const anchor = node.is('a') ? node : node.find('a[href]').first();
    const officialUrl = absoluteUrl(source.url, anchor.attr('href'));
    if (!officialUrl) return;

    const title = titleFromContainer($, node);
    if (isBadTitle(title)) return;
    if (!looksLikeCampaign(title, officialUrl, category)) return;

    results.push({
      title,
      officialUrl,
      imageUrl: imageFromElement($, node, source.url),
      description: descriptionFromContainer($, node, title)
    });
  });

  return results;
}

async function enrichMissingFields(item) {
  if (item.imageUrl && item.description) return item;

  try {
    const response = await axios.get(item.officialUrl, {
      headers: HTTP_HEADERS,
      timeout: 15000,
      maxRedirects: 5,
      responseType: 'text',
      validateStatus: status => status >= 200 && status < 400
    });

    const $ = cheerio.load(response.data);

    return {
      ...item,
      imageUrl: item.imageUrl || pageMetaImage($, item.officialUrl),
      description:
        item.description ||
        pageMetaDescription($) ||
        cleanText($('main p, article p').first().text()).slice(0, 500)
    };
  } catch (_) {
    return item;
  }
}

function toOpportunity(item, source, category) {
  const now = new Date().toISOString();
  const badge = category === 'bank' ? 'BANKA KAMPANYASI' : 'OTOMOBİL KAMPANYASI';

  return {
    id: stableId(category, source.key, item.title, item.officialUrl),
    category,
    source: source.key,
    sourceName: source.name,
    store: source.key,
    seller: source.name,
    title: item.title,
    description: item.description || `${source.name} resmî kampanya sayfasındaki güncel fırsat.`,
    imageUrl: item.imageUrl || '',
    officialUrl: item.officialUrl,
    url: item.officialUrl,
    campaignDate: 'Resmî kaynakta güncel',
    badge,
    rozet: badge,
    active: true,
    verified: true,
    verifiedAt: now,
    createdAt: now,
    collectedAt: now,
    sourceColor: source.color
  };
}

async function collectSource(source, category, maxItemsPerSource = 12) {
  try {
    const response = await axios.get(source.url, {
      headers: HTTP_HEADERS,
      timeout: 20000,
      maxRedirects: 5,
      responseType: 'text',
      validateStatus: status => status >= 200 && status < 400
    });

    const $ = cheerio.load(response.data);
    const rawItems = [
      ...extractJsonLdCampaigns($, source, category),
      ...extractDomCampaigns($, source, category)
    ];

    const deduped = [];
    const seen = new Set();

    for (const item of rawItems) {
      const key = `${cleanText(item.title).toLocaleLowerCase('tr-TR')}|${item.officialUrl}`;
      if (seen.has(key)) continue;
      seen.add(key);
      deduped.push(item);
      if (deduped.length >= maxItemsPerSource) break;
    }

    const enriched = [];
    for (const item of deduped) {
      enriched.push(await enrichMissingFields(item));
    }

    return {
      source: source.name,
      success: true,
      count: enriched.length,
      items: enriched.map(item => toOpportunity(item, source, category))
    };
  } catch (error) {
    console.error(`${source.name} kampanyaları alınamadı:`, error.message);

    return {
      source: source.name,
      success: false,
      count: 0,
      error: error.message,
      items: []
    };
  }
}

async function collectCampaignGroup(sources, category) {
  const results = await Promise.all(
    sources.map(source => collectSource(source, category))
  );

  return {
    category,
    sourceResults: results.map(result => ({
      source: result.source,
      success: result.success,
      count: result.count,
      error: result.error || null
    })),
    items: results.flatMap(result => result.items)
  };
}

async function bankaKampanyalariniGetir() {
  return collectCampaignGroup(BANK_SOURCES, 'bank');
}

async function otomobilKampanyalariniGetir() {
  return collectCampaignGroup(AUTOMOTIVE_SOURCES, 'automotive');
}

async function tumKampanyalariGetir() {
  const [bank, automotive] = await Promise.all([
    bankaKampanyalariniGetir(),
    otomobilKampanyalariniGetir()
  ]);

  return {
    bank,
    automotive,
    items: [...bank.items, ...automotive.items]
  };
}

module.exports = {
  BANK_SOURCES,
  AUTOMOTIVE_SOURCES,
  bankaKampanyalariniGetir,
  otomobilKampanyalariniGetir,
  tumKampanyalariGetir
};
