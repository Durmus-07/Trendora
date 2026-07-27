const path = require('path');
const {
  spawn
} = require('child_process');

console.log('');
console.log('========================================');
console.log('Trendora başlangıç sistemi çalışıyor');
console.log('========================================');
console.log('');

/*
  API ana süreçte hemen başlar.
  Collector işlemleri ayrı Node süreçlerinde çalışır.
*/
const { startServer } = require('./server');
startServer();

if (envEnabled('ENABLE_MARKET_COLLECTOR', true)) {
  const {
    startMarketCollectorScheduler
  } = require('./services/marketCollectorScheduler');

  startMarketCollectorScheduler();
}

const children = new Map();
const restartTimers = new Map();

let shuttingDown = false;

function envEnabled(
  name,
  defaultValue = false
) {
  const raw = process.env[name];

  if (
    raw == null ||
    String(raw).trim() === ''
  ) {
    return defaultValue;
  }

  return [
    '1',
    'true',
    'yes',
    'on'
  ].includes(
    String(raw)
      .trim()
      .toLowerCase()
  );
}

function startChild({
  name,
  filePath,
  enabled,
  initialDelayMs = 0,
  failureBackoffMs = null,
  errorRestartDelayMs = 15000,
  successfulRestartDelayMs = 15000
}) {
  let consecutiveFailures = 0;
  if (!enabled) {
    console.log(
      `[STARTUP] ${name} devre dışı.`
    );

    return;
  }

  const absolutePath = path.join(
    __dirname,
    filePath
  );

  function scheduleRestart(delayMs) {
    if (shuttingDown) {
      return;
    }

    const existingTimer =
      restartTimers.get(name);

    if (existingTimer) {
      clearTimeout(existingTimer);
    }

    console.log(
      `[STARTUP] ${name} ` +
      `${Math.round(delayMs / 1000)} saniye ` +
      'sonra yeniden başlatılacak.'
    );

    const timer = setTimeout(
      () => {
        restartTimers.delete(name);
        launch();
      },
      delayMs
    );

    restartTimers.set(
      name,
      timer
    );
  }

  function launch() {
    if (shuttingDown) {
      return;
    }

    console.log(
      `[STARTUP] ${name} başlatılıyor: ` +
      absolutePath
    );

    const child = spawn(
      process.execPath,
      [
        absolutePath
      ],
      {
        cwd: __dirname,
        env: process.env,
        stdio: 'inherit'
      }
    );

    children.set(
      name,
      child
    );

    child.on(
      'error',
      error => {
        console.error(
          `[STARTUP] ${name} başlatılamadı:`,
          error?.message || error
        );
      }
    );

    child.on(
      'exit',
      (code, signal) => {
        children.delete(name);

        console.log(
          `[STARTUP] ${name} kapandı. ` +
          `Kod: ${code}, ` +
          `sinyal: ${signal || '-'}`
        );

        if (shuttingDown) {
          return;
        }

        /*
          Kod 0:
          Collector görevini başarıyla tamamladı.

          Kod 0 dışındaki değer:
          Collector hata nedeniyle kapandı.
        */
        const completedSuccessfully =
          code === 0 &&
          !signal;

        consecutiveFailures = completedSuccessfully
          ? 0
          : consecutiveFailures + 1;

        const restartDelay =
          completedSuccessfully
            ? successfulRestartDelayMs
            : Array.isArray(failureBackoffMs) && failureBackoffMs.length > 0
              ? failureBackoffMs[Math.min(consecutiveFailures - 1, failureBackoffMs.length - 1)]
              : errorRestartDelayMs;

        scheduleRestart(
          restartDelay
        );
      }
    );
  }

  if (initialDelayMs > 0) {
    const timer = setTimeout(launch, initialDelayMs);
    restartTimers.set(name, timer);
  } else {
    launch();
  }
}

/*
  Haber Collector kendi çalışma döngüsüne sahiptir.

  Beklenmedik şekilde kapanırsa:
  - Başarılı kapanmada 10 dakika sonra
  - Hatalı kapanmada 15 saniye sonra
  yeniden başlatılır.
*/
startChild({
  name: 'Haber Collector',
  filePath:
    'services/newsCollector.js',
  enabled: envEnabled(
    'ENABLE_NEWS_COLLECTOR',
    true
  ),
  initialDelayMs: 30 * 1000,
  errorRestartDelayMs:
    15 * 1000,
  successfulRestartDelayMs:
    10 * 60 * 1000
});

/*
  Trend Collector tek taramayı tamamlayıp
  kod 0 ile kapanıyor.

  Önceden her başarılı tamamlanmadan sonra
  15 saniyede bir tekrar başlatılıyordu.

  Artık:
  - Başarılı çalışma: 15 dakika sonra
  - Gerçek hata: 15 saniye sonra
*/
startChild({
  name: 'Trend Collector',
  filePath:
    'services/trendCollector.js',
  enabled: envEnabled(
    'ENABLE_TREND_COLLECTOR',
    true
  ),
  initialDelayMs: 2 * 60 * 1000,
  errorRestartDelayMs:
    15 * 1000,
  successfulRestartDelayMs:
    15 * 60 * 1000
});

/*
  API kararlılığı doğrulanana kadar
  Telegram Collector kapalı tutulur.
*/
startChild({
  name: 'Telegram Collector',
  filePath:
    'telegram/collector.js',
  enabled: envEnabled(
    'ENABLE_TELEGRAM_COLLECTOR',
    false
  ),
  initialDelayMs: 5 * 60 * 1000,
  failureBackoffMs: [
    60 * 60 * 1000,
    6 * 60 * 60 * 1000,
    24 * 60 * 60 * 1000
  ],
  errorRestartDelayMs:
    15 * 1000,
  successfulRestartDelayMs:
    15 * 60 * 1000
});

function shutdown(signal) {
  if (shuttingDown) {
    return;
  }

  shuttingDown = true;

  console.log(
    `[STARTUP] ${signal} alındı. ` +
    'Alt süreçler kapatılıyor...'
  );

  for (
    const timer
    of restartTimers.values()
  ) {
    clearTimeout(timer);
  }

  restartTimers.clear();

  for (
    const [
      name,
      child
    ] of children.entries()
  ) {
    console.log(
      `[STARTUP] ${name} kapatılıyor.`
    );

    if (!child.killed) {
      child.kill('SIGTERM');
    }
  }

  setTimeout(
    () => process.exit(0),
    5000
  ).unref();
}

process.on(
  'SIGTERM',
  () => shutdown('SIGTERM')
);

process.on(
  'SIGINT',
  () => shutdown('SIGINT')
);

process.on(
  'unhandledRejection',
  error => {
    console.error(
      '[STARTUP] Yakalanmamış Promise hatası:',
      error?.stack || error
    );
  }
);

process.on(
  'uncaughtException',
  error => {
    console.error(
      '[STARTUP] Yakalanmamış hata:',
      error?.stack || error
    );
  }
);
