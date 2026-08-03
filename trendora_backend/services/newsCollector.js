const Parser = require('rss-parser');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const axios = require('axios');


const parser = new Parser({
  timeout: 7000,
  headers: {
    'User-Agent': 'Mozilla/5.0 Trendora/2.0 (+https://trendora-icj9.onrender.com)',
    Accept: 'application/rss+xml, application/xml, text/xml, application/atom+xml, */*',
  },
  customFields: {
    item: [
      ['media:content', 'mediaContent', { keepArray: true }],
      ['media:thumbnail', 'mediaThumbnail', { keepArray: true }],
      ['content:encoded', 'contentEncoded'],
    ],
  },
});

const GOOGLE_TR = { hl: 'tr', gl: 'TR', ceid: 'TR:tr' };
const GOOGLE_EN = { hl: 'en-US', gl: 'US', ceid: 'US:en' };

const NEWS_SOURCES = [
  // Türkiye - doğrudan açık RSS
  { name: 'TRT Haber - Son Dakika', category: 'son_dakika', url: 'https://www.trthaber.com/sondakika_articles.rss', priority: 100, confidence: 96, region: 'tr' },
  { name: 'TRT Haber - Gündem', category: 'gundem', url: 'https://www.trthaber.com/gundem_articles.rss', priority: 94, confidence: 96, region: 'tr' },
  { name: 'TRT Haber - Türkiye', category: 'gundem', url: 'https://www.trthaber.com/turkiye_articles.rss', priority: 92, confidence: 96, region: 'tr' },
  { name: 'TRT Haber - Dünya', category: 'dunya', url: 'https://www.trthaber.com/dunya_articles.rss', priority: 90, confidence: 96, region: 'world' },
  { name: 'TRT Haber - Ekonomi', category: 'ekonomi', url: 'https://www.trthaber.com/ekonomi_articles.rss', priority: 92, confidence: 96, region: 'tr' },
  { name: 'TRT Haber - Spor', category: 'spor', url: 'https://www.trthaber.com/spor_articles.rss', priority: 84, confidence: 94, region: 'tr' },
  { name: 'TRT Haber - Teknoloji', category: 'teknoloji', url: 'https://www.trthaber.com/bilim_teknoloji_articles.rss', priority: 85, confidence: 94, region: 'tr' },

  // Türkiye - Google News kümeleri. Tek tek siteleri kazımak yerine açık haber indeksini kullanır.
  { name: 'Google Haberler - Türkiye Genel', category: 'gundem', googleQuery: 'Türkiye gündem', priority: 86, confidence: 84, region: 'tr', locale: GOOGLE_TR },
  { name: 'Google Haberler - Son Dakika', category: 'son_dakika', googleQuery: 'son dakika Türkiye', priority: 90, confidence: 84, region: 'tr', locale: GOOGLE_TR },
  { name: 'Google Haberler - Ekonomi', category: 'ekonomi', googleQuery: 'Türkiye ekonomi OR enflasyon OR faiz OR dolar OR altın', priority: 86, confidence: 84, region: 'tr', locale: GOOGLE_TR },
  { name: 'Google Haberler - Spor', category: 'spor', googleQuery: 'Türkiye spor OR futbol OR basketbol', priority: 80, confidence: 82, region: 'tr', locale: GOOGLE_TR },
  { name: 'Google Haberler - Teknoloji', category: 'teknoloji', googleQuery: 'teknoloji OR yapay zeka OR yazılım', priority: 80, confidence: 82, region: 'tr', locale: GOOGLE_TR },

  // Dünya - yabancı kaynakların Google News kümeleri
  { name: 'World - Top Stories', category: 'dunya', googleQuery: 'world news', priority: 93, confidence: 88, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Europe', category: 'dunya', googleQuery: 'Europe latest news', priority: 88, confidence: 87, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Middle East', category: 'dunya', googleQuery: 'Middle East latest news', priority: 91, confidence: 87, region: 'world', locale: GOOGLE_EN },
  { name: 'World - United States', category: 'dunya', googleQuery: 'United States latest news', priority: 87, confidence: 86, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Asia Pacific', category: 'dunya', googleQuery: 'Asia Pacific latest news', priority: 87, confidence: 86, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Russia Ukraine', category: 'dunya', googleQuery: 'Russia Ukraine latest news', priority: 92, confidence: 87, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Economy', category: 'ekonomi', googleQuery: 'global economy markets central banks', priority: 88, confidence: 87, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Technology', category: 'teknoloji', googleQuery: 'global technology AI cybersecurity', priority: 86, confidence: 86, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Sports', category: 'spor', googleQuery: 'world sports football basketball', priority: 78, confidence: 84, region: 'world', locale: GOOGLE_EN },

  // Türkiye - güvenilir yayınları Google News açık RSS indeksi üzerinden izleme
  { name: 'Türkiye - Anadolu Ajansı', category: 'gundem', googleQuery: 'site:aa.com.tr Türkiye', priority: 94, confidence: 95, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - NTV', category: 'gundem', googleQuery: 'site:ntv.com.tr Türkiye', priority: 88, confidence: 89, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Habertürk', category: 'gundem', googleQuery: 'site:haberturk.com Türkiye', priority: 87, confidence: 87, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Hürriyet', category: 'gundem', googleQuery: 'site:hurriyet.com.tr Türkiye', priority: 86, confidence: 86, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Milliyet', category: 'gundem', googleQuery: 'site:milliyet.com.tr Türkiye', priority: 84, confidence: 84, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Sabah', category: 'gundem', googleQuery: 'site:sabah.com.tr Türkiye', priority: 84, confidence: 84, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Sözcü', category: 'gundem', googleQuery: 'site:sozcu.com.tr Türkiye', priority: 84, confidence: 84, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Cumhuriyet', category: 'gundem', googleQuery: 'site:cumhuriyet.com.tr Türkiye', priority: 83, confidence: 84, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - T24', category: 'gundem', googleQuery: 'site:t24.com.tr Türkiye', priority: 83, confidence: 85, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Gazete Duvar', category: 'gundem', googleQuery: 'site:gazeteduvar.com.tr Türkiye', priority: 82, confidence: 83, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - BBC Türkçe', category: 'dunya', googleQuery: 'site:bbc.com/turkce', priority: 91, confidence: 94, region: 'world', locale: GOOGLE_TR },
  { name: 'Türkiye - DW Türkçe', category: 'dunya', googleQuery: 'site:dw.com/tr', priority: 90, confidence: 93, region: 'world', locale: GOOGLE_TR },
  { name: 'Türkiye - Euronews Türkçe', category: 'dunya', googleQuery: 'site:tr.euronews.com', priority: 89, confidence: 91, region: 'world', locale: GOOGLE_TR },
  { name: 'Türkiye - Bloomberg HT', category: 'ekonomi', googleQuery: 'site:bloomberght.com ekonomi', priority: 91, confidence: 92, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Ekonomim', category: 'ekonomi', googleQuery: 'site:ekonomim.com ekonomi', priority: 88, confidence: 89, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Dünya Gazetesi', category: 'ekonomi', googleQuery: 'site:dunya.com ekonomi', priority: 87, confidence: 88, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Fanatik', category: 'spor', googleQuery: 'site:fanatik.com.tr spor', priority: 82, confidence: 82, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - NTV Spor', category: 'spor', googleQuery: 'site:ntvspor.net spor', priority: 84, confidence: 86, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - TRT Spor', category: 'spor', googleQuery: 'site:trtspor.com.tr spor', priority: 87, confidence: 92, region: 'tr', locale: GOOGLE_TR },

  // Dünya - büyük yayınları Google News açık RSS indeksi üzerinden izleme
  { name: 'World - Reuters', category: 'dunya', googleQuery: 'site:reuters.com world', priority: 98, confidence: 98, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Associated Press', category: 'dunya', googleQuery: 'site:apnews.com world', priority: 97, confidence: 98, region: 'world', locale: GOOGLE_EN },
  { name: 'World - BBC News', category: 'dunya', googleQuery: 'site:bbc.com/news world', priority: 96, confidence: 97, region: 'world', locale: GOOGLE_EN },
  { name: 'World - CNN', category: 'dunya', googleQuery: 'site:cnn.com world', priority: 91, confidence: 91, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Al Jazeera', category: 'dunya', googleQuery: 'site:aljazeera.com news', priority: 93, confidence: 93, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Euronews', category: 'dunya', googleQuery: 'site:euronews.com world', priority: 90, confidence: 91, region: 'world', locale: GOOGLE_EN },
  { name: 'World - France 24', category: 'dunya', googleQuery: 'site:france24.com latest', priority: 90, confidence: 92, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Deutsche Welle', category: 'dunya', googleQuery: 'site:dw.com latest world', priority: 92, confidence: 94, region: 'world', locale: GOOGLE_EN },
  { name: 'World - The Guardian', category: 'dunya', googleQuery: 'site:theguardian.com/world', priority: 90, confidence: 91, region: 'world', locale: GOOGLE_EN },
  { name: 'World - New York Times', category: 'dunya', googleQuery: 'site:nytimes.com world', priority: 91, confidence: 92, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Washington Post', category: 'dunya', googleQuery: 'site:washingtonpost.com world', priority: 90, confidence: 91, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Financial Times', category: 'ekonomi', googleQuery: 'site:ft.com global economy', priority: 94, confidence: 95, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Bloomberg', category: 'ekonomi', googleQuery: 'site:bloomberg.com markets economy', priority: 95, confidence: 96, region: 'world', locale: GOOGLE_EN },
  { name: 'World - CNBC', category: 'ekonomi', googleQuery: 'site:cnbc.com markets economy', priority: 91, confidence: 92, region: 'world', locale: GOOGLE_EN },
  { name: 'World - The Verge', category: 'teknoloji', googleQuery: 'site:theverge.com technology', priority: 88, confidence: 89, region: 'world', locale: GOOGLE_EN },
  { name: 'World - TechCrunch', category: 'teknoloji', googleQuery: 'site:techcrunch.com technology', priority: 88, confidence: 88, region: 'world', locale: GOOGLE_EN },
  { name: 'World - ESPN', category: 'spor', googleQuery: 'site:espn.com latest sports', priority: 86, confidence: 88, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Sky Sports', category: 'spor', googleQuery: 'site:skysports.com latest', priority: 85, confidence: 87, region: 'world', locale: GOOGLE_EN },

  // Bundle benzeri geniş kaynak havuzu: uygulamadan değil, yayıncıların açık Google News/RSS akışlarından
  // Teknoloji
  { name: 'Türkiye - Webtekno', category: 'teknoloji', googleQuery: 'site:webtekno.com teknoloji', priority: 86, confidence: 85, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - ShiftDelete.Net', category: 'teknoloji', googleQuery: 'site:shiftdelete.net teknoloji', priority: 86, confidence: 85, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - DonanımHaber', category: 'teknoloji', googleQuery: 'site:donanimhaber.com teknoloji', priority: 87, confidence: 87, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Teknolojioku', category: 'teknoloji', googleQuery: 'site:teknolojioku.com teknoloji', priority: 81, confidence: 82, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Log', category: 'teknoloji', googleQuery: 'site:log.com.tr teknoloji', priority: 83, confidence: 84, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Chip Online', category: 'teknoloji', googleQuery: 'site:chip.com.tr teknoloji', priority: 82, confidence: 84, region: 'tr', locale: GOOGLE_TR },
  { name: 'World - Ars Technica', category: 'teknoloji', googleQuery: 'site:arstechnica.com technology', priority: 91, confidence: 93, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Wired', category: 'teknoloji', googleQuery: 'site:wired.com technology', priority: 91, confidence: 92, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Engadget', category: 'teknoloji', googleQuery: 'site:engadget.com technology', priority: 88, confidence: 89, region: 'world', locale: GOOGLE_EN },
  { name: 'World - ZDNET', category: 'teknoloji', googleQuery: 'site:zdnet.com technology', priority: 88, confidence: 90, region: 'world', locale: GOOGLE_EN },
  { name: 'World - MIT Technology Review', category: 'teknoloji', googleQuery: 'site:technologyreview.com AI technology', priority: 93, confidence: 95, region: 'world', locale: GOOGLE_EN },
  { name: 'World - AI News', category: 'teknoloji', googleQuery: 'artificial intelligence OpenAI Google Microsoft Nvidia latest', priority: 90, confidence: 89, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Cybersecurity', category: 'teknoloji', googleQuery: 'cybersecurity data breach malware latest', priority: 90, confidence: 90, region: 'world', locale: GOOGLE_EN },

  // Ekonomi
  { name: 'Türkiye - ParaAnaliz', category: 'ekonomi', googleQuery: 'site:paraanaliz.com ekonomi piyasalar', priority: 84, confidence: 85, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Foreks', category: 'ekonomi', googleQuery: 'site:foreks.com ekonomi piyasa', priority: 87, confidence: 89, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Bigpara', category: 'ekonomi', googleQuery: 'site:bigpara.hurriyet.com.tr ekonomi', priority: 85, confidence: 86, region: 'tr', locale: GOOGLE_TR },
  { name: 'World - MarketWatch', category: 'ekonomi', googleQuery: 'site:marketwatch.com markets economy', priority: 90, confidence: 91, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Wall Street Journal', category: 'ekonomi', googleQuery: 'site:wsj.com economy markets', priority: 94, confidence: 95, region: 'world', locale: GOOGLE_EN },
  { name: 'World - The Economist', category: 'ekonomi', googleQuery: 'site:economist.com economy finance', priority: 94, confidence: 95, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Investing', category: 'ekonomi', googleQuery: 'site:investing.com news markets economy', priority: 87, confidence: 88, region: 'world', locale: GOOGLE_EN },

  // Spor
  { name: 'Türkiye - Sporx', category: 'spor', googleQuery: 'site:sporx.com spor', priority: 82, confidence: 82, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Ajansspor', category: 'spor', googleQuery: 'site:ajansspor.com spor', priority: 83, confidence: 84, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Fotomaç', category: 'spor', googleQuery: 'site:fotomac.com.tr spor', priority: 81, confidence: 81, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - beIN Sports', category: 'spor', googleQuery: 'site:beinsports.com.tr spor', priority: 86, confidence: 88, region: 'tr', locale: GOOGLE_TR },
  { name: 'World - BBC Sport', category: 'spor', googleQuery: 'site:bbc.com/sport latest', priority: 92, confidence: 94, region: 'world', locale: GOOGLE_EN },
  { name: 'World - The Athletic', category: 'spor', googleQuery: 'site:theathletic.com sports latest', priority: 89, confidence: 91, region: 'world', locale: GOOGLE_EN },
  { name: 'World - Goal', category: 'spor', googleQuery: 'site:goal.com latest football', priority: 86, confidence: 87, region: 'world', locale: GOOGLE_EN },

  // Gündem ve dünya
  { name: 'Türkiye - Yeni Şafak', category: 'gundem', googleQuery: 'site:yenisafak.com gündem', priority: 81, confidence: 82, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - BirGün', category: 'gundem', googleQuery: 'site:birgun.net gündem', priority: 81, confidence: 83, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Karar', category: 'gundem', googleQuery: 'site:karar.com gündem', priority: 82, confidence: 83, region: 'tr', locale: GOOGLE_TR },
  { name: 'Türkiye - Independent Türkçe', category: 'gundem', googleQuery: 'site:indyturk.com Türkiye', priority: 86, confidence: 88, region: 'tr', locale: GOOGLE_TR },
  { name: 'World - Politico', category: 'dunya', googleQuery: 'site:politico.com world politics', priority: 91, confidence: 92, region: 'world', locale: GOOGLE_EN },
  { name: 'World - NBC News', category: 'dunya', googleQuery: 'site:nbcnews.com world latest', priority: 89, confidence: 90, region: 'world', locale: GOOGLE_EN },
  { name: 'World - CBS News', category: 'dunya', googleQuery: 'site:cbsnews.com world latest', priority: 88, confidence: 89, region: 'world', locale: GOOGLE_EN },
  { name: 'World - ABC News', category: 'dunya', googleQuery: 'site:abcnews.go.com international latest', priority: 88, confidence: 89, region: 'world', locale: GOOGLE_EN },
  { name: 'World - TIME', category: 'dunya', googleQuery: 'site:time.com world latest', priority: 89, confidence: 90, region: 'world', locale: GOOGLE_EN },

  // Tematik açık akışlar
  { name: 'CoinDesk', category: 'ekonomi', url: 'https://www.coindesk.com/arc/outboundfeeds/rss/', priority: 84, confidence: 90, region: 'world' },
  { name: 'NASA Breaking News', category: 'teknoloji', url: 'https://www.nasa.gov/news-release/feed/', priority: 82, confidence: 97, region: 'world' },

  // Doğrudan yabancı RSS akışları: Dünya, teknoloji ve ekonomi kategorilerinin
  // Google News'e bağımlı kalmadan dolmasını sağlar.
  { name: 'BBC News - World RSS', category: 'dunya', url: 'https://feeds.bbci.co.uk/news/world/rss.xml', priority: 96, confidence: 97, region: 'world' },
  { name: 'BBC News - Top Stories RSS', category: 'dunya', url: 'https://feeds.bbci.co.uk/news/rss.xml', priority: 94, confidence: 97, region: 'world' },
  { name: 'The Guardian - World RSS', category: 'dunya', url: 'https://www.theguardian.com/world/rss', priority: 91, confidence: 92, region: 'world' },
  { name: 'Al Jazeera - All RSS', category: 'dunya', url: 'https://www.aljazeera.com/xml/rss/all.xml', priority: 92, confidence: 93, region: 'world' },
  { name: 'France 24 - English RSS', category: 'dunya', url: 'https://www.france24.com/en/rss', priority: 90, confidence: 92, region: 'world' },
  { name: 'DW - Top Stories RSS', category: 'dunya', url: 'https://rss.dw.com/rdf/rss-en-top', priority: 91, confidence: 94, region: 'world' },

  { name: 'BBC News - Technology RSS', category: 'teknoloji', url: 'https://feeds.bbci.co.uk/news/technology/rss.xml', priority: 93, confidence: 96, region: 'world' },
  { name: 'TechCrunch RSS', category: 'teknoloji', url: 'https://techcrunch.com/feed/', priority: 90, confidence: 90, region: 'world' },
  { name: 'Ars Technica RSS', category: 'teknoloji', url: 'https://feeds.arstechnica.com/arstechnica/index', priority: 92, confidence: 94, region: 'world' },
  { name: 'The Guardian - Technology RSS', category: 'teknoloji', url: 'https://www.theguardian.com/uk/technology/rss', priority: 89, confidence: 91, region: 'world' },
  { name: 'WIRED RSS', category: 'teknoloji', url: 'https://www.wired.com/feed/rss', priority: 90, confidence: 92, region: 'world' },

  { name: 'BBC News - Business RSS', category: 'ekonomi', url: 'https://feeds.bbci.co.uk/news/business/rss.xml', priority: 94, confidence: 96, region: 'world' },
  { name: 'The Guardian - Business RSS', category: 'ekonomi', url: 'https://www.theguardian.com/uk/business/rss', priority: 90, confidence: 92, region: 'world' },
  { name: 'CNBC - World News RSS', category: 'ekonomi', url: 'https://www.cnbc.com/id/100727362/device/rss/rss.html', priority: 91, confidence: 92, region: 'world' },
  { name: 'CNBC - Finance RSS', category: 'ekonomi', url: 'https://www.cnbc.com/id/10000664/device/rss/rss.html', priority: 92, confidence: 93, region: 'world' },
];

const CACHE_DURATION_MS = 3 * 60 * 1000;
const SOURCE_CONCURRENCY = Math.max(1, Number(process.env.NEWS_SOURCE_CONCURRENCY || 8));
const SOURCE_TIMEOUT_MS = Math.max(5000, Number(process.env.NEWS_SOURCE_TIMEOUT_MS || 10000));
const SCAN_TIMEOUT_MS = Math.max(60000, Number(process.env.NEWS_SCAN_TIMEOUT_MS || 180000));
const MAX_ITEMS_PER_SOURCE = 100;
const MAX_FULL_TEXT_LENGTH = 30000;
const MAX_ARCHIVE_ITEMS = 50000;
const ARCHIVE_RETENTION_MS = 370 * 24 * 60 * 60 * 1000;
const ARCHIVE_FILE = path.join(__dirname, '..', 'database', 'news_archive.json');
const NEWS_DATABASE_FILE = path.join(__dirname, '..', 'database', 'news_database.json');
const NEWS_STATUS_FILE = path.join(__dirname, '..', 'database', 'news_status.json');
const NEWS_REFRESH_INTERVAL_MS = Math.max(
  5 * 60 * 1000,
  Number(process.env.NEWS_REFRESH_INTERVAL_MS || 10 * 60 * 1000)
);
const REFRESH_TIER_INTERVALS_MS = Object.freeze({
  breaking: 5 * 60 * 1000,
  fast: 10 * 60 * 1000,
  normal: 15 * 60 * 1000,
  slow: 30 * 60 * 1000
});
const COLLECTOR_TICK_MS = Math.min(
  NEWS_REFRESH_INTERVAL_MS,
  REFRESH_TIER_INTERVALS_MS.breaking
);

const PERIODS = {
  '1h': 60 * 60 * 1000,
  '4h': 4 * 60 * 60 * 1000,
  '12h': 12 * 60 * 60 * 1000,
  '24h': 24 * 60 * 60 * 1000,
  '48h': 48 * 60 * 60 * 1000,
  '7d': 7 * 24 * 60 * 60 * 1000,
  '30d': 30 * 24 * 60 * 60 * 1000,
  '60d': 60 * 24 * 60 * 60 * 1000,
  '180d': 180 * 24 * 60 * 60 * 1000,
  '365d': 365 * 24 * 60 * 60 * 1000,
  all: null,
};

let newsCache = { createdAt: 0, items: [], sourceResults: [], period: 'all' };
let refreshPromise = null;
let collectorRunPromise = null;
let archiveWriteQueue = Promise.resolve();
let archiveCache = null;
let archiveSignature = null;
let lastPublishedSignature = null;
const sourceState = new Map();
let persistedCollectorStatus = {};

function hydrateSourceState() {
  try {
    if (!fs.existsSync(NEWS_STATUS_FILE)) return;
    const saved = JSON.parse(fs.readFileSync(NEWS_STATUS_FILE, 'utf8'));
    persistedCollectorStatus = saved && typeof saved === 'object' ? saved : {};
    if (!saved?.sourceStates || typeof saved.sourceStates !== 'object') return;
    for (const [name, state] of Object.entries(saved.sourceStates)) {
      if (state && typeof state === 'object') {
        // Yeni proses ilk turunda repository'den veya eski sistem saatinden kalan
        // uygunluk zamanı kaynakları yanlışlıkla uzun süre susturmamalı.
        sourceState.set(name, { ...state, nextEligibleFetchAt: null });
      }
    }
  } catch (error) {
    console.warn('[NEWS COLLECTOR] Kaynak durumu geri yüklenemedi:', error?.message || error);
  }
}

hydrateSourceState();

function refreshTierForSource(source) {
  if (source.refreshTier && REFRESH_TIER_INTERVALS_MS[source.refreshTier]) {
    return source.refreshTier;
  }
  if (source.category === 'son_dakika' || source.priority >= 96) return 'breaking';
  if (source.priority >= 90) return 'fast';
  if (source.category === 'teknoloji' || source.priority < 84) return 'slow';
  return 'normal';
}

function sourceStateFor(source) {
  if (!sourceState.has(source.name)) {
    sourceState.set(source.name, {
      refreshTier: refreshTierForSource(source),
      lastAttemptAt: null,
      lastSuccessAt: null,
      lastFailureAt: null,
      consecutiveFailures: 0,
      lastItemCount: 0,
      lastContentHash: null,
      lastEtag: null,
      lastModified: null,
      nextEligibleFetchAt: null,
      averageDurationMs: 0,
      lastErrorType: null
    });
  }
  return sourceState.get(source.name);
}

function sourceBackoffMs(source, failures) {
  if (failures >= 5) return source.category === 'son_dakika'
    ? 30 * 60 * 1000
    : 2 * 60 * 60 * 1000;
  if (failures >= 3) return 30 * 60 * 1000;
  return REFRESH_TIER_INTERVALS_MS[refreshTierForSource(source)];
}

function sourceIsEligible(source, now = Date.now()) {
  const state = sourceStateFor(source);
  if (!state.nextEligibleFetchAt) return true;
  const nextEligibleAt = new Date(state.nextEligibleFetchAt).getTime();
  return !Number.isFinite(nextEligibleAt) || nextEligibleAt <= now;
}

function stableHash(value) {
  return crypto.createHash('sha1').update(String(value || '')).digest('hex');
}

function newsContentHash(item) {
  return stableHash([
    cleanText(item.url).replace(/[?#].*$/, ''),
    normalizeText(item.title),
    cleanText(item.description),
    cleanText(item.content),
    item.publishedAt,
    cleanText(item.source),
    cleanText(item.imageUrl)
  ].join('|'));
}

function snapshotSignature(items) {
  return stableHash(items.map(item => `${item.id || item.url}:${newsContentHash(item)}`).join('\n'));
}

function cleanText(value) {
  if (!value) return '';
  return String(value)
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

function cleanFullText(value) {
  const cleaned = cleanText(value);
  if (cleaned.length <= MAX_FULL_TEXT_LENGTH) return cleaned;
  return cleaned.slice(0, MAX_FULL_TEXT_LENGTH).trimEnd();
}

function normalizeText(value) {
  return cleanText(value)
    .toLocaleLowerCase('tr-TR')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9çğıöşü\s]/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const STOP_WORDS = new Set([
  've','veya','ile','icin','olan','olarak','bir','bu','şu','da','de','mi','mı','mu','mü','the','a','an','to','of','in','on','for','and','or','is','are','at','from','latest','news','son','dakika','haber','haberi',
]);

function titleTokens(title) {
  return normalizeText(title)
    .split(' ')
    .filter((word) => word.length > 2 && !STOP_WORDS.has(word));
}

function similarity(a, b) {
  const left = new Set(titleTokens(a));
  const right = new Set(titleTokens(b));
  if (!left.size || !right.size) return 0;
  let intersection = 0;
  for (const token of left) if (right.has(token)) intersection += 1;
  return intersection / Math.max(left.size, right.size);
}

function getGoogleNewsPublisher(title) {
  const parts = String(title || '').split(' - ');
  return parts.length < 2 ? '' : parts[parts.length - 1].trim();
}

function removeGoogleNewsPublisher(title) {
  const parts = String(title || '').split(' - ');
  if (parts.length < 2) return cleanText(title);
  parts.pop();
  return cleanText(parts.join(' - '));
}

function extractImage(item) {
  const candidates = [
    item?.enclosure?.url,
    item?.mediaContent?.[0]?.$?.url,
    item?.mediaContent?.[0]?.url,
    item?.mediaThumbnail?.[0]?.$?.url,
    item?.mediaThumbnail?.[0]?.url,
  ];
  for (const candidate of candidates) {
    if (typeof candidate === 'string' && /^https?:\/\//i.test(candidate)) return candidate;
  }
  const html = [item?.contentEncoded, item?.content, item?.description, item?.summary]
    .filter(Boolean)
    .join(' ');
  const match = html.match(/<img[^>]+src=["'](https?:\/\/[^"']+)["']/i);
  return match ? match[1] : '';
}

function parsePublishedDate(item) {
  const raw = item?.isoDate || item?.pubDate || item?.published || item?.updated || '';
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? new Date(0) : parsed;
}

function googleNewsUrl(query, period, locale = GOOGLE_TR) {
  const periodQuery = period && period !== 'all' ? ` when:${period}` : '';
  return `https://news.google.com/rss/search?q=${encodeURIComponent(`${query}${periodQuery}`)}&hl=${locale.hl}&gl=${locale.gl}&ceid=${locale.ceid}`;
}

function sourceUrl(source, period) {
  const effectivePeriod = source.category === 'son_dakika' ? '1h' : period;
  return source.googleQuery ? googleNewsUrl(source.googleQuery, effectivePeriod, source.locale) : source.url;
}


const BREAKING_SIGNAL_PATTERN = /son dakika|breaking|acil|sıcak gelişme|flas|flash|just in|developing|az önce açıklandı|resmen duyuruldu/;
const HIGH_IMPACT_PATTERN = /deprem|yangın|sel|fırtına|patlama|saldırı|operasyon|çökme|kaza|ölü|yaralı|tahliye|afet|savaş|ateşkes|istifa|görevden alındı|yasaklandı|faiz kararı|merkez bankası|seçim sonucu|mahkeme kararı|tutuklandı|gözaltı|acil uyarı|meteorolojik uyarı|hava sahası|füze|darbe|kriz/;
const LOW_IMPACT_PATTERN = /yarış başladı|maç sonucu|finalde|şampiyon|transfer|konser|festival|ödül|magazin|ünlü|rekor kırdı|en yoğun havalimanı|haneye ulaştık|ziyaret etti|mesaj yayımladı|açılış yaptı/;

function hasExplicitBreakingSignal(text) {
  return BREAKING_SIGNAL_PATTERN.test(normalizeText(text));
}

function hasHighImpactSignal(text) {
  return HIGH_IMPACT_PATTERN.test(normalizeText(text));
}

function hasLowImpactSignal(text) {
  return LOW_IMPACT_PATTERN.test(normalizeText(text));
}

function calculateBreakingState({ title, description, publishedDate, source }) {
  const text = `${title} ${description}`;
  const ageMinutes = (Date.now() - publishedDate.getTime()) / 60000;
  if (!Number.isFinite(ageMinutes) || ageMinutes < 0 || ageMinutes > 120) return false;

  const explicit = hasExplicitBreakingSignal(text);
  const highImpact = hasHighImpactSignal(text);
  const lowImpact = hasLowImpactSignal(text);
  const trustedBreakingFeed = source.category === 'son_dakika' && (source.confidence || 0) >= 92;

  if (lowImpact && !highImpact) return false;
  if (explicit && (highImpact || trustedBreakingFeed)) return true;
  if (trustedBreakingFeed && highImpact && ageMinutes <= 90) return true;
  return false;
}

function calculateTrendScore(item) {
  let score = 28 + Math.round((item.priority || 70) * 0.2);
  const ageMinutes = (Date.now() - new Date(item.publishedAt).getTime()) / 60000;
  if (ageMinutes <= 15) score += 28;
  else if (ageMinutes <= 60) score += 22;
  else if (ageMinutes <= 180) score += 15;
  else if (ageMinutes <= 720) score += 8;
  if (item.isBreaking) score += 12;
  if (item.imageUrl) score += 2;
  return Math.max(0, Math.min(100, Math.round(score)));
}

function normalizeItem(item, source) {
  const isGoogle = source.name.startsWith('Google Haberler') || source.name.startsWith('World -') || source.name.startsWith('Türkiye -');
  const rawTitle = cleanText(item?.title);
  const title = isGoogle ? removeGoogleNewsPublisher(rawTitle) : rawTitle;
  const publisher = isGoogle ? getGoogleNewsPublisher(rawTitle) : '';
  const description = cleanText(item?.contentSnippet || item?.summary || item?.description || item?.content || '');
  const fullText = cleanFullText(item?.contentEncoded || item?.content || '');
  const content = fullText === description ? '' : fullText;
  const publishedDate = parsePublishedDate(item);
  const sourceName = publisher || cleanText(item?.creator) || cleanText(item?.author) || source.name;
  const isBreaking = calculateBreakingState({ title, description, publishedDate, source });
  const normalized = {
    id: Buffer.from(`${source.name}|${item?.link || ''}|${title}`).toString('base64url'),
    title,
    description,
    content,
    url: item?.link || item?.guid || '',
    imageUrl: extractImage(item),
    source: sourceName,
    feedSource: source.name,
    category: source.category === 'son_dakika' ? 'gundem' : source.category,
    region: source.region || 'tr',
    language: source.locale === GOOGLE_EN ? 'en' : 'tr',
    publishedAt: publishedDate.toISOString(),
    isBreaking,
    priority: source.priority || 70,
    confidenceScore: source.confidence || 80,
  };
  return { ...normalized, trendScore: calculateTrendScore(normalized) };
}

function withTimeout(promise, timeoutMs, label) {
  let timeoutHandle;
  const timeoutPromise = new Promise((_, reject) => {
    timeoutHandle = setTimeout(() => {
      const error = new Error(`${label} ${timeoutMs} ms içinde yanıt vermedi`);
      error.code = 'NEWS_SOURCE_TIMEOUT';
      reject(error);
    }, timeoutMs);
  });

  return Promise.race([promise, timeoutPromise]).finally(() => {
    clearTimeout(timeoutHandle);
  });
}

async function fetchSource(source, period = '24h') {
  const startedAt = Date.now();
  const url = sourceUrl(source, period);
  const state = sourceStateFor(source);
  state.lastAttemptAt = new Date(startedAt).toISOString();

  try {
    const response = await withTimeout(
      axios.get(url, {
        timeout: SOURCE_TIMEOUT_MS,
        responseType: 'text',
        maxContentLength: 5 * 1024 * 1024,
        validateStatus: status => status === 200 || status === 304,
        headers: {
          'User-Agent': 'Mozilla/5.0 Trendora/3.0 (+https://trendora-icj9.onrender.com)',
          Accept: 'application/rss+xml, application/xml, text/xml, application/atom+xml',
          ...(state.lastEtag ? { 'If-None-Match': state.lastEtag } : {}),
          ...(state.lastModified ? { 'If-Modified-Since': state.lastModified } : {})
        }
      }),
      SOURCE_TIMEOUT_MS,
      source.name
    );
    const durationMs = Date.now() - startedAt;

    if (response.status === 304) {
      state.lastSuccessAt = new Date().toISOString();
      state.consecutiveFailures = 0;
      state.averageDurationMs = Math.round(
        state.averageDurationMs ? state.averageDurationMs * 0.75 + durationMs * 0.25 : durationMs
      );
      state.lastErrorType = null;
      state.nextEligibleFetchAt = new Date(
        Date.now() + REFRESH_TIER_INTERVALS_MS[refreshTierForSource(source)]
      ).toISOString();
      return {
        ok: true,
        notModified: true,
        source: source.name,
        count: state.lastItemCount,
        durationMs,
        items: []
      };
    }

    const body = String(response.data || '');
    const bodyHash = stableHash(body);
    if (state.lastContentHash && state.lastContentHash === bodyHash) {
      state.lastSuccessAt = new Date().toISOString();
      state.consecutiveFailures = 0;
      state.averageDurationMs = Math.round(
        state.averageDurationMs ? state.averageDurationMs * 0.75 + durationMs * 0.25 : durationMs
      );
      state.lastErrorType = null;
      state.nextEligibleFetchAt = new Date(
        Date.now() + REFRESH_TIER_INTERVALS_MS[refreshTierForSource(source)]
      ).toISOString();
      return {
        ok: true,
        notModified: true,
        source: source.name,
        count: state.lastItemCount,
        durationMs,
        items: []
      };
    }

    const feed = await parser.parseString(body);

    const items = (feed.items || [])
      .slice(0, MAX_ITEMS_PER_SOURCE)
      .map((item) => normalizeItem(item, source))
      .filter((item) => item.title && item.url && new Date(item.publishedAt).getFullYear() >= 2000);

    state.lastSuccessAt = new Date().toISOString();
    state.consecutiveFailures = 0;
    state.lastItemCount = items.length;
    state.lastContentHash = bodyHash;
    state.lastEtag = response.headers?.etag || state.lastEtag;
    state.lastModified = response.headers?.['last-modified'] || state.lastModified;
    state.averageDurationMs = Math.round(
      state.averageDurationMs ? state.averageDurationMs * 0.75 + durationMs * 0.25 : durationMs
    );
    state.lastErrorType = null;
    state.nextEligibleFetchAt = new Date(
      Date.now() + REFRESH_TIER_INTERVALS_MS[refreshTierForSource(source)]
    ).toISOString();

    console.log(`[NEWS] ${source.name}: ${items.length} haber, ${durationMs} ms`);

    return {
      ok: true,
      source: source.name,
      count: items.length,
      durationMs,
      items
    };
  } catch (error) {
    const message = error?.message || 'Kaynak okunamadı';
    const durationMs = Date.now() - startedAt;
    state.lastFailureAt = new Date().toISOString();
    state.consecutiveFailures += 1;
    state.averageDurationMs = Math.round(
      state.averageDurationMs ? state.averageDurationMs * 0.75 + durationMs * 0.25 : durationMs
    );
    state.lastErrorType = error?.code || error?.name || 'SOURCE_ERROR';
    state.nextEligibleFetchAt = new Date(
      Date.now() + sourceBackoffMs(source, state.consecutiveFailures)
    ).toISOString();
    console.error(`[NEWS] ${source.name} okunamadı: ${message}`);
    return {
      ok: false,
      source: source.name,
      count: 0,
      durationMs,
      error: message,
      items: []
    };
  }
}

async function mapWithConcurrency(items, limit, mapper) {
  const results = new Array(items.length);
  let cursor = 0;
  async function worker() {
    while (true) {
      const index = cursor++;
      if (index >= items.length) return;
      results[index] = await mapper(items[index], index);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

function buildStoryGroups(items) {
  const sorted = [...items]
    .sort(
      (a, b) =>
        new Date(b.publishedAt) -
        new Date(a.publishedAt)
    );

  const groups = [];
  const recentGroupsByCategory = new Map();

  for (const item of sorted) {
    const itemTime =
      new Date(item.publishedAt).getTime();

    const bucketKey =
      `${item.category}|${item.region || 'tr'}`;

    const candidates =
      recentGroupsByCategory.get(bucketKey) || [];

    let group = null;

    /*
      Bütün geçmiş grupları taramak yerine yalnızca
      aynı kategori/bölgedeki en yeni 40 gruba bakar.
      Böylece 10.000+ haberde sistem kilitlenmez.
    */
    for (
      let index = candidates.length - 1;
      index >= 0;
      index--
    ) {
      const candidate = candidates[index];

      const candidateTime =
        new Date(
          candidate.primary.publishedAt
        ).getTime();

      if (
        Math.abs(itemTime - candidateTime) >
        30 * 60 * 60 * 1000
      ) {
        continue;
      }

      const sameTitle =
        normalizeText(item.title) ===
        normalizeText(candidate.primary.title);

      const similarTitle =
        similarity(
          item.title,
          candidate.primary.title
        ) >= 0.56;

      if (sameTitle || similarTitle) {
        group = candidate;
        break;
      }
    }

    if (!group) {
      group = {
        primary: item,
        items: [],
        keys: new Set()
      };

      groups.push(group);
      candidates.push(group);

      /*
        Bellek ve işlem yükünü kontrollü tut.
      */
      if (candidates.length > 40) {
        candidates.shift();
      }

      recentGroupsByCategory.set(
        bucketKey,
        candidates
      );
    }

    const normalizedUrl =
      cleanText(item.url)
        .replace(/[?#].*$/, '');

    const storyKey =
      `${normalizeText(item.title)}|` +
      `${normalizeText(item.source)}|` +
      normalizedUrl;

    if (group.keys.has(storyKey)) {
      continue;
    }

    group.keys.add(storyKey);
    group.items.push(item);

    const better =
      item.priority > group.primary.priority ||
      (
        item.priority ===
          group.primary.priority &&
        item.confidenceScore >
          group.primary.confidenceScore
      ) ||
      (
        item.priority ===
          group.primary.priority &&
        item.confidenceScore ===
          group.primary.confidenceScore &&
        itemTime >
          new Date(
            group.primary.publishedAt
          ).getTime()
      );

    if (better) {
      group.primary = item;
    }
  }

  return groups
    .map((group) => {
      const uniqueStories = [];
      const seenStoryKeys = new Set();

      for (const story of group.items) {
        const normalizedUrl =
          cleanText(story.url)
            .replace(/[?#].*$/, '');

        const key =
          normalizedUrl ||
          `${normalizeText(story.title)}|` +
          `${normalizeText(story.source)}`;

        if (
          !key ||
          seenStoryKeys.has(key)
        ) {
          continue;
        }

        seenStoryKeys.add(key);
        uniqueStories.push(story);
      }

      const uniqueSources = [
        ...new Set(
          uniqueStories
            .map((item) => item.source)
            .filter(Boolean)
        )
      ];

      const latest = Math.max(
        ...uniqueStories.map(
          (item) =>
            new Date(
              item.publishedAt
            ).getTime()
        )
      );

      const confirmationBonus =
        Math.min(
          18,
          Math.max(
            0,
            uniqueSources.length - 1
          ) * 4
        );

      const primary = group.primary;

      const groupBreaking =
        uniqueStories.some(
          (item) => item.isBreaking
        ) &&
        uniqueStories.some(
          (item) =>
            hasHighImpactSignal(
              `${item.title} ${item.description}`
            )
        );

      const importanceScore =
        Math.max(
          0,
          Math.min(
            100,
            Math.round(
              primary.trendScore * 0.50 +
              primary.confidenceScore * 0.30 +
              confirmationBonus +
              (groupBreaking ? 8 : 0)
            )
          )
        );

      return {
        ...primary,
        publishedAt:
          new Date(latest).toISOString(),
        isBreaking: groupBreaking,
        sourceCount: uniqueSources.length,
        confirmingSources:
          uniqueSources.slice(0, 12),
        relatedStories:
          uniqueStories
            .slice(0, 12)
            .map((item) => ({
              title: item.title,
              source: item.source,
              url: item.url,
              publishedAt:
                item.publishedAt
            })),
        importanceScore,
        trendScore: Math.min(
          100,
          primary.trendScore +
          confirmationBonus
        ),
        isTrending:
          uniqueSources.length >= 3 ||
          importanceScore >= 82
      };
    })
    .sort((a, b) => {
      const breakingDiff =
        Number(b.isBreaking) -
        Number(a.isBreaking);

      if (breakingDiff !== 0) {
        return breakingDiff;
      }

      const importanceDiff =
        b.importanceScore -
        a.importanceScore;

      if (importanceDiff !== 0) {
        return importanceDiff;
      }

      return (
        new Date(b.publishedAt) -
        new Date(a.publishedAt)
      );
    });
}
function loadArchive() {
  if (archiveCache) return archiveCache;
  try {
    if (!fs.existsSync(ARCHIVE_FILE)) {
      archiveCache = [];
      archiveSignature = snapshotSignature(archiveCache);
      return archiveCache;
    }
    const parsed = JSON.parse(fs.readFileSync(ARCHIVE_FILE, 'utf8'));
    archiveCache = Array.isArray(parsed) ? parsed : [];
    archiveSignature = snapshotSignature(archiveCache);
    return archiveCache;
  } catch (error) {
    console.error('[NEWS] Arşiv okunamadı:', error?.message || error);
    archiveCache = [];
    archiveSignature = snapshotSignature(archiveCache);
    return archiveCache;
  }
}

function persistArchive(items) {
  archiveWriteQueue = archiveWriteQueue.then(async () => {
    await fs.promises.mkdir(path.dirname(ARCHIVE_FILE), { recursive: true });
    const temp = `${ARCHIVE_FILE}.tmp`;
    await fs.promises.writeFile(temp, JSON.stringify(items, null, 2), 'utf8');
    await fs.promises.rename(temp, ARCHIVE_FILE);
  }).catch((error) => console.error('[NEWS] Arşiv yazılamadı:', error?.message || error));
  return archiveWriteQueue;
}

function mergeWithArchive(current) {
  const cutoff = Date.now() - ARCHIVE_RETENTION_MS;
  const archived = loadArchive().filter((item) => {
    const t = new Date(item.publishedAt).getTime();
    return Number.isFinite(t) && t >= cutoff;
  });
  const byId = new Map();
  for (const item of [...archived, ...current]) byId.set(item.id || `${item.title}|${item.url}`, item);
  const merged = [...byId.values()]
    .sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt))
    .slice(0, MAX_ARCHIVE_ITEMS);
  const mergedSignature = snapshotSignature(merged);
  if (mergedSignature !== archiveSignature) {
    archiveCache = merged;
    archiveSignature = mergedSignature;
    void persistArchive(merged);
  }
  return merged;
}


function dedupeRawItems(items) {
  const seen = new Set();
  const output = [];
  for (const item of [...items].sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt))) {
    const titleKey = normalizeText(item.title);
    const urlKey = cleanText(item.url).replace(/[?#].*$/, '');
    const key = titleKey || urlKey;
    if (!key || seen.has(key) || (urlKey && seen.has(urlKey))) continue;
    seen.add(key);
    if (urlKey) seen.add(urlKey);
    output.push(item);
  }
  return output;
}

function classifyNewsItems(currentItems, previousItems) {
  const previousById = new Map(
    previousItems.map(item => [item.id || `${normalizeText(item.title)}|${item.url}`, item])
  );
  const items = [];
  let newCount = 0;
  let changedCount = 0;
  let unchangedCount = 0;
  for (const item of currentItems) {
    const key = item.id || `${normalizeText(item.title)}|${item.url}`;
    const previous = previousById.get(key);
    if (!previous) {
      newCount += 1;
      items.push(item);
    } else if (newsContentHash(previous) !== newsContentHash(item)) {
      changedCount += 1;
      items.push({ ...previous, ...item });
    } else {
      unchangedCount += 1;
      items.push(previous);
    }
  }
  return { items, newCount, changedCount, unchangedCount };
}

async function refreshNewsCache(period = 'all') {
  if (refreshPromise) return refreshPromise;

  refreshPromise = (async () => {
    const completedResults = [];
    let finished = false;

    const scanPromise = mapWithConcurrency(
      NEWS_SOURCES,
      SOURCE_CONCURRENCY,
      async (source) => {
        const state = sourceStateFor(source);
        const result = sourceIsEligible(source)
          ? await fetchSource(source, period)
          : {
              ok: Boolean(state.lastSuccessAt),
              skipped: true,
              source: source.name,
              count: state.lastItemCount,
              durationMs: 0,
              error: state.lastErrorType,
              items: []
            };
        completedResults.push(result);
        return result;
      }
    ).then((results) => {
      finished = true;
      return results;
    });

    scanPromise.catch(() => {});

    let results;
    try {
      results = await withTimeout(
        scanPromise,
        SCAN_TIMEOUT_MS,
        'Haber taraması'
      );
    } catch (error) {
      console.error(
        `[NEWS COLLECTOR] Genel tarama süresi aşıldı. ` +
        `${completedResults.length}/${NEWS_SOURCES.length} kaynak tamamlandı. ` +
        `Tamamlanan kaynaklarla devam ediliyor.`
      );
      results = [...completedResults];
    }

    // Güvenlik: Herhangi bir nedenle hiç sonuç oluşmadıysa önceki cache'i koru.
    if (!results.length && newsCache.items.length > 0) {
      console.warn('[NEWS COLLECTOR] Yeni sonuç alınamadı, önceki haber cache’i korunuyor.');
      return newsCache;
    }

    const currentRaw = dedupeRawItems(results.flatMap((result) => result.items));
    const classified = classifyNewsItems(currentRaw, loadArchive());
    const runMetrics = {
      attemptedSources: results.filter(result => !result.skipped).length,
      skippedSources: results.filter(result => result.skipped).length,
      notModifiedSources: results.filter(result => result.notModified).length,
      newItems: classified.newCount,
      changedItems: classified.changedCount,
      unchangedItems: classified.unchangedCount,
      reusedItems: classified.unchangedCount
    };
    const sourceResults = results.map(({ ok, source, count, durationMs, error,
      skipped, notModified }) => ({
      ok,
      source,
      count,
      durationMs,
      error: error || null,
      skipped: Boolean(skipped),
      notModified: Boolean(notModified)
    }));

    if (classified.newCount === 0 &&
        classified.changedCount === 0 &&
        newsCache.items.length > 0) {
      newsCache = {
        ...newsCache,
        sourceResults,
        metrics: runMetrics,
        partial: !finished,
        completedSourceCount: results.length
      };
      return newsCache;
    }

    const archivedRaw = dedupeRawItems(mergeWithArchive(classified.items));

    /*
      CANLI VERİ GÜVENCESİ
      -------------------
      Render yeniden başladığında repodaki eski JSON dosyası kısa süreliğine
      servis edilebilir. Ağır gruplama bitmeden önce en güncel 500 haberi hızlıca
      gruplayıp atomik olarak yayınlıyoruz. Böylece uygulama dakikalarca eski
      haber göstermiyor. Tam gruplama bittiğinde bu geçici snapshot otomatik
      olarak daha zengin nihai snapshot ile değiştirilir.
    */
    const fastPublishLimit = Math.max(
      100,
      Math.min(1000, Number(process.env.NEWS_FAST_PUBLISH_LIMIT || 500))
    );
    const fastItems = archivedRaw.slice(0, fastPublishLimit);

    if (fastItems.length > 0 && (classified.newCount > 0 || classified.changedCount > 0)) {
      const fastGrouped = buildStoryGroups(fastItems);
      const fastSourceResults = sourceResults;
      const fastActiveSources = fastSourceResults.filter((item) => item.ok).length;
      const fastCreatedAt = Date.now();

      await writeJsonAtomic(NEWS_DATABASE_FILE, {
        success: true,
        createdAt: fastCreatedAt,
        updatedAt: new Date(fastCreatedAt).toISOString(),
        newsCount: fastGrouped.length,
        totalSources: NEWS_SOURCES.length,
        activeSources: fastActiveSources,
        failedSources: Math.max(0, NEWS_SOURCES.length - fastActiveSources),
        items: fastGrouped,
        sourceResults: fastSourceResults,
        partial: true,
        completedSourceCount: results.length,
        fastPublished: true,
        ...runMetrics
      });

      await writeCollectorStatus({
        running: true,
        phase: 'grouping',
        startedAt: new Date().toISOString(),
        completedAt: null,
        newsCount: fastGrouped.length,
        totalSources: NEWS_SOURCES.length,
        activeSources: fastActiveSources,
        failedSources: Math.max(0, NEWS_SOURCES.length - fastActiveSources),
        lastFastPublishAt: new Date(fastCreatedAt).toISOString(),
        error: null
      });

      lastPublishedSignature = snapshotSignature(fastGrouped);
      console.log(
        `[NEWS COLLECTOR] Hızlı yayın tamamlandı: ${fastGrouped.length} güncel haber`
      );
    }

    // Arşivin tamamı korunur; yalnızca en güncel bölüm gruplanır.
    // Varsayılan 1.500 sınırı Render CPU/RAM yükünü güvenli tutar.
    const groupingLimit = Math.max(
      500,
      Math.min(2500, Number(process.env.NEWS_GROUPING_LIMIT || 1500))
    );
    const groupingItems = archivedRaw.slice(0, groupingLimit);

    console.log(
      `[NEWS COLLECTOR] Gruplama başladı: ${groupingItems.length} haber`
    );

    const grouped = buildStoryGroups(groupingItems);

    console.log(
      `[NEWS COLLECTOR] Gruplama tamamlandı: ${grouped.length} haber grubu`
    );

    newsCache = {
      createdAt: Date.now(),
      items: grouped,
      period,
      sourceResults,
      partial: !finished,
      completedSourceCount: results.length,
      totalSourceCount: NEWS_SOURCES.length,
      metrics: runMetrics
    };

    return newsCache;
  })().finally(() => {
    refreshPromise = null;
  });

  return refreshPromise;
}

async function getNewsData(forceRefresh = false, period = 'all') {
  const valid = newsCache.items.length > 0 && Date.now() - newsCache.createdAt < CACHE_DURATION_MS && newsCache.period === period;
  if (!forceRefresh && valid) return { ...newsCache, fromCache: true };
  return { ...(await refreshNewsCache(period)), fromCache: false };
}

function normalizePeriod(value) {
  const period = String(value || 'all').toLowerCase();
  return Object.prototype.hasOwnProperty.call(PERIODS, period) ? period : 'all';
}

function filterByPeriod(items, period) {
  const duration = PERIODS[period];
  if (duration == null) return items;
  const cutoff = Date.now() - duration;
  return items.filter((item) => {
    const t = new Date(item.publishedAt).getTime();
    return Number.isFinite(t) && t >= cutoff && t <= Date.now() + 300000;
  });
}

function diversifySources(items) {
  const queue = [...items];
  const output = [];
  while (queue.length) {
    const recentSources = new Set(output.slice(-3).map((x) => x.source));
    let index = queue.findIndex((x) => !recentSources.has(x.source));
    if (index < 0) index = 0;
    output.push(queue.splice(index, 1)[0]);
  }
  return output;
}

function balanceGeneralFeed(items) {
  const categories = ['gundem', 'dunya', 'ekonomi', 'spor', 'teknoloji'];
  const buckets = new Map(categories.map((category) => [category, []]));
  const other = [];

  for (const item of items) {
    const bucket = buckets.get(item.category);
    if (bucket) bucket.push(item);
    else other.push(item);
  }

  for (const bucket of buckets.values()) {
    bucket.sort((a, b) => {
      const importanceDiff = b.importanceScore - a.importanceScore;
      if (importanceDiff !== 0) return importanceDiff;
      return new Date(b.publishedAt) - new Date(a.publishedAt);
    });
  }

  const weights = ['gundem', 'dunya', 'ekonomi', 'gundem', 'spor', 'teknoloji'];
  const output = [];
  let progressed = true;
  while (progressed) {
    progressed = false;
    for (const category of weights) {
      const bucket = buckets.get(category);
      if (bucket && bucket.length) {
        output.push(bucket.shift());
        progressed = true;
      }
    }
  }

  return diversifySources([...output, ...other]);
}

function isStrictBreaking(item) {
  const ageMs = Date.now() - new Date(item.publishedAt).getTime();
  if (!item.isBreaking || ageMs < 0 || ageMs > 2 * 60 * 60 * 1000) return false;
  const text = `${item.title} ${item.description}`;
  if (hasLowImpactSignal(text) && !hasHighImpactSignal(text)) return false;
  return hasHighImpactSignal(text) && (hasExplicitBreakingSignal(text) || item.sourceCount >= 2 || item.confidenceScore >= 94);
}

async function writeJsonAtomic(filePath, value) {
  await fs.promises.mkdir(path.dirname(filePath), { recursive: true });
  const tempPath = `${filePath}.tmp`;
  await fs.promises.writeFile(
    tempPath,
    JSON.stringify(value, null, 2),
    'utf8'
  );
  await fs.promises.rename(tempPath, filePath);
}

function mergeCollectorStatus(previous, current) {
  return {
    ...(previous && typeof previous === 'object' ? previous : {}),
    ...(current && typeof current === 'object' ? current : {})
  };
}

async function writeCollectorStatus(status) {
  try {
    const nextStatus = {
      ...mergeCollectorStatus(persistedCollectorStatus, status),
      sourceStates: Object.fromEntries(sourceState),
      processId: process.pid,
      writtenAt: new Date().toISOString()
    };
    await writeJsonAtomic(NEWS_STATUS_FILE, nextStatus);
    persistedCollectorStatus = nextStatus;
  } catch (error) {
    console.error(
      '[NEWS COLLECTOR] Durum dosyası yazılamadı:',
      error?.message || error
    );
  }
}

async function runCollectorOnce() {
  const startedAt = Date.now();

  await writeCollectorStatus({
    running: true,
    phase: 'scanning',
    startedAt: new Date(startedAt).toISOString(),
    completedAt: null,
    error: null
  });

  try {
    console.log(
      `[NEWS COLLECTOR] Tarama başladı. Kaynak sayısı: ${NEWS_SOURCES.length}`
    );

    const data = await refreshNewsCache('all');
    const activeSources = data.sourceResults.filter(
      (item) => item.ok
    ).length;

    const snapshot = {
      success: true,
      createdAt: data.createdAt,
      updatedAt: new Date(data.createdAt).toISOString(),
      newsCount: data.items.length,
      totalSources: NEWS_SOURCES.length,
      activeSources,
      failedSources: Math.max(
        0,
        NEWS_SOURCES.length - activeSources
      ),
      items: data.items,
      sourceResults: data.sourceResults,
      partial: Boolean(data.partial),
      completedSourceCount: data.completedSourceCount || data.sourceResults.length
    };

    const finalSignature = snapshotSignature(snapshot.items);
    const finalPublished = finalSignature !== lastPublishedSignature;
    if (finalPublished) {
      await writeJsonAtomic(NEWS_DATABASE_FILE, snapshot);
      lastPublishedSignature = finalSignature;
    }

    const metrics = data.metrics || {};

    await writeCollectorStatus({
      running: false,
      phase: 'completed',
      startedAt: new Date(startedAt).toISOString(),
      completedAt: new Date().toISOString(),
      durationMs: Date.now() - startedAt,
      newsCount: snapshot.newsCount,
      totalSources: snapshot.totalSources,
      activeSources: snapshot.activeSources,
      failedSources: snapshot.failedSources,
      attemptedSources: metrics.attemptedSources || 0,
      successfulSources: data.sourceResults.filter(item => item.ok && !item.skipped).length,
      skippedSources: metrics.skippedSources || 0,
      notModifiedSources: metrics.notModifiedSources || 0,
      newItems: metrics.newItems || 0,
      changedItems: metrics.changedItems || 0,
      unchangedItems: metrics.unchangedItems || 0,
      reusedItems: metrics.reusedItems || 0,
      finalPublished,
      ...(finalPublished ? { lastFinalPublishAt: new Date().toISOString() } : {}),
      nextScheduledRunAt: new Date(Date.now() + COLLECTOR_TICK_MS).toISOString(),
      lastRunStartedAt: new Date(startedAt).toISOString(),
      lastRunCompletedAt: new Date().toISOString(),
      lastSuccessfulRunAt: new Date().toISOString(),
      error: null
    });

    console.log(
      `[NEWS COLLECTOR] Tamamlandı: ${snapshot.newsCount} haber, ` +
      `${snapshot.activeSources}/${snapshot.totalSources} kaynak, ` +
      `${Date.now() - startedAt} ms`
    );
    console.log('[NEWS COLLECTOR] Tur özeti:', {
      ...metrics,
      finalPublished,
      durationMs: Date.now() - startedAt,
      slowestSources: [...data.sourceResults]
        .filter(item => !item.skipped)
        .sort((left, right) => right.durationMs - left.durationMs)
        .slice(0, 5)
        .map(item => ({ source: item.source, durationMs: item.durationMs, ok: item.ok }))
    });
  } catch (error) {
    console.error(
      '[NEWS COLLECTOR] Tarama hatası:',
      error?.stack || error?.message || error
    );

    await writeCollectorStatus({
      running: false,
      phase: 'failed',
      startedAt: new Date(startedAt).toISOString(),
      completedAt: new Date().toISOString(),
      durationMs: Date.now() - startedAt,
      error: error?.message || String(error)
    });
  }
}

function collectAndSaveNews() {
  if (collectorRunPromise) return collectorRunPromise;
  collectorRunPromise = runCollectorOnce().finally(() => {
    collectorRunPromise = null;
  });
  return collectorRunPromise;
}

let intervalHandle = null;
let stopping = false;

async function startCollector() {
  console.log(
    `[NEWS COLLECTOR] Başlatıldı. Yenileme aralığı: ` +
    `${Math.round(COLLECTOR_TICK_MS / 60000)} dakika kontrol turu`
  );

  await collectAndSaveNews();

  intervalHandle = setInterval(() => {
    void collectAndSaveNews();
  }, COLLECTOR_TICK_MS);


}

async function stopCollector(signal) {
  if (stopping) return;
  stopping = true;

  console.log(`[NEWS COLLECTOR] ${signal} alındı, kapanıyor...`);

  if (intervalHandle) {
    clearInterval(intervalHandle);
  }

  await writeCollectorStatus({
    running: false,
    phase: 'stopped',
    completedAt: new Date().toISOString(),
    error: null
  });

  process.exit(0);
}

if (require.main === module) {
  process.on('SIGTERM', () => {
    void stopCollector('SIGTERM');
  });

  process.on('SIGINT', () => {
    void stopCollector('SIGINT');
  });

  process.on('unhandledRejection', (error) => {
    console.error(
      '[NEWS COLLECTOR] Yakalanmamış Promise hatası:',
      error?.stack || error
    );
  });

  process.on('uncaughtException', (error) => {
    console.error(
      '[NEWS COLLECTOR] Yakalanmamış hata:',
      error?.stack || error
    );
  });

  void startCollector();
}

module.exports = {
  classifyNewsItems,
  collectAndSaveNews,
  fetchSource,
  mergeCollectorStatus,
  newsContentHash,
  refreshTierForSource,
  snapshotSignature,
  sourceBackoffMs,
  sourceIsEligible,
  sourceStateFor
};
