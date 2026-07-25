console.log('BENİM YENİ SERVER ÇALIŞTI');

const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const opportunitiesRoutes = require('./routes/opportunities');
const newsRoutes = require('./routes/news');
const trendsRoutes = require('./routes/trends');
const aiRoutes = require('./routes/ai');

const app = express();
const PORT = Number(process.env.PORT || 3000);

app.use(cors());

app.use((req, res, next) => {
  console.log(`[ISTEK] ${req.method} ${req.originalUrl}`);

  res.on('finish', () => {
    console.log(
      `[CEVAP] ${req.method} ${req.originalUrl} -> ${res.statusCode}`
    );
  });

  next();
});

app.use(express.json());

const opportunitiesFilePath = path.join(
  __dirname,
  'database',
  'opportunities.json'
);

function readOpportunitiesDatabase() {
  try {
    if (!fs.existsSync(opportunitiesFilePath)) {
      return {
        updatedAt: null,
        items: []
      };
    }

    const rawData = fs.readFileSync(
      opportunitiesFilePath,
      'utf8'
    );

    const parsedData = JSON.parse(rawData);

    return {
      updatedAt: parsedData.updatedAt || null,
      items: Array.isArray(parsedData.items)
        ? parsedData.items
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

function normalize(value) {
  return String(value || '')
    .trim()
    .toLowerCase();
}

function isOpportunityActive(item) {
  if (item.active === false) {
    return false;
  }

  const now = new Date();

  if (item.catalogStartDate) {
    const startDate = new Date(
      `${item.catalogStartDate}T00:00:00`
    );

    if (now < startDate) {
      return false;
    }
  }

  if (item.catalogEndDate) {
    const endDate = new Date(
      `${item.catalogEndDate}T23:59:59`
    );

    if (now > endDate) {
      return false;
    }
  }

  return true;
}

function prepareOpportunity(item) {
  return {
    ...item,
    url: item.officialUrl || item.url || '',
    verified: Boolean(item.verifiedAt),
    status: isOpportunityActive(item)
      ? 'active'
      : 'expired'
  };
}

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Trendora sunucusu çalışıyor.',
    endpoints: {
      opportunities: '/api/opportunities',
      a101: '/api/opportunities/a101',
      bim: '/api/opportunities/bim',
      trendyol: '/api/opportunities/trendyol',
      trends: '/api/trends',
      trendAnalysis: '/api/trends/analyze',
      trendHealth: '/api/trends/health',
      ai: '/api/ai'
    }
  });
});

/*
  Eski Flutter kodu /api/trendyol adresini kullanıyorsa
  çalışmaya devam etsin diye bu adres korunur.
*/
app.get('/api/trendyol', (req, res) => {
  try {
    const database =
      readOpportunitiesDatabase();

    const items = database.items
      .map(prepareOpportunity)
      .filter(item => {
        return (
          normalize(item.source) ===
            'trendyol' &&
          item.status === 'active'
        );
      });

    res.json({
      success: true,
      count: items.length,
      updatedAt: database.updatedAt,
      opportunities: items,
      products: items,
      items,
      data: items
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message:
        'Trendyol fırsatları okunamadı.',
      error: error.message
    });
  }
});

app.use(
  '/api/opportunities',
  opportunitiesRoutes
);

app.use(
  '/api/news',
  newsRoutes
);

app.use(
  '/api/trends',
  trendsRoutes
);

app.use(
  '/api/ai',
  aiRoutes
);

function getOpportunityStatus() {
  const database =
    readOpportunitiesDatabase();

  const activeItems = database.items
    .map(prepareOpportunity)
    .filter(
      item => item.status === 'active'
    );

  const sourceKeys = new Set(
    activeItems
      .map(item =>
        normalize(
          item.store ||
          item.source ||
          item.seller ||
          item.sourceName
        )
      )
      .filter(Boolean)
  );

  return {
    opportunityCount: activeItems.length,
    totalSources: sourceKeys.size,
    activeSources: sourceKeys.size,
    updatedAt: database.updatedAt
  };
}

