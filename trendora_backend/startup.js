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
    collectorProcess.kill('SIGTERM');
  }
}

function startTrendora() {
  startServer();

  setTimeout(() => {
    startCollectorInBackground();
  }, 2000);
}

process.on('SIGTERM', stopCollector);
process.on('SIGINT', stopCollector);

startTrendora();