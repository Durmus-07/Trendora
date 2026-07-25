require('dotenv').config();

const path = require('path');
const { spawn } = require('child_process');

const collectorPath = path.join(
  __dirname,
  'telegram',
  'collector.js'
);

let collectorProcess = null;

function startServer() {
  console.log('');
  console.log('Trendora API sunucusu başlatılıyor...');

  require('./server');
}

function startCollectorInBackground() {
  if (
    collectorProcess &&
    collectorProcess.exitCode === null
  ) {
    console.log(
      'Telegram collector zaten çalışıyor; ikinci kez başlatılmadı.'
    );
    return;
  }

  console.log('');
  console.log('Telegram collector arka planda başlatılıyor...');

  collectorProcess = spawn(
    process.execPath,
    [collectorPath],
    {
      cwd: __dirname,
      env: process.env,
      stdio: 'inherit'
    }
  );

  collectorProcess.on('error', error => {
    console.error(
      'Telegram collector başlatılamadı:',
      error.message
    );

    collectorProcess = null;
  });

  collectorProcess.on('close', code => {
    if (code === 0) {
      console.log(
        'Telegram collector veri çekimini tamamladı.'
      );
    } else {
      console.error(
        `Telegram collector ${code} hata koduyla kapandı; API çalışmaya devam ediyor.`
      );
    }

    collectorProcess = null;
  });
}

function stopCollector() {
  if (
    collectorProcess &&
    collectorProcess.exitCode === null
  ) {
    console.log(
      'Telegram collector güvenli şekilde durduruluyor...'
    );

    collectorProcess.kill('SIGTERM');
  }
}

function startTrendora() {
  // API her zaman önce ve hemen açılır.
  startServer();

  /*
    Collector yalnızca Render ortam değişkenlerinde:

    ENABLE_TELEGRAM_COLLECTOR=true

    yazıyorsa başlatılır.

    Şimdilik bu değişkeni eklemeyeceğiz.
    Böylece API üzerindeki yoğun yükü kaldırıp
    sorunun collectordan kaynaklandığını doğrulayacağız.
  */
  const collectorAktif =
    process.env.ENABLE_TELEGRAM_COLLECTOR === 'true';

  if (!collectorAktif) {
    console.log('');
    console.log(
      'Telegram collector şu anda devre dışı. API bağımsız olarak çalışıyor.'
    );
    return;
  }

  setTimeout(() => {
    startCollectorInBackground();
  }, 5000);
}

process.on('SIGTERM', () => {
  stopCollector();
});

process.on('SIGINT', () => {
  stopCollector();
});

process.on('uncaughtException', error => {
  console.error(
    'Beklenmeyen uygulama hatası:',
    error
  );
});

process.on('unhandledRejection', reason => {
  console.error(
    'Yakalanmamış Promise hatası:',
    reason
  );
});

startTrendora();