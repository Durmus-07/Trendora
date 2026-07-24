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

    console.log(
      'API sunucusu çalışmaya devam edecek.'
    );
  });

  collector.on('close', code => {
    if (code === 0) {
      console.log(
        'Telegram collector ilk veri çekimini tamamladı.'
      );
    } else {
      console.error(
        `Telegram collector ${code} hata koduyla kapandı.`
      );

      console.log(
        'API sunucusu çalışmaya devam edecek.'
      );
    }
  });
}

/*
  Render portu mümkün olan en kısa sürede görebilsin diye
  önce mevcut API sunucusu açılır. Telegram collector ise
  hemen ardından ayrı süreçte arka planda çalışır.
*/
startServer();

setTimeout(() => {
  startCollectorInBackground();
}, 1000);
