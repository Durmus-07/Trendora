'use strict';

const STORM_CODES = new Set([95, 96, 99]);
const ICING_CODES = new Set([56, 57, 66, 67]);
const UNSAFE_PRECIPITATION_CODES = new Set([
  56, 57, 65, 66, 67, 71, 73, 75, 77, 82, 85, 86, 95, 96, 99
]);

function number(value, fallback = 0) {
  if (value === null || value === undefined || value === '') return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function hourOf(value) {
  const match = String(value || '').match(/T(\d{2}):/);
  return match ? Number(match[1]) : null;
}

function hourLabel(value) {
  const hour = hourOf(value);
  return hour === null ? null : `${String(hour).padStart(2, '0')}.00`;
}

function firstMatching(hours, predicate) {
  return hours.find(hour => predicate(hour)) || null;
}

function timeRange(hours) {
  if (!hours.length) return null;
  const start = hourLabel(hours[0].time);
  const endHour = hourOf(hours[hours.length - 1].time);
  if (!start || endHour === null) return null;
  const end = `${String((endHour + 1) % 24).padStart(2, '0')}.00`;
  return `${start}–${end}`;
}

function contiguousWindow(hours, predicate, minimumHours = 2) {
  let current = [];
  for (const hour of hours) {
    if (predicate(hour)) {
      current.push(hour);
    } else {
      if (current.length >= minimumHours) return current;
      current = [];
    }
  }
  return current.length >= minimumHours ? current : [];
}

function matchingSequence(hours, predicate) {
  const start = hours.findIndex(predicate);
  if (start < 0) return [];
  const result = [];
  for (let index = start; index < hours.length; index += 1) {
    if (!predicate(hours[index])) break;
    result.push(hours[index]);
  }
  return result;
}

function addWarning(warnings, warning) {
  if (!warnings.some(item => item.type === warning.type)) {
    warnings.push(warning);
  }
}

function safeOutdoorHour(hour, { child = false } = {}) {
  const clockHour = hourOf(hour.time);
  if (clockHour === null) return false;
  const temperature = number(hour.temperature, Number.NaN);
  const apparent = number(hour.apparentTemperature, temperature);
  const precipitation = number(hour.precipitationProbability);
  const wind = number(hour.windSpeed);
  const gust = number(hour.windGust);
  const uv = number(hour.uvIndex);
  const visibility = number(hour.visibility, 10000);
  const code = number(hour.weatherCode, -1);

  if (STORM_CODES.has(code) || UNSAFE_PRECIPITATION_CODES.has(code)) return false;
  if (child) {
    return clockHour >= 8 && clockHour <= 19 && temperature >= 10 &&
      temperature <= 28 && apparent >= 8 && apparent <= 30 &&
      precipitation < 20 && wind < 20 && gust < 30 && uv < 6 &&
      visibility >= 3000;
  }
  return clockHour >= 7 && clockHour <= 21 && temperature >= 8 &&
    temperature <= 30 && apparent >= 5 && apparent <= 32 &&
    precipitation < 30 && wind < 25 && gust < 40 && uv < 6 &&
    visibility >= 2000;
}

function buildWeatherInsights(current, hours, days, baseWarnings = []) {
  const next12 = Array.isArray(hours) ? hours.slice(0, 12) : [];
  const next24 = Array.isArray(hours) ? hours.slice(0, 24) : [];
  const warnings = Array.isArray(baseWarnings)
    ? baseWarnings.map(item => ({ ...item }))
    : [];
  const insights = [];
  const activities = [];

  const stormHour = firstMatching(next12, hour =>
    STORM_CODES.has(number(hour.weatherCode, -1))
  );
  if (stormHour) {
    const at = hourLabel(stormHour.time);
    addWarning(warnings, {
      level: 'high',
      type: 'storm',
      message: at
        ? `Saat ${at} civarında gök gürültülü fırtına başlayabilir.`
        : 'Önümüzdeki saatlerde gök gürültülü fırtına etkili olabilir.'
    });
  }

  const icingHour = firstMatching(next12, hour =>
    ICING_CODES.has(number(hour.weatherCode, -1))
  );
  if (icingHour) {
    const at = hourLabel(icingHour.time);
    addWarning(warnings, {
      level: 'high',
      type: 'icing',
      message: at
        ? `Saat ${at} civarında buzlanma riski bulunuyor.`
        : 'Buzlanma riski bulunuyor.'
    });
  }

  const lowVisibilityHour = firstMatching(next12, hour =>
    number(hour.visibility, 10000) < 1000
  );
  if (lowVisibilityHour) {
    const at = hourLabel(lowVisibilityHour.time);
    addWarning(warnings, {
      level: number(lowVisibilityHour.visibility, 10000) < 500 ? 'high' : 'medium',
      type: 'low_visibility',
      message: at
        ? `Saat ${at} civarında görüş mesafesi düşebilir.`
        : 'Görüş mesafesi düşebilir.'
    });
  }

  const rainHour = firstMatching(next12, hour =>
    number(hour.precipitationProbability) >= 50
  );
  if (rainHour) {
    const at = hourLabel(rainHour.time);
    const clockHour = hourOf(rainHour.time);
    const rainLevel = number(rainHour.precipitationProbability) >= 75
      ? 'high'
      : 'medium';
    addWarning(warnings, {
      level: rainLevel,
      type: 'rain',
      message: at
        ? `Saat ${at} civarında yağış başlayabilir.`
        : 'Önümüzdeki saatlerde yağış bekleniyor.'
    });
    insights.push({
      type: 'rain_timing',
      message: clockHour !== null && clockHour >= 18
        ? 'Akşam yağış bekleniyor.'
        : at
          ? `Saat ${at} civarında yağış başlayabilir.`
          : 'Önümüzdeki saatlerde yağış bekleniyor.'
    });
  }

  const windHour = firstMatching(next12, hour =>
    number(hour.windSpeed) >= 35 || number(hour.windGust) >= 50
  );
  if (windHour) {
    const at = hourLabel(windHour.time);
    const windLevel = number(windHour.windSpeed) >= 50 ||
      number(windHour.windGust) >= 70
      ? 'high'
      : 'medium';
    addWarning(warnings, {
      level: windLevel,
      type: 'wind',
      message: at
        ? `Saat ${at} civarında kuvvetli rüzgâr başlayabilir.`
        : 'Önümüzdeki saatlerde kuvvetli rüzgâr başlayabilir.'
    });
    insights.push({
      type: 'wind_timing',
      message: at
        ? `Saat ${at} civarında kuvvetli rüzgâr başlayabilir.`
        : 'Önümüzdeki saatlerde kuvvetli rüzgâr başlayabilir.'
    });
  }

  const uvHours = matchingSequence(next12, hour => number(hour.uvIndex) >= 6);
  if (uvHours.length) {
    const range = timeRange(uvHours);
    const maxUv = Math.max(...uvHours.map(hour => number(hour.uvIndex)));
    addWarning(warnings, {
      level: maxUv >= 8 ? 'high' : 'medium',
      type: 'uv',
      message: range
        ? `Saat ${range} arasında UV yüksek.`
        : 'Önümüzdeki saatlerde UV yüksek.'
    });
    insights.push({
      type: 'uv_timing',
      message: range
        ? `Saat ${range} arasında UV yüksek.`
        : 'Önümüzdeki saatlerde UV yüksek.'
    });
  }

  const walkWindow = contiguousWindow(next24, hour => safeOutdoorHour(hour));
  if (walkWindow.length) {
    const range = timeRange(walkWindow);
    activities.push({
      type: 'walking',
      suitable: true,
      startTime: walkWindow[0].time,
      endTime: walkWindow[walkWindow.length - 1].time,
      message: range
        ? `Bugün ${range} arası yürüyüş için daha uygun.`
        : 'Bugün yürüyüş için uygun bir zaman aralığı bulunuyor.'
    });
  }

  const childWindow = contiguousWindow(
    next24,
    hour => safeOutdoorHour(hour, { child: true })
  );
  if (childWindow.length) {
    const range = timeRange(childWindow);
    activities.push({
      type: 'with_children',
      suitable: true,
      startTime: childWindow[0].time,
      endTime: childWindow[childWindow.length - 1].time,
      message: range
        ? `Bugün ${range} arası çocukla dışarı çıkmak için daha uygun.`
        : 'Bugün çocukla dışarı çıkmak için uygun bir zaman aralığı bulunuyor.'
    });
  }

  const drivingReasons = [];
  if (stormHour) drivingReasons.push('fırtına');
  if (icingHour) drivingReasons.push('buzlanma');
  if (lowVisibilityHour) drivingReasons.push('düşük görüş');
  if (firstMatching(next12, hour =>
    number(hour.precipitationProbability) >= 75 ||
    number(hour.windGust) >= 70 ||
    UNSAFE_PRECIPITATION_CODES.has(number(hour.weatherCode, -1))
  )) {
    drivingReasons.push('olumsuz hava');
  }

  return {
    warnings: warnings.slice(0, 8),
    insights,
    activities,
    drivingWarning: drivingReasons.length
      ? {
          level: 'high',
          reasons: [...new Set(drivingReasons)],
          message: 'Araç kullanırken hızını ve takip mesafeni hava koşullarına göre ayarla.'
        }
      : null,
    sponsoredRecommendations: []
  };
}

module.exports = { buildWeatherInsights };
