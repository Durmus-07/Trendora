const express = require("express");
const Parser = require("rss-parser");
const fs = require("fs");
const path = require("path");

const router = express.Router();

const parser = new Parser({
  timeout: 12000,
  headers: {
    "User-Agent":
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Trendora/1.0",
    Accept:
      "application/rss+xml, application/xml, text/xml, application/atom+xml, */*",
  },
  customFields: {
    item: [
      ["media:content", "mediaContent", { keepArray: true }],
      ["media:thumbnail", "mediaThumbnail", { keepArray: true }],
      ["content:encoded", "contentEncoded"],
    ],
  },
});

const NEWS_SOURCES = [
  {
    name: "TRT Haber - Son Dakika",
    category: "son_dakika",
    url: "https://www.trthaber.com/sondakika_articles.rss",
    priority: 100,
  },
  {
    name: "TRT Haber - Gündem",
    category: "gundem",
    url: "https://www.trthaber.com/gundem_articles.rss",
    priority: 90,
  },
  {
    name: "TRT Haber - Türkiye",
    category: "turkiye",
    url: "https://www.trthaber.com/turkiye_articles.rss",
    priority: 90,
  },
  {
    name: "TRT Haber - Dünya",
    category: "dunya",
    url: "https://www.trthaber.com/dunya_articles.rss",
    priority: 85,
  },
  {
    name: "TRT Haber - Ekonomi",
    category: "ekonomi",
    url: "https://www.trthaber.com/ekonomi_articles.rss",
    priority: 90,
  },
  {
    name: "TRT Haber - Spor",
    category: "spor",
    url: "https://www.trthaber.com/spor_articles.rss",
    priority: 80,
  },
  {
    name: "TRT Haber - Bilim Teknoloji",
    category: "teknoloji",
    url: "https://www.trthaber.com/bilim_teknoloji_articles.rss",
    priority: 85,
  },
  {
    name: "Google Haberler - Genel",
    category: "gundem",
    googleQuery: "Türkiye",
    priority: 82,
  },
  {
    name: "Google Haberler - Gündem",
    category: "gundem",
    googleQuery: "gündem Türkiye",
    priority: 84,
  },
  {
    name: "Google Haberler - Ekonomi",
    category: "ekonomi",
    googleQuery: "ekonomi OR enflasyon OR faiz OR dolar OR altın",
    priority: 82,
  },
  {
    name: "Google Haberler - Spor",
    category: "spor",
    googleQuery: "spor OR futbol OR basketbol",
    priority: 78,
  },
  {
    name: "Google Haberler - Yapay Zekâ",
    category: "yapay_zeka",
    googleQuery: "yapay zeka",
    priority: 80,
  },
  {
    name: "Google Haberler - Teknoloji",
    category: "teknoloji",
    googleQuery: "teknoloji",
    priority: 75,
  },
  {
    name: "Google Haberler - Borsa",
    category: "borsa",
    googleQuery: "borsa OR BIST",
    priority: 80,
  },
  {
    name: "Google Haberler - Kripto",
    category: "kripto",
    googleQuery: "kripto OR bitcoin",
    priority: 75,
  },
  {
    name: "CoinDesk",
    category: "kripto",
    url: "https://www.coindesk.com/arc/outboundfeeds/rss/",
    priority: 85,
  },
];

const CACHE_DURATION_MS = 3 * 60 * 1000;
const MAX_ARCHIVE_ITEMS = 12000;
const ARCHIVE_RETENTION_MS = 370 * 24 * 60 * 60 * 1000;
const ARCHIVE_FILE = path.join(__dirname, "..", "database", "news_archive.json");

const PERIODS = {
  "1h": 60 * 60 * 1000,
  "4h": 4 * 60 * 60 * 1000,
  "12h": 12 * 60 * 60 * 1000,
  "24h": 24 * 60 * 60 * 1000,
  "7d": 7 * 24 * 60 * 60 * 1000,
  "30d": 30 * 24 * 60 * 60 * 1000,
  "60d": 60 * 24 * 60 * 60 * 1000,
  "180d": 180 * 24 * 60 * 60 * 1000,
  "365d": 365 * 24 * 60 * 60 * 1000,
  all: null,
};

