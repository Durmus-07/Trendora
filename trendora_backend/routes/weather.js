'use strict';

const express = require('express');
const { normalizeWeather } = require('../services/dataModels');
const sourceHealth = require('../services/sourceHealth');
const { buildWeatherInsights } = require('../services/weatherInsights');
const axios = require('axios');

const router = express.Router();

const FORECAST_URL =
  'https://api.open-meteo.com/v1/forecast';

const GEOCODING_URL =
  'https://geocoding-api.open-meteo.com/v1/search';

const BACKUP_FORECAST_URL =
  'https://api.met.no/weatherapi/locationforecast/2.0/compact';

const CACHE_TTL_MS = 15 * 60 * 1000;
const STALE_CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const RATE_LIMIT_BACKOFF_MS = 5 * 60 * 1000;
const SEARCH_CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const REQUEST_TIMEOUT_MS = 9000;
const MAX_CACHE_ITEMS = 250;

const weatherCache = new Map();
const searchCache = new Map();
const weatherInFlight = new Map();
const weatherBackoff = new Map();
let weatherRequester = (url, options) => axios.get(url, options);
let backupWeatherRequester = (url, options) => axios.get(url, options);

function normalizeText(value) {
  return String(value || '').trim();
}

function normalizeCoordinate(value, min, max) {
  const number = Number(value);

  if (
    !Number.isFinite(number) ||
    number < min ||
    number > max
  ) {
    return null;
  }

  return Number(number.toFixed(4));
}

