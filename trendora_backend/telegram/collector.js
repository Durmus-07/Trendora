require('dotenv').config();

const fs = require('fs');
const path = require('path');
const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');

const channels = require('./channels');

const DATABASE_FILE = path.join(
  __dirname,
  '..',
  'database',
  'opportunities.json'
);

const MESSAGE_LIMIT_PER_CHANNEL = 30;
const MAX_STORED_TELEGRAM_ITEMS = 1000;

const PAGE_FETCH_TIMEOUT_MS = 12000;
const PAGE_FETCH_CONCURRENCY = 4;
const MAX_PAGE_BYTES = 1_500_000;

function requiredEnv(name) {
  const value = String(process.env[name] || '').trim();

  if (!value) {
    throw new Error(`${name} .env dosyasında boş veya eksik.`);
  }

  return value;
}

function readDatabase() {
  try {
    if (!fs.existsSync(DATABASE_FILE)) {
      return {
        updatedAt: null,
        items: []
      };
    }

    const parsed = JSON.parse(
      fs.readFileSync(DATABASE_FILE, 'utf8')
    );

    return {
      updatedAt: parsed.updatedAt || null,
      items: Array.isArray(parsed.items)
        ? parsed.items
        : []
    };
  } catch (error) {
    console.error(
      'opportunities.json okunamadı:',
      error.message
    );

    return {
      updatedAt: null,
      items: []
    };
  }
}

function writeDatabase(items) {
  const databaseDir = path.dirname(DATABASE_FILE);

  if (!fs.existsSync(databaseDir)) {
    fs.mkdirSync(databaseDir, {
      recursive: true
    });
  }

  const database = {
    updatedAt: new Date().toISOString(),
    items
  };

  fs.writeFileSync(
    DATABASE_FILE,
    JSON.stringify(database, null, 2),
    'utf8'
  );

  return database;
}