let newsCache = {
  createdAt: 0,
  items: [],
  sourceResults: [],
  period: "24h",
};

let archiveWriteQueue = Promise.resolve();

function cleanText(value) {
  if (!value) return "";

  return String(value)
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/\s+/g, " ")
    .trim();
}

function getGoogleNewsPublisher(title) {
  if (!title) return "";
  const parts = String(title).split(" - ");
  return parts.length < 2 ? "" : parts[parts.length - 1].trim();
}

function removeGoogleNewsPublisher(title) {
  if (!title) return "";
  const parts = String(title).split(" - ");
  if (parts.length < 2) return cleanText(title);
  parts.pop();
  return cleanText(parts.join(" - "));
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
    if (typeof candidate === "string" && /^https?:\/\//i.test(candidate)) {
      return candidate;
    }
  }

  const html = [
    item?.contentEncoded,
    item?.content,
    item?.description,
    item?.summary,
  ]
    .filter(Boolean)
    .join(" ");

  const imageMatch = html.match(/<img[^>]+src=["'](https?:\/\/[^"']+)["']/i);
  return imageMatch ? imageMatch[1] : "";
}

function parsePublishedDate(item) {
  const rawDate =
    item?.isoDate || item?.pubDate || item?.published || item?.updated || "";
  const parsed = new Date(rawDate);
  return Number.isNaN(parsed.getTime()) ? new Date(0) : parsed;
}