function finiteNumber(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function cleanupCache(cache, now = Date.now()) {
  for (const [key, item] of cache.entries()) {
    if (!item || (item.staleExpiresAt || item.expiresAt) <= now) {
      cache.delete(key);
    }
  }

  while (cache.size > MAX_CACHE_ITEMS) {
    const firstKey = cache.keys().next().value;

    if (!firstKey) {
      break;
    }

    cache.delete(firstKey);
  }
}

function getCached(cache, key) {
  const item = cache.get(key);

  if (!item) {
    return null;
  }

  if (item.expiresAt <= Date.now()) {
    return null;
  }

  return item.value;
}

function getStale(cache, key) {
  const item = cache.get(key);
  if (!item || (item.staleExpiresAt || item.expiresAt) <= Date.now()) {
    return null;
  }
  return item.value;
}

function setCached(cache, key, value, ttl, staleTtl = ttl) {
  cleanupCache(cache);

  cache.set(key, {
    value,
    expiresAt: Date.now() + ttl,
    staleExpiresAt: Date.now() + staleTtl
  });
}

function weatherDescription(code) {
  const descriptions = {
    0: 'Açık',
    1: 'Çoğunlukla açık',
    2: 'Parçalı bulutlu',
    3: 'Kapalı',
    45: 'Sisli',
    48: 'Kırağılı sis',
    51: 'Hafif çisenti',
    53: 'Çisenti',
    55: 'Yoğun çisenti',
    56: 'Hafif donan çisenti',
    57: 'Yoğun donan çisenti',
    61: 'Hafif yağmur',
    63: 'Yağmur',
    65: 'Kuvvetli yağmur',
    66: 'Hafif donan yağmur',
    67: 'Kuvvetli donan yağmur',
    71: 'Hafif kar',
    73: 'Kar',
    75: 'Yoğun kar',
    77: 'Kar taneleri',
    80: 'Hafif sağanak',
    81: 'Sağanak',
    82: 'Kuvvetli sağanak',
    85: 'Hafif kar sağanağı',
    86: 'Kuvvetli kar sağanağı',
    95: 'Gök gürültülü fırtına',
    96: 'Dolu ihtimalli fırtına',
    99: 'Kuvvetli dolulu fırtına'
  };

  return descriptions[Number(code)] || 'Bilinmiyor';
}

function buildWarnings(current, hourly, daily) {
  const warnings = [];

  const next12Precipitation =
    (hourly.precipitation_probability || [])
      .slice(0, 12);

  const next12Wind =
    (hourly.wind_speed_10m || [])
      .slice(0, 12);

  const next12Gust =
    (hourly.wind_gusts_10m || [])
      .slice(0, 12);

  const maxPrecipitation = Math.max(
    0,
    ...next12Precipitation.map(Number)
  );

  const maxWind = Math.max(
    Number(current.wind_speed_10m || 0),
    ...next12Wind.map(Number)
  );

  const maxGust = Math.max(
    Number(current.wind_gusts_10m || 0),
    ...next12Gust.map(Number)
  );

  const uv = finiteNumber(
    (daily.uv_index_max || [])[0]
  );

  const maxTemp = finiteNumber(
    (daily.temperature_2m_max || [])[0]
  );

  const minTemp = finiteNumber(
    (daily.temperature_2m_min || [])[0]
  );

  if (maxPrecipitation >= 75) {
    warnings.push({
      level: 'high',
      type: 'rain',
      message:
        'Önümüzdeki 12 saatte yağış ihtimali çok yüksek.'
    });
  } else if (maxPrecipitation >= 50) {
    warnings.push({
      level: 'medium',
      type: 'rain',
      message:
        'Önümüzdeki 12 saatte yağış ihtimali bulunuyor.'
    });
  }

  if (maxGust >= 70 || maxWind >= 50) {
    warnings.push({
      level: 'high',
      type: 'wind',
      message:
        'Kuvvetli rüzgâr ve ani hamle riski var.'
    });
  } else if (maxGust >= 50 || maxWind >= 35) {
    warnings.push({
      level: 'medium',
      type: 'wind',
      message:
        'Rüzgâr zaman zaman kuvvetlenebilir.'
    });
  }

  if (uv !== null && uv >= 8) {
    warnings.push({
      level: 'high',
      type: 'uv',
      message:
        'UV seviyesi çok yüksek; doğrudan güneşten korun.'
    });
  } else if (uv !== null && uv >= 6) {
    warnings.push({
      level: 'medium',
      type: 'uv',
      message: 'UV seviyesi yüksek.'
    });
  }

  if (maxTemp !== null && maxTemp >= 40) {
    warnings.push({
      level: 'high',
      type: 'heat',
      message: 'Aşırı sıcak riski var.'
    });
  } else if (maxTemp !== null && maxTemp >= 35) {
    warnings.push({
      level: 'medium',
      type: 'heat',
      message:
        'Gün içinde yüksek sıcaklık bekleniyor.'
    });
  }

  if (minTemp !== null && minTemp <= 0) {
    warnings.push({
      level: 'high',
      type: 'freeze',
      message: 'Gece don riski bulunuyor.'
    });
  } else if (minTemp !== null && minTemp <= 3) {
    warnings.push({
      level: 'medium',
      type: 'freeze',
      message:
        'Gece sıcaklığı don seviyesine yaklaşabilir.'
    });
  }

  if (
    [95, 96, 99].includes(
      Number(current.weather_code)
    )
  ) {
    warnings.unshift({
      level: 'high',
      type: 'storm',
      message:
        'Gök gürültülü fırtına etkili olabilir.'
    });
  }

  return warnings.slice(0, 4);
}

async function searchLocation(query) {
  const key =
    query.toLocaleLowerCase('tr-TR');

  const cached =
    getCached(searchCache, key);

  if (cached) {
    return {
      ...cached,
      cached: true
    };
  }

  const response =
    await axios.get(GEOCODING_URL, {
      timeout: REQUEST_TIMEOUT_MS,
      params: {
        name: query,
        count: 8,
        language: 'tr',
        format: 'json'
      }
    });

  const results =
    Array.isArray(response.data?.results)
      ? response.data.results.map(item => ({
          id: item.id,
          name: item.name,
          admin1: item.admin1 || '',
          country: item.country || '',
          countryCode:
            item.country_code || '',
          latitude: item.latitude,
          longitude: item.longitude,
          elevation: item.elevation,
          timezone:
            item.timezone || 'auto',
          population:
            item.population || null,
          label: [
            item.name,
            item.admin1,
            item.country
          ]
            .filter(Boolean)
            .join(', ')
        }))
      : [];

  const value = {
    success: true,
    query,
    count: results.length,
    results
  };

  setCached(
    searchCache,
    key,
    value,
    SEARCH_CACHE_TTL_MS
  );

  return {
    ...value,
    cached: false
  };
}

async function fetchWeatherFromProvider(
  latitude,
  longitude,
  locationName
) {
  const params = {
    latitude,
    longitude,
    timezone: 'auto',
    forecast_days: 8,

    current: [
      'temperature_2m',
      'relative_humidity_2m',
      'apparent_temperature',
      'is_day',
      'precipitation',
      'rain',
      'weather_code',
      'cloud_cover',
      'surface_pressure',
      'wind_speed_10m',
      'wind_direction_10m',
      'wind_gusts_10m'
    ].join(','),

    hourly: [
      'temperature_2m',
      'apparent_temperature',
      'precipitation_probability',
      'precipitation',
      'weather_code',
      'cloud_cover',
      'visibility',
      'wind_speed_10m',
      'wind_gusts_10m',
      'relative_humidity_2m',
      'uv_index'
    ].join(','),

    daily: [
      'weather_code',
      'temperature_2m_max',
      'temperature_2m_min',
      'apparent_temperature_max',
      'apparent_temperature_min',
      'sunrise',
      'sunset',
      'uv_index_max',
      'precipitation_sum',
      'precipitation_probability_max',
      'wind_speed_10m_max',
      'wind_gusts_10m_max'
    ].join(',')
  };

  const response =
    await weatherRequester(FORECAST_URL, {
      timeout: REQUEST_TIMEOUT_MS,
      params
    });

  const data = response.data || {};
  const current = data.current || {};
  const hourly = data.hourly || {};
  const daily = data.daily || {};

  const nowIndex = Math.max(
    0,
    (hourly.time || []).findIndex(
      time => time >= current.time
    )
  );

  const hours =
    (hourly.time || [])
      .slice(nowIndex, nowIndex + 24)
      .map((time, index) => {
        const i = nowIndex + index;

        return {
          time,
          temperature:
            hourly.temperature_2m?.[i],
          apparentTemperature:
            hourly.apparent_temperature?.[i],
          precipitationProbability:
            hourly
              .precipitation_probability?.[i],
          precipitation:
            hourly.precipitation?.[i],
          weatherCode:
            hourly.weather_code?.[i],
          description:
            weatherDescription(
              hourly.weather_code?.[i]
            ),
          cloudCover:
            hourly.cloud_cover?.[i],
          visibility:
            hourly.visibility?.[i],
          windSpeed:
            hourly.wind_speed_10m?.[i],
          windGust:
            hourly.wind_gusts_10m?.[i],
          humidity:
            hourly
              .relative_humidity_2m?.[i],
          uvIndex:
            hourly.uv_index?.[i]
        };
      });

  const days =
    (daily.time || []).map((date, i) => ({
      date,
      weatherCode:
        daily.weather_code?.[i],
      description:
        weatherDescription(
          daily.weather_code?.[i]
        ),
      maxTemperature:
        daily.temperature_2m_max?.[i],
      minTemperature:
        daily.temperature_2m_min?.[i],
      maxApparentTemperature:
        daily.apparent_temperature_max?.[i],
      minApparentTemperature:
        daily.apparent_temperature_min?.[i],
      sunrise:
        daily.sunrise?.[i],
      sunset:
        daily.sunset?.[i],
      uvIndex:
        daily.uv_index_max?.[i],
      precipitationSum:
        daily.precipitation_sum?.[i],
      precipitationProbability:
        daily
          .precipitation_probability_max?.[i],
      maxWindSpeed:
        daily.wind_speed_10m_max?.[i],
      maxWindGust:
        daily.wind_gusts_10m_max?.[i]
    }));

  const baseWarnings = buildWarnings(
    current,
    hourly,
    daily
  );
  const guidance = buildWeatherInsights(
    current,
    hours,
    days,
    baseWarnings
  );

  const value = {
    success: true,

    location: {
      name: locationName || '',
      latitude: data.latitude,
      longitude: data.longitude,
      elevation: data.elevation,
      timezone: data.timezone,
      utcOffsetSeconds:
        data.utc_offset_seconds
    },

    current: {
      time: current.time,
      temperature:
        current.temperature_2m,
      apparentTemperature:
        current.apparent_temperature,
      humidity:
        current.relative_humidity_2m,
      precipitation:
        current.precipitation,
      rain:
        current.rain,
      weatherCode:
        current.weather_code,
      description:
        weatherDescription(
          current.weather_code
        ),
      cloudCover:
        current.cloud_cover,
      pressure:
        current.surface_pressure,
      windSpeed:
        current.wind_speed_10m,
      windDirection:
        current.wind_direction_10m,
      windGust:
        current.wind_gusts_10m,
      isDay:
        current.is_day === 1
    },

    hourly: hours,
    daily: days,

    warnings: guidance.warnings,
    insights: guidance.insights,
    activities: guidance.activities,
    drivingWarning: guidance.drivingWarning,
    sponsoredRecommendations:
      guidance.sponsoredRecommendations,

    source: 'Open-Meteo',
    attribution:
      'Weather data by Open-Meteo.com',

    updatedAt:
      new Date().toISOString()
  };

  return value;
}



function metSymbolToWeatherCode(symbolCode) {
  const symbol = String(symbolCode || '').toLowerCase();
  if (symbol.includes('thunder')) return 95;
  if (symbol.includes('heavysnow')) return 75;
  if (symbol.includes('snow')) return 73;
  if (symbol.includes('sleet')) return 67;
  if (symbol.includes('heavyrain')) return 65;
  if (symbol.includes('rainshowers')) return 80;
  if (symbol.includes('rain')) return 63;
  if (symbol.includes('fog')) return 45;
  if (symbol.includes('cloudy')) return 3;
  if (symbol.includes('partlycloudy')) return 2;
  if (symbol.includes('fair')) return 1;
  if (symbol.includes('clearsky')) return 0;
  return 1;
}

function pickMetPeriod(data) {
  return data?.next_1_hours || data?.next_6_hours || data?.next_12_hours || {};
}

function average(values) {
  const usable = values.filter(value => Number.isFinite(Number(value))).map(Number);
  if (!usable.length) return null;
  return usable.reduce((sum, value) => sum + value, 0) / usable.length;
}

function aggregateMetDays(hours) {
  const grouped = new Map();
  for (const hour of hours) {
    const date = String(hour.time || '').slice(0, 10);
    if (!date) continue;
    if (!grouped.has(date)) grouped.set(date, []);
    grouped.get(date).push(hour);
  }

  return [...grouped.entries()].slice(0, 8).map(([date, items]) => {
    const temperatures = items.map(item => item.temperature);
    const apparent = items.map(item => item.apparentTemperature);
    const precipitations = items.map(item => item.precipitation);
    const probabilities = items.map(item => item.precipitationProbability);
    const winds = items.map(item => item.windSpeed);
    const gusts = items.map(item => item.windGust);
    const representative = items.find(item => {
      const hour = Number(String(item.time || '').slice(11, 13));
      return hour >= 11 && hour <= 14;
    }) || items[0] || {};

    return {
      date,
      weatherCode: representative.weatherCode,
      description: representative.description || 'Bilinmiyor',
      maxTemperature: Math.max(...temperatures.filter(value => Number.isFinite(Number(value))).map(Number)),
      minTemperature: Math.min(...temperatures.filter(value => Number.isFinite(Number(value))).map(Number)),
      maxApparentTemperature: Math.max(...apparent.filter(value => Number.isFinite(Number(value))).map(Number)),
      minApparentTemperature: Math.min(...apparent.filter(value => Number.isFinite(Number(value))).map(Number)),
      sunrise: null,
      sunset: null,
      uvIndex: null,
      precipitationSum: precipitations.filter(value => Number.isFinite(Number(value))).map(Number).reduce((sum, value) => sum + value, 0),
      precipitationProbability: probabilities.filter(value => Number.isFinite(Number(value))).map(Number).reduce((max, value) => Math.max(max, value), 0),
      maxWindSpeed: winds.filter(value => Number.isFinite(Number(value))).map(Number).reduce((max, value) => Math.max(max, value), 0),
      maxWindGust: gusts.filter(value => Number.isFinite(Number(value))).map(Number).reduce((max, value) => Math.max(max, value), 0)
    };
  });
}

async function fetchWeatherFromBackupProvider(latitude, longitude, locationName) {
  const response = await backupWeatherRequester(BACKUP_FORECAST_URL, {
    timeout: REQUEST_TIMEOUT_MS,
    params: { lat: latitude, lon: longitude },
    headers: {
      'User-Agent': 'Trendora/1.0 weather-fallback contact@trendora.app',
      Accept: 'application/json'
    }
  });

  const data = response.data || {};
  const timeseries = Array.isArray(data?.properties?.timeseries)
    ? data.properties.timeseries
    : [];
  if (!timeseries.length) throw new Error('Yedek hava sağlayıcısı boş veri döndürdü.');

  const hours = timeseries.slice(0, 192).map(item => {
    const instant = item?.data?.instant?.details || {};
    const period = pickMetPeriod(item?.data);
    const periodDetails = period.details || {};
    const symbolCode = period.summary?.symbol_code || '';
    const weatherCode = metSymbolToWeatherCode(symbolCode);
    return {
      time: item.time,
      temperature: finiteNumber(instant.air_temperature),
      apparentTemperature: finiteNumber(instant.air_temperature),
      precipitationProbability: finiteNumber(periodDetails.probability_of_precipitation),
      precipitation: finiteNumber(periodDetails.precipitation_amount),
      weatherCode,
      description: weatherDescription(weatherCode),
      cloudCover: finiteNumber(instant.cloud_area_fraction),
      visibility: finiteNumber(instant.fog_area_fraction) !== null
        ? Math.max(500, 10000 - finiteNumber(instant.fog_area_fraction) * 95)
        : null,
      windSpeed: finiteNumber(instant.wind_speed) !== null
        ? finiteNumber(instant.wind_speed) * 3.6
        : null,
      windGust: finiteNumber(instant.wind_speed_of_gust) !== null
        ? finiteNumber(instant.wind_speed_of_gust) * 3.6
        : null,
      humidity: finiteNumber(instant.relative_humidity),
      uvIndex: finiteNumber(instant.ultraviolet_index_clear_sky)
    };
  });

  const currentHour = hours[0];
  const currentRaw = timeseries[0]?.data?.instant?.details || {};
  const days = aggregateMetDays(hours);
  const baseWarnings = buildWarnings(
    {
      weather_code: currentHour.weatherCode,
      wind_speed_10m: currentHour.windSpeed,
      wind_gusts_10m: currentHour.windGust
    },
    {
      precipitation_probability: hours.map(item => item.precipitationProbability),
      wind_speed_10m: hours.map(item => item.windSpeed),
      wind_gusts_10m: hours.map(item => item.windGust)
    },
    {
      uv_index_max: days.map(item => item.uvIndex),
      temperature_2m_max: days.map(item => item.maxTemperature),
      temperature_2m_min: days.map(item => item.minTemperature)
    }
  );
  const guidance = buildWeatherInsights(currentHour, hours.slice(0, 24), days, baseWarnings);
  const coordinates = data?.geometry?.coordinates || [];

  return {
    success: true,
    location: {
      name: locationName || '',
      latitude: finiteNumber(coordinates[1]) ?? latitude,
      longitude: finiteNumber(coordinates[0]) ?? longitude,
      elevation: finiteNumber(coordinates[2]),
      timezone: 'UTC',
      utcOffsetSeconds: 0
    },
    current: {
      time: currentHour.time,
      temperature: currentHour.temperature,
      apparentTemperature: currentHour.apparentTemperature,
      humidity: currentHour.humidity,
      precipitation: currentHour.precipitation,
      rain: currentHour.precipitation,
      weatherCode: currentHour.weatherCode,
      description: currentHour.description,
      cloudCover: currentHour.cloudCover,
      pressure: finiteNumber(currentRaw.air_pressure_at_sea_level),
      windSpeed: currentHour.windSpeed,
      windDirection: finiteNumber(currentRaw.wind_from_direction),
      windGust: currentHour.windGust,
      isDay: true
    },
    hourly: hours.slice(0, 24),
    daily: days,
    warnings: guidance.warnings,
    insights: guidance.insights,
    activities: guidance.activities,
    drivingWarning: guidance.drivingWarning,
    sponsoredRecommendations: guidance.sponsoredRecommendations,
    source: 'MET Norway',
    attribution: 'Weather data by MET Norway',
    updatedAt: new Date().toISOString(),
    fallback: true
  };
}

async function fetchWeather(latitude, longitude, locationName) {
  const key = `${latitude},${longitude}`;
  const cached = getCached(weatherCache, key);
  if (cached) return { ...cached, cached: true, stale: false };

  const stale = getStale(weatherCache, key);
  const retryAt = weatherBackoff.get(key) || 0;
  if (retryAt > Date.now()) {
    if (stale) return {
      ...stale,
      cached: true,
      stale: true,
      message: 'Yeni hava verisi şu anda alınamıyor. Son başarılı tahmin gösteriliyor.'
    };
    const error = new Error('Hava sağlayıcısı kısa süreliğine beklemede.');
    error.statusCode = 503;
    throw error;
  }

  if (weatherInFlight.has(key)) return weatherInFlight.get(key);

  const request = fetchWeatherFromProvider(latitude, longitude, locationName)
    .catch(async error => {
      const providerStatus = Number(error?.response?.status);
      if (providerStatus === 429 || providerStatus >= 500) {
        const retryAfterSeconds = Number(error.response.headers?.['retry-after']);
        const delay = Number.isFinite(retryAfterSeconds)
          ? Math.max(RATE_LIMIT_BACKOFF_MS, retryAfterSeconds * 1000)
          : RATE_LIMIT_BACKOFF_MS;
        weatherBackoff.set(key, Date.now() + delay);
        if (stale) return {
          ...stale,
          cached: true,
          stale: true,
          message: 'Yeni hava verisi şu anda alınamıyor. Son başarılı tahmin gösteriliyor.'
        };
        try {
          return await fetchWeatherFromBackupProvider(latitude, longitude, locationName);
        } catch (backupError) {
          backupError.cause = error;
          throw backupError;
        }
      }
      throw error;
    })
    .then(value => {
      if (value?.stale) return value;
      setCached(weatherCache, key, value, CACHE_TTL_MS, STALE_CACHE_TTL_MS);
      if (!value.fallback) weatherBackoff.delete(key);
      return { ...value, cached: false, stale: false };
    })
    .finally(() => weatherInFlight.delete(key));
  weatherInFlight.set(key, request);
  return request;
}

router.get('/search', async (req, res) => {
  const startedAt = Date.now();
  try {
    const query =
      normalizeText(req.query.q);

    if (query.length < 2) {
      return res.status(400).json({
        success: false,
        message:
          'En az 2 karakterlik şehir adı gir.'
      });
    }

    res.set(
      'Cache-Control',
      'public, max-age=3600'
    );

    const result = await searchLocation(query);
    sourceHealth.success('weather:geocoding', {
      recordCount: Array.isArray(result?.results) ? result.results.length : 0,
      responseTimeMs: Date.now() - startedAt
    });
    res.json(normalizeWeather(result, { source: 'Open-Meteo Geocoding' }));
  } catch (error) {
    sourceHealth.failure('weather:geocoding', error, { responseTimeMs: Date.now() - startedAt });
    console.error(
      '[HAVA ARAMA]',
      error.message
    );

    res.status(502).json({
      success: false,
      message:
        'Şehir araması şu anda alınamadı.',
      error: error.message
    });
  }
});

router.get('/', async (req, res) => {
  const startedAt = Date.now();
  try {
    const latitude =
      normalizeCoordinate(
        req.query.latitude ??
        req.query.lat,
        -90,
        90
      );

    const longitude =
      normalizeCoordinate(
        req.query.longitude ??
        req.query.lon,
        -180,
        180
      );

    const locationName =
      normalizeText(req.query.name);

    if (
      latitude === null ||
      longitude === null
    ) {
      return res.status(400).json({
        success: false,
        message:
          'Geçerli latitude ve longitude gönderilmelidir.'
      });
    }

    res.set(
      'Cache-Control',
      'public, max-age=300, stale-while-revalidate=600'
    );

    const result = await fetchWeather(
        latitude,
        longitude,
        locationName
      );
    sourceHealth.success('weather:forecast', {
      recordCount: Array.isArray(result?.hourly) ? result.hourly.length : 1,
      responseTimeMs: Date.now() - startedAt
    });
    res.json(normalizeWeather(result, { source: 'Open-Meteo Forecast' }));
  } catch (error) {
    sourceHealth.failure('weather:forecast', error, { responseTimeMs: Date.now() - startedAt });
    console.error(
      '[HAVA]',
      error.message
    );

    res.status(error.statusCode || (error?.response?.status === 429 ? 503 : 502)).json({
      success: false,
      message:
        'Hava durumu şu anda alınamadı.',
      error: error.message
    });
  }
});

router.get('/health', (req, res) => {
  cleanupCache(weatherCache);
  cleanupCache(searchCache);

  res.json({
    success: true,
    service: 'weather',
    weatherCacheItems:
      weatherCache.size,
    searchCacheItems:
      searchCache.size,
    cacheTtlMinutes:
      CACHE_TTL_MS / 60000,
    staleCacheTtlMinutes: STALE_CACHE_TTL_MS / 60000,
    inFlightRequests: weatherInFlight.size,
    backoffLocations: weatherBackoff.size
  });
});

module.exports = router;
module.exports._test = {
  fetchWeather,
  weatherCache,
  weatherInFlight,
  weatherBackoff,
  setWeatherRequester(requester) {
    weatherRequester = requester;
  },
  setBackupWeatherRequester(requester) {
    backupWeatherRequester = requester;
  },
  reset() {
    weatherRequester = (url, options) => axios.get(url, options);
    backupWeatherRequester = (url, options) => axios.get(url, options);
    weatherCache.clear();
    weatherInFlight.clear();
    weatherBackoff.clear();
  }
};