function normalizeText(value) {
  return String(value || '')
    .replace(/\r/g, '')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function normalizeForSearch(value) {
  return String(value || '')
    .toLocaleLowerCase('tr-TR')
    .replace(/ı/g, 'i')
    .replace(/ş/g, 's')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .trim();
}

function firstNonEmptyLine(text) {
  return normalizeText(text)
    .split('\n')
    .map(line => line.trim())
    .find(Boolean) || 'Telegram fırsatı';
}

function cleanUrl(value) {
  return String(value || '')
    .replace(/[.,;!?]+$/g, '')
    .trim();
}

function extractUrls(text) {
  const matches = String(text || '').match(
    /https?:\/\/[^\s<>"')\]]+/gi
  );

  return matches
    ? [...new Set(matches.map(cleanUrl))]
    : [];
}

function cleanPriceNumber(value) {
  let raw = String(value || '')
    .replace(/\s/g, '')
    .replace(/[^\d.,]/g, '');

  if (!raw) {
    return null;
  }

  const commaCount = (raw.match(/,/g) || []).length;
  const dotCount = (raw.match(/\./g) || []).length;

  if (commaCount > 0 && dotCount > 0) {
    const lastComma = raw.lastIndexOf(',');
    const lastDot = raw.lastIndexOf('.');

    if (lastComma > lastDot) {
      raw = raw
        .replace(/\./g, '')
        .replace(',', '.');
    } else {
      raw = raw.replace(/,/g, '');
    }
  } else if (commaCount === 1) {
    const parts = raw.split(',');

    raw = parts[1].length === 2
      ? `${parts[0]}.${parts[1]}`
      : parts.join('');
  } else if (dotCount === 1) {
    const parts = raw.split('.');

    // 8.799 çoğunlukla 8799 TL, 8.99 ise 8,99 TL kabul edilir.
    raw = parts[1].length === 2
      ? `${parts[0]}.${parts[1]}`
      : parts.join('');
  } else {
    raw = raw.replace(/[.,]/g, '');
  }

  const parsed = Number(raw);

  return Number.isFinite(parsed)
    ? parsed
    : null;
}

function extractPrices(text) {
  const source = String(text || '');

  const regex =
    /(?:₺\s?[\d.,]+|[\d.,]+\s?(?:₺|TL|TRY))/gi;

  const found = source.match(regex) || [];

  return found
    .map(raw => ({
      raw: raw.trim(),
      value: cleanPriceNumber(raw)
    }))
    .filter(item => item.value !== null);
}

function detectStore(text, urls) {
  const haystack = normalizeForSearch(
    `${text} ${urls.join(' ')}`
  );

  const stores = [
    ['Amazon', ['amazon.', 'amzn.', 'publicis.link/amzn']],
    ['Trendyol', ['trendyol.', 'ty.gl/']],
    ['Hepsiburada', ['hepsiburada.', 'hb.biz/', 'app.hb.biz/']],
    ['N11', ['n11.', 'sl.n11.com/']],
    ['A101', ['a101.']],
    ['BİM', ['bim.']],
    ['ŞOK', ['sokmarket.', 'sok.']],
    ['Migros', ['migros.']],
    ['CarrefourSA', ['carrefoursa.']],
    ['Pazarama', ['pazarama.', 'publicis.link/pazarama']],
    ['Teknosa', ['teknosa.']],
    ['MediaMarkt', ['mediamarkt.']],
    ['Vatan', ['vatanbilgisayar.']],
    ['ÇiçekSepeti', ['ciceksepeti.']],
    ['Boyner', ['boyner.']]
  ];

  for (const [name, keys] of stores) {
    if (keys.some(key => haystack.includes(key))) {
      return name;
    }
  }

  return 'Telegram';
}

function detectCategory(text) {
  const value = normalizeForSearch(text);

  const categoryRules = [
    [
      'Elektronik',
      [
        'telefon',
        'tablet',
        'laptop',
        'bilgisayar',
        'kulaklik',
        'televizyon',
        'sarj',
        'powerbank',
        'oyuncu',
        'ssd',
        'ekran karti',
        'kamera'
      ]
    ],
    [
      'Ev & Yaşam',
      [
        'mobilya',
        'koltuk',
        'masa',
        'sandalye',
        'mutfak',
        'tencere',
        'nevresim',
        'supurge',
        'airfryer',
        'kahve makinesi',
        'buzdolabi',
        'camasir makinesi'
      ]
    ],
    [
      'Market',
      [
        'market',
        'gida',
        'cikolata',
        'kahve',
        'cay',
        'deterjan',
        'sampuan',
        'bebek bezi',
        'mama',
        'aycicek yagi'
      ]
    ],
    [
      'Giyim',
      [
        'ayakkabi',
        'mont',
        'pantolon',
        'tisort',
        'kazak',
        'elbise',
        'canta',
        'sandalet'
      ]
    ],
    [
      'Otomotiv',
      [
        'lastik',
        'motor yagi',
        'otomobil',
        'arac',
        'oto '
      ]
    ],
    [
      'Kozmetik',
      [
        'parfum',
        'kozmetik',
        'krem',
        'makyaj'
      ]
    ]
  ];

  for (const [category, keywords] of categoryRules) {
    if (keywords.some(keyword => value.includes(keyword))) {
      return category;
    }
  }

  return 'Genel';
}

function makeTelegramMessageUrl(channel, messageId) {
  if (channel.type === 'public') {
    return `https://t.me/${channel.username}/${messageId}`;
  }

  return `https://t.me/c/${channel.channelId}/${messageId}`;
}

function messageDateToIso(message) {
  if (!message.date) {
    return new Date().toISOString();
  }

  if (message.date instanceof Date) {
    return message.date.toISOString();
  }

  if (typeof message.date === 'number') {
    const milliseconds =
      message.date < 10_000_000_000
        ? message.date * 1000
        : message.date;

    const parsedFromNumber =
      new Date(milliseconds);

    return Number.isNaN(parsedFromNumber.getTime())
      ? new Date().toISOString()
      : parsedFromNumber.toISOString();
  }

  const parsed = new Date(message.date);

  return Number.isNaN(parsed.getTime())
    ? new Date().toISOString()
    : parsed.toISOString();
}

function decodeHtmlEntities(value) {
  return String(value || '')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>');
}

function absoluteUrl(value, baseUrl) {
  try {
    return new URL(
      decodeHtmlEntities(value),
      baseUrl
    ).toString();
  } catch {
    return '';
  }
}

function extractMetaContent(html, names) {
  for (const name of names) {
    const escaped = name.replace(
      /[.*+?^${}()|[\]\\]/g,
      '\\$&'
    );

    const patterns = [
      new RegExp(
        `<meta[^>]+(?:property|name)=["']${escaped}["'][^>]+content=["']([^"']+)["'][^>]*>`,
        'i'
      ),
      new RegExp(
        `<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']${escaped}["'][^>]*>`,
        'i'
      )
    ];

    for (const pattern of patterns) {
      const match = html.match(pattern);

      if (match && match[1]) {
        return decodeHtmlEntities(match[1]).trim();
      }
    }
  }

  return '';
}

function extractJsonLdProducts(html) {
  const results = [];
  const regex =
    /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;

  let match;

  while ((match = regex.exec(html))) {
    const raw = match[1].trim();

    if (!raw) continue;

    try {
      const parsed = JSON.parse(raw);
      const stack = Array.isArray(parsed)
        ? [...parsed]
        : [parsed];

      while (stack.length > 0) {
        const item = stack.shift();

        if (!item || typeof item !== 'object') {
          continue;
        }

        if (Array.isArray(item)) {
          stack.push(...item);
          continue;
        }

        const type = Array.isArray(item['@type'])
          ? item['@type'].join(' ')
          : String(item['@type'] || '');

        if (
          type.toLocaleLowerCase('en-US')
            .includes('product')
        ) {
          results.push(item);
        }

        if (Array.isArray(item['@graph'])) {
          stack.push(...item['@graph']);
        }
      }
    } catch {
      // Bozuk JSON-LD blokları atlanır.
    }
  }

  return results;
}

function imageFromJsonLd(product, baseUrl) {
  const image = product && product.image;

  if (Array.isArray(image)) {
    for (const candidate of image) {
      if (typeof candidate === 'string') {
        const resolved = absoluteUrl(
          candidate,
          baseUrl
        );

        if (resolved) return resolved;
      }

      if (
        candidate &&
        typeof candidate === 'object' &&
        candidate.url
      ) {
        const resolved = absoluteUrl(
          candidate.url,
          baseUrl
        );

        if (resolved) return resolved;
      }
    }
  }

  if (typeof image === 'string') {
    return absoluteUrl(
      image,
      baseUrl
    );
  }

  if (
    image &&
    typeof image === 'object' &&
    image.url
  ) {
    return absoluteUrl(
      image.url,
      baseUrl
    );
  }

  return '';
}

function priceFromJsonLd(product) {
  if (!product || typeof product !== 'object') {
    return null;
  }

  const offers = Array.isArray(product.offers)
    ? product.offers
    : [product.offers].filter(Boolean);

  for (const offer of offers) {
    if (!offer || typeof offer !== 'object') {
      continue;
    }

    const candidate =
      offer.price ??
      offer.lowPrice ??
      offer.highPrice;

    const parsed = cleanPriceNumber(candidate);

    if (parsed !== null && parsed > 0) {
      return parsed;
    }
  }

  return null;
}

function titleSimilarity(a, b) {
  const left = new Set(
    normalizeForSearch(a)
      .split(/[^a-z0-9]+/)
      .filter(token => token.length >= 3)
  );

  const right = new Set(
    normalizeForSearch(b)
      .split(/[^a-z0-9]+/)
      .filter(token => token.length >= 3)
  );

  if (left.size === 0 || right.size === 0) {
    return 0;
  }

  let common = 0;

  for (const token of left) {
    if (right.has(token)) {
      common += 1;
    }
  }

  return common / Math.min(left.size, right.size);
}

function isLikelyProductImage(url) {
  const value = normalizeForSearch(url);

  if (!value.startsWith('http')) {
    return false;
  }

  const blocked = [
    'logo',
    'icon',
    'favicon',
    'sprite',
    'avatar',
    'profile',
    'banner',
    'placeholder',
    'default-image'
  ];

  return !blocked.some(word =>
    value.includes(word)
  );
}

function isCouponOnlyMessage(text) {
  const value = normalizeForSearch(text);

  const couponWords = [
    'kuponmatik',
    'indirim kodu',
    'kupon kodu',
    'alt limitsiz',
    'kampanyali urunleri gor',
    'urunlere git',
    'bakiyenizi kontrol edin',
    'hediye kartiniza bakiye',
    '2.sine %',
    'ikinci urune'
  ];

  const productWords = [
    'telefon',
    'ayakkabi',
    'tisort',
    'sampuan',
    'mama',
    'powerbank',
    'buzdolabi',
    'camasir makinesi',
    'kahve makinesi',
    'parfum',
    'klima',
    'termos',
    'yag',
    'deterjan',
    'kulaklik',
    'tablet',
    'laptop',
    'kamera'
  ];

  const hasCouponAnnouncement =
    couponWords.some(word => value.includes(word));

  const hasConcreteProduct =
    productWords.some(word => value.includes(word));

  return hasCouponAnnouncement && !hasConcreteProduct;
}

function looksLikeProductTitle(title) {
  const value = normalizeForSearch(title);

  if (!value || value.length < 8) {
    return false;
  }

  const blockedStarts = [
    'kuponmatik geldi',
    'indirim kodu',
    'kupon kodu',
    'amazon bakiyenizi',
    'urunlere git',
    'kampanya geldi',
    'firsat kodu'
  ];

  if (blockedStarts.some(prefix =>
    value.startsWith(prefix)
  )) {
    return false;
  }

  return true;
}

async function fetchPageMetadata(url, expectedTitle) {
  const controller =
    new AbortController();

  const timeout = setTimeout(
    () => controller.abort(),
    PAGE_FETCH_TIMEOUT_MS
  );

  try {
    const response = await fetch(url, {
      redirect: 'follow',
      signal: controller.signal,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36',
        'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language':
          'tr-TR,tr;q=0.9,en;q=0.7'
      }
    });

    if (!response.ok) {
      return {
        ok: false,
        finalUrl: response.url || url
      };
    }

    const contentType =
      String(response.headers.get('content-type') || '');

    if (!contentType.includes('text/html')) {
      return {
        ok: false,
        finalUrl: response.url || url
      };
    }

    const contentLength = Number(
      response.headers.get('content-length') || 0
    );

    if (
      contentLength > 0 &&
      contentLength > MAX_PAGE_BYTES
    ) {
      return {
        ok: false,
        finalUrl: response.url || url
      };
    }

    const html = (
      await response.text()
    ).slice(0, MAX_PAGE_BYTES);

    const finalUrl = response.url || url;
    const products = extractJsonLdProducts(html);
    const product = products[0] || null;

    const pageTitle =
      (product && product.name) ||
      extractMetaContent(html, [
        'og:title',
        'twitter:title'
      ]) ||
      '';

    const ogImage = extractMetaContent(html, [
      'og:image',
      'og:image:secure_url',
      'twitter:image',
      'twitter:image:src'
    ]);

    const jsonLdImage =
      imageFromJsonLd(product, finalUrl);

    const imageUrl =
      isLikelyProductImage(jsonLdImage)
        ? jsonLdImage
        : (
            isLikelyProductImage(
              absoluteUrl(ogImage, finalUrl)
            )
              ? absoluteUrl(ogImage, finalUrl)
              : ''
          );

    const jsonLdPrice =
      priceFromJsonLd(product);

    const metaPrice = cleanPriceNumber(
      extractMetaContent(html, [
        'product:price:amount',
        'og:price:amount'
      ])
    );

    const livePrice =
      jsonLdPrice ??
      metaPrice;

    const similarity =
      titleSimilarity(
        expectedTitle,
        pageTitle
      );

    const verifiedProduct =
      Boolean(product) ||
      (
        pageTitle &&
        similarity >= 0.25 &&
        Boolean(imageUrl)
      );

    return {
      ok: true,
      finalUrl,
      pageTitle: normalizeText(pageTitle),
      imageUrl,
      livePrice,
      verifiedProduct,
      titleSimilarity: similarity
    };
  } catch {
    return {
      ok: false,
      finalUrl: url
    };
  } finally {
    clearTimeout(timeout);
  }
}

function calculateDiscountPercent(
  oldPrice,
  currentPrice
) {
  if (
    !oldPrice ||
    !currentPrice ||
    oldPrice <= currentPrice
  ) {
    return null;
  }

  return Math.round(
    ((oldPrice - currentPrice) / oldPrice) * 100
  );
}

function priceDifferencePercent(a, b) {
  if (!a || !b) {
    return null;
  }

  return Math.round(
    (Math.abs(a - b) / Math.max(a, b)) * 100
  );
}

function createBaseOpportunity(channel, message) {
  const text = normalizeText(
    message.message || message.text || ''
  );

  if (!text) {
    return null;
  }

  if (isCouponOnlyMessage(text)) {
    return null;
  }

  const title =
    firstNonEmptyLine(text).slice(0, 180);

  if (!looksLikeProductTitle(title)) {
    return null;
  }

  const urls = extractUrls(text);
  const prices = extractPrices(text);

  const advertisedPrice = prices.length > 0
    ? prices[prices.length - 1].value
    : null;

  const advertisedOldPrice = prices.length > 1
    ? prices[0].value
    : null;

  const messageUrl = makeTelegramMessageUrl(
    channel,
    message.id
  );

  const productUrl =
    urls.find(url => !url.includes('t.me/')) ||
    '';

  /*
    Ürün bağlantısı olmayan salt duyurular alınmaz.
    Özel kanaldaki gerçek ürün mesajı link içermiyorsa Telegram
    mesaj linki kullanılabilir ancak doğrulanmış sayılmaz.
  */
  if (!productUrl && channel.type === 'public') {
    return null;
  }

  return {
    channel,
    message,
    text,
    urls,
    title,
    messageUrl,
    productUrl,
    advertisedPrice,
    advertisedOldPrice
  };
}

async function enrichOpportunity(base) {
  const metadata = base.productUrl
    ? await fetchPageMetadata(
        base.productUrl,
        base.title
      )
    : {
        ok: false,
        finalUrl: base.messageUrl
      };

  /*
    Ürün sayfası doğrulanamadıysa ve mesaj da net ürün değilse kayıt alınmaz.
  */
  const verifiedProduct =
    metadata.verifiedProduct === true;

  if (
    base.productUrl &&
    metadata.ok &&
    !verifiedProduct &&
    titleSimilarity(
      base.title,
      metadata.pageTitle || ''
    ) < 0.15
  ) {
    return null;
  }

  const livePrice =
    metadata.livePrice || null;

  const currentPrice =
    livePrice ||
    base.advertisedPrice ||
    null;

  const oldPrice =
    base.advertisedOldPrice &&
    currentPrice &&
    base.advertisedOldPrice > currentPrice
      ? base.advertisedOldPrice
      : null;

  const mismatchPercent =
    livePrice &&
    base.advertisedPrice
      ? priceDifferencePercent(
          livePrice,
          base.advertisedPrice
        )
      : null;

  const priceMatches =
    mismatchPercent === null
      ? null
      : mismatchPercent <= 5;

  const finalUrl =
    metadata.finalUrl ||
    base.productUrl ||
    base.messageUrl;

  const finalTitle =
    verifiedProduct &&
    metadata.pageTitle &&
    titleSimilarity(
      base.title,
      metadata.pageTitle
    ) >= 0.25
      ? metadata.pageTitle.slice(0, 180)
      : base.title;

  const store = detectStore(
    `${base.text} ${metadata.pageTitle || ''}`,
    [
      ...base.urls,
      finalUrl
    ]
  );

  return {
    id: `telegram:${base.channel.type}:${base.channel.username || base.channel.channelId}:${base.message.id}`,
    source: 'telegram',
    sourceName: base.channel.name,
    sourceChannel:
      base.channel.username
        ? `@${base.channel.username}`
        : base.channel.channelId,
    telegramMessageId:
      String(base.message.id),
    telegramMessageUrl:
      base.messageUrl,
    title: finalTitle,
    description: base.text,
    category: detectCategory(
      `${finalTitle} ${base.text}`
    ),
    store,
    oldPrice,
    advertisedPrice:
      base.advertisedPrice,
    livePrice,
    price: currentPrice,
    currentPrice,
    discountPercent:
      calculateDiscountPercent(
        oldPrice,
        currentPrice
      ),
    currency: 'TRY',
    url: finalUrl,
    officialUrl: finalUrl,
    imageUrl:
      metadata.imageUrl || '',
    publishedAt:
      messageDateToIso(base.message),
    collectedAt:
      new Date().toISOString(),
    active: true,
    verifiedAt:
      verifiedProduct
        ? new Date().toISOString()
        : null,
    verified: verifiedProduct,
    priceMatches,
    priceDifferencePercent:
      mismatchPercent,
    priceStatus:
      priceMatches === false
        ? 'changed'
        : (
            priceMatches === true
              ? 'matched'
              : 'unknown'
          ),
    rawLinks: base.urls
  };
}

async function resolvePrivateEntity(client, channel) {
  const dialogs = await client.getDialogs({
    limit: 500
  });

  const match = dialogs.find(dialog => {
    const dialogId = String(dialog.id || '');
    const entityId = String(
      dialog.entity && dialog.entity.id
        ? dialog.entity.id
        : ''
    );

    return (
      dialogId === channel.channelId ||
      dialogId === `-100${channel.channelId}` ||
      dialogId.endsWith(channel.channelId) ||
      entityId === channel.channelId
    );
  });

  if (!match) {
    throw new Error(
      `${channel.name} özel kanalı, hesabın diyaloglarında bulunamadı.`
    );
  }

  return match.entity;
}

async function resolveChannelEntity(client, channel) {
  if (channel.type === 'public') {
    return client.getEntity(channel.username);
  }

  return resolvePrivateEntity(client, channel);
}

async function mapWithConcurrency(
  values,
  limit,
  mapper
) {
  const results = new Array(values.length);
  let nextIndex = 0;

  async function worker() {
    while (true) {
      const currentIndex = nextIndex;
      nextIndex += 1;

      if (currentIndex >= values.length) {
        return;
      }

      try {
        results[currentIndex] =
          await mapper(
            values[currentIndex],
            currentIndex
          );
      } catch (error) {
        console.error(
          'Fırsat zenginleştirme hatası:',
          error.message
        );

        results[currentIndex] = null;
      }
    }
  }

  const workers = Array.from(
    {
      length: Math.min(
        limit,
        values.length
      )
    },
    () => worker()
  );

  await Promise.all(workers);

  return results;
}

async function collectChannel(client, channel) {
  const entity = await resolveChannelEntity(
    client,
    channel
  );

  const messages = await client.getMessages(
    entity,
    {
      limit: MESSAGE_LIMIT_PER_CHANNEL
    }
  );

  const baseItems = [];

  for (const message of messages) {
    const base = createBaseOpportunity(
      channel,
      message
    );

    if (base) {
      baseItems.push(base);
    }
  }

  const enriched = await mapWithConcurrency(
    baseItems,
    PAGE_FETCH_CONCURRENCY,
    enrichOpportunity
  );

  return enriched.filter(Boolean);
}

function dedupeKey(item) {
  const normalizedUrl =
    String(
      item.officialUrl ||
      item.url ||
      ''
    )
      .split('?')[0]
      .replace(/\/+$/g, '')
      .toLocaleLowerCase('tr-TR');

  if (normalizedUrl) {
    return `url:${normalizedUrl}`;
  }

  const normalizedTitle =
    normalizeForSearch(item.title)
      .replace(/[^a-z0-9]+/g, ' ')
      .trim();

  return `title:${normalizedTitle}`;
}

function chooseBetterItem(a, b) {
  const score = item => {
    let value = 0;

    if (item.verified) value += 10;
    if (item.imageUrl) value += 5;
    if (item.livePrice) value += 4;
    if (item.currentPrice) value += 2;
    if (item.store && item.store !== 'Telegram') {
      value += 2;
    }

    return value;
  };

  return score(b) > score(a)
    ? b
    : a;
}

function mergeItems(existingItems, newTelegramItems) {
  const nonTelegramItems = existingItems.filter(
    item =>
      String(item.source || '')
        .toLocaleLowerCase('tr-TR') !==
      'telegram'
  );

  const oldTelegramItems = existingItems.filter(
    item =>
      String(item.source || '')
        .toLocaleLowerCase('tr-TR') ===
      'telegram'
  );

  const byId = new Map();

  for (const item of [
    ...oldTelegramItems,
    ...newTelegramItems
  ]) {
    byId.set(item.id, item);
  }

  const byProduct = new Map();

  for (const item of byId.values()) {
    const key = dedupeKey(item);

    if (!byProduct.has(key)) {
      byProduct.set(key, item);
      continue;
    }

    byProduct.set(
      key,
      chooseBetterItem(
        byProduct.get(key),
        item
      )
    );
  }

  const telegramItems =
    [...byProduct.values()]
      .filter(item => {
        /*
          Eski collector'ın kaydettiği kupon/duyuru kayıtlarını da
          yeni çalıştırmada temizler.
        */
        return (
          looksLikeProductTitle(item.title) &&
          !isCouponOnlyMessage(
            `${item.title || ''} ${item.description || ''}`
          )
        );
      })
      .sort((a, b) => {
        return new Date(b.publishedAt || 0) -
          new Date(a.publishedAt || 0);
      })
      .slice(0, MAX_STORED_TELEGRAM_ITEMS);

  return [
    ...nonTelegramItems,
    ...telegramItems
  ];
}

async function runCollector() {
  const apiId = Number(
    requiredEnv('TELEGRAM_API_ID')
  );

  const apiHash = requiredEnv(
    'TELEGRAM_API_HASH'
  );

  const session = requiredEnv(
    'TELEGRAM_SESSION'
  );

  if (!Number.isInteger(apiId) || apiId <= 0) {
    throw new Error(
      'TELEGRAM_API_ID geçerli bir sayı değil.'
    );
  }

  if (typeof fetch !== 'function') {
    throw new Error(
      'Bu collector Node.js 18 veya daha yeni sürüm gerektirir.'
    );
  }

  const client = new TelegramClient(
    new StringSession(session),
    apiId,
    apiHash,
    {
      connectionRetries: 5
    }
  );

  console.log('');
  console.log(
    'Trendora Telegram Collector başlatılıyor...'
  );

  await client.connect();

  const authorized =
    await client.checkAuthorization();

  if (!authorized) {
    throw new Error(
      'Telegram oturumu geçersiz. createSession.js ile yeniden oluştur.'
    );
  }

  const collectedItems = [];

  for (const channel of channels) {
    try {
      console.log(
        `Okunuyor: ${channel.name}`
      );

      const items = await collectChannel(
        client,
        channel
      );

      collectedItems.push(...items);

      console.log(
        `  ${items.length} doğrulanabilir ürün fırsatı alındı.`
      );
    } catch (error) {
      console.error(
        `  ${channel.name} okunamadı:`,
        error.message
      );
    }
  }

  const database = readDatabase();

  const mergedItems = mergeItems(
    database.items,
    collectedItems
  );

  const saved = writeDatabase(mergedItems);

  console.log('');
  console.log(
    `${collectedItems.length} ürün fırsatı işlendi.`
  );
  console.log(
    `Toplam kayıt: ${saved.items.length}`
  );
  console.log(
    `Güncelleme: ${saved.updatedAt}`
  );
  console.log('');

  await client.disconnect();
}

runCollector()
  .then(() => {
    process.exit(0);
  })
  .catch(error => {
    console.error('');
    console.error(
      'Collector hatası:',
      error.message
    );
    console.error('');

    process.exit(1);
  });