require('dotenv').config();

const path = require('path');
const { spawn } = require('child_process');

const collectorPath = path.join(
  __dirname,
  'telegram',
  'collector.js'
);

function startServer() {
  console.log('');
  console.log('Trendora API sunucusu başlatılıyor...');

  require('./server');
}

function startCollectorInBackground() {
  console.log('');
  console.log('Telegram collector arka planda başlatılıyor...');

  const collector = spawn(
    process.execPath,
    [collectorPath],
    {
      cwd: __dirname,
      env: process.env,
      stdio: 'inherit'
    }
  );

  collector.on('error', error => {
    console.error(
      'Telegram collector başlatılamadı:',
      error.message
    );
  });

  collector.on('close', code => {
    if (code === 0) {
      console.log(
        'Telegram collector veri çekimini tamamladı.'
      );
    } else {
      console.error(
        `Telegram collector ${code} hata koduyla kapandı.`
      );
    }
  });
}

function startTrendora() {
  /*
    Render'ın portu hemen görebilmesi için
    API sunucusu önce başlatılır.
  */
  startServer();

  /*
    Telegram collector sunucuyu bekletmeden
    arka planda çalıştırılır.
  */
  setTimeout(() => {
    startCollectorInBackground();
  }, 2000);
}

startTrendora();