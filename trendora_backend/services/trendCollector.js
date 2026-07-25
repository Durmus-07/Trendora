const fs = require('fs');
const path = require('path');

const {
  getTrendOverview
} = require('./trendEngine');

const TRENDS_DATABASE_FILE = path.join(
  __dirname,
  '..',
  'database',
  'trends_database.json'
);

const TRENDS_STATUS_FILE = path.join(
  __dirname,
  '..',
  'database',
  'trends_status.json'
);

const REFRESH_INTERVAL_MS = Math.max(
  5 * 60 * 1000,
  Number(
    process.env.TRENDS_REFRESH_INTERVAL_MS ||
    15 * 60 * 1000
  )
);

let collecting = false;
let timer = null;
let stopping = false;

async function writeJsonAtomic(filePath, value) {
  await fs.promises.mkdir(
    path.dirname(filePath),
    { recursive: true }
  );

  const tempPath = `${filePath}.tmp`;

  await fs.promises.writeFile(
    tempPath,
    JSON.stringify(value, null, 2),
    'utf8'
  );

  await fs.promises.rename(
    tempPath,
    filePath
  );
}

async function writeStatus(status) {
  try {
    await writeJsonAtomic(
      TRENDS_STATUS_FILE,
      {
        ...status,
        processId: process.pid,
        writtenAt: new Date().toISOString()
      }
    );
  } catch (error) {
    console.error(
      '[TREND COLLECTOR] Durum yazılamadı:',
      error?.message || error
    );
  }
}

async function collectTrends() {
  if (collecting) {
    console.log(
      '[TREND COLLECTOR] Önceki tarama sürüyor, yeni tur atlandı.'
    );
    return;
  }

  collecting = true;
  const startedAt = Date.now();

  await writeStatus({
    running: true,
    phase: 'analyzing',
    startedAt: new Date(startedAt).toISOString(),
    completedAt: null,
    error: null
  });

  try {
    console.log(
      '[TREND COLLECTOR] Trend özeti hazırlanıyor...'
    );

    /*
      forceRefresh true:
      Collector eski RAM önbelleğini kullanmak yerine
      yeni analiz üretir. API ise bu işlemi beklemez.
    */
    const overview = await getTrendOverview({
      forceRefresh: true
    });

    const trends = Array.isArray(overview?.trends)
      ? overview.trends
      : [];

    const updatedAt =
      overview?.updatedAt ||
      new Date().toISOString();

    const database = {
      success: true,
      ready: true,
      createdAt: Date.now(),
      updatedAt,
      methodology: overview?.methodology || null,
      trendCount: trends.length,
      trends
    };

    await writeJsonAtomic(
      TRENDS_DATABASE_FILE,
      database
    );

    await writeStatus({
      running: false,
      phase: 'completed',
      startedAt: new Date(startedAt).toISOString(),
      completedAt: new Date().toISOString(),
      durationMs: Date.now() - startedAt,
      trendCount: trends.length,
      error: null
    });

    console.log(
      `[TREND COLLECTOR] Tamamlandı: ` +
      `${trends.length} trend, ` +
      `${Date.now() - startedAt} ms`
    );
  } catch (error) {
    console.error(
      '[TREND COLLECTOR] Tarama hatası:',
      error?.stack || error?.message || error
    );

    await writeStatus({
      running: false,
      phase: 'failed',
      startedAt: new Date(startedAt).toISOString(),
      completedAt: new Date().toISOString(),
      durationMs: Date.now() - startedAt,
      error: error?.message || String(error)
    });
  } finally {
    collecting = false;
  }
}

async function start() {
  console.log(
    '[TREND COLLECTOR] Başlatıldı. Yenileme aralığı: ' +
    `${Math.round(REFRESH_INTERVAL_MS / 60000)} dakika`
  );

  await collectTrends();

  timer = setInterval(
    () => void collectTrends(),
    REFRESH_INTERVAL_MS
  );

  if (typeof timer.unref === 'function') {
    timer.unref();
  }
}

async function stop(signal) {
  if (stopping) return;
  stopping = true;

  console.log(
    `[TREND COLLECTOR] ${signal} alındı, kapanıyor...`
  );

  if (timer) {
    clearInterval(timer);
  }

  await writeStatus({
    running: false,
    phase: 'stopped',
    completedAt: new Date().toISOString(),
    error: null
  });

  process.exit(0);
}

process.on(
  'SIGTERM',
  () => void stop('SIGTERM')
);

process.on(
  'SIGINT',
  () => void stop('SIGINT')
);

process.on(
  'unhandledRejection',
  error => {
    console.error(
      '[TREND COLLECTOR] Yakalanmamış Promise hatası:',
      error?.stack || error
    );
  }
);

process.on(
  'uncaughtException',
  error => {
    console.error(
      '[TREND COLLECTOR] Yakalanmamış hata:',
      error?.stack || error
    );
  }
);

void start();