function normalizeForDeduplication(text) {
  return cleanText(text)
    .toLocaleLowerCase("tr-TR")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function createDeduplicationKey(item) {
  const normalizedTitle = normalizeForDeduplication(item.title);
  return normalizedTitle || item.url;
}

function calculateTrendScore(item) {
  let score = 45;
  const ageMinutes =
    (Date.now() - new Date(item.publishedAt).getTime()) / 60000;

  if (ageMinutes <= 15) score += 35;
  else if (ageMinutes <= 60) score += 25;
  else if (ageMinutes <= 180) score += 15;
  else if (ageMinutes <= 720) score += 8;

  if (item.isBreaking) score += 15;
  if (item.imageUrl) score += 3;
  if (item.category === "borsa" || item.category === "kripto") score += 2;

  return Math.max(0, Math.min(100, Math.round(score)));
}

function googleNewsUrl(query, period) {
  const periodQuery = period && period !== "all" ? ` when:${period}` : "";
  return `https://news.google.com/rss/search?q=${encodeURIComponent(
    `${query}${periodQuery}`
  )}&hl=tr&gl=TR&ceid=TR:tr`;
}

function sourceUrl(source, period) {
  if (source.googleQuery) return googleNewsUrl(source.googleQuery, period);
  return source.url;
}

function normalizeItem(item, source) {
  const isGoogleNews = source.name.startsWith("Google Haberler");
  const rawTitle = cleanText(item?.title);
  const title = isGoogleNews ? removeGoogleNewsPublisher(rawTitle) : rawTitle;
  const googlePublisher = isGoogleNews ? getGoogleNewsPublisher(rawTitle) : "";
  const description = cleanText(
    item?.contentSnippet ||
      item?.summary ||
      item?.description ||
      item?.content ||
      ""
  );
  const publishedDate = parsePublishedDate(item);
  const sourceName =
    googlePublisher ||
    cleanText(item?.creator) ||
    cleanText(item?.author) ||
    source.name;
  const titleLower = title.toLocaleLowerCase("tr-TR");
  const isBreaking =
    source.category === "son_dakika" ||
    titleLower.includes("son dakika") ||
    titleLower.includes("sıcak gelişme") ||
    titleLower.includes("acil");

  const normalized = {
    id: Buffer.from(`${source.name}|${item?.link || ""}|${title}`).toString(
      "base64url"
    ),
    title,
    description,
    url: item?.link || item?.guid || "",
    imageUrl: extractImage(item),
    source: sourceName,
    feedSource: source.name,
    category: source.category,
    publishedAt: publishedDate.toISOString(),
    isBreaking,
    priority: source.priority,
  };

  return {
    ...normalized,
    trendScore: calculateTrendScore(normalized),
    confidenceScore: source.name.startsWith("TRT Haber")
      ? 95
      : source.name === "CoinDesk"
        ? 90
        : 82,
  };
}

async function fetchSource(source, period = "24h") {
  try {
    const url = sourceUrl(source, period);
    const feed = await parser.parseURL(url);
    const items = (feed.items || [])
      .map((item) => normalizeItem(item, source))
      .filter((item) => item.title && item.url && item.publishedAt !== new Date(0).toISOString());

    return { ok: true, source: source.name, count: items.length, items };
  } catch (error) {
    console.error(`[NEWS] ${source.name} okunamadı:`, error?.message || error);
    return {
      ok: false,
      source: source.name,
      count: 0,
      error: error?.message || "Kaynak okunamadı",
      items: [],
    };
  }
}

function deduplicateAndSort(items) {
  const uniqueItems = new Map();

  for (const item of items) {
    const key = createDeduplicationKey(item);
    const existing = uniqueItems.get(key);

    if (!existing) {
      uniqueItems.set(key, item);
      continue;
    }

    const existingDate = new Date(existing.publishedAt).getTime();
    const newDate = new Date(item.publishedAt).getTime();

    if (
      item.priority > existing.priority ||
      (item.priority === existing.priority && newDate > existingDate)
    ) {
      uniqueItems.set(key, item);
    }
  }

  return [...uniqueItems.values()].sort((a, b) => {
    const dateDifference =
      new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime();
    if (dateDifference !== 0) return dateDifference;
    if (a.isBreaking !== b.isBreaking) {
      return Number(b.isBreaking) - Number(a.isBreaking);
    }
    return b.priority - a.priority;
  });
}

function loadArchive() {
  try {
    if (!fs.existsSync(ARCHIVE_FILE)) return [];
    const parsed = JSON.parse(fs.readFileSync(ARCHIVE_FILE, "utf8"));
    return Array.isArray(parsed) ? parsed : [];
  } catch (error) {
    console.error("[NEWS] Haber arşivi okunamadı:", error?.message || error);
    return [];
  }
}

function persistArchive(items) {
  archiveWriteQueue = archiveWriteQueue
    .then(async () => {
      await fs.promises.mkdir(path.dirname(ARCHIVE_FILE), { recursive: true });
      const temporaryFile = `${ARCHIVE_FILE}.tmp`;
      await fs.promises.writeFile(
        temporaryFile,
        JSON.stringify(items, null, 2),
        "utf8"
      );
      await fs.promises.rename(temporaryFile, ARCHIVE_FILE);
    })
    .catch((error) => {
      console.error("[NEWS] Haber arşivi yazılamadı:", error?.message || error);
    });

  return archiveWriteQueue;
}

function mergeWithArchive(currentItems) {
  const cutoff = Date.now() - ARCHIVE_RETENTION_MS;
  const archivedItems = loadArchive().filter((item) => {
    const timestamp = new Date(item.publishedAt).getTime();
    return Number.isFinite(timestamp) && timestamp >= cutoff;
  });

  const merged = deduplicateAndSort([...currentItems, ...archivedItems]).slice(
    0,
    MAX_ARCHIVE_ITEMS
  );

  void persistArchive(merged);
  return merged;
}

async function refreshNewsCache(period = "24h") {
  const results = await Promise.all(
    NEWS_SOURCES.map((source) => fetchSource(source, period))
  );
  const currentItems = deduplicateAndSort(results.flatMap((result) => result.items));
  const finalItems = mergeWithArchive(currentItems);

  newsCache = {
    createdAt: Date.now(),
    items: finalItems,
    period,
    sourceResults: results.map(({ ok, source, count, error }) => ({
      ok,
      source,
      count,
      error: error || null,
    })),
  };

  return newsCache;
}

async function getNewsData(forceRefresh = false, period = "24h") {
  const cacheIsValid =
    newsCache.items.length > 0 &&
    Date.now() - newsCache.createdAt < CACHE_DURATION_MS &&
    newsCache.period === period;

  if (!forceRefresh && cacheIsValid) {
    return { ...newsCache, fromCache: true };
  }

  const refreshed = await refreshNewsCache(period);
  return { ...refreshed, fromCache: false };
}

function normalizePeriod(value) {
  const period = String(value || "24h").toLowerCase();
  return Object.prototype.hasOwnProperty.call(PERIODS, period) ? period : "24h";
}

function filterByPeriod(items, period) {
  const duration = PERIODS[period];
  if (duration == null) return items;
  const cutoff = Date.now() - duration;

  return items.filter((item) => {
    const timestamp = new Date(item.publishedAt).getTime();
    return Number.isFinite(timestamp) && timestamp >= cutoff && timestamp <= Date.now() + 300000;
  });
}

router.get("/", async (req, res) => {
  try {
    const requestedCategory = cleanText(req.query.category).toLocaleLowerCase("tr-TR");
    const breakingOnly = String(req.query.breaking || "").toLowerCase() === "true";
    const period = normalizePeriod(req.query.period);
    const forceRefresh = String(req.query.refresh || "").toLowerCase() === "true";
    const parsedLimit = Number.parseInt(req.query.limit, 10);
    const limit = Number.isFinite(parsedLimit)
      ? Math.min(Math.max(parsedLimit, 1), 2000)
      : 200;

    const data = await getNewsData(forceRefresh, period);
    let filteredNews = filterByPeriod(data.items, period);

    if (requestedCategory && requestedCategory !== "tumu") {
      if (requestedCategory === "son_dakika") {
        filteredNews = filteredNews.filter((item) => item.isBreaking);
      } else {
        filteredNews = filteredNews.filter(
          (item) => item.category === requestedCategory
        );
      }
    }

    if (breakingOnly) {
      filteredNews = filteredNews.filter((item) => item.isBreaking);
    }

    const workingSources = data.sourceResults.filter((source) => source.ok).length;

    res.json({
      success: true,
      message: "Trendora Haber Servisi Aktif",
      updatedAt: new Date(data.createdAt).toISOString(),
      fromCache: data.fromCache,
      total: filteredNews.length,
      returned: Math.min(filteredNews.length, limit),
      archiveCount: data.items.length,
      workingSources,
      totalSources: NEWS_SOURCES.length,
      filters: {
        category: requestedCategory || "tumu",
        breakingOnly,
        period,
        limit,
      },
      news: filteredNews.slice(0, limit),
    });
  } catch (error) {
    console.error("[NEWS] Genel hata:", error);
    res.status(500).json({
      success: false,
      error: "Haberler şu anda alınamadı.",
      details:
        process.env.NODE_ENV === "development" ? error?.message : undefined,
    });
  }
});

router.get("/health", async (req, res) => {
  try {
    const data = await getNewsData(false, "24h");
    res.json({
      success: true,
      service: "Trendora Haber Merkezi",
      cachedNewsCount: data.items.length,
      cacheUpdatedAt: new Date(data.createdAt).toISOString(),
      archiveFile: ARCHIVE_FILE,
      sources: data.sourceResults,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error?.message || "Haber servisi kontrol edilemedi.",
    });
  }
});

router.get("/sources", (req, res) => {
  res.json({
    success: true,
    total: NEWS_SOURCES.length,
    sources: NEWS_SOURCES.map(({ name, category, url, googleQuery, priority }) => ({
      name,
      category,
      url: url || googleNewsUrl(googleQuery, "24h"),
      priority,
    })),
  });
});

async function getNewsStatus(options = {}) {
  const forceRefresh = options.forceRefresh === true;
  const data = await getNewsData(forceRefresh, "24h");
  const activeSources = data.sourceResults.filter((source) => source.ok).length;

  return {
    newsCount: data.items.length,
    totalSources: NEWS_SOURCES.length,
    activeSources,
    failedSources: Math.max(0, NEWS_SOURCES.length - activeSources),
    updatedAt: data.createdAt > 0 ? new Date(data.createdAt).toISOString() : null,
    fromCache: data.fromCache === true,
  };
}

module.exports = router;
module.exports.getNewsStatus = getNewsStatus;
