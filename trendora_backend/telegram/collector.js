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

function firstNonEmptyLine(text) {
  return normalizeText(text)
    .split('\n')
    .map(line => line.trim())
    .find(Boolean) || 'Telegram fırsatı';
}

function extractUrls(text) {
  const matches = String(text || '').match(
    /https?:\/\/[^\s<>"')\]]+/gi
  );

  return matches
    ? [...new Set(matches)]
    : [];
}

function cleanPriceNumber(value) {
  const raw = String(value || '')
    .replace(/\s/g, '')
    .replace(/[^\d.,]/g, '');

  if (!raw) {
    return null;
  }

  let normalized = raw;

  const lastComma = normalized.lastIndexOf(',');
  const lastDot = normalized.lastIndexOf('.');

  if (lastComma > lastDot) {
    normalized = normalized
      .replace(/\./g, '')
      .replace(',', '.');
  } else if (lastDot > lastComma) {
    normalized = normalized.replace(/,/g, '');
  } else {
    normalized = normalized.replace(/[.,]/g, '');
  }

  const parsed = Number(normalized);

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
  const haystack = `${text} ${urls.join(' ')}`
    .toLocaleLowerCase('tr-TR');

  const stores = [
    ['Amazon', ['amazon.', 'amzn.']],
    ['Trendyol', ['trendyol.']],
    ['Hepsiburada', ['hepsiburada.']],
    ['N11', ['n11.']],
    ['A101', ['a101.']],
    ['BİM', ['bim.']],
    ['ŞOK', ['sokmarket.', 'sok.']],
    ['Migros', ['migros.']],
    ['CarrefourSA', ['carrefoursa.']],
    ['Pazarama', ['pazarama.']],
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
  const value = String(text || '')
    .toLocaleLowerCase('tr-TR');

  const categoryRules = [
    [
      'Elektronik',
      [
        'telefon',
        'tablet',
        'laptop',
        'bilgisayar',
        'kulaklık',
        'televizyon',
        'şarj',
        'powerbank',
        'oyuncu',
        'ssd',
        'ekran kartı'
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
        'süpürge',
        'airfryer',
        'kahve makinesi'
      ]
    ],
    [
      'Market',
      [
        'market',
        'gıda',
        'çikolata',
        'kahve',
        'çay',
        'deterjan',
        'şampuan',
        'bebek bezi'
      ]
    ],
    [
      'Giyim',
      [
        'ayakkabı',
        'mont',
        'pantolon',
        'tişört',
        'kazak',
        'elbise',
        'çanta'
      ]
    ],
    [
      'Otomotiv',
      [
        'lastik',
        'motor yağı',
        'otomobil',
        'araç',
        'oto '
      ]
    ],
    [
      'Kozmetik',
      [
        'parfüm',
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

  const parsed = new Date(message.date);

  return Number.isNaN(parsed.getTime())
    ? new Date().toISOString()
    : parsed.toISOString();
}

function createOpportunity(channel, message) {
  const text = normalizeText(
    message.message || message.text || ''
  );

  if (!text) {
    return null;
  }

  const urls = extractUrls(text);
  const prices = extractPrices(text);

  const currentPrice = prices.length > 0
    ? prices[prices.length - 1].value
    : null;

  const oldPrice = prices.length > 1
    ? prices[0].value
    : null;

  const messageUrl = makeTelegramMessageUrl(
    channel,
    message.id
  );

  const productUrl =
    urls.find(url => !url.includes('t.me/')) ||
    messageUrl;

  const discountPercent =
    oldPrice &&
    currentPrice &&
    oldPrice > currentPrice
      ? Math.round(
          ((oldPrice - currentPrice) / oldPrice) * 100
        )
      : null;

  return {
    id: `telegram:${channel.type}:${channel.username || channel.channelId}:${message.id}`,
    source: 'telegram',
    sourceName: channel.name,
    sourceChannel:
      channel.username
        ? `@${channel.username}`
        : channel.channelId,
    telegramMessageId: String(message.id),
    telegramMessageUrl: messageUrl,
    title: firstNonEmptyLine(text).slice(0, 180),
    description: text,
    category: detectCategory(text),
    store: detectStore(text, urls),
    oldPrice,
    price: currentPrice,
    currentPrice,
    discountPercent,
    currency: 'TRY',
    url: productUrl,
    officialUrl: productUrl,
    imageUrl: '',
    publishedAt: messageDateToIso(message),
    collectedAt: new Date().toISOString(),
    active: true,
    verifiedAt: null,
    rawLinks: urls
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

  const items = [];

  for (const message of messages) {
    const opportunity = createOpportunity(
      channel,
      message
    );

    if (opportunity) {
      items.push(opportunity);
    }
  }

  return items;
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

  const telegramItems = [...byId.values()]
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
        `  ${items.length} mesaj alındı.`
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
    `${collectedItems.length} Telegram fırsatı işlendi.`
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
