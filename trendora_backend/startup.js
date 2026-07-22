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

function runCollectorThenStartServer() {
  console.log('');
  console.log('Telegram collector ilk veri çekimi için başlatılıyor...');

  const collector = spawn(
    process.execPath,
    [collectorPath],
    {
      cwd: __dirname,
      env: process.env,
      stdio: 'inherit'
    }
  );

  let serverStarted = false;

  const continueWithServer = () => {
    if (serverStarted) {
      return;
    }

    serverStarted = true;
    startServer();
  };

  collector.on('error', error => {
    console.error(
      'Telegram collector başlatılamadı:',
      error.message
    );

    console.log(
      'Collector hatasına rağmen mevcut API sunucusu açılacak.'
    );

    continueWithServer();
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
        'Collector hatasına rağmen mevcut API sunucusu açılacak.'
      );
    }

    continueWithServer();
  });

  /*
    Collector herhangi bir sebeple uzun süre beklerse
    API tamamen kapalı kalmasın. 90 saniye sonra sunucu
    yine açılır; collector arka planda tamamlanabilir.
  */
  setTimeout(() => {
    if (!serverStarted) {
      console.log(
        'Telegram collector bekleme süresini aştı. API sunucusu açılıyor.'
      );

      continueWithServer();
    }
  }, 90000);
}

runCollectorThenStartServer();