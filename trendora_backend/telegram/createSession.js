require('dotenv').config();

const { TelegramClient } = require('telegram');
const {
  StringSession
} = require('telegram/sessions');

const input = require('input');

function envDegeriniAl(degiskenAdi) {
  const deger = String(
    process.env[degiskenAdi] || ''
  ).trim();

  if (!deger) {
    throw new Error(
      `${degiskenAdi} .env dosyasında bulunamadı veya boş.`
    );
  }

  return deger;
}

async function telegramOturumuOlustur() {
  try {
    console.log('');
    console.log(
      '========================================'
    );
    console.log(
      'Trendora Telegram oturumu oluşturuluyor'
    );
    console.log(
      '========================================'
    );
    console.log('');

    const apiIdMetni =
      envDegeriniAl('TELEGRAM_API_ID');

    const apiHash =
      envDegeriniAl('TELEGRAM_API_HASH');

    const telefonNumarasi =
      envDegeriniAl('TELEGRAM_PHONE');

    const apiId = Number(apiIdMetni);

    if (
      !Number.isInteger(apiId) ||
      apiId <= 0
    ) {
      throw new Error(
        'TELEGRAM_API_ID geçerli bir sayı olmalıdır.'
      );
    }

    const stringSession =
      new StringSession('');

    const client = new TelegramClient(
      stringSession,
      apiId,
      apiHash,
      {
        connectionRetries: 5
      }
    );

    console.log(
      'Telegram sunucusuna bağlanılıyor...'
    );
    console.log('');

    await client.start({
      phoneNumber: async () =>
        telefonNumarasi,

      phoneCode: async () => {
        console.log('');
        console.log(
          'Telegram uygulamana gelen kodu kontrol et.'
        );

        return input.text(
          'Doğrulama kodunu yaz: '
        );
      },

      password: async () => {
        console.log('');
        console.log(
          'İki aşamalı doğrulama açıksa Telegram şifreni yaz.'
        );

        return input.text(
          'Telegram iki aşamalı doğrulama şifresi: '
        );
      },

      onError: error => {
        console.error(
          'Telegram giriş hatası:',
          error.message
        );
      }
    });

    const sessionDegeri =
      client.session.save();

    console.log('');
    console.log(
      '========================================'
    );
    console.log(
      'TELEGRAM BAĞLANTISI BAŞARILI'
    );
    console.log(
      '========================================'
    );
    console.log('');
    console.log(
      'Aşağıdaki değerin tamamını kopyala:'
    );
    console.log('');
    console.log(sessionDegeri);
    console.log('');
    console.log(
      '.env dosyasındaki TELEGRAM_SESSION= satırının karşısına yapıştır.'
    );
    console.log('');
    console.log(
      'Bu oturum değerini kimseyle paylaşma.'
    );
    console.log('');

    await client.disconnect();

    process.exit(0);
  } catch (error) {
    console.error('');
    console.error(
      'Oturum oluşturulamadı:',
      error.message
    );
    console.error('');

    process.exit(1);
  }
}

telegramOturumuOlustur();