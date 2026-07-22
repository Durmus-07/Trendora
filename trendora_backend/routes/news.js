const express = require("express");
const Parser = require("rss-parser");

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
    name: "Google Haberler - Yapay Zekâ",
    category: "yapay_zeka",
    url:
      "https://news.google.com/rss/search?q=yapay+zeka&hl=tr&gl=TR&ceid=TR:tr",
    priority: 80,
  },
  {
    name: "Google Haberler - Teknoloji",
    category: "teknoloji",
    url:
      "https://news.google.com/rss/search?q=teknoloji&hl=tr&gl=TR&ceid=TR:tr",
    priority: 75,
  },
  {
    name: "Google Haberler - Borsa",
    category: "borsa",
    url:
      "https://news.google.com/rss/search?q=borsa+OR+BIST&hl=tr&gl=TR&ceid=TR:tr",
    priority: 80,
  },
  {
    name: "Google Haberler - Kripto",
    category: "kripto",
    url:
      "https://news.google.com/rss/search?q=kripto+OR+bitcoin&hl=tr&gl=TR&ceid=TR:tr",
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

let newsCache = {
  createdAt: 0,
  items: [],
  sourceResults: [],
};

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
  if (parts.length < 2) return "";

  return parts[parts.length - 1].trim();
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
    if (
      typeof candidate === "string" &&
      /^https?:\/\//i.test(candidate)
    ) {
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

  const imageMatch = html.match(
    /<img[^>]+src=["'](https?:\/\/[^"']+)["']/i
  );

  return imageMatch ? imageMatch[1] : "";
}

function parsePublishedDate(item) {
  const rawDate =
    item?.isoDate ||
    item?.pubDate ||
    item?.published ||
    item?.updated ||
    "";

  const parsed = new Date(rawDate);

  if (Number.isNaN(parsed.getTime())) {
    return new Date(0);
  }

  return parsed;
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

function normalizeItem(item, source) {
  const isGoogleNews = source.name.startsWith("Google Haberler");

  const rawTitle = cleanText(item?.title);
  const title = isGoogleNews
    ? removeGoogleNewsPublisher(rawTitle)
    : rawTitle;

  const googlePublisher = isGoogleNews
    ? getGoogleNewsPublisher(rawTitle)
    : "";

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
    id: Buffer.from(
      `${source.name}|${item?.link || ""}|${title}`
    ).toString("base64url"),
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

async function fetchSource(source) {
  try {
    const feed = await parser.parseURL(source.url);

    const items = (feed.items || [])
      .map((item) => normalizeItem(item, source))
      .filter((item) => item.title && item.url);

    return {
      ok: true,
      source: source.name,
      count: items.length,
      items,
    };
  } catch (error) {
    console.error(
      `[NEWS] ${source.name} okunamadı:`,
      error?.message || error
    );

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
    if (a.isBreaking !== b.isBreaking) {
      return Number(b.isBreaking) - Number(a.isBreaking);
    }

    const dateDifference =
      new Date(b.publishedAt).getTime() -
      new Date(a.publishedAt).getTime();

    if (dateDifference !== 0) return dateDifference;

    return b.priority - a.priority;
  });
}

async function refreshNewsCache() {
  const results = await Promise.all(
    NEWS_SOURCES.map((source) => fetchSource(source))
  );

  const allItems = results.flatMap((result) => result.items);
  const finalItems = deduplicateAndSort(allItems);

  newsCache = {
    createdAt: Date.now(),
    items: finalItems,
    sourceResults: results.map(
      ({ ok, source, count, error }) => ({
        ok,
        source,
        count,
        error: error || null,
      })
    ),
  };

  return newsCache;
}

async function getNewsData(forceRefresh = false) {
  const cacheIsValid =
    newsCache.items.length > 0 &&
    Date.now() - newsCache.createdAt < CACHE_DURATION_MS;

  if (!forceRefresh && cacheIsValid) {
    return {
      ...newsCache,
      fromCache: true,
    };
  }

  const refreshed = await refreshNewsCache();

  return {
    ...refreshed,
    fromCache: false,
  };
}

router.get("/", async (req, res) => {
  try {
    const requestedCategory = cleanText(req.query.category)
      .toLocaleLowerCase("tr-TR");

    const breakingOnly =
      String(req.query.breaking || "").toLowerCase() === "true";
const period = String(req.query.period || "24h").toLowerCase();
    const forceRefresh =
      String(req.query.refresh || "").toLowerCase() === "true";

    const parsedLimit = Number.parseInt(req.query.limit, 10);
    const limit = Number.isFinite(parsedLimit)
      ? Math.min(Math.max(parsedLimit, 1), 100)
      : 50;

    const data = await getNewsData(forceRefresh);

    let filteredNews = data.items;
if (
  requestedCategory &&
  requestedCategory !== "tumu" &&
  requestedCategory !== "son_dakika"
) {
  filteredNews = filteredNews.filter(
    (item) => item.category === requestedCategory
  );
}

if (requestedCategory === "son_dakika" || breakingOnly) {
  filteredNews = filteredNews.filter(
    (item) => item.isBreaking
  );
}
    if (requestedCategory && requestedCategory !== "tumu") {
      filteredNews = filteredNews.filter(
        (item) => item.category === requestedCategory
      );
    }

    if (breakingOnly) {
      filteredNews = filteredNews.filter(
        (item) => item.isBreaking
      );
    }

    const workingSources = data.sourceResults.filter(
      (source) => source.ok
    ).length;

    res.json({
      success: true,
      message: "Trendora Haber Servisi Aktif",
      updatedAt: new Date(data.createdAt).toISOString(),
      fromCache: data.fromCache,
      total: filteredNews.length,
      returned: Math.min(filteredNews.length, limit),
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
        process.env.NODE_ENV === "development"
          ? error?.message
          : undefined,
    });
  }
});

router.get("/health", async (req, res) => {
  try {
    const data = await getNewsData(false);

    res.json({
      success: true,
      service: "Trendora Haber Merkezi",
      cachedNewsCount: data.items.length,
      cacheUpdatedAt: new Date(data.createdAt).toISOString(),
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
    sources: NEWS_SOURCES.map(
      ({ name, category, url, priority }) => ({
        name,
        category,
        url,
        priority,
      })
    ),
  });
});

module.exports = router;
