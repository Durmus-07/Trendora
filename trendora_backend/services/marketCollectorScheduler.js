'use strict';

const fs = require('fs');
const path = require('path');

const {
  bimUrunleriniGetir
} = require('./bimCollector');

const {
  migrosUrunleriniGetir
} = require('./migrosCollector');

const {
  carrefoursaUrunleriniGetir
} = require('./carrefoursaCollector');

const sourceHealth = require('./sourceHealth');
const { dedupe } = require('./duplicateDetector');

/*
  A101 ve CarrefourSA geçici olarak devre dışıdır.

  Sebep:
  - A101: HTTP 403
  - CarrefourSA: HTTP 403

  Collector dosyaları burada require edilmediği için
  bu iki kaynağa hiçbir istek gönderilmez.
*/

const databasePath = path.join(
  __dirname,
  '..',
  'database',
  'opportunities.json'
);

const statePath = path.join(
  __dirname,
  '..',
  'database',
  'market-collector-state.json'
);

const DAY = 24 * 60 * 60 * 1000;

const LEVELS = [
  DAY,
  2 * DAY,
  7 * DAY
];

const BETWEEN_MARKETS_MS = 45 * 1000;

let started = false;
let running = false;
let timer = null;

function ensureDirectory(filePath) {
  fs.mkdirSync(
    path.dirname(filePath),
    {
      recursive: true
    }
  );
}

function readJson(filePath, fallback) {
  try {
    if (!fs.existsSync(filePath)) {
      return fallback;
    }

    return JSON.parse(
      fs.readFileSync(filePath, 'utf8')
    );
  } catch (error) {
    console.error(
      `[MarketScheduler] ${path.basename(filePath)} okunamadı:`,
      error.message
    );

    return fallback;
  }
}

function writeJsonAtomic(filePath, value) {
  ensureDirectory(filePath);

  const tempPath = `${filePath}.tmp`;

  fs.writeFileSync(
    tempPath,
    JSON.stringify(value, null, 2),
    'utf8'
  );

  fs.renameSync(
    tempPath,
    filePath
  );
}

function readDatabase() {
  const data = readJson(
    databasePath,
    {
      updatedAt: null,
      items: []
    }
  );

  return {
    updatedAt: data.updatedAt || null,
    items: Array.isArray(data.items)
      ? data.items
      : []
  };
}

function detectSource(item) {
  return String(
    item.store ||
    item.source ||
    ''
  )
    .trim()
    .toLocaleLowerCase('tr-TR')
    .replace('bi̇m', 'bim')
    .replace('şok', 'sok');
}

function replaceSourceItems(source, newItems) {
  const database = readDatabase();

  const untouched = database.items.filter(
    item => detectSource(item) !== source
  );

  const next = {
    updatedAt: new Date().toISOString(),
    // Only dedupe the refreshed source batch. Existing data from unrelated
    // sources must never be removed by a broad cross-source fingerprint.
    items: [
      ...untouched,
      ...dedupe(newItems, 'opportunity')
    ]
  };

  writeJsonAtomic(
    databasePath,
    next
  );

  return next;
}

function readState() {
  return readJson(
    statePath,
    {
      level: 0,
      consecutiveFailures: 0,
      consecutiveSuccesses: 0,
      nextRunAt: null,
      markets: {}
    }
  );
}

function saveState(state) {
  writeJsonAtomic(
    statePath,
    state
  );
}

function sleep(ms) {
  return new Promise(
    resolve => setTimeout(resolve, ms)
  );
}

async function collectBim(previousState) {
  const items = await bimUrunleriniGetir();

  return {
    changed: items.length > 0,
    reason: items.length > 0
      ? 'parsed'
      : 'empty',
    items,
    state: {
      ...previousState,
      checkedAt: new Date().toISOString(),
      itemCount: items.length
    }
  };
}

/*
  Şimdilik yalnızca çalışan marketler aktiftir.

  Aktif:
  - BİM
  - Migros

  Geçici kapalı:
  - A101
  - CarrefourSA
*/
const collectors = [
  [
    'bim',
    collectBim
  ],
  [
    'migros',
    migrosUrunleriniGetir
  ],
  [
    'carrefoursa',
    carrefoursaUrunleriniGetir
  ]
];

