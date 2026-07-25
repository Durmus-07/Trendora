const path = require('path');
const { spawn } = require('child_process');

console.log('');
console.log('========================================');
console.log('Trendora başlangıç sistemi çalışıyor');
console.log('========================================');
console.log('');

/*
  API ana süreçte hemen başlar.
  Böylece collector dış kaynakları tararken HTTP istekleri beklemez.
*/
require('./server');

const children = new Map();
let shuttingDown = false;

function envEnabled(name, defaultValue = false) {
  const raw = process.env[name];

  if (raw == null || String(raw).trim() === '') {
    return defaultValue;
  }

  return ['1', 'true', 'yes', 'on'].includes(
    String(raw).trim().toLowerCase()
  );
}

function startChild({
  name,
  filePath,
  enabled,
  restartDelayMs = 15000
}) {
  if (!enabled) {
    console.log(`[STARTUP] ${name} devre dışı.`);
    return;
  }

  const absolutePath = path.join(__dirname, filePath);

  function launch() {
    if (shuttingDown) return;

    console.log(
      `[STARTUP] ${name} başlatılıyor: ${absolutePath}`
    );

    const child = spawn(
      process.execPath,
      [absolutePath],
      {
        cwd: __dirname,
        env: process.env,
        stdio: 'inherit'
      }
    );

    children.set(name, child);

    child.on('error', (error) => {
      console.error(
        `[STARTUP] ${name} başlatılamadı:`,
        error?.message || error
      );
    });

    child.on('exit', (code, signal) => {
      children.delete(name);

      console.log(
        `[STARTUP] ${name} kapandı. ` +
        `Kod: ${code}, sinyal: ${signal || '-'}`
      );

      if (!shuttingDown) {
        console.log(
          `[STARTUP] ${name} ${restartDelayMs / 1000} ` +
          'saniye sonra yeniden başlatılacak.'
        );

        setTimeout(launch, restartDelayMs);
      }
    });
  }

  launch();
}

/*
  Haber collector varsayılan olarak açıktır.
  Render Environment içine ENABLE_NEWS_COLLECTOR=false yazılırsa kapanır.
*/
startChild({
  name: 'Haber Collector',
  filePath: 'services/newsCollector.js',
  enabled: envEnabled(
    'ENABLE_NEWS_COLLECTOR',
    true
  )
});

/*
  Telegram collector başlangıçta kapalı tutulur.
  API kararlılığı doğrulandıktan sonra Render Environment içine:
  ENABLE_TELEGRAM_COLLECTOR=true
  eklenerek açılır.
*/
startChild({
  name: 'Telegram Collector',
  filePath: 'telegram/collector.js',
  enabled: envEnabled(
    'ENABLE_TELEGRAM_COLLECTOR',
    false
  )
});

function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;

  console.log(
    `[STARTUP] ${signal} alındı. Alt süreçler kapatılıyor...`
  );

  for (const [name, child] of children.entries()) {
    console.log(`[STARTUP] ${name} kapatılıyor.`);

    if (!child.killed) {
      child.kill('SIGTERM');
    }
  }

  setTimeout(() => {
    process.exit(0);
  }, 5000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (error) => {
  console.error(
    '[STARTUP] Yakalanmamış Promise hatası:',
    error?.stack || error
  );
});

process.on('uncaughtException', (error) => {
  console.error(
    '[STARTUP] Yakalanmamış hata:',
    error?.stack || error
  );
});
