# Trendora

Trendora; haberleri, fırsatları, piyasa verilerini ve kaynak destekli trend analizlerini tek uygulamada birleştiren Flutter + Node.js projesidir.

## Yapı

- `lib/`: Flutter istemcisi
- `trendora_backend/`: Express API, analiz servisleri ve veri toplayıcıları
- `trendora_backend/database/`: geliştirme aşamasındaki JSON veri deposu
- `trendora_backend/public/`: fırsat görselleri

## Gereksinimler

- Flutter SDK (projenin `pubspec.yaml` dosyasındaki SDK sürümüyle uyumlu)
- Node.js 20 veya daha yeni

## Backend'i çalıştırma

```powershell
cd trendora_backend
Copy-Item .env.example .env
npm install
npm test
npm start
```

`.env` içindeki `ADMIN_API_KEY` üretimde uzun ve rastgele olmalıdır. `ALLOWED_ORIGINS`, yalnızca yayınlanan web istemcilerinin adreslerini içermelidir. API varsayılan olarak `http://localhost:3000` üzerinde açılır.

AI altyapısı varsayılan olarak kapalıdır. Bu durumda AI sohbeti ve OpenAI web araştırması çalışmaz. Trend Analiz Motoru ise AI kullanmadan piyasa, haber ve teknik veri altyapısıyla tüm kullanıcıların sorularını analiz etmeye devam eder. `/api/features` çalışma politikasını istemcilere bildirir. AI ileride yalnızca sunucu tarafından doğrulanmış Premium üyelikle açılmalıdır; yalnızca uygulama içi bir bayrak güvenlik amacıyla yeterli değildir.

Collector süreçlerini başlatmadan yalnızca API geliştirmek için:

```powershell
$env:ENABLE_NEWS_COLLECTOR='false'
$env:ENABLE_TREND_COLLECTOR='false'
npm run dev
```

## Flutter uygulamasını çalıştırma

```powershell
flutter pub get
flutter analyze
flutter run
```

API adresi derleme sırasında değiştirilebilir:

```powershell
flutter run
```

Android emülatöründe `10.0.2.2`, bilgisayardaki yerel backend'i gösterir. Varsayılan değer `lib/core/api_config.dart` içindeki HTTPS üretim adresidir.

## Kontroller

```powershell
cd trendora_backend
npm run check
npm test
```

Flutter tarafında:

```powershell
flutter analyze
flutter test
```

## Güvenlik notları

- Gizli değerleri repoya eklemeyin; `.env.example` yalnızca değişken adlarını içerir.
- Veri yenileyen endpoint'ler `x-admin-api-key` başlığı ister.
- CORS, istek boyutu ve istek sıklığı ortam değişkenleriyle sınırlandırılır.
- JSON veri dosyaları prototip içindir; çoklu instance veya yüksek trafikten önce kalıcı veritabanına geçilmelidir.