async function runOneMarket(
  source,
  collector,
  state
) {
  const marketState =
    state.markets[source] || {};

  if (
    marketState.nextRunAt &&
    new Date(marketState.nextRunAt).getTime() > Date.now()
  ) {
    return null;
  }

  const startedAt = Date.now();

  try {
    const result = await collector(
      marketState
    );

    const items = Array.isArray(result.items)
      ? result.items
      : [];

    if (
      result.changed &&
      items.length > 0
    ) {
      replaceSourceItems(
        source,
        items
      );

      console.log(
        `[MarketScheduler] ${source}: ` +
        `${items.length} ürün güncellendi.`
      );
    } else {
      console.log(
        `[MarketScheduler] ${source}: ` +
        `değişiklik yok ` +
        `(${result.reason || 'unchanged'}).`
      );
    }

    state.markets[source] = {
      ...(result.state || marketState),
      lastSuccessAt:
        new Date().toISOString(),
      lastDurationMs:
        Date.now() - startedAt,
      lastError: null,
      level: Math.max(
        0,
        Number(marketState.level || 0) -
          (Number(marketState.consecutiveSuccesses || 0) >= 2 ? 1 : 0)
      ),
      consecutiveSuccesses:
        Number(marketState.consecutiveSuccesses || 0) + 1,
      consecutiveFailures: 0
    };

    state.markets[source].nextRunAt = new Date(
      Date.now() + LEVELS[state.markets[source].level]
    ).toISOString();

    sourceHealth.success(`market:${source}`, {
      recordCount: items.length,
      responseTimeMs: Date.now() - startedAt
    });

    return true;
  } catch (error) {
    console.error(
      `[MarketScheduler] ${source} hatası:`,
      error.message
    );

    state.markets[source] = {
      ...marketState,
      lastFailureAt:
        new Date().toISOString(),
      lastDurationMs:
        Date.now() - startedAt,
      lastError: error.message,
      level: Math.min(
        LEVELS.length - 1,
        Number(marketState.level || 0) + 1
      ),
      consecutiveFailures:
        Number(marketState.consecutiveFailures || 0) + 1,
      consecutiveSuccesses: 0
    };

    state.markets[source].nextRunAt = new Date(
      Date.now() + LEVELS[state.markets[source].level]
    ).toISOString();

    sourceHealth.failure(`market:${source}`, error, {
      responseTimeMs: Date.now() - startedAt
    });

    return false;
  } finally {
    saveState(state);
  }
}

async function runMarketCollectorsNow() {
  if (running) {
    return {
      success: false,
      message:
        'Market collector zaten çalışıyor.'
    };
  }

  running = true;

  const state = readState();

  let successCount = 0;
  let attemptedCount = 0;

  try {
    for (
      let index = 0;
      index < collectors.length;
      index += 1
    ) {
      const [
        source,
        collector
      ] = collectors[index];

      const successful =
        await runOneMarket(
          source,
          collector,
          state
        );

      if (successful === true) {
        successCount += 1;
      }
      if (successful !== null) {
        attemptedCount += 1;
      }

      if (
        index <
        collectors.length - 1
      ) {
        await sleep(
          BETWEEN_MARKETS_MS
        );
      }
    }

    const allSuccessful = successCount === attemptedCount;

    if (allSuccessful) {
      state.consecutiveFailures = 0;

      state.consecutiveSuccesses =
        (state.consecutiveSuccesses || 0) + 1;

      if (
        state.level > 0 &&
        state.consecutiveSuccesses >= 3
      ) {
        state.level -= 1;
        state.consecutiveSuccesses = 0;
      }
    } else {
      state.consecutiveFailures =
        (state.consecutiveFailures || 0) + 1;

      state.consecutiveSuccesses = 0;

      if (
        state.consecutiveFailures >= 2 &&
        state.level < LEVELS.length - 1
      ) {
        state.level += 1;
        state.consecutiveFailures = 0;
      }
    }

    state.lastRunAt =
      new Date().toISOString();

    state.nextRunAt =
      new Date(
        Date.now() +
        LEVELS[state.level]
      ).toISOString();

    saveState(state);

    return {
      success: allSuccessful,
      successCount,
      total: attemptedCount,
      activeMarkets:
        collectors.map(
          ([source]) => source
        ),
      disabledMarkets: [
        'a101'
      ],
      level: state.level,
      nextRunAt: state.nextRunAt
    };
  } finally {
    running = false;
  }
}

function scheduleNext() {
  clearTimeout(timer);

  const state = readState();

  const sourceNextRuns = Object.values(state.markets || {})
    .map(item => new Date(item.nextRunAt || 0).getTime())
    .filter(value => Number.isFinite(value) && value > Date.now());
  const independentNextRunAt = sourceNextRuns.length
    ? Math.min(...sourceNextRuns)
    : null;

  const nextRunMs =
    independentNextRunAt
      ? Math.max(
          60 * 1000,
          independentNextRunAt - Date.now()
        )
      : 2 * 60 * 1000;

  timer = setTimeout(
    async () => {
      try {
        await runMarketCollectorsNow();
      } catch (error) {
        console.error(
          '[MarketScheduler] Genel çalışma hatası:',
          error?.stack || error
        );
      } finally {
        scheduleNext();
      }
    },
    nextRunMs
  );

  if (
    typeof timer.unref === 'function'
  ) {
    timer.unref();
  }
}

function startMarketCollectorScheduler() {
  if (started) {
    return;
  }

  started = true;

  console.log(
    '[MarketScheduler] Düşük yük market ' +
    'zamanlayıcısı başlatıldı.'
  );

  console.log(
    '[MarketScheduler] Aktif marketler: ' +
    'BİM, Migros.'
  );

  console.log(
    '[MarketScheduler] Geçici kapalı: ' +
    'A101, CarrefourSA.'
  );

  scheduleNext();
}

function getMarketCollectorStatus() {
  return {
    running,
    activeMarkets: [
      'bim',
      'migros',
      'carrefoursa'
    ],
    disabledMarkets: [
      'a101'
    ],
    ...readState()
  };
}

module.exports = {
  startMarketCollectorScheduler,
  runMarketCollectorsNow,
  getMarketCollectorStatus
};