app.get('/api/scan-status', async (req, res) => {
  const startedAt = Date.now();

  const opportunityStatus =
    getOpportunityStatus();

  const newsFallback = {
    newsCount: 0,
    totalSources: 0,
    activeSources: 0,
    failedSources: 0,
    updatedAt: null,
    error: 'Haber durumu okunamadı.'
  };

  const trendFallback = {
    trends: [],
    trendCount: 0,
    updatedAt: null,
    ready: false,
    error: 'Trend durumu okunamadı.'
  };

  const [
    newsResult,
    trendResult
  ] = await Promise.allSettled([
    newsRoutes.getNewsStatus(),
    trendsRoutes.getTrendStatus()
  ]);

  const newsStatus =
    newsResult.status === 'fulfilled'
      ? newsResult.value
      : {
          ...newsFallback,
          error:
            newsResult.reason?.message ||
            newsFallback.error
        };

  const trendStatus =
    trendResult.status === 'fulfilled'
      ? trendResult.value
      : {
          ...trendFallback,
          error:
            trendResult.reason?.message ||
            trendFallback.error
        };

  const trendCount =
    Number.isFinite(
      Number(trendStatus.trendCount)
    )
      ? Number(trendStatus.trendCount)
      : Array.isArray(trendStatus.trends)
        ? trendStatus.trends.length
        : 0;

  const trendEngineCompleted =
    trendStatus.ready === true &&
    !trendStatus.error;

  const scannedSources =
    Number(newsStatus.totalSources || 0) +
    Number(
      opportunityStatus.totalSources || 0
    ) +
    1;

  const activeSources =
    Number(newsStatus.activeSources || 0) +
    Number(
      opportunityStatus.activeSources || 0
    ) +
    (trendEngineCompleted ? 1 : 0);

  const partial =
    Boolean(newsStatus.error) ||
    Number(
      newsStatus.failedSources || 0
    ) > 0 ||
    !trendEngineCompleted;

  res.set('Cache-Control', 'no-store');

  res.json({
    success: true,
    status:
      partial
        ? 'partial'
        : 'completed',
    message:
      partial
        ? 'Dünya taraması tamamlandı; bazı kaynaklar henüz hazır değil.'
        : 'Dünya taraması tamamlandı.',
    scannedSources,
    activeSources,
    failedSources: Math.max(
      0,
      scannedSources - activeSources
    ),
    newsCount:
      Number(newsStatus.newsCount || 0),
    opportunityCount:
      opportunityStatus.opportunityCount,
    trendCount,
    modules: {
      news: {
        status:
          newsStatus.error ||
          Number(
            newsStatus.failedSources || 0
          ) > 0
            ? 'partial'
            : 'completed',
        count:
          Number(newsStatus.newsCount || 0),
        activeSources:
          Number(
            newsStatus.activeSources || 0
          ),
        totalSources:
          Number(
            newsStatus.totalSources || 0
          ),
        updatedAt:
          newsStatus.updatedAt || null
      },
      opportunities: {
        status: 'completed',
        count:
          opportunityStatus.opportunityCount,
        activeSources:
          opportunityStatus.activeSources,
        totalSources:
          opportunityStatus.totalSources,
        updatedAt:
          opportunityStatus.updatedAt || null
      },
      trends: {
        status:
          trendEngineCompleted
            ? 'completed'
            : 'partial',
        count: trendCount,
        activeSources:
          trendEngineCompleted ? 1 : 0,
        totalSources: 1,
        updatedAt:
          trendStatus.updatedAt || null,
        collectorRunning:
          trendStatus.collectorRunning === true,
        collectorPhase:
          trendStatus.collectorPhase ||
          'unknown'
      }
    },
    durationMs:
      Date.now() - startedAt,
    updatedAt:
      new Date().toISOString()
  });
});

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message:
      `Adres bulunamadı: ${req.method} ${req.originalUrl}`
  });
});

app.listen(
  PORT,
  '0.0.0.0',
  () => {
    console.log('');

    console.log(
      `Trendora sunucusu çalışıyor: ` +
      `http://127.0.0.1:${PORT}`
    );

    console.log(
      `Tüm fırsatlar: ` +
      `http://127.0.0.1:${PORT}/api/opportunities`
    );

    console.log(
      `A101: ` +
      `http://127.0.0.1:${PORT}/api/opportunities/a101`
    );

    console.log(
      `BİM: ` +
      `http://127.0.0.1:${PORT}/api/opportunities/bim`
    );

    console.log(
      `Trendyol: ` +
      `http://127.0.0.1:${PORT}/api/opportunities/trendyol`
    );
  }
);
