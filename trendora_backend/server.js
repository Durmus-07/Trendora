console.log('BENİM YENİ SERVER ÇALIŞTI');

const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const opportunitiesRoutes = require('./routes/opportunities');

const app = express();
const PORT = 3000;

app.use(cors());
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
      opportunities:
        '/api/opportunities',
      a101:
        '/api/opportunities/a101',
      bim:
        '/api/opportunities/bim',
      trendyol:
        '/api/opportunities/trendyol'
    }
  });
});

/*
  Eski Flutter kodu /api/trendyol adresini kullanıyorsa
  çalışmaya devam etsin diye bu adresi koruyoruz.
*/
app.get('/api/trendyol', (req, res) => {
  try {
    const database = readOpportunitiesDatabase();

    const items = database.items
      .map(prepareOpportunity)
      .filter(item => {
        return (
          normalize(item.source) === 'trendyol' &&
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
      message: 'Trendyol fırsatları okunamadı.',
      error: error.message
    });
  }
});

/*
  A101, BİM, Trendyol ve diğer bütün fırsatlar
  routes/opportunities.js dosyasından yönetilir.
*/
app.use(
  '/api/opportunities',
  opportunitiesRoutes
);

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message:
      `Adres bulunamadı: ${req.method} ${req.originalUrl}`
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log(
    `Trendora sunucusu çalışıyor: http://127.0.0.1:${PORT}`
  );

  console.log(
    `Tüm fırsatlar: http://127.0.0.1:${PORT}/api/opportunities`
  );

  console.log(
    `A101: http://127.0.0.1:${PORT}/api/opportunities/a101`
  );

  console.log(
    `BİM: http://127.0.0.1:${PORT}/api/opportunities/bim`
  );

  console.log(
    `Trendyol: http://127.0.0.1:${PORT}/api/opportunities/trendyol`
  );
});