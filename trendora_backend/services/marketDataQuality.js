'use strict';

const DEFAULT_MINIMUM_OBSERVATIONS = 35;
const DEFAULT_MAXIMUM_GAP_DAYS = 10;
const DEFAULT_EXTREME_CHANGE_PERCENT = 60;

function finiteNumber(value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function normalizeTimestamp(value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  if (value instanceof Date) {
    const milliseconds = value.getTime();
    return Number.isFinite(milliseconds)
      ? Math.floor(milliseconds / 1000)
      : null;
  }

  const numericValue = Number(value);

  if (Number.isFinite(numericValue)) {
    if (numericValue <= 0) return null;

    return numericValue >= 1e12
      ? Math.floor(numericValue / 1000)
      : Math.floor(numericValue);
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return Math.floor(parsed.getTime() / 1000);
}

function createIssue(code, message, details = {}) {
  return {
    code,
    message,
    ...details
  };
}

function normalizeRow(inputRow, index) {
  const row = inputRow && typeof inputRow === 'object'
    ? inputRow
    : {};

  return {
    originalIndex: index,
    timestamp: normalizeTimestamp(row.timestamp ?? row.date),
    open: finiteNumber(row.open),
    high: finiteNumber(row.high),
    low: finiteNumber(row.low),
    close: finiteNumber(row.close),
    volume: finiteNumber(row.volume)
  };
}

function inspectRow(row) {
  const issues = [];

  if (row.timestamp === null) {
    issues.push(createIssue(
      'invalid_timestamp',
      'Kayıtta geçerli zaman bilgisi bulunmuyor.'
    ));
  }

  const requiredPrices = [
    ['open', row.open],
    ['high', row.high],
    ['low', row.low],
    ['close', row.close]
  ];

  for (const [field, value] of requiredPrices) {
    if (value === null) {
      issues.push(createIssue(
        `invalid_${field}`,
        `${field} alanı geçerli bir sayı değil.`,
        { field }
      ));
      continue;
    }

    if (value <= 0) {
      issues.push(createIssue(
        `non_positive_${field}`,
        `${field} alanı sıfır veya negatif.`,
        { field, value }
      ));
    }
  }

  if (row.high !== null && row.low !== null && row.high < row.low) {
    issues.push(createIssue(
      'high_below_low',
      'En yüksek fiyat, en düşük fiyattan küçük.'
    ));
  }

  if (
    row.high !== null &&
    row.open !== null &&
    row.high < row.open
  ) {
    issues.push(createIssue(
      'high_below_open',
      'En yüksek fiyat, açılış fiyatından küçük.'
    ));
  }

  if (
    row.high !== null &&
    row.close !== null &&
    row.high < row.close
  ) {
    issues.push(createIssue(
      'high_below_close',
      'En yüksek fiyat, kapanış fiyatından küçük.'
    ));
  }

  if (
    row.low !== null &&
    row.open !== null &&
    row.low > row.open
  ) {
    issues.push(createIssue(
      'low_above_open',
      'En düşük fiyat, açılış fiyatından büyük.'
    ));
  }

  if (
    row.low !== null &&
    row.close !== null &&
    row.low > row.close
  ) {
    issues.push(createIssue(
      'low_above_close',
      'En düşük fiyat, kapanış fiyatından büyük.'
    ));
  }

  if (row.volume !== null && row.volume < 0) {
    issues.push(createIssue(
      'negative_volume',
      'Hacim değeri negatif.',
      { value: row.volume }
    ));
  }

  return issues;
}

function isFatalIssue(issue) {
  return [
    'invalid_timestamp',
    'invalid_open',
    'invalid_high',
    'invalid_low',
    'invalid_close',
    'non_positive_open',
    'non_positive_high',
    'non_positive_low',
    'non_positive_close',
    'high_below_low',
    'high_below_open',
    'high_below_close',
    'low_above_open',
    'low_above_close'
  ].includes(issue.code);
}

function calculateAgeDays(timestamp) {
  if (!Number.isFinite(timestamp)) return null;

  const ageMilliseconds = Date.now() - timestamp * 1000;

  if (!Number.isFinite(ageMilliseconds)) return null;

  return Math.max(0, ageMilliseconds / 86400000);
}

function determineQuality({
  originalCount,
  validCount,
  filteredCount,
  duplicateCount,
  gapCount,
  extremeMovementCount,
  latestTimestamp,
  minimumObservations
}) {
  if (validCount === 0) {
    return {
      level: 'unusable',
      label: 'Kullanılamaz',
      score: 0
    };
  }

  const validRatio = originalCount > 0
    ? validCount / originalCount
    : 0;

  const ageDays = calculateAgeDays(latestTimestamp);

  let score = 100;

  score -= Math.round((1 - validRatio) * 70);
  score -= Math.min(20, duplicateCount * 3);
  score -= Math.min(20, gapCount * 4);
  score -= Math.min(15, extremeMovementCount * 2);

  if (validCount < minimumObservations) {
    score -= 30;
  }

  if (ageDays === null) {
    score -= 15;
  } else if (ageDays > 30) {
    score -= 25;
  } else if (ageDays > 7) {
    score -= 15;
  } else if (ageDays > 3) {
    score -= 5;
  }

  if (filteredCount > Math.max(5, originalCount * 0.2)) {
    score -= 15;
  }

  score = Math.max(0, Math.min(100, score));

  if (score >= 90) {
    return {
      level: 'excellent',
      label: 'Mükemmel',
      score
    };
  }

  if (score >= 75) {
    return {
      level: 'good',
      label: 'İyi',
      score
    };
  }

  if (score >= 50) {
    return {
      level: 'limited',
      label: 'Sınırlı',
      score
    };
  }

  if (score >= 25) {
    return {
      level: 'poor',
      label: 'Zayıf',
      score
    };
  }

  return {
    level: 'unusable',
    label: 'Kullanılamaz',
    score
  };
}

function validateMarketRows(inputRows, options = {}) {
  const rows = Array.isArray(inputRows)
    ? inputRows
    : [];

  const minimumObservations = Number.isFinite(
    Number(options.minimumObservations)
  )
    ? Math.max(1, Number(options.minimumObservations))
    : DEFAULT_MINIMUM_OBSERVATIONS;

  const maximumGapDays = Number.isFinite(
    Number(options.maximumGapDays)
  )
    ? Math.max(1, Number(options.maximumGapDays))
    : DEFAULT_MAXIMUM_GAP_DAYS;

  const extremeChangePercent = Number.isFinite(
    Number(options.extremeChangePercent)
  )
    ? Math.max(1, Number(options.extremeChangePercent))
    : DEFAULT_EXTREME_CHANGE_PERCENT;

  const rejectedRows = [];
  const warnings = [];
  const normalizedRows = [];

  rows.forEach((inputRow, index) => {
    const row = normalizeRow(inputRow, index);
    const rowIssues = inspectRow(row);
    const fatalIssues = rowIssues.filter(isFatalIssue);

    if (fatalIssues.length > 0) {
      rejectedRows.push({
        index,
        timestamp: row.timestamp,
        issues: fatalIssues
      });
      return;
    }

    if (row.volume !== null && row.volume < 0) {
      warnings.push(createIssue(
        'negative_volume_removed',
        'Negatif hacim değeri boş değere çevrildi.',
        {
          index,
          timestamp: row.timestamp
        }
      ));

      row.volume = null;
    }

    normalizedRows.push(row);
  });

  normalizedRows.sort((left, right) => (
    left.timestamp - right.timestamp
  ));

  const uniqueRows = [];
  const timestampIndexes = new Map();
  let duplicateCount = 0;

  for (const row of normalizedRows) {
    if (!timestampIndexes.has(row.timestamp)) {
      timestampIndexes.set(row.timestamp, uniqueRows.length);
      uniqueRows.push(row);
      continue;
    }

    duplicateCount += 1;

    const existingIndex = timestampIndexes.get(row.timestamp);
    const existing = uniqueRows[existingIndex];

    const existingCompleteness = [
      existing.open,
      existing.high,
      existing.low,
      existing.close,
      existing.volume
    ].filter((value) => value !== null).length;

    const candidateCompleteness = [
      row.open,
      row.high,
      row.low,
      row.close,
      row.volume
    ].filter((value) => value !== null).length;

    if (candidateCompleteness > existingCompleteness) {
      uniqueRows[existingIndex] = row;
    }
  }

  if (duplicateCount > 0) {
    warnings.push(createIssue(
      'duplicate_timestamps',
      'Tekrarlanan zaman kayıtları tekilleştirildi.',
      { count: duplicateCount }
    ));
  }

  let gapCount = 0;
  let extremeMovementCount = 0;

  for (let index = 1; index < uniqueRows.length; index += 1) {
    const previous = uniqueRows[index - 1];
    const current = uniqueRows[index];

    const differenceSeconds = current.timestamp - previous.timestamp;
    const differenceDays = differenceSeconds / 86400;

    if (differenceDays > maximumGapDays) {
      gapCount += 1;

      warnings.push(createIssue(
        'large_time_gap',
        'Piyasa verisi serisinde büyük zaman boşluğu tespit edildi.',
        {
          from: previous.timestamp,
          to: current.timestamp,
          gapDays: Number(differenceDays.toFixed(2))
        }
      ));
    }

    if (
      previous.close !== null &&
      previous.close > 0 &&
      current.close !== null
    ) {
      const changePercent = Math.abs(
        ((current.close - previous.close) / previous.close) * 100
      );

      if (changePercent > extremeChangePercent) {
        extremeMovementCount += 1;

        warnings.push(createIssue(
          'extreme_price_movement',
          'Aşırı fiyat hareketi tespit edildi. Bölünme veya veri anomalisi olabilir.',
          {
            timestamp: current.timestamp,
            changePercent: Number(changePercent.toFixed(2))
          }
        ));
      }
    }
  }

  const cleanedRows = uniqueRows.map((row) => ({
    timestamp: row.timestamp,
    open: row.open,
    high: row.high,
    low: row.low,
    close: row.close,
    volume: row.volume
  }));

  const originalCount = rows.length;
  const validCount = cleanedRows.length;
  const filteredCount = Math.max(0, originalCount - validCount);
  const latestTimestamp = cleanedRows.length
    ? cleanedRows[cleanedRows.length - 1].timestamp
    : null;

  if (validCount < minimumObservations) {
    warnings.push(createIssue(
      'insufficient_observations',
      'Teknik analiz için gözlem sayısı sınırlı.',
      {
        available: validCount,
        required: minimumObservations
      }
    ));
  }

  const quality = determineQuality({
    originalCount,
    validCount,
    filteredCount,
    duplicateCount,
    gapCount,
    extremeMovementCount,
    latestTimestamp,
    minimumObservations
  });

  return {
    rows: cleanedRows,
    quality,
    warnings,
    rejectedRows,
    statistics: {
      originalCount,
      validCount,
      filteredCount,
      duplicateCount,
      gapCount,
      extremeMovementCount,
      latestTimestamp,
      minimumObservations
    }
  };
}

function sanitizePriceLevels(levels) {
  if (!Array.isArray(levels)) {
    return [];
  }

  return [...new Set(
    levels
      .map(finiteNumber)
      .filter((value) => value !== null && value > 0)
  )];
}

module.exports = {
  finiteNumber,
  normalizeTimestamp,
  sanitizePriceLevels,
  validateMarketRows
};